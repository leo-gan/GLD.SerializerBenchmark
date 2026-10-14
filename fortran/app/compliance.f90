program compliance_fortran
  ! Parse-only probe for the JSON, TOML, HDF5, NetCDF, and ADIOS2 corpora.
  !   compliance_fortran json|toml|hdf5|netcdf|adios2 cases.bin outcomes.bin
  ! cases.bin: int32 count, then (int32 nbytes, bytes) in little-endian.
  ! outcomes.bin: for each case, int32 ok (1 accepted), int32 nbytes, bytes of
  ! the library's re-serialized text (empty when the parse failed).
  ! HDF5 and NetCDF inputs are raw file bytes. ADIOS2 inputs are a directory
  ! entry name (empty means an empty directory).
  use, intrinsic :: iso_fortran_env, only: int8, int32, real64
  use json_module, only: json_core, json_value
  use jonquil, only: json_loads, json_dumps, json_error, jq_value => json_value
  use rojff, only: fallible_json_value_t, parse_json_from_string
  use messagepack, only: msgpack, mp_value_type
  use tomlf, only: toml_table, toml_error, toml_serialize, toml_loads
  use hdf5
  use netcdf
  use adios2
  implicit none

  character(len=16) :: fmt
  character(len=1024) :: in_path, out_path
  integer :: in_unit, out_unit, ios, n, i, narg
  integer(int32) :: ncases, nbytes, ok, dlen
  character(len=:), allocatable :: text, dump

  narg = command_argument_count()
  if (narg < 3) then
    write(0, '(A)') "usage: compliance_fortran json|jonquil|rojff|toml|msgpack|hdf5|netcdf|adios2 cases.bin outcomes.bin"
    error stop 2
  end if
  call get_command_argument(1, fmt, length=n)
  call get_command_argument(2, in_path)
  call get_command_argument(3, out_path)
  open(newunit=in_unit, file=trim(in_path), access="stream", form="unformatted", &
       status="old", action="read", iostat=ios)
  if (ios /= 0) error stop 1
  open(newunit=out_unit, file=trim(out_path), access="stream", form="unformatted", &
       status="replace", action="write", iostat=ios)
  if (ios /= 0) error stop 1
  read(in_unit, iostat=ios) ncases
  if (ios /= 0 .or. ncases < 0) error stop 1
  do i = 1, int(ncases)
    read(in_unit, iostat=ios) nbytes
    if (ios /= 0 .or. nbytes < 0) error stop 1
    if (allocated(text)) deallocate(text)
    if (nbytes == 0) then
      text = ""
    else
      allocate(character(len=nbytes) :: text)
      read(in_unit, iostat=ios) text
      if (ios /= 0) error stop 1
    end if
    if (fmt(1:n) == "toml") then
      call parse_toml(text, ok, dump)
    else if (fmt(1:n) == "jonquil") then
      call parse_jonquil(text, ok, dump)
    else if (fmt(1:n) == "rojff") then
      call parse_rojff(text, ok, dump)
    else if (fmt(1:n) == "msgpack") then
      call probe_msgpack(text, ok, dump)
    else if (fmt(1:n) == "hdf5") then
      call probe_hdf5(text, ok, dump)
    else if (fmt(1:n) == "netcdf") then
      call probe_netcdf(text, ok, dump)
    else if (fmt(1:n) == "adios2") then
      call probe_adios2(text, ok, dump)
    else
      call parse_json(text, ok, dump)
    end if
    if (.not. allocated(dump)) dump = ""
    dlen = int(len(dump), int32)
    write(out_unit) ok
    write(out_unit) dlen
    if (dlen > 0) write(out_unit) dump
  end do
  close(in_unit)
  close(out_unit)

contains

  subroutine parse_json(text, ok, dump)
    character(len=*), intent(in) :: text
    integer(int32), intent(out) :: ok
    character(len=:), allocatable, intent(out) :: dump
    type(json_core) :: core
    type(json_value), pointer :: root
    ok = 0_int32
    dump = ""
    root => null()
    call core%initialize()
    call core%deserialize(root, text)
    if (.not. core%failed() .and. associated(root)) then
      call core%serialize(root, dump)
      if (.not. core%failed() .and. allocated(dump)) ok = 1_int32
    end if
    if (.not. allocated(dump)) dump = ""
    if (associated(root)) call core%destroy(root)
  end subroutine

  subroutine parse_jonquil(text, ok, dump)
    character(len=*), intent(in) :: text
    integer(int32), intent(out) :: ok
    character(len=:), allocatable, intent(out) :: dump
    class(jq_value), allocatable :: value
    type(json_error), allocatable :: error
    ok = 0_int32
    dump = ""
    call json_loads(value, text, error=error)
    if (allocated(error) .or. .not. allocated(value)) return
    ok = 1_int32
    call json_dumps(value, dump, error=error)
    if (allocated(error) .or. .not. allocated(dump)) dump = ""
  end subroutine

  subroutine parse_rojff(text, ok, dump)
    character(len=*), intent(in) :: text
    integer(int32), intent(out) :: ok
    character(len=:), allocatable, intent(out) :: dump
    type(fallible_json_value_t) :: parsed
    ok = 0_int32
    dump = ""
    parsed = parse_json_from_string(text)
    if (parsed%failed()) return
    ok = 1_int32
    dump = ""
    ! rojff formats some reals into a 34-character buffer and aborts with
    ! "End of record" (utils_s.f90). That abort is the re-serialization, not
    ! the parse. Keep the accept and leave the dump empty when it happens.
    call safe_rojff_dump(parsed, dump)
  end subroutine

  subroutine safe_rojff_dump(parsed, dump)
    use iso_c_binding, only: c_int, c_char, c_ptr, c_loc, c_size_t, c_null_char, c_long
    type(fallible_json_value_t), intent(in) :: parsed
    character(len=:), allocatable, intent(out) :: dump
    interface
      function c_pipe(fds) bind(C, name="pipe")
        import :: c_int
        integer(c_int) :: c_pipe
        integer(c_int), intent(out) :: fds(2)
      end function
      function c_fork() bind(C, name="fork")
        import :: c_int
        integer(c_int) :: c_fork
      end function
      function c_read(fd, buf, n) bind(C, name="read")
        import :: c_int, c_ptr, c_long, c_size_t
        integer(c_long) :: c_read
        integer(c_int), value :: fd
        type(c_ptr), value :: buf
        integer(c_size_t), value :: n
      end function
      function c_write(fd, buf, n) bind(C, name="write")
        import :: c_int, c_ptr, c_long, c_size_t
        integer(c_long) :: c_write
        integer(c_int), value :: fd
        type(c_ptr), value :: buf
        integer(c_size_t), value :: n
      end function
      function c_close(fd) bind(C, name="close")
        import :: c_int
        integer(c_int) :: c_close
        integer(c_int), value :: fd
      end function
      function c_open(path, flags) bind(C, name="open")
        import :: c_int, c_ptr
        integer(c_int) :: c_open
        type(c_ptr), value :: path
        integer(c_int), value :: flags
      end function
      function c_dup2(oldfd, newfd) bind(C, name="dup2")
        import :: c_int
        integer(c_int) :: c_dup2
        integer(c_int), value :: oldfd, newfd
      end function
      subroutine c_exit(code) bind(C, name="_exit")
        import :: c_int
        integer(c_int), value :: code
      end subroutine
      function c_waitpid(pid, stat, opt) bind(C, name="waitpid")
        import :: c_int
        integer(c_int) :: c_waitpid
        integer(c_int), value :: pid
        integer(c_int), intent(out) :: stat
        integer(c_int), value :: opt
      end function
    end interface
    integer(c_int) :: fds(2), pid, stat, rc, devnull
    integer(c_long) :: nw
    integer :: total, i
    integer(c_size_t) :: n, off
    character(len=10), target :: dev
    character(len=:), allocatable :: text
    character(kind=c_char), allocatable, target :: raw(:), buf(:), got(:), bigger(:)

    dump = ""
    if (.not. allocated(parsed%value_)) return
    ! The outcome and case files are still open. Flush them before the fork so
    ! a child that dies inside rojff cannot flush a copy of those buffers and
    ! move the shared file offset. The child then closes its copies.
    flush(out_unit)
    flush(in_unit)
    if (c_pipe(fds) /= 0) return
    pid = c_fork()
    if (pid < 0) then
      rc = c_close(fds(1))
      rc = c_close(fds(2))
      return
    end if
    if (pid == 0) then
      close(out_unit)
      close(in_unit)
      rc = c_close(fds(1))
      dev = "/dev/null" // c_null_char
      devnull = c_open(c_loc(dev), 1_c_int)
      if (devnull >= 0) then
        rc = c_dup2(devnull, 2_c_int)
        rc = c_close(devnull)
      end if
      text = parsed%value_%to_compact_string()
      if (.not. allocated(text)) call c_exit(1_c_int)
      n = len(text, kind=c_size_t)
      if (n > 0) then
        allocate(raw(n))
        do i = 1, int(n)
          raw(i) = text(i:i)
        end do
        off = 0_c_size_t
        do while (off < n)
          nw = c_write(fds(2), c_loc(raw(int(off) + 1)), n - off)
          if (nw <= 0) call c_exit(1_c_int)
          off = off + int(nw, c_size_t)
        end do
      end if
      call c_exit(0_c_int)
    end if
    rc = c_close(fds(2))
    total = 0
    allocate(buf(8192))
    do
      nw = c_read(fds(1), c_loc(buf(1)), int(size(buf), c_size_t))
      if (nw < 0) then
        rc = c_close(fds(1))
        rc = c_waitpid(pid, stat, 0_c_int)
        return
      end if
      if (nw == 0) exit
      allocate(bigger(total + int(nw)))
      if (total > 0) bigger(1:total) = got(1:total)
      bigger(total + 1:total + int(nw)) = buf(1:int(nw))
      call move_alloc(bigger, got)
      total = total + int(nw)
    end do
    rc = c_close(fds(1))
    rc = c_waitpid(pid, stat, 0_c_int)
    if (iand(stat, 127) == 0 .and. ishft(stat, -8) == 0 .and. total > 0) then
      block
        character(len=total) :: copied
        do i = 1, total
          copied(i:i) = got(i)
        end do
        dump = copied
      end block
    end if
  end subroutine

  subroutine probe_msgpack(text, ok, dump)
    character(len=*), intent(in) :: text
    integer(int32), intent(out) :: ok
    character(len=:), allocatable, intent(out) :: dump
    integer(int8), allocatable :: bytes(:)
    type(msgpack) :: mp
    class(mp_value_type), allocatable :: root
    ok = 0_int32
    dump = ""
    if (len(text) == 0) then
      allocate(bytes(0))
    else
      allocate(bytes(len(text)))
      bytes = transfer(text, bytes, len(text))
    end if
    mp = msgpack()
    call mp%extra_bytes_is_error(.true.)
    call mp%unpack(bytes, root)
    if (.not. mp%failed() .and. allocated(root)) ok = 1_int32
  end subroutine

  subroutine parse_toml(text, ok, dump)
    character(len=*), intent(in) :: text
    integer(int32), intent(out) :: ok
    character(len=:), allocatable, intent(out) :: dump
    type(toml_table), allocatable :: table
    type(toml_error), allocatable :: error
    ok = 0_int32
    dump = ""
    call toml_loads(table, text, error=error)
    if (.not. allocated(error) .and. allocated(table)) then
      dump = toml_serialize(table)
      if (allocated(dump)) ok = 1_int32
    end if
    if (.not. allocated(dump)) dump = ""
  end subroutine

  subroutine write_payload(path, text, ios)
    character(len=*), intent(in) :: path, text
    integer, intent(out) :: ios
    integer :: unit
    open(newunit=unit, file=path, access="stream", form="unformatted", &
         status="replace", action="write", iostat=ios)
    if (ios /= 0) return
    if (len(text) > 0) write(unit, iostat=ios) text
    close(unit)
  end subroutine

  subroutine probe_hdf5(text, ok, dump)
    character(len=*), intent(in) :: text
    integer(int32), intent(out) :: ok
    character(len=:), allocatable, intent(out) :: dump
    integer :: err, unit_err
    logical :: is_h5
    logical, save :: opened = .false.
    character(len=*), parameter :: path = "/tmp/gld-cmp-fortran.h5"
    ok = 0_int32
    dump = ""
    if (.not. opened) then
      call h5open_f(err)
      if (err == 0) call h5eset_auto_f(0, err)
      opened = .true.
    end if
    call write_payload(path, text, unit_err)
    if (unit_err /= 0) return
    is_h5 = .false.
    call h5fis_hdf5_f(path, is_h5, err)
    if (err == 0 .and. is_h5) ok = 1_int32
  end subroutine

  subroutine probe_netcdf(text, ok, dump)
    character(len=*), intent(in) :: text
    integer(int32), intent(out) :: ok
    character(len=:), allocatable, intent(out) :: dump
    integer :: ncid, stat, unit_err
    character(len=*), parameter :: path = "/tmp/gld-cmp-fortran.nc"
    ok = 0_int32
    dump = ""
    call write_payload(path, text, unit_err)
    if (unit_err /= 0) return
    stat = nf90_open(path, NF90_NOWRITE, ncid)
    if (stat /= nf90_noerr) return
    stat = nf90_close(ncid)
    if (stat == nf90_noerr) ok = 1_int32
  end subroutine

  subroutine probe_adios2(text, ok, dump)
    ! Empty text: this library must refuse a fresh empty directory.
    ! Any other text is a file name. This library writes a one-step BP5
    ! directory, that name must exist in it, and this library reads it back.
    character(len=*), intent(in) :: text
    integer(int32), intent(out) :: ok
    character(len=:), allocatable, intent(out) :: dump
    type(adios2_adios), save :: adios
    logical, save :: ready = .false.
    integer, save :: seq = 0
    type(adios2_io) :: io
    type(adios2_engine) :: eng
    type(adios2_variable) :: var
    real(real64) :: values(1, 1)
    integer(kind=8) :: shp(2), sta(2), cnt(2)
    integer :: stat, ierr
    logical :: exist
    character(len=32) :: ioname
    character(len=*), parameter :: empty_dir = "/tmp/gld-cmp-f-empty"
    character(len=*), parameter :: bp_dir = "/tmp/gld-cmp-f-bp5"
    ok = 0_int32
    dump = ""
    if (.not. ready) then
      call adios2_init(adios, stat)
      if (stat /= 0) return
      ready = .true.
    end if
    if (len_trim(text) == 0) then
      call execute_command_line("rm -rf " // empty_dir // " && mkdir -p " // empty_dir, exitstat=stat)
      if (stat /= 0) return
      seq = seq + 1
      write(ioname, '("ce",I0)') seq
      call adios2_declare_io(io, adios, trim(ioname), stat)
      if (stat /= 0) return
      call adios2_set_engine(io, "BP5", stat)
      if (stat /= 0) return
      call adios2_open(eng, io, empty_dir, adios2_mode_readRandomAccess, stat)
      if (stat == 0) then
        call adios2_close(eng, ierr)
        ok = 1_int32
      end if
      return
    end if
    if (index(text, "/") /= 0) return
    call execute_command_line("rm -rf " // bp_dir // " && mkdir -p " // bp_dir, exitstat=stat)
    if (stat /= 0) return
    seq = seq + 1
    write(ioname, '("cw",I0)') seq
    call adios2_declare_io(io, adios, trim(ioname), stat)
    if (stat /= 0) return
    call adios2_set_engine(io, "BP5", stat)
    if (stat /= 0) return
    shp = 1_8
    sta = 0_8
    cnt = 1_8
    values(1, 1) = 1.0_real64
    call adios2_define_variable(var, io, "grid", adios2_type_real8, 2, shp, sta, cnt, &
         adios2_constant_dims, stat)
    if (stat /= 0) return
    call adios2_open(eng, io, bp_dir, adios2_mode_write, stat)
    if (stat /= 0) return
    call adios2_begin_step(eng, adios2_step_mode_append, stat)
    if (stat == 0) call adios2_put(eng, var, values, adios2_mode_sync, stat)
    if (stat == 0) call adios2_end_step(eng, stat)
    call adios2_close(eng, ierr)
    if (stat /= 0 .or. ierr /= 0) return
    inquire(file=bp_dir // "/" // trim(text), exist=exist)
    if (.not. exist) return
    seq = seq + 1
    write(ioname, '("cr",I0)') seq
    call adios2_declare_io(io, adios, trim(ioname), stat)
    if (stat /= 0) return
    call adios2_set_engine(io, "BP5", stat)
    if (stat /= 0) return
    call adios2_open(eng, io, bp_dir, adios2_mode_readRandomAccess, stat)
    if (stat /= 0) return
    call adios2_inquire_variable(var, io, "grid", stat)
    if (stat == 0) call adios2_get(eng, var, values, adios2_mode_sync, stat)
    call adios2_close(eng, ierr)
    if (stat == 0 .and. ierr == 0) ok = 1_int32
  end subroutine

end program compliance_fortran
