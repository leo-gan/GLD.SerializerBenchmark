program compliance_fortran
  ! Parse-only probe for the JSON and TOML corpora.
  !   compliance_fortran json|toml cases.bin outcomes.bin
  ! cases.bin: int32 count, then (int32 nbytes, bytes) in little-endian.
  ! outcomes.bin: for each case, int32 ok (1 accepted), int32 nbytes, bytes of
  ! the library's re-serialized text (empty when the parse failed).
  use, intrinsic :: iso_fortran_env, only: int32
  use json_module, only: json_core, json_value
  use tomlf, only: toml_table, toml_error, toml_serialize, toml_loads
  implicit none

  character(len=16) :: fmt
  character(len=1024) :: in_path, out_path
  integer :: in_unit, out_unit, ios, n, i, narg
  integer(int32) :: ncases, nbytes, ok, dlen
  character(len=:), allocatable :: text, dump

  narg = command_argument_count()
  if (narg < 3) then
    write(0, '(A)') "usage: compliance_fortran json|toml cases.bin outcomes.bin"
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

end program compliance_fortran
