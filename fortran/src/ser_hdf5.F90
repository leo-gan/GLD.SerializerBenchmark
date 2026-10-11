module ser_hdf5
  ! HDF5 Fortran API, core virtual file driver, one float64 dataset "grid".
  ! h5_prepare builds the access property list and a contiguous dataset
  ! creation property list. The timed calls create the file, write the whole
  ! array, and read either the whole array or an interior hyperslab.
  use, intrinsic :: iso_c_binding, only: c_ptr, c_loc, c_null_ptr, c_size_t, c_int64_t
  use, intrinsic :: iso_fortran_env, only: int8, real64
  use hdf5
  implicit none
  private
  public :: h5_name, h5_version, h5_prepare, h5_write_grid, h5_read_grid, h5_read_window

  character(len=*), parameter :: h5_name = "hdf5-fortran"
  character(len=16) :: h5_version = "1.10.7"

  integer(hid_t) :: fapl = 0
  integer(hid_t) :: dcpl = 0
  integer(hid_t) :: t_f64 = 0
  logical :: ready = .false.

  interface
    function c_h5fget_file_image(file_id, buf, buf_size) &
        bind(C, name="H5Fget_file_image") result(n)
      import :: hid_t, c_ptr, c_size_t, c_int64_t
      integer(hid_t), value :: file_id
      type(c_ptr), value :: buf
      integer(c_size_t), value :: buf_size
      integer(c_int64_t) :: n
    end function
  end interface

contains

  subroutine h5_prepare(stat)
    integer, intent(out) :: stat
    integer :: err, maj, minv, rel
    integer(size_t) :: inc
    stat = 0
    if (ready) return
    call h5open_f(err)
    if (err /= 0) then
      stat = 1
      return
    end if
    call h5get_libversion_f(maj, minv, rel, err)
    if (err == 0) write(h5_version, '(I0,".",I0,".",I0)') maj, minv, rel
    call h5pcreate_f(H5P_FILE_ACCESS_F, fapl, err)
    inc = 1048576_size_t
    call h5pset_fapl_core_f(fapl, inc, .false., err)
    if (err /= 0) then
      stat = 1
      return
    end if
    call h5pcreate_f(H5P_DATASET_CREATE_F, dcpl, err)
    if (err /= 0) then
      stat = 1
      return
    end if
    call h5pset_layout_f(dcpl, H5D_CONTIGUOUS_F, err)
    if (err /= 0) then
      stat = 1
      return
    end if
    t_f64 = h5kind_to_type(real64, H5_REAL_KIND)
    ready = .true.
  end subroutine

  subroutine h5_write_grid(values, payload, stat)
    real(real64), intent(in) :: values(:, :)
    integer(int8), allocatable, target, intent(out) :: payload(:)
    integer, intent(out) :: stat
    integer(hid_t) :: file_id, space, dset
    integer :: err
    integer(hsize_t) :: dims(2)
    integer(c_int64_t) :: nbytes
    type(c_ptr) :: p
    stat = 0
    if (.not. ready) call h5_prepare(stat)
    if (stat /= 0) return
    call h5fcreate_f("gld.h5", H5F_ACC_TRUNC_F, file_id, err, access_prp=fapl)
    if (err /= 0) then
      stat = 1
      return
    end if
    dims(1) = size(values, 1)
    dims(2) = size(values, 2)
    call h5screate_simple_f(2, dims, space, err)
    if (err == 0) call h5dcreate_f(file_id, "grid", t_f64, space, dset, err, dcpl)
    if (err == 0) call h5dwrite_f(dset, t_f64, values, dims, err)
    if (err == 0) call h5dclose_f(dset, err)
    call h5sclose_f(space, err)
    if (err /= 0) stat = 1
    if (stat == 0) then
      call h5fflush_f(file_id, H5F_SCOPE_GLOBAL_F, err)
      nbytes = c_h5fget_file_image(file_id, c_null_ptr, 0_c_size_t)
      if (nbytes <= 0) then
        stat = 1
      else
        allocate(payload(nbytes))
        p = c_loc(payload(1))
        nbytes = c_h5fget_file_image(file_id, p, int(size(payload), c_size_t))
        if (nbytes /= size(payload)) stat = 1
      end if
    end if
    call h5fclose_f(file_id, err)
  end subroutine

  subroutine h5_read_grid(payload, values, stat)
    integer(int8), intent(in), target :: payload(:)
    real(real64), intent(out) :: values(:, :)
    integer, intent(out) :: stat
    integer(hid_t) :: file_id, rfapl, dset
    integer :: err
    integer(hsize_t) :: dims(2)
    stat = 0
    call open_image(payload, file_id, rfapl, stat)
    if (stat /= 0) return
    call h5dopen_f(file_id, "grid", dset, err)
    dims(1) = size(values, 1)
    dims(2) = size(values, 2)
    if (err == 0) call h5dread_f(dset, t_f64, values, dims, err)
    if (err /= 0) stat = 1
    call h5dclose_f(dset, err)
    call h5fclose_f(file_id, err)
    call h5pclose_f(rfapl, err)
  end subroutine

  subroutine h5_read_window(payload, x0, y0, wx, wy, window, stat)
    ! 0-based origin. The memory dataspace is the window, not the full array.
    integer(int8), intent(in), target :: payload(:)
    integer, intent(in) :: x0, y0, wx, wy
    real(real64), intent(out) :: window(:, :)
    integer, intent(out) :: stat
    integer(hid_t) :: file_id, rfapl, dset, file_space, mem_space
    integer :: err
    integer(hsize_t) :: start(2), cnt(2), mem_dims(2)
    stat = 0
    if (size(window, 1) /= wx .or. size(window, 2) /= wy) then
      stat = 1
      return
    end if
    call open_image(payload, file_id, rfapl, stat)
    if (stat /= 0) return
    call h5dopen_f(file_id, "grid", dset, err)
    if (err == 0) call h5dget_space_f(dset, file_space, err)
    start(1) = int(x0, hsize_t)
    start(2) = int(y0, hsize_t)
    cnt(1) = int(wx, hsize_t)
    cnt(2) = int(wy, hsize_t)
    if (err == 0) call h5sselect_hyperslab_f(file_space, H5S_SELECT_SET_F, start, cnt, err)
    mem_dims(1) = int(wx, hsize_t)
    mem_dims(2) = int(wy, hsize_t)
    if (err == 0) call h5screate_simple_f(2, mem_dims, mem_space, err)
    if (err == 0) call h5dread_f(dset, t_f64, window, mem_dims, err, mem_space, file_space)
    if (err /= 0) stat = 1
    call h5sclose_f(mem_space, err)
    call h5sclose_f(file_space, err)
    call h5dclose_f(dset, err)
    call h5fclose_f(file_id, err)
    call h5pclose_f(rfapl, err)
  end subroutine

  subroutine open_image(payload, file_id, rfapl, stat)
    integer(int8), intent(in), target :: payload(:)
    integer(hid_t), intent(out) :: file_id, rfapl
    integer, intent(out) :: stat
    integer :: err
    integer(size_t) :: inc
    type(c_ptr) :: p
    stat = 0
    file_id = 0
    rfapl = 0
    if (.not. ready) call h5_prepare(stat)
    if (stat /= 0) return
    if (size(payload) < 1) then
      stat = 1
      return
    end if
    call h5pcreate_f(H5P_FILE_ACCESS_F, rfapl, err)
    inc = 1048576_size_t
    call h5pset_fapl_core_f(rfapl, inc, .false., err)
    p = c_loc(payload(1))
    call h5pset_file_image_f(rfapl, p, int(size(payload), size_t), err)
    if (err /= 0) then
      stat = 1
      call h5pclose_f(rfapl, err)
      return
    end if
    call h5fopen_f("gld.h5", H5F_ACC_RDONLY_F, file_id, err, access_prp=rfapl)
    if (err /= 0) then
      stat = 1
      call h5pclose_f(rfapl, err)
    end if
  end subroutine

end module
