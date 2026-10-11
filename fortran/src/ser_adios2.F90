module ser_adios2
  ! Official ADIOS2 Fortran bindings over the C++ core. Serial BP5 writes a
  ! directory, so this row is file-only (stream/native). There is no bytes API.
  ! ad_prepare initializes the library. ad_setup_cell declares the IO, selects
  ! BP5, and defines variable "grid". The timed calls open, put or get, and close.
  ! A window read sets a 0-based selection before get.
  use, intrinsic :: iso_fortran_env, only: int8, int64, real64
  use, intrinsic :: iso_c_binding, only: c_char, c_int, c_int64_t, c_null_char
  use adios2
  implicit none
  private
  public :: ad_name, ad_version, ad_prepare, ad_setup_cell
  public :: ad_write_grid, ad_read_grid, ad_read_window, ad_remove, ad_slurp

  character(len=*), parameter :: ad_name = "adios2"
  character(len=*), parameter :: ad_version = "2.10.2"

  type(adios2_adios) :: adios
  type(adios2_io) :: io_w, io_r
  type(adios2_variable) :: var_w
  integer :: io_seq = 0
  integer :: cell_nx = 0
  integer :: cell_ny = 0
  logical :: ready = .false.
  logical :: cell_ready = .false.

  interface
    function c_tree_bytes(path) bind(C, name="gld_tree_bytes") result(n)
      import :: c_char, c_int64_t
      character(kind=c_char), intent(in) :: path(*)
      integer(c_int64_t) :: n
    end function
    function c_rm_rf(path) bind(C, name="gld_rm_rf") result(rc)
      import :: c_char, c_int
      character(kind=c_char), intent(in) :: path(*)
      integer(c_int) :: rc
    end function
    function c_tree_slurp(path, buf, cap) bind(C, name="gld_tree_slurp") result(n)
      import :: c_char, c_int, int8
      character(kind=c_char), intent(in) :: path(*)
      integer(int8), intent(out) :: buf(*)
      integer(c_int), value :: cap
      integer(c_int) :: n
    end function
  end interface

contains

  subroutine ad_prepare(stat)
    integer, intent(out) :: stat
    stat = 0
    if (ready) return
    call adios2_init(adios, stat)
    if (stat /= 0) return
    ready = .true.
  end subroutine

  subroutine ad_setup_cell(nx, ny, stat)
    ! Once per cell, outside the repetition clock.
    integer, intent(in) :: nx, ny
    integer, intent(out) :: stat
    character(len=32) :: ioname
    integer(kind=8) :: shp(2), sta(2), cnt(2)
    stat = 1
    if (.not. ready) return
    if (nx < 1 .or. ny < 1) return
    io_seq = io_seq + 1
    write(ioname, '("gw",I0)') io_seq
    call adios2_declare_io(io_w, adios, trim(ioname), stat)
    if (stat /= 0) return
    call adios2_set_engine(io_w, "BP5", stat)
    if (stat /= 0) return
    shp(1) = int(nx, kind=8)
    shp(2) = int(ny, kind=8)
    sta = 0_8
    cnt = shp
    call adios2_define_variable(var_w, io_w, "grid", adios2_type_real8, 2, shp, sta, cnt, &
         adios2_constant_dims, stat)
    if (stat /= 0) return
    io_seq = io_seq + 1
    write(ioname, '("gr",I0)') io_seq
    call adios2_declare_io(io_r, adios, trim(ioname), stat)
    if (stat /= 0) return
    call adios2_set_engine(io_r, "BP5", stat)
    if (stat /= 0) return
    cell_nx = nx
    cell_ny = ny
    cell_ready = .true.
  end subroutine

  subroutine ad_write_grid(values, path, nbytes, stat)
    real(real64), intent(in) :: values(:, :)
    character(len=*), intent(in) :: path
    integer(int64), intent(out) :: nbytes
    integer, intent(out) :: stat
    type(adios2_engine) :: eng
    integer :: ierr
    integer(c_int64_t) :: tree_n
    nbytes = 0
    stat = 1
    if (.not. cell_ready) return
    if (size(values, 1) /= cell_nx .or. size(values, 2) /= cell_ny) return
    call ad_remove(path)
    call adios2_open(eng, io_w, trim(path), adios2_mode_write, stat)
    if (stat /= 0) return
    call adios2_begin_step(eng, adios2_step_mode_append, stat)
    if (stat == 0) call adios2_put(eng, var_w, values, adios2_mode_sync, stat)
    if (stat == 0) call adios2_end_step(eng, stat)
    call adios2_close(eng, ierr)
    if (stat == 0 .and. ierr /= 0) stat = ierr
    if (stat /= 0) then
      call ad_remove(path)
      return
    end if
    tree_n = c_tree_bytes(trim(path) // c_null_char)
    if (tree_n < 0) then
      stat = 1
      nbytes = 0
    else
      nbytes = int(tree_n, int64)
    end if
  end subroutine

  subroutine ad_read_grid(path, values, stat)
    character(len=*), intent(in) :: path
    real(real64), intent(out) :: values(:, :)
    integer, intent(out) :: stat
    if (size(values, 1) /= cell_nx .or. size(values, 2) /= cell_ny) then
      stat = 1
      return
    end if
    call read_selection(path, 0, 0, cell_nx, cell_ny, values, stat)
  end subroutine

  subroutine ad_read_window(path, x0, y0, wx, wy, window, stat)
    character(len=*), intent(in) :: path
    integer, intent(in) :: x0, y0, wx, wy
    real(real64), intent(out) :: window(:, :)
    integer, intent(out) :: stat
    if (size(window, 1) /= wx .or. size(window, 2) /= wy) then
      stat = 1
      return
    end if
    call read_selection(path, x0, y0, wx, wy, window, stat)
  end subroutine

  subroutine read_selection(path, x0, y0, wx, wy, buf, stat)
    character(len=*), intent(in) :: path
    integer, intent(in) :: x0, y0, wx, wy
    real(real64), intent(out) :: buf(:, :)
    integer, intent(out) :: stat
    type(adios2_engine) :: eng
    type(adios2_variable) :: var
    integer :: ierr
    integer(kind=8) :: start(2), cnt(2)
    stat = 1
    if (.not. cell_ready) return
    call adios2_open(eng, io_r, trim(path), adios2_mode_readRandomAccess, stat)
    if (stat /= 0) return
    call adios2_inquire_variable(var, io_r, "grid", stat)
    if (stat /= 0) then
      call adios2_close(eng, ierr)
      stat = 1
      return
    end if
    start(1) = int(x0, kind=8)
    start(2) = int(y0, kind=8)
    cnt(1) = int(wx, kind=8)
    cnt(2) = int(wy, kind=8)
    call adios2_set_selection(var, 2, start, cnt, stat)
    if (stat == 0) call adios2_get(eng, var, buf, adios2_mode_sync, stat)
    call adios2_close(eng, ierr)
    if (stat == 0 .and. ierr /= 0) stat = 1
    if (stat /= 0) stat = 1
  end subroutine

  subroutine ad_remove(path)
    character(len=*), intent(in) :: path
    integer(c_int) :: rc
    rc = c_rm_rf(trim(path) // c_null_char)
    if (rc /= 0) then
      ! The next write removes the same path again. A leftover directory
      ! fails open, which the trial records as a serialize error.
    end if
  end subroutine

  subroutine ad_slurp(path, buf, n, cap)
    character(len=*), intent(in) :: path
    integer(int8), intent(out) :: buf(*)
    integer, intent(out) :: n
    integer, intent(in) :: cap
    n = int(c_tree_slurp(trim(path) // c_null_char, buf, int(cap, c_int)))
  end subroutine

end module
