program test_grid
  ! Catalog shape: 512x512 float64, window (128, 64, 256, 128).
  ! Full read and an interior hyperslab for HDF5, NetCDF, and ADIOS2.
  use, intrinsic :: iso_fortran_env, only: int8, int64, real64
  use bench_data
  use ser_hdf5
  use ser_netcdf
  use ser_adios2
  implicit none
  integer, parameter :: nx = 512
  integer, parameter :: ny = 512
  integer, parameter :: x0 = 128
  integer, parameter :: y0 = 64
  integer, parameter :: wx = 256
  integer, parameter :: wy = 128
  integer, parameter :: buf_cap = 8 * 1024 * 1024
  real(real64), allocatable :: values(:, :), got(:, :), win(:, :), expect(:, :)
  real(real64), allocatable :: other(:, :)
  integer(int8), allocatable :: payload(:)
  integer(int64) :: nbytes
  integer :: stat, nfail
  character(len=*), parameter :: nc_path = "/tmp/gld-grid-test.nc"
  character(len=*), parameter :: ad_path = "/tmp/gld-grid-test.bp"

  nfail = 0
  allocate(values(nx, ny), got(nx, ny), win(wx, wy), expect(wx, wy), other(nx, ny))
  call make_grid(values, 42_int64, kind_grid, 0)
  call make_grid(other, 42_int64, kind_grid, 0)
  if (.not. grid_equal(values, other)) call fail("make_grid is not deterministic")
  call make_grid(other, 42_int64, kind_grid_window, 0)
  if (grid_equal(values, other)) call fail("grid and grid_window share a seed stream")
  expect = values(x0 + 1:x0 + wx, y0 + 1:y0 + wy)
  if (size(expect) /= 32768) call fail("window length")

  call h5_prepare(stat)
  if (stat /= 0) call fail("h5_prepare")
  call h5_write_grid(values, payload, stat)
  if (stat /= 0 .or. .not. allocated(payload)) then
    call fail("h5 write")
  else
    if (size(payload) <= 2000000 .or. size(payload) > buf_cap) call fail("h5 size")
    got = 0
    call h5_read_grid(payload, got, stat)
    if (stat /= 0 .or. .not. grid_equal(got, values)) call fail("h5 full read")
    win = 0
    call h5_read_window(payload, x0, y0, wx, wy, win, stat)
    if (stat /= 0 .or. size(win) /= 32768 .or. .not. grid_equal(win, expect)) call fail("h5 window")
  end if

  call nc_prepare(stat)
  if (stat /= 0) call fail("nc_prepare")
  call nc_write_grid(values, nc_path, nbytes, stat)
  if (stat /= 0) then
    call fail("nc write")
  else
    if (nbytes <= 2000000 .or. nbytes > buf_cap) call fail("nc size")
    got = 0
    call nc_read_grid(nc_path, got, stat)
    if (stat /= 0 .or. .not. grid_equal(got, values)) call fail("nc full read")
    win = 0
    call nc_read_window(nc_path, x0, y0, wx, wy, win, stat)
    if (stat /= 0 .or. .not. grid_equal(win, expect)) call fail("nc window")
  end if
  call nc_remove(nc_path)

  call ad_prepare(stat)
  if (stat /= 0) call fail("ad_prepare")
  call ad_setup_cell(nx, ny, stat)
  if (stat /= 0) then
    call fail("ad_setup_cell")
  else
    call ad_remove(ad_path)
    call ad_write_grid(values, ad_path, nbytes, stat)
    if (stat /= 0) then
      call fail("ad write")
    else
      if (nbytes <= 2000000 .or. nbytes > buf_cap) call fail("ad size")
      got = 0
      call ad_read_grid(ad_path, got, stat)
      if (stat /= 0 .or. .not. grid_equal(got, values)) call fail("ad full read")
      win = 0
      call ad_read_window(ad_path, x0, y0, wx, wy, win, stat)
      if (stat /= 0 .or. .not. grid_equal(win, expect)) call fail("ad window")
    end if
    call ad_remove(ad_path)
  end if

  if (nfail /= 0) error stop 1
  write(*, '(A)') "ok"

contains

  subroutine fail(msg)
    character(len=*), intent(in) :: msg
    write(0, '(A,A)') "FAIL ", msg
    nfail = nfail + 1
  end subroutine

end program
