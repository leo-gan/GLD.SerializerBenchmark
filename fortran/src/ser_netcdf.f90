module ser_netcdf
  ! NetCDF Fortran API. One NF90_DOUBLE variable "grid" on dimensions x, y.
  ! NF90_DISKLESS discards the file on close, so this row writes a real
  ! NetCDF-4 file and is published as file-only (stream/native).
  ! Window reads add 1 to the catalog's 0-based origin. NetCDF start is 1-based.
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use netcdf
  implicit none
  private
  public :: nc_name, nc_version, nc_prepare, nc_write_grid, nc_read_grid, nc_read_window, nc_remove

  character(len=*), parameter :: nc_name = "netcdf-fortran"
  character(len=32) :: nc_version = "4.5.4"

contains

  subroutine nc_prepare(stat)
    integer, intent(out) :: stat
    character(len=80) :: ver
    stat = 0
    ver = nf90_inq_libvers()
    nc_version = trim(ver)
  end subroutine

  subroutine nc_write_grid(values, path, nbytes, stat)
    real(real64), intent(in) :: values(:, :)
    character(len=*), intent(in) :: path
    integer(int64), intent(out) :: nbytes
    integer, intent(out) :: stat
    integer :: ncid, dimx, dimy, varid, err
    nbytes = 0
    call nc_remove(path)
    stat = nf90_create(path, ior(NF90_NETCDF4, NF90_CLOBBER), ncid)
    if (stat /= nf90_noerr) return
    stat = nf90_def_dim(ncid, "x", size(values, 1), dimx)
    if (stat == nf90_noerr) stat = nf90_def_dim(ncid, "y", size(values, 2), dimy)
    if (stat == nf90_noerr) stat = nf90_def_var(ncid, "grid", NF90_DOUBLE, [dimx, dimy], varid)
    if (stat == nf90_noerr) stat = nf90_enddef(ncid)
    if (stat == nf90_noerr) stat = nf90_put_var(ncid, varid, values)
    err = nf90_close(ncid)
    if (stat == nf90_noerr .and. err /= nf90_noerr) stat = err
    if (stat == nf90_noerr) then
      inquire(file=path, size=nbytes)
      if (nbytes < 0) stat = 1
    else
      stat = 1
    end if
  end subroutine

  subroutine nc_read_grid(path, values, stat)
    character(len=*), intent(in) :: path
    real(real64), intent(out) :: values(:, :)
    integer, intent(out) :: stat
    integer :: ncid, varid
    stat = nf90_open(path, NF90_NOWRITE, ncid)
    if (stat /= nf90_noerr) return
    stat = nf90_inq_varid(ncid, "grid", varid)
    if (stat == nf90_noerr) stat = nf90_get_var(ncid, varid, values)
    if (nf90_close(ncid) /= nf90_noerr) stat = 1
    if (stat /= nf90_noerr) stat = 1
  end subroutine

  subroutine nc_read_window(path, x0, y0, wx, wy, window, stat)
    character(len=*), intent(in) :: path
    integer, intent(in) :: x0, y0, wx, wy
    real(real64), intent(out) :: window(:, :)
    integer, intent(out) :: stat
    integer :: ncid, varid
    integer :: start(2), cnt(2)
    if (size(window, 1) /= wx .or. size(window, 2) /= wy) then
      stat = 1
      return
    end if
    stat = nf90_open(path, NF90_NOWRITE, ncid)
    if (stat /= nf90_noerr) return
    stat = nf90_inq_varid(ncid, "grid", varid)
    start(1) = x0 + 1
    start(2) = y0 + 1
    cnt(1) = wx
    cnt(2) = wy
    if (stat == nf90_noerr) stat = nf90_get_var(ncid, varid, window, start=start, count=cnt)
    if (nf90_close(ncid) /= nf90_noerr) stat = 1
    if (stat /= nf90_noerr) stat = 1
  end subroutine

  subroutine nc_remove(path)
    character(len=*), intent(in) :: path
    integer :: unit, ios
    logical :: exists
    inquire(file=path, exist=exists)
    if (.not. exists) return
    open(newunit=unit, file=path, status="old", iostat=ios)
    if (ios == 0) close(unit, status="delete")
  end subroutine

end module
