module ser_hdf5
  ! HDF5 through the official Fortran API and the core virtual file driver.
  ! The file-access property list is created in h5_prepare, outside the timer.
  ! h5_write creates the memory file, writes datasets, flushes, and copies the
  ! file image. h5_read opens that image. Bool is int8 0/1. Strings are
  ! fixed-length HDF5 strings of the suite cap (48) plus an explicit length.
  use, intrinsic :: iso_c_binding, only: c_ptr, c_loc, c_null_ptr, c_size_t, c_int64_t
  use, intrinsic :: iso_fortran_env, only: int8, int32, int64, real64
  use hdf5
  use bench_data
  implicit none
  private
  public :: h5_name, h5_version, h5_prepare, h5_write, h5_read

  character(len=*), parameter :: h5_name = "hdf5-fortran"
  character(len=16) :: h5_version = "1.10.7"

  integer(hid_t) :: fapl = 0
  integer(hid_t) :: t_i8 = 0, t_i32 = 0, t_i64 = 0, t_f64 = 0, t_str = 0
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
    t_i8 = h5kind_to_type(int8, H5_INTEGER_KIND)
    t_i32 = h5kind_to_type(int32, H5_INTEGER_KIND)
    t_i64 = h5kind_to_type(int64, H5_INTEGER_KIND)
    t_f64 = h5kind_to_type(real64, H5_REAL_KIND)
    call h5tcopy_f(H5T_FORTRAN_S1, t_str, err)
    call h5tset_size_f(t_str, int(v2_str, size_t), err)
    if (err /= 0) then
      stat = 1
      return
    end if
    ready = .true.
  end subroutine

  subroutine h5_write(items, payload, stat)
    type(fixture_t), intent(in) :: items(:)
    integer(int8), allocatable, target, intent(out) :: payload(:)
    integer, intent(out) :: stat
    integer(hid_t) :: file_id, grp
    integer :: err, i, n
    integer(c_int64_t) :: nbytes
    character(len=16) :: gname
    type(c_ptr) :: p
    stat = 0
    if (.not. ready) call h5_prepare(stat)
    if (stat /= 0) return
    call h5fcreate_f("gld.h5", H5F_ACC_TRUNC_F, file_id, err, access_prp=fapl)
    if (err /= 0) then
      stat = 1
      return
    end if
    n = size(items)
    do i = 1, n
      write(gname, '("r",I0)') i
      call h5gcreate_f(file_id, trim(gname), grp, err)
      if (err /= 0) then
        stat = 1
        exit
      end if
      call write_record(grp, items(i), stat)
      call h5gclose_f(grp, err)
      if (stat /= 0) exit
    end do
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

  subroutine h5_read(payload, expected_n, items, stat)
    integer(int8), intent(in), target :: payload(:)
    integer, intent(in) :: expected_n
    type(fixture_t), allocatable, intent(out) :: items(:)
    integer, intent(out) :: stat
    integer(hid_t) :: rfapl, file_id, grp
    integer :: err, i, n
    integer(size_t) :: inc
    character(len=16) :: gname
    type(c_ptr) :: p
    stat = 0
    n = expected_n
    if (n < 1) n = 1
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
      return
    end if
    allocate(items(n))
    do i = 1, n
      write(gname, '("r",I0)') i
      call h5gopen_f(file_id, trim(gname), grp, err)
      if (err /= 0) then
        stat = 1
        exit
      end if
      call read_record(grp, items(i), stat)
      call h5gclose_f(grp, err)
      if (stat /= 0) exit
    end do
    call h5fclose_f(file_id, err)
    call h5pclose_f(rfapl, err)
  end subroutine

  subroutine write_record(grp, fx, stat)
    integer(hid_t), intent(in) :: grp
    type(fixture_t), intent(in) :: fx
    integer, intent(out) :: stat
    integer(hid_t) :: sub, items_g
    integer :: i
    stat = 0
    call put_i32(grp, "kind", fx%kind_id, stat)
    if (stat /= 0) return
    select case (fx%kind_id)
    case (kind_message)
      call put_bool(grp, "f_bool", fx%message%f_bool, stat)
      call put_i32(grp, "f_int32", fx%message%f_int32, stat)
      call put_i64(grp, "f_int64", fx%message%f_int64, stat)
      call put_f64(grp, "f_float64", fx%message%f_float64, stat)
      call put_text(grp, "f_string", fx%message%f_string, fx%message%f_string_n, stat)
      call put_bool(grp, "f_bool_2", fx%message%f_bool_2, stat)
      call put_i32(grp, "f_int32_2", fx%message%f_int32_2, stat)
      call put_text(grp, "f_string_2", fx%message%f_string_2, fx%message%f_string_2_n, stat)
    case (kind_document)
      call put_text(grp, "id", fx%document%id, fx%document%id_n, stat)
      call put_i32(grp, "status", fx%document%status, stat)
      call h5gcreate_f(grp, "meta", sub, i)
      if (i /= 0) then
        stat = 1
        return
      end if
      call put_text(sub, "region", fx%document%region, fx%document%region_n, stat)
      call put_i32(sub, "version", fx%document%version, stat)
      call h5gclose_f(sub, i)
      call h5gcreate_f(grp, "items", items_g, i)
      if (i /= 0) then
        stat = 1
        return
      end if
      call put_i32(items_g, "count", fx%document%item_count, stat)
      call put_text_1d(items_g, "sku", fx%document%item_count, stat, skus=fx)
      call put_i32_1d_qty(items_g, fx, stat)
      call put_i64_1d_price(items_g, fx, stat)
      call h5gclose_f(items_g, i)
    case (kind_telemetry)
      call put_text(grp, "source", fx%telemetry%source, fx%telemetry%source_n, stat)
      call put_i64(grp, "ts", fx%telemetry%ts, stat)
      call put_i32(grp, "tag_count", fx%telemetry%tag_count, stat)
      call put_tags(grp, fx, stat)
      call put_i32(grp, "value_count", fx%telemetry%value_count, stat)
      call put_values(grp, fx, stat)
    case (kind_strings)
      call put_i32(grp, "count", fx%strings%count, stat)
      call put_strings(grp, fx, stat)
    case (kind_event)
      call put_text(grp, "event_id", fx%event%event_id, fx%event%event_id_n, stat)
      call put_text(grp, "event_type", fx%event%event_type, fx%event%event_type_n, stat)
      call put_i64(grp, "occurred_at", fx%event%occurred_at, stat)
      call put_text(grp, "producer", fx%event%producer, fx%event%producer_n, stat)
      call put_i32(grp, "attr_count", fx%event%attr_count, stat)
      call put_attrs(grp, fx, stat)
    case default
      stat = 1
    end select
  end subroutine

  subroutine read_record(grp, fx, stat)
    integer(hid_t), intent(in) :: grp
    type(fixture_t), intent(out) :: fx
    integer, intent(out) :: stat
    integer(hid_t) :: sub
    integer :: err, kind, n
    stat = 0
    kind = get_i32(grp, "kind", stat)
    if (stat /= 0) return
    fx%kind_id = kind
    select case (kind)
    case (kind_message)
      fx%message%f_bool = get_bool(grp, "f_bool", stat)
      fx%message%f_int32 = get_i32(grp, "f_int32", stat)
      fx%message%f_int64 = get_i64(grp, "f_int64", stat)
      fx%message%f_float64 = get_f64(grp, "f_float64", stat)
      call get_text(grp, "f_string", fx%message%f_string, fx%message%f_string_n, stat)
      fx%message%f_bool_2 = get_bool(grp, "f_bool_2", stat)
      fx%message%f_int32_2 = get_i32(grp, "f_int32_2", stat)
      call get_text(grp, "f_string_2", fx%message%f_string_2, fx%message%f_string_2_n, stat)
    case (kind_document)
      call get_text(grp, "id", fx%document%id, fx%document%id_n, stat)
      fx%document%status = get_i32(grp, "status", stat)
      call h5gopen_f(grp, "meta", sub, err)
      if (err /= 0) then
        stat = 1
        return
      end if
      call get_text(sub, "region", fx%document%region, fx%document%region_n, stat)
      fx%document%version = get_i32(sub, "version", stat)
      call h5gclose_f(sub, err)
      call h5gopen_f(grp, "items", sub, err)
      if (err /= 0) then
        stat = 1
        return
      end if
      n = get_i32(sub, "count", stat)
      fx%document%item_count = n
      call get_skus(sub, fx, stat)
      call get_qty(sub, fx, stat)
      call get_price(sub, fx, stat)
      call h5gclose_f(sub, err)
    case (kind_telemetry)
      call get_text(grp, "source", fx%telemetry%source, fx%telemetry%source_n, stat)
      fx%telemetry%ts = get_i64(grp, "ts", stat)
      fx%telemetry%tag_count = get_i32(grp, "tag_count", stat)
      call get_tags(grp, fx, stat)
      fx%telemetry%value_count = get_i32(grp, "value_count", stat)
      call get_values(grp, fx, stat)
    case (kind_strings)
      fx%strings%count = get_i32(grp, "count", stat)
      call get_strings(grp, fx, stat)
    case (kind_event)
      call get_text(grp, "event_id", fx%event%event_id, fx%event%event_id_n, stat)
      call get_text(grp, "event_type", fx%event%event_type, fx%event%event_type_n, stat)
      fx%event%occurred_at = get_i64(grp, "occurred_at", stat)
      call get_text(grp, "producer", fx%event%producer, fx%event%producer_n, stat)
      fx%event%attr_count = get_i32(grp, "attr_count", stat)
      call get_attrs(grp, fx, stat)
    case default
      stat = 1
    end select
  end subroutine

  subroutine put_scalar_space(space, dset, loc, name, dtype, stat)
    integer(hid_t), intent(out) :: space, dset
    integer(hid_t), intent(in) :: loc, dtype
    character(len=*), intent(in) :: name
    integer, intent(inout) :: stat
    integer :: err
    integer(hsize_t) :: dims(1)
    if (stat /= 0) return
    dims(1) = 1
    call h5screate_simple_f(1, dims, space, err)
    if (err /= 0) then
      stat = 1
      return
    end if
    call h5dcreate_f(loc, name, dtype, space, dset, err)
    if (err /= 0) stat = 1
  end subroutine

  subroutine put_i32(loc, name, value, stat)
    integer(hid_t), intent(in) :: loc
    character(len=*), intent(in) :: name
    integer, intent(in) :: value
    integer, intent(inout) :: stat
    integer(hid_t) :: space, dset
    integer :: err
    integer(hsize_t) :: dims(1)
    integer(int32) :: tmp
    if (stat /= 0) return
    call put_scalar_space(space, dset, loc, name, t_i32, stat)
    if (stat /= 0) return
    dims(1) = 1
    tmp = int(value, int32)
    call h5dwrite_f(dset, t_i32, tmp, dims, err)
    if (err /= 0) stat = 1
    call h5dclose_f(dset, err)
    call h5sclose_f(space, err)
  end subroutine

  subroutine put_i64(loc, name, value, stat)
    integer(hid_t), intent(in) :: loc
    character(len=*), intent(in) :: name
    integer(int64), intent(in) :: value
    integer, intent(inout) :: stat
    integer(hid_t) :: space, dset
    integer :: err
    integer(hsize_t) :: dims(1)
    if (stat /= 0) return
    call put_scalar_space(space, dset, loc, name, t_i64, stat)
    if (stat /= 0) return
    dims(1) = 1
    call h5dwrite_f(dset, t_i64, value, dims, err)
    if (err /= 0) stat = 1
    call h5dclose_f(dset, err)
    call h5sclose_f(space, err)
  end subroutine

  subroutine put_f64(loc, name, value, stat)
    integer(hid_t), intent(in) :: loc
    character(len=*), intent(in) :: name
    real(real64), intent(in) :: value
    integer, intent(inout) :: stat
    integer(hid_t) :: space, dset
    integer :: err
    integer(hsize_t) :: dims(1)
    if (stat /= 0) return
    call put_scalar_space(space, dset, loc, name, t_f64, stat)
    if (stat /= 0) return
    dims(1) = 1
    call h5dwrite_f(dset, t_f64, value, dims, err)
    if (err /= 0) stat = 1
    call h5dclose_f(dset, err)
    call h5sclose_f(space, err)
  end subroutine

  subroutine put_bool(loc, name, value, stat)
    integer(hid_t), intent(in) :: loc
    character(len=*), intent(in) :: name
    logical, intent(in) :: value
    integer, intent(inout) :: stat
    integer(hid_t) :: space, dset
    integer :: err
    integer(hsize_t) :: dims(1)
    integer(int8) :: tmp
    if (stat /= 0) return
    call put_scalar_space(space, dset, loc, name, t_i8, stat)
    if (stat /= 0) return
    dims(1) = 1
    tmp = 0_int8
    if (value) tmp = 1_int8
    call h5dwrite_f(dset, t_i8, tmp, dims, err)
    if (err /= 0) stat = 1
    call h5dclose_f(dset, err)
    call h5sclose_f(space, err)
  end subroutine

  subroutine put_text(loc, name, text, n, stat)
    integer(hid_t), intent(in) :: loc
    character(len=*), intent(in) :: name, text
    integer, intent(in) :: n
    integer, intent(inout) :: stat
    integer(hid_t) :: space, dset
    integer :: err, m
    integer(hsize_t) :: dims(1)
    character(len=v2_str) :: buf
    if (stat /= 0) return
    call put_i32(loc, trim(name) // "_n", n, stat)
    if (stat /= 0) return
    buf = ""
    m = n
    if (m < 0) m = 0
    if (m > v2_str) m = v2_str
    if (m > 0) buf(1:m) = text(1:m)
    call put_scalar_space(space, dset, loc, name, t_str, stat)
    if (stat /= 0) return
    dims(1) = 1
    call h5dwrite_f(dset, t_str, buf, dims, err)
    if (err /= 0) stat = 1
    call h5dclose_f(dset, err)
    call h5sclose_f(space, err)
  end subroutine

  subroutine put_text_1d(loc, name, n, stat, skus)
    integer(hid_t), intent(in) :: loc
    character(len=*), intent(in) :: name
    integer, intent(in) :: n
    integer, intent(inout) :: stat
    type(fixture_t), intent(in) :: skus
    integer(hid_t) :: space, dset
    integer :: err, i, m
    integer(hsize_t) :: dims(1)
    character(len=v2_str), allocatable :: buf(:)
    integer(int32), allocatable :: lens(:)
    if (stat /= 0) return
    if (n <= 0) return
    allocate(buf(n), lens(n))
    do i = 1, n
      m = skus%document%items(i)%sku_n
      if (m < 0) m = 0
      if (m > v2_str) m = v2_str
      lens(i) = int(m, int32)
      buf(i) = ""
      if (m > 0) buf(i)(1:m) = skus%document%items(i)%sku(1:m)
    end do
    dims(1) = n
    call h5screate_simple_f(1, dims, space, err)
    if (err /= 0) then
      stat = 1
      return
    end if
    call h5dcreate_f(loc, name // "_n", t_i32, space, dset, err)
    if (err == 0) call h5dwrite_f(dset, t_i32, lens, dims, err)
    call h5dclose_f(dset, err)
    call h5sclose_f(space, err)
    if (err /= 0) stat = 1
    if (stat /= 0) return
    call h5screate_simple_f(1, dims, space, err)
    call h5dcreate_f(loc, name, t_str, space, dset, err)
    if (err == 0) call h5dwrite_f(dset, t_str, buf, dims, err)
    if (err /= 0) stat = 1
    call h5dclose_f(dset, err)
    call h5sclose_f(space, err)
  end subroutine

  subroutine put_i32_1d_qty(loc, fx, stat)
    integer(hid_t), intent(in) :: loc
    type(fixture_t), intent(in) :: fx
    integer, intent(inout) :: stat
    integer :: n, i
    integer(int32), allocatable :: buf(:)
    n = fx%document%item_count
    if (n <= 0 .or. stat /= 0) return
    allocate(buf(n))
    do i = 1, n
      buf(i) = fx%document%items(i)%qty
    end do
    call put_i32_vec(loc, "qty", buf, stat)
  end subroutine

  subroutine put_i64_1d_price(loc, fx, stat)
    integer(hid_t), intent(in) :: loc
    type(fixture_t), intent(in) :: fx
    integer, intent(inout) :: stat
    integer :: n, i
    integer(int64), allocatable :: buf(:)
    n = fx%document%item_count
    if (n <= 0 .or. stat /= 0) return
    allocate(buf(n))
    do i = 1, n
      buf(i) = fx%document%items(i)%price_minor
    end do
    call put_i64_vec(loc, "price_minor", buf, stat)
  end subroutine

  subroutine put_i32_vec(loc, name, buf, stat)
    integer(hid_t), intent(in) :: loc
    character(len=*), intent(in) :: name
    integer(int32), intent(in) :: buf(:)
    integer, intent(inout) :: stat
    integer(hid_t) :: space, dset
    integer :: err
    integer(hsize_t) :: dims(1)
    if (stat /= 0) return
    dims(1) = size(buf)
    call h5screate_simple_f(1, dims, space, err)
    call h5dcreate_f(loc, name, t_i32, space, dset, err)
    if (err == 0) call h5dwrite_f(dset, t_i32, buf, dims, err)
    if (err /= 0) stat = 1
    call h5dclose_f(dset, err)
    call h5sclose_f(space, err)
  end subroutine

  subroutine put_i64_vec(loc, name, buf, stat)
    integer(hid_t), intent(in) :: loc
    character(len=*), intent(in) :: name
    integer(int64), intent(in) :: buf(:)
    integer, intent(inout) :: stat
    integer(hid_t) :: space, dset
    integer :: err
    integer(hsize_t) :: dims(1)
    if (stat /= 0) return
    dims(1) = size(buf)
    call h5screate_simple_f(1, dims, space, err)
    call h5dcreate_f(loc, name, t_i64, space, dset, err)
    if (err == 0) call h5dwrite_f(dset, t_i64, buf, dims, err)
    if (err /= 0) stat = 1
    call h5dclose_f(dset, err)
    call h5sclose_f(space, err)
  end subroutine

  subroutine put_tags(loc, fx, stat)
    integer(hid_t), intent(in) :: loc
    type(fixture_t), intent(in) :: fx
    integer, intent(inout) :: stat
    integer :: n, i, m
    character(len=v2_str), allocatable :: buf(:)
    integer(int32), allocatable :: lens(:)
    n = fx%telemetry%tag_count
    if (n <= 0 .or. stat /= 0) return
    allocate(buf(n), lens(n))
    do i = 1, n
      m = fx%telemetry%tag_n(i)
      if (m < 0) m = 0
      if (m > v2_str) m = v2_str
      lens(i) = int(m, int32)
      buf(i) = ""
      if (m > 0) buf(i)(1:m) = fx%telemetry%tags(i)(1:m)
    end do
    call put_i32_vec(loc, "tag_n", lens, stat)
    call put_str_vec(loc, "tags", buf, stat)
  end subroutine

  subroutine put_values(loc, fx, stat)
    integer(hid_t), intent(in) :: loc
    type(fixture_t), intent(in) :: fx
    integer, intent(inout) :: stat
    integer(hid_t) :: space, dset
    integer :: err, n
    integer(hsize_t) :: dims(1)
    n = fx%telemetry%value_count
    if (n <= 0 .or. stat /= 0) return
    dims(1) = n
    call h5screate_simple_f(1, dims, space, err)
    call h5dcreate_f(loc, "values", t_f64, space, dset, err)
    if (err == 0) call h5dwrite_f(dset, t_f64, fx%telemetry%values(1:n), dims, err)
    if (err /= 0) stat = 1
    call h5dclose_f(dset, err)
    call h5sclose_f(space, err)
  end subroutine

  subroutine put_strings(loc, fx, stat)
    integer(hid_t), intent(in) :: loc
    type(fixture_t), intent(in) :: fx
    integer, intent(inout) :: stat
    integer :: n, i, m
    character(len=v2_str), allocatable :: buf(:)
    integer(int32), allocatable :: lens(:)
    n = fx%strings%count
    if (n <= 0 .or. stat /= 0) return
    allocate(buf(n), lens(n))
    do i = 1, n
      m = fx%strings%item_n(i)
      if (m < 0) m = 0
      if (m > v2_str) m = v2_str
      lens(i) = int(m, int32)
      buf(i) = ""
      if (m > 0) buf(i)(1:m) = fx%strings%items(i)(1:m)
    end do
    call put_i32_vec(loc, "item_n", lens, stat)
    call put_str_vec(loc, "items", buf, stat)
  end subroutine

  subroutine put_attrs(loc, fx, stat)
    integer(hid_t), intent(in) :: loc
    type(fixture_t), intent(in) :: fx
    integer, intent(inout) :: stat
    integer :: n, i, m
    character(len=v2_str), allocatable :: keys(:), vals(:)
    integer(int32), allocatable :: kn(:), vn(:)
    n = fx%event%attr_count
    if (n <= 0 .or. stat /= 0) return
    allocate(keys(n), vals(n), kn(n), vn(n))
    do i = 1, n
      m = fx%event%attrs(i)%key_n
      if (m < 0) m = 0
      if (m > v2_str) m = v2_str
      kn(i) = int(m, int32)
      keys(i) = ""
      if (m > 0) keys(i)(1:m) = fx%event%attrs(i)%key(1:m)
      m = fx%event%attrs(i)%value_n
      if (m < 0) m = 0
      if (m > v2_str) m = v2_str
      vn(i) = int(m, int32)
      vals(i) = ""
      if (m > 0) vals(i)(1:m) = fx%event%attrs(i)%value(1:m)
    end do
    call put_i32_vec(loc, "key_n", kn, stat)
    call put_str_vec(loc, "key", keys, stat)
    call put_i32_vec(loc, "value_n", vn, stat)
    call put_str_vec(loc, "value", vals, stat)
  end subroutine

  subroutine put_str_vec(loc, name, buf, stat)
    integer(hid_t), intent(in) :: loc
    character(len=*), intent(in) :: name
    character(len=v2_str), intent(in) :: buf(:)
    integer, intent(inout) :: stat
    integer(hid_t) :: space, dset
    integer :: err
    integer(hsize_t) :: dims(1)
    if (stat /= 0) return
    dims(1) = size(buf)
    call h5screate_simple_f(1, dims, space, err)
    call h5dcreate_f(loc, name, t_str, space, dset, err)
    if (err == 0) call h5dwrite_f(dset, t_str, buf, dims, err)
    if (err /= 0) stat = 1
    call h5dclose_f(dset, err)
    call h5sclose_f(space, err)
  end subroutine

  function open_dset(loc, name, dset, stat) result(ok)
    integer(hid_t), intent(in) :: loc
    character(len=*), intent(in) :: name
    integer(hid_t), intent(out) :: dset
    integer, intent(inout) :: stat
    logical :: ok
    integer :: err
    ok = .false.
    if (stat /= 0) return
    call h5dopen_f(loc, name, dset, err)
    if (err /= 0) then
      stat = 1
      return
    end if
    ok = .true.
  end function

  function get_i32(loc, name, stat) result(value)
    integer(hid_t), intent(in) :: loc
    character(len=*), intent(in) :: name
    integer, intent(inout) :: stat
    integer :: value
    integer(hid_t) :: dset
    integer :: err
    integer(hsize_t) :: dims(1)
    integer(int32) :: tmp
    value = 0
    if (.not. open_dset(loc, name, dset, stat)) return
    dims(1) = 1
    call h5dread_f(dset, t_i32, tmp, dims, err)
    if (err /= 0) stat = 1
    value = int(tmp)
    call h5dclose_f(dset, err)
  end function

  function get_i64(loc, name, stat) result(value)
    integer(hid_t), intent(in) :: loc
    character(len=*), intent(in) :: name
    integer, intent(inout) :: stat
    integer(int64) :: value
    integer(hid_t) :: dset
    integer :: err
    integer(hsize_t) :: dims(1)
    value = 0
    if (.not. open_dset(loc, name, dset, stat)) return
    dims(1) = 1
    call h5dread_f(dset, t_i64, value, dims, err)
    if (err /= 0) stat = 1
    call h5dclose_f(dset, err)
  end function

  function get_f64(loc, name, stat) result(value)
    integer(hid_t), intent(in) :: loc
    character(len=*), intent(in) :: name
    integer, intent(inout) :: stat
    real(real64) :: value
    integer(hid_t) :: dset
    integer :: err
    integer(hsize_t) :: dims(1)
    value = 0
    if (.not. open_dset(loc, name, dset, stat)) return
    dims(1) = 1
    call h5dread_f(dset, t_f64, value, dims, err)
    if (err /= 0) stat = 1
    call h5dclose_f(dset, err)
  end function

  function get_bool(loc, name, stat) result(value)
    integer(hid_t), intent(in) :: loc
    character(len=*), intent(in) :: name
    integer, intent(inout) :: stat
    logical :: value
    integer(hid_t) :: dset
    integer :: err
    integer(hsize_t) :: dims(1)
    integer(int8) :: tmp
    value = .false.
    if (.not. open_dset(loc, name, dset, stat)) return
    dims(1) = 1
    call h5dread_f(dset, t_i8, tmp, dims, err)
    if (err /= 0) stat = 1
    value = tmp /= 0_int8
    call h5dclose_f(dset, err)
  end function

  subroutine get_text(loc, name, text, n, stat)
    integer(hid_t), intent(in) :: loc
    character(len=*), intent(in) :: name
    character(len=*), intent(out) :: text
    integer, intent(out) :: n
    integer, intent(inout) :: stat
    integer(hid_t) :: dset
    integer :: err
    integer(hsize_t) :: dims(1)
    character(len=v2_str) :: buf
    n = get_i32(loc, trim(name) // "_n", stat)
    if (stat /= 0) return
    if (.not. open_dset(loc, name, dset, stat)) return
    dims(1) = 1
    buf = ""
    call h5dread_f(dset, t_str, buf, dims, err)
    if (err /= 0) stat = 1
    call h5dclose_f(dset, err)
    call keep_text(buf, n, text, n)
  end subroutine

  subroutine keep_text(raw, nraw, dst, ndst)
    character(len=*), intent(in) :: raw
    integer, intent(in) :: nraw
    character(len=*), intent(out) :: dst
    integer, intent(out) :: ndst
    integer :: m
    m = nraw
    if (m < 0) m = 0
    if (m > len(raw)) m = len(raw)
    if (m > len(dst)) m = len(dst)
    if (m == 0) then
      call store_text(dst, ndst, "")
    else
      call store_text(dst, ndst, raw(1:m))
    end if
  end subroutine

  subroutine get_i32_vec(loc, name, n, buf, stat)
    integer(hid_t), intent(in) :: loc
    character(len=*), intent(in) :: name
    integer, intent(in) :: n
    integer(int32), intent(out) :: buf(:)
    integer, intent(inout) :: stat
    integer(hid_t) :: dset
    integer :: err
    integer(hsize_t) :: dims(1)
    if (n <= 0 .or. stat /= 0) return
    if (.not. open_dset(loc, name, dset, stat)) return
    dims(1) = n
    call h5dread_f(dset, t_i32, buf(1:n), dims, err)
    if (err /= 0) stat = 1
    call h5dclose_f(dset, err)
  end subroutine

  subroutine get_skus(loc, fx, stat)
    integer(hid_t), intent(in) :: loc
    type(fixture_t), intent(inout) :: fx
    integer, intent(inout) :: stat
    integer :: n, i
    character(len=v2_str), allocatable :: buf(:)
    integer(int32), allocatable :: lens(:)
    n = fx%document%item_count
    if (n <= 0 .or. stat /= 0) return
    allocate(buf(n), lens(n))
    call get_i32_vec(loc, "sku_n", n, lens, stat)
    call get_str_vec(loc, "sku", n, buf, stat)
    if (stat /= 0) return
    do i = 1, n
      call keep_text(buf(i), int(lens(i)), fx%document%items(i)%sku, fx%document%items(i)%sku_n)
    end do
  end subroutine

  subroutine get_qty(loc, fx, stat)
    integer(hid_t), intent(in) :: loc
    type(fixture_t), intent(inout) :: fx
    integer, intent(inout) :: stat
    integer :: n, i
    integer(int32), allocatable :: buf(:)
    n = fx%document%item_count
    if (n <= 0 .or. stat /= 0) return
    allocate(buf(n))
    call get_i32_vec(loc, "qty", n, buf, stat)
    if (stat /= 0) return
    do i = 1, n
      fx%document%items(i)%qty = buf(i)
    end do
  end subroutine

  subroutine get_price(loc, fx, stat)
    integer(hid_t), intent(in) :: loc
    type(fixture_t), intent(inout) :: fx
    integer, intent(inout) :: stat
    integer :: n, i
    integer(int64), allocatable :: buf(:)
    integer(hid_t) :: dset
    integer :: err
    integer(hsize_t) :: dims(1)
    n = fx%document%item_count
    if (n <= 0 .or. stat /= 0) return
    allocate(buf(n))
    if (.not. open_dset(loc, "price_minor", dset, stat)) return
    dims(1) = n
    call h5dread_f(dset, t_i64, buf, dims, err)
    if (err /= 0) stat = 1
    call h5dclose_f(dset, err)
    if (stat /= 0) return
    do i = 1, n
      fx%document%items(i)%price_minor = buf(i)
    end do
  end subroutine

  subroutine get_str_vec(loc, name, n, buf, stat)
    integer(hid_t), intent(in) :: loc
    character(len=*), intent(in) :: name
    integer, intent(in) :: n
    character(len=v2_str), intent(out) :: buf(:)
    integer, intent(inout) :: stat
    integer(hid_t) :: dset
    integer :: err
    integer(hsize_t) :: dims(1)
    if (n <= 0 .or. stat /= 0) return
    if (.not. open_dset(loc, name, dset, stat)) return
    dims(1) = n
    call h5dread_f(dset, t_str, buf(1:n), dims, err)
    if (err /= 0) stat = 1
    call h5dclose_f(dset, err)
  end subroutine

  subroutine get_tags(loc, fx, stat)
    integer(hid_t), intent(in) :: loc
    type(fixture_t), intent(inout) :: fx
    integer, intent(inout) :: stat
    integer :: n, i
    character(len=v2_str), allocatable :: buf(:)
    integer(int32), allocatable :: lens(:)
    n = fx%telemetry%tag_count
    if (n <= 0 .or. stat /= 0) return
    allocate(buf(n), lens(n))
    call get_i32_vec(loc, "tag_n", n, lens, stat)
    call get_str_vec(loc, "tags", n, buf, stat)
    if (stat /= 0) return
    do i = 1, n
      call keep_text(buf(i), int(lens(i)), fx%telemetry%tags(i), fx%telemetry%tag_n(i))
    end do
  end subroutine

  subroutine get_values(loc, fx, stat)
    integer(hid_t), intent(in) :: loc
    type(fixture_t), intent(inout) :: fx
    integer, intent(inout) :: stat
    integer :: n
    integer(hid_t) :: dset
    integer :: err
    integer(hsize_t) :: dims(1)
    n = fx%telemetry%value_count
    if (n <= 0 .or. stat /= 0) return
    if (.not. open_dset(loc, "values", dset, stat)) return
    dims(1) = n
    call h5dread_f(dset, t_f64, fx%telemetry%values(1:n), dims, err)
    if (err /= 0) stat = 1
    call h5dclose_f(dset, err)
  end subroutine

  subroutine get_strings(loc, fx, stat)
    integer(hid_t), intent(in) :: loc
    type(fixture_t), intent(inout) :: fx
    integer, intent(inout) :: stat
    integer :: n, i
    character(len=v2_str), allocatable :: buf(:)
    integer(int32), allocatable :: lens(:)
    n = fx%strings%count
    if (n <= 0 .or. stat /= 0) return
    allocate(buf(n), lens(n))
    call get_i32_vec(loc, "item_n", n, lens, stat)
    call get_str_vec(loc, "items", n, buf, stat)
    if (stat /= 0) return
    do i = 1, n
      call keep_text(buf(i), int(lens(i)), fx%strings%items(i), fx%strings%item_n(i))
    end do
  end subroutine

  subroutine get_attrs(loc, fx, stat)
    integer(hid_t), intent(in) :: loc
    type(fixture_t), intent(inout) :: fx
    integer, intent(inout) :: stat
    integer :: n, i
    character(len=v2_str), allocatable :: keys(:), vals(:)
    integer(int32), allocatable :: kn(:), vn(:)
    n = fx%event%attr_count
    if (n <= 0 .or. stat /= 0) return
    allocate(keys(n), vals(n), kn(n), vn(n))
    call get_i32_vec(loc, "key_n", n, kn, stat)
    call get_str_vec(loc, "key", n, keys, stat)
    call get_i32_vec(loc, "value_n", n, vn, stat)
    call get_str_vec(loc, "value", n, vals, stat)
    if (stat /= 0) return
    do i = 1, n
      call keep_text(keys(i), int(kn(i)), fx%event%attrs(i)%key, fx%event%attrs(i)%key_n)
      call keep_text(vals(i), int(vn(i)), fx%event%attrs(i)%value, fx%event%attrs(i)%value_n)
    end do
  end subroutine

end module
