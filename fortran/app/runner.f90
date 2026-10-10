program serializer_benchmark_fortran
  use, intrinsic :: iso_fortran_env, only: int8, int64, real64
  use, intrinsic :: iso_c_binding, only: c_ptr, c_loc, c_size_t, c_int64_t, c_int
  use bench_data
  use custom_binary
  use csv_log
  use schedule
  use ser_json_fortran
  use ser_jonquil
  use ser_rojff
  use ser_tomlf
  use ser_msgpack
  use ser_hdf5
  use ser_netcdf
  use ser_adios2
  implicit none

  integer, parameter :: max_sers = 12
  integer, parameter :: ser_custom = 1
  integer, parameter :: ser_jf = 2
  integer, parameter :: ser_jonquil = 3
  integer, parameter :: ser_rojff = 4
  integer, parameter :: ser_toml = 5
  integer, parameter :: ser_mp = 6
  integer, parameter :: ser_h5 = 7
  integer, parameter :: ser_nc = 8
  integer, parameter :: ser_ad = 9
  integer, parameter :: buf_cap = 8 * 1024 * 1024
  character(len=64) :: ser_names(max_sers)
  character(len=32) :: ser_versions(max_sers)
  integer :: nser
  integer(int8), target :: buf(buf_cap)
  integer(int64) :: seed, clock_rate
  logical :: use_none, record_ro

  interface
    subroutine black_box_bytes(p, n) bind(C, name="black_box_bytes")
      import :: c_ptr, c_size_t
      type(c_ptr), value :: p
      integer(c_size_t), value :: n
    end subroutine
    subroutine bench_compress_sizes(data, n, gz, zs) bind(C, name="bench_compress_sizes")
      import :: c_ptr, c_size_t
      type(c_ptr), value :: data
      integer(c_size_t), value :: n
      integer(c_size_t), intent(out) :: gz, zs
    end subroutine
    function c_getpid() bind(C, name="getpid") result(pid)
      import :: c_int
      integer(c_int) :: pid
    end function
  end interface

  call load_registry()
  if (.not. schedule_ok()) then
    write(0, '(A)') "schedule golden vector mismatch"
    error stop 1
  end if
  seed = read_seed()
  use_none = schedule_is_none()
  record_ro = schedule_record_run_order()
  call system_clock(count_rate=clock_rate)
  write(*, '(A,I0,A,I0)') "[PROGRESS] fortran serializers=", nser, " clock_rate=", clock_rate
  call run()

contains

  subroutine load_registry()
    integer :: prep
    nser = 9
    ser_names(ser_custom) = cb_name
    ser_versions(ser_custom) = cb_version
    ser_names(ser_jf) = jf_name
    ser_versions(ser_jf) = jf_version
    ser_names(ser_jonquil) = jonquil_name
    ser_versions(ser_jonquil) = jonquil_version
    ser_names(ser_rojff) = rojff_name
    ser_versions(ser_rojff) = rojff_version
    ser_names(ser_toml) = tomlf_name
    ser_versions(ser_toml) = tomlf_version
    ser_names(ser_mp) = mp_name
    ser_versions(ser_mp) = mp_version
    ser_names(ser_h5) = h5_name
    call h5_prepare(prep)
    ser_versions(ser_h5) = h5_version
    ser_names(ser_nc) = nc_name
    call nc_prepare(prep)
    ser_versions(ser_nc) = nc_version
    ser_names(ser_ad) = ad_name
    call ad_prepare(prep)
    ser_versions(ser_ad) = ad_version
  end subroutine

  function read_seed() result(v)
    integer(int64) :: v
    character(len=64) :: text
    integer :: ios, n
    v = 42_int64
    call get_environment_variable("BENCHMARK_SEED", text, length=n, status=ios)
    if (ios == 0 .and. n > 0) read(text(1:n), *, iostat=ios) v
  end function

  function arg_text(index) result(text)
    integer, intent(in) :: index
    character(len=512) :: text
    integer :: n
    text = ""
    if (index <= command_argument_count()) then
      call get_command_argument(index, text, length=n)
    end if
  end function

  function elapsed_ns(t0, t1) result(ns)
    integer(int64), intent(in) :: t0, t1
    integer(int64) :: ns
    if (clock_rate == 1000000000_int64) then
      ns = t1 - t0
    else if (clock_rate > 0) then
      ns = nint((real(t1 - t0, real64) * 1.0e9_real64) / real(clock_rate, real64), int64)
    else
      ns = 0
    end if
  end function

  subroutine split_tabs(line, fields, nfields)
    character(len=*), intent(in) :: line
    character(len=128), intent(out) :: fields(8)
    integer, intent(out) :: nfields
    integer :: i, start, n
    nfields = 0
    fields = ""
    n = len_trim(line)
    start = 1
    do i = 1, n
      if (line(i:i) == achar(9)) then
        if (nfields >= 8) exit
        nfields = nfields + 1
        if (i > start) fields(nfields) = line(start:i - 1)
        start = i + 1
      end if
    end do
    if (start <= n .and. nfields < 8) then
      nfields = nfields + 1
      fields(nfields) = line(start:n)
    end if
  end subroutine

  subroutine touch_text(text)
    character(len=*), intent(in) :: text
    integer(int8), target :: mark(2)
    if (len(text) == 0) then
      mark = 0_int8
    else
      mark(1) = int(iand(ichar(text(1:1)), 255), int8)
      mark(2) = int(iand(ichar(text(len(text):len(text))), 255), int8)
    end if
    call black_box_bytes(c_loc(mark), 2_c_size_t)
  end subroutine

  subroutine touch_payload(payload)
    integer(int8), intent(in) :: payload(:)
    integer(int8), target :: mark(2)
    if (size(payload) == 0) then
      mark = 0_int8
    else
      mark(1) = payload(1)
      mark(2) = payload(size(payload))
    end if
    call black_box_bytes(c_loc(mark), 2_c_size_t)
  end subroutine

  subroutine copy_text(text, out_len)
    character(len=*), intent(in) :: text
    integer, intent(out) :: out_len
    integer :: i, n
    n = len(text)
    if (n > buf_cap) n = buf_cap
    do i = 1, n
      buf(i) = int(iand(ichar(text(i:i)), 255), int8)
    end do
    out_len = len(text)
  end subroutine

  subroutine slurp_file(path, out_len)
    character(len=*), intent(in) :: path
    integer, intent(out) :: out_len
    integer :: unit, ios, n
    integer(int64) :: file_n
    out_len = 0
    inquire(file=path, size=file_n)
    if (file_n <= 0) return
    n = int(file_n)
    if (n > buf_cap) n = buf_cap
    open(newunit=unit, file=path, access="stream", form="unformatted", status="old", iostat=ios)
    if (ios /= 0) return
    read(unit, iostat=ios) buf(1:n)
    close(unit)
    if (ios == 0) out_len = n
  end subroutine

  subroutine copy_payload(payload, out_len)
    integer(int8), intent(in) :: payload(:)
    integer, intent(out) :: out_len
    integer :: n
    n = size(payload)
    out_len = n
    if (n > buf_cap) n = buf_cap
    if (n > 0) buf(1:n) = payload(1:n)
  end subroutine

  subroutine run_trial(items, type_id, reps, rep, ser_index, type_hash, run_order, pos, failed)
    type(fixture_t), intent(in) :: items(:)
    character(len=*), intent(in) :: type_id, type_hash
    integer, intent(in) :: reps, rep, ser_index, pos
    integer, intent(inout) :: run_order
    logical, intent(out) :: failed
    type(fixture_t), allocatable :: got(:)
    character(len=:), allocatable :: text
    integer(int8), allocatable :: payload(:)
    integer(int64) :: t0, t1, t2, gz, zs
    integer(c_size_t) :: gz_c, zs_c
    integer :: out_len, stat, ro, sp
    integer(int64), target :: mark
    integer(int64) :: size_col
    character(len=256) :: nc_path, ad_path
    character(len=8) :: io_mode, sm_csv
    failed = .false.
    io_mode = "bytes"
    sm_csv = ""
    if (ser_index == ser_nc .or. ser_index == ser_ad) then
      io_mode = "stream"
      sm_csv = "native"
    end if
    out_len = 0
    stat = 0
    call system_clock(t0)
    select case (ser_index)
    case (ser_custom)
      call cb_serialize(items, buf, out_len, stat)
      call black_box_bytes(c_loc(buf), int(max(out_len, 0), c_size_t))
    case (ser_jf)
      call jf_write(items, text, stat)
      if (stat == 0) call touch_text(text)
    case (ser_jonquil)
      call jonquil_write(items, text, stat)
      if (stat == 0) call touch_text(text)
    case (ser_rojff)
      call rojff_write(items, text, stat)
      if (stat == 0) call touch_text(text)
    case (ser_toml)
      call tomlf_write(items, text, stat)
      if (stat == 0) call touch_text(text)
    case (ser_mp)
      call mp_write(items, payload, stat)
      if (stat == 0) call touch_payload(payload)
    case (ser_h5)
      call h5_write(items, payload, stat)
      if (stat == 0) call touch_payload(payload)
    case (ser_nc)
      write(nc_path, '("/tmp/gld-fortran-nc-",I0,".nc")') c_getpid()
      call nc_write(items, trim(nc_path), mark, stat)
      if (stat == 0) call black_box_bytes(c_loc(mark), 8_c_size_t)
    case (ser_ad)
      write(ad_path, '("/tmp/gld-fortran-ad-",I0,".bp")') c_getpid()
      call ad_write(items, trim(ad_path), mark, stat)
      if (stat == 0) call black_box_bytes(c_loc(mark), 8_c_size_t)
    case default
      stat = 1
    end select
    call system_clock(t1)
    if (stat /= 0) then
      if (ser_index == ser_nc) call nc_remove(trim(nc_path))
      if (ser_index == ser_ad) call ad_remove(trim(ad_path))
      call csv_error(type_id, trim(ser_names(ser_index)), io_mode, rep, "serialize failed")
      failed = .true.
      return
    end if
    select case (ser_index)
    case (ser_custom)
      call cb_deserialize(buf, out_len, size(items), got, stat)
      call black_box_bytes(c_loc(buf), int(out_len, c_size_t))
    case (ser_jf)
      call jf_read(text, size(items), got, stat)
      call touch_text(text)
    case (ser_jonquil)
      call jonquil_read(text, size(items), got, stat)
      call touch_text(text)
    case (ser_rojff)
      call rojff_read(text, size(items), got, stat)
      call touch_text(text)
    case (ser_toml)
      call tomlf_read(text, size(items), got, stat)
      call touch_text(text)
    case (ser_mp)
      call mp_read(payload, size(items), got, stat)
      call touch_payload(payload)
    case (ser_h5)
      call h5_read(payload, size(items), got, stat)
      call touch_payload(payload)
    case (ser_nc)
      call nc_read(trim(nc_path), size(items), got, stat)
      if (stat == 0) call black_box_bytes(c_loc(mark), 8_c_size_t)
    case (ser_ad)
      call ad_read(trim(ad_path), size(items), got, stat)
      if (stat == 0) call black_box_bytes(c_loc(mark), 8_c_size_t)
    case default
      stat = 1
    end select
    call system_clock(t2)
    if (stat /= 0 .or. .not. allocated(got)) then
      if (ser_index == ser_nc) call nc_remove(trim(nc_path))
      if (ser_index == ser_ad) call ad_remove(trim(ad_path))
      call csv_error(type_id, trim(ser_names(ser_index)), io_mode, rep, "deserialize failed")
      failed = .true.
      return
    end if
    if (.not. fixtures_equal(items, got)) then
      if (ser_index == ser_nc) call nc_remove(trim(nc_path))
      if (ser_index == ser_ad) call ad_remove(trim(ad_path))
      call csv_error(type_id, trim(ser_names(ser_index)), io_mode, rep, "fidelity failed")
      failed = .true.
      return
    end if
    select case (ser_index)
    case (ser_jf, ser_jonquil, ser_rojff, ser_toml)
      call copy_text(text, out_len)
    case (ser_mp, ser_h5)
      call copy_payload(payload, out_len)
    case (ser_nc)
      call slurp_file(trim(nc_path), out_len)
      call nc_remove(trim(nc_path))
    case (ser_ad)
      call ad_slurp(trim(ad_path), buf, out_len, buf_cap)
      call ad_remove(trim(ad_path))
    end select
    gz_c = 0
    zs_c = 0
    call bench_compress_sizes(c_loc(buf), int(out_len, c_size_t), gz_c, zs_c)
    gz = int(gz_c, int64)
    zs = int(zs_c, int64)
    ro = -1
    sp = -1
    if (record_ro) then
      ro = run_order
      sp = pos
      run_order = run_order + 1
    end if
    size_col = int(out_len, int64)
    if (ser_index == ser_nc .or. ser_index == ser_ad) size_col = mark
    call csv_row(io_mode, type_id, reps, rep, trim(ser_names(ser_index)), trim(ser_versions(ser_index)), &
         elapsed_ns(t0, t1), elapsed_ns(t1, t2), size_col, size(items), type_hash, ro, sp, gz, zs, &
         stream_mode=sm_csv)
  end subroutine

  subroutine run_cell(type_id, n, type_hash, points, children, str_count, attr_count, tag_count, &
                      reps, filter_ser, run_order)
    character(len=*), intent(in) :: type_id, type_hash, filter_ser
    integer, intent(in) :: n, points, children, str_count, attr_count, tag_count, reps
    integer, intent(inout) :: run_order
    type(fixture_t), allocatable :: items(:)
    integer :: kind_id, i, ready(max_sers), nready, order(max_sers), rep, pos, si
    logical :: failed(max_sers), trial_failed
    integer(c_int64_t) :: shuf
    kind_id = kind_from_name(type_id)
    if (kind_id < 0) return
    allocate(items(n))
    do i = 1, n
      call make_one(items(i), kind_id, seed, i - 1, children, points, str_count, attr_count, tag_count)
    end do
    nready = 0
    failed = .false.
    do i = 1, nser
      if (len_trim(filter_ser) > 0 .and. trim(ser_names(i)) /= trim(filter_ser)) cycle
      nready = nready + 1
      ready(nready) = i
    end do
    if (nready == 0) then
      deallocate(items)
      return
    end if
    if (use_none) then
      do i = 1, nready
        si = ready(i)
        do rep = 0, reps - 1
          if (failed(si)) exit
          call run_trial(items, type_id, reps, rep, si, type_hash, run_order, 0, trial_failed)
          failed(si) = trial_failed
        end do
      end do
    else
      do rep = 0, reps - 1
        shuf = schedule_seed(int(seed, c_int64_t), trim(type_id), n, trim(type_hash), "bytes", rep)
        call fisher_yates(order, nready, shuf)
        do pos = 1, nready
          si = ready(order(pos))
          if (failed(si)) cycle
          call run_trial(items, type_id, reps, rep, si, type_hash, run_order, pos - 1, trial_failed)
          failed(si) = trial_failed
        end do
      end do
    end if
    deallocate(items)
  end subroutine

  subroutine run()
    character(len=512) :: reps_txt, tsv, log_dir, ts, filter_ser, filter_data, csv_path
    character(len=1024) :: line
    character(len=128) :: fields(8)
    integer :: reps, unit, ios, nfields, n, points, children, str_count, attr_count, tag_count
    integer :: run_order, cells
    reps_txt = arg_text(1)
    tsv = arg_text(2)
    log_dir = arg_text(3)
    ts = arg_text(4)
    filter_ser = arg_text(5)
    filter_data = arg_text(6)
    if (len_trim(reps_txt) == 0 .or. len_trim(tsv) == 0 .or. len_trim(log_dir) == 0 .or. len_trim(ts) == 0) then
      write(0, '(A)') "usage: serializer_benchmark_fortran REPS CELLS.tsv LOG_DIR TIMESTAMP [serializer] [type]"
      error stop 2
    end if
    read(reps_txt, *, iostat=ios) reps
    if (ios /= 0 .or. reps < 1) error stop 2
    csv_path = trim(log_dir) // "/" // trim(ts) // ".csv"
    call csv_open(trim(csv_path))
    open(newunit=unit, file=trim(tsv), status="old", action="read", iostat=ios)
    if (ios /= 0) then
      write(0, '(A)') "cannot read cells " // trim(tsv)
      error stop 1
    end if
    run_order = 0
    cells = 0
    do
      read(unit, '(A)', iostat=ios) line
      if (ios /= 0) exit
      if (len_trim(line) == 0) cycle
      call split_tabs(line, fields, nfields)
      if (nfields < 3) cycle
      if (len_trim(filter_data) > 0 .and. trim(fields(1)) /= trim(filter_data)) cycle
      read(fields(2), *, iostat=ios) n
      if (ios /= 0 .or. n < 1) cycle
      points = 32
      children = 8
      str_count = 32
      attr_count = 4
      tag_count = 2
      if (nfields >= 4) read(fields(4), *, iostat=ios) points
      if (nfields >= 5) read(fields(5), *, iostat=ios) children
      if (nfields >= 6) read(fields(6), *, iostat=ios) str_count
      if (nfields >= 7) read(fields(7), *, iostat=ios) attr_count
      if (nfields >= 8) read(fields(8), *, iostat=ios) tag_count
      cells = cells + 1
      write(*, '(A,A,A,I0)') "[PROGRESS] Cell ", trim(fields(1)), " N=", n
      call run_cell(trim(fields(1)), n, trim(fields(3)), points, children, str_count, attr_count, &
                    tag_count, reps, filter_ser, run_order)
    end do
    close(unit)
    call csv_close()
    write(*, '(A,I0,A,A)') "[PROGRESS] fortran complete (", cells, " cells) -> ", trim(csv_path)
  end subroutine

end program
