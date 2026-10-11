module ser_gld_arrow
  ! gld-arrow 0.2.0: Arrow C Data Interface for one contiguous float64 grid.
  use, intrinsic :: iso_c_binding, only: c_double, c_int32_t, c_loc, c_associated, &
      c_f_procpointer, c_funptr
  use, intrinsic :: iso_fortran_env, only: real64
  use gld_arrow, only: arrow_schema_t, arrow_array_t, arrow_export_float64, &
      arrow_import_float64, arrow_free, ARROW_OK, ARROW_VERSION
  implicit none
  private
  public :: ga_name, ga_version, ga_prepare, ga_write_grid, ga_read_grid, ga_read_window

  character(len=*), parameter :: ga_name = "gld-arrow"
  character(len=*), parameter :: ga_version = ARROW_VERSION

  type(arrow_schema_t), save :: saved_schema
  type(arrow_array_t), save :: saved_array
  integer(c_int32_t), save :: release_schema = 0
  integer(c_int32_t), save :: release_array = 0
  logical, save :: have_export = .false.

contains

  subroutine ga_prepare(stat)
    integer, intent(out) :: stat
    stat = 0
  end subroutine ga_prepare

  subroutine ga_write_grid(values, stat)
    real(real64), intent(in), target :: values(:, :)
    integer, intent(out) :: stat
    call drop_export()
    release_schema = 0
    release_array = 0
    call arrow_export_float64(values, saved_schema, saved_array, stat, &
        release_schema=release_schema, release_array=release_array)
    have_export = stat == ARROW_OK
    if (.not. have_export) stat = 1
    if (have_export) stat = 0
  end subroutine ga_write_grid

  subroutine ga_read_grid(values, stat)
    real(real64), intent(out) :: values(:, :)
    integer, intent(out) :: stat
    real(c_double), pointer :: view(:, :)
    integer :: i, j
    if (.not. have_export) then
      stat = 1
      return
    end if
    nullify(view)
    call arrow_import_float64(saved_schema, saved_array, view, stat)
    have_export = .false.
    if (stat /= ARROW_OK .or. .not. associated(view)) then
      stat = 1
      return
    end if
    if (size(view, 1) /= size(values, 1) .or. size(view, 2) /= size(values, 2)) then
      call arrow_free(c_loc(view(1, 1)))
      stat = 1
      return
    end if
    do j = 1, size(values, 2)
      do i = 1, size(values, 1)
        values(i, j) = view(i, j)
      end do
    end do
    call arrow_free(c_loc(view(1, 1)))
    stat = 0
  end subroutine ga_read_grid

  subroutine ga_read_window(x0, y0, wx, wy, window, stat)
    integer, intent(in) :: x0, y0, wx, wy
    real(real64), intent(out) :: window(:, :)
    integer, intent(out) :: stat
    real(c_double), pointer :: view(:, :)
    integer :: i, j
    if (.not. have_export) then
      stat = 1
      return
    end if
    nullify(view)
    call arrow_import_float64(saved_schema, saved_array, view, stat)
    have_export = .false.
    if (stat /= ARROW_OK .or. .not. associated(view)) then
      stat = 1
      return
    end if
    if (x0 < 0 .or. y0 < 0 .or. wx /= size(window, 1) .or. wy /= size(window, 2)) then
      call arrow_free(c_loc(view(1, 1)))
      stat = 1
      return
    end if
    if (x0 + wx > size(view, 1) .or. y0 + wy > size(view, 2)) then
      call arrow_free(c_loc(view(1, 1)))
      stat = 1
      return
    end if
    do j = 1, wy
      do i = 1, wx
        window(i, j) = view(x0 + i, y0 + j)
      end do
    end do
    call arrow_free(c_loc(view(1, 1)))
    stat = 0
  end subroutine ga_read_window

  subroutine drop_export()
    abstract interface
      subroutine schema_rel(schema) bind(C)
        import :: arrow_schema_t
        type(arrow_schema_t), intent(inout) :: schema
      end subroutine schema_rel
      subroutine array_rel(array) bind(C)
        import :: arrow_array_t
        type(arrow_array_t), intent(inout) :: array
      end subroutine array_rel
    end interface
    procedure(schema_rel), pointer :: srel
    procedure(array_rel), pointer :: arel
    type(c_funptr) :: fp
    if (.not. have_export) return
    fp = saved_schema%release
    if (c_associated(fp)) then
      call c_f_procpointer(fp, srel)
      if (associated(srel)) call srel(saved_schema)
    end if
    fp = saved_array%release
    if (c_associated(fp)) then
      call c_f_procpointer(fp, arel)
      if (associated(arel)) call arel(saved_array)
    end if
    have_export = .false.
  end subroutine drop_export

end module ser_gld_arrow
