module ser_adios2
  ! Official ADIOS2 Fortran bindings over the C++ core. Serial BP5 writes a
  ! directory, so this row is file-only (stream/native). There is no bytes API.
  ! Bool is int8 0/1. Strings are fixed-length byte arrays plus an explicit length.
  use, intrinsic :: iso_fortran_env, only: int8, int32, int64, real64
  use, intrinsic :: iso_c_binding, only: c_char, c_int, c_int64_t, c_null_char
  use adios2
  use bench_data
  implicit none
  private
  public :: ad_name, ad_version, ad_prepare, ad_write, ad_read, ad_remove, ad_slurp

  character(len=*), parameter :: ad_name = "adios2"
  character(len=*), parameter :: ad_version = "2.10.2"

  type(adios2_adios) :: adios
  integer :: io_seq = 0
  logical :: ready = .false.

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

  subroutine ad_write(items, path, nbytes, stat)
    type(fixture_t), intent(in) :: items(:)
    character(len=*), intent(in) :: path
    integer(int64), intent(out) :: nbytes
    integer, intent(out) :: stat
    type(adios2_io) :: io
    character(len=32) :: ioname
    integer(c_int64_t) :: tree_n
    nbytes = 0
    stat = 1
    if (.not. ready) return
    call ad_remove(path)
    io_seq = io_seq + 1
    write(ioname, '("w",I0)') io_seq
    call adios2_declare_io(io, adios, trim(ioname), stat)
    if (stat /= 0) return
    call adios2_set_engine(io, "BP5", stat)
    if (stat /= 0) return
    select case (items(1)%kind_id)
    case (kind_message)
      call write_message(io, path, items, stat)
    case (kind_document)
      call write_document(io, path, items, stat)
    case (kind_telemetry)
      call write_telemetry(io, path, items, stat)
    case (kind_strings)
      call write_strings(io, path, items, stat)
    case (kind_event)
      call write_event(io, path, items, stat)
    case default
      stat = 1
    end select
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

  subroutine ad_read(path, expected_n, items, stat)
    character(len=*), intent(in) :: path
    integer, intent(in) :: expected_n
    type(fixture_t), allocatable, intent(out) :: items(:)
    integer, intent(out) :: stat
    type(adios2_io) :: io
    type(adios2_engine) :: eng
    type(adios2_variable) :: vk
    character(len=32) :: ioname
    integer :: n, kind, ierr
    integer(kind=4) :: kind4
    n = expected_n
    if (n < 1) n = 1
    stat = 1
    if (.not. ready) return
    io_seq = io_seq + 1
    write(ioname, '("r",I0)') io_seq
    call adios2_declare_io(io, adios, trim(ioname), stat)
    if (stat /= 0) return
    call adios2_open(eng, io, trim(path), adios2_mode_readRandomAccess, stat)
    if (stat /= 0) return
    call adios2_inquire_variable(vk, io, "kind", ierr)
    if (ierr /= 0) then
      call adios2_close(eng, stat)
      stat = 1
      return
    end if
    call adios2_get(eng, vk, kind4, adios2_mode_sync, ierr)
    if (ierr /= 0) then
      call adios2_close(eng, stat)
      stat = 1
      return
    end if
    kind = int(kind4)
    allocate(items(n))
    items%kind_id = kind
    select case (kind)
    case (kind_message)
      call read_message(eng, io, items, stat)
    case (kind_document)
      call read_document(eng, io, items, stat)
    case (kind_telemetry)
      call read_telemetry(eng, io, items, stat)
    case (kind_strings)
      call read_strings(eng, io, items, stat)
    case (kind_event)
      call read_event(eng, io, items, stat)
    case default
      stat = 1
    end select
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

  subroutine open_write(io, path, eng, stat)
    type(adios2_io), intent(in) :: io
    character(len=*), intent(in) :: path
    type(adios2_engine), intent(out) :: eng
    integer, intent(out) :: stat
    call adios2_open(eng, io, trim(path), adios2_mode_write, stat)
    if (stat /= 0) return
    call adios2_begin_step(eng, adios2_step_mode_append, stat)
  end subroutine

  subroutine close_write(eng, stat)
    type(adios2_engine), intent(inout) :: eng
    integer, intent(inout) :: stat
    integer :: ierr
    if (stat == 0) call adios2_end_step(eng, stat)
    call adios2_close(eng, ierr)
    if (stat == 0 .and. ierr /= 0) stat = ierr
  end subroutine

  subroutine def_scalar_i4(io, var, name, ierr)
    type(adios2_io), intent(in) :: io
    type(adios2_variable), intent(out) :: var
    character(len=*), intent(in) :: name
    integer, intent(out) :: ierr
    call adios2_define_variable(var, io, name, adios2_type_integer4, ierr)
  end subroutine

  subroutine def_1d(io, var, name, typ, n, ierr)
    type(adios2_io), intent(in) :: io
    type(adios2_variable), intent(out) :: var
    character(len=*), intent(in) :: name
    integer, intent(in) :: typ, n
    integer, intent(out) :: ierr
    integer(kind=8) :: shp(1), sta(1), cnt(1)
    shp(1) = int(n, kind=8)
    sta(1) = 0_8
    cnt(1) = shp(1)
    call adios2_define_variable(var, io, name, typ, 1, shp, sta, cnt, &
         adios2_constant_dims, ierr)
  end subroutine

  subroutine pack_text_1d(dst, src, nsrc)
    integer(kind=1), intent(out) :: dst(:)
    character(len=*), intent(in) :: src
    integer, intent(in) :: nsrc
    integer :: j, m
    dst = 0_1
    m = nsrc
    if (m > size(dst)) m = size(dst)
    if (m > len(src)) m = len(src)
    do j = 1, m
      dst(j) = int(iand(ichar(src(j:j)), 255), kind=1)
    end do
  end subroutine

  subroutine unpack_text(dst, ndst, raw, nraw)
    character(len=*), intent(out) :: dst
    integer, intent(out) :: ndst
    integer(kind=1), intent(in) :: raw(:)
    integer, intent(in) :: nraw
    character(len=:), allocatable :: tmp
    integer :: j, m
    m = nraw
    if (m < 0) m = 0
    if (m > size(raw)) m = size(raw)
    if (m == 0) then
      call store_text(dst, ndst, "")
      return
    end if
    allocate(character(len=m) :: tmp)
    do j = 1, m
      tmp(j:j) = achar(iand(int(raw(j), int32), 255))
    end do
    call store_text(dst, ndst, tmp)
  end subroutine

  subroutine write_message(io, path, items, stat)
    type(adios2_io), intent(in) :: io
    character(len=*), intent(in) :: path
    type(fixture_t), intent(in) :: items(:)
    integer, intent(out) :: stat
    type(adios2_engine) :: eng
    type(adios2_variable) :: vk, vb, vi32, vi64, vf, vs, vn, vb2, vi322, vs2, vn2
    integer :: n, i, ierr
    integer(kind=4) :: kind4
    integer(kind=1), allocatable :: b(:), b2(:), s(:), s2(:)
    integer(kind=4), allocatable :: i32(:), i322(:), sn(:), sn2(:)
    integer(kind=8), allocatable :: i64(:)
    real(kind=8), allocatable :: f64(:)
    n = size(items)
    kind4 = int(kind_message, kind=4)
    call def_scalar_i4(io, vk, "kind", stat)
    if (stat /= 0) return
    call def_1d(io, vb, "f_bool", adios2_type_integer1, n, stat)
    call def_1d(io, vi32, "f_int32", adios2_type_integer4, n, ierr)
    call def_1d(io, vi64, "f_int64", adios2_type_integer8, n, ierr)
    call def_1d(io, vf, "f_float64", adios2_type_real8, n, ierr)
    call def_1d(io, vs, "f_string", adios2_type_integer1, n * v2_str, ierr)
    call def_1d(io, vn, "f_string_n", adios2_type_integer4, n, ierr)
    call def_1d(io, vb2, "f_bool_2", adios2_type_integer1, n, ierr)
    call def_1d(io, vi322, "f_int32_2", adios2_type_integer4, n, ierr)
    call def_1d(io, vs2, "f_string_2", adios2_type_integer1, n * v2_str, ierr)
    call def_1d(io, vn2, "f_string_2_n", adios2_type_integer4, n, ierr)
    if (stat /= 0 .or. ierr /= 0) then
      stat = 1
      return
    end if
    allocate(b(n), b2(n), s(n * v2_str), s2(n * v2_str))
    allocate(i32(n), i322(n), sn(n), sn2(n), i64(n), f64(n))
    do i = 1, n
      b(i) = merge(1_1, 0_1, items(i)%message%f_bool)
      b2(i) = merge(1_1, 0_1, items(i)%message%f_bool_2)
      i32(i) = int(items(i)%message%f_int32, kind=4)
      i322(i) = int(items(i)%message%f_int32_2, kind=4)
      i64(i) = int(items(i)%message%f_int64, kind=8)
      f64(i) = real(items(i)%message%f_float64, kind=8)
      sn(i) = int(items(i)%message%f_string_n, kind=4)
      sn2(i) = int(items(i)%message%f_string_2_n, kind=4)
      call pack_text_1d(s((i - 1) * v2_str + 1 : i * v2_str), &
           items(i)%message%f_string, items(i)%message%f_string_n)
      call pack_text_1d(s2((i - 1) * v2_str + 1 : i * v2_str), &
           items(i)%message%f_string_2, items(i)%message%f_string_2_n)
    end do
    call open_write(io, path, eng, stat)
    if (stat /= 0) return
    call adios2_put(eng, vk, kind4, adios2_mode_sync, stat)
    call adios2_put(eng, vb, b, adios2_mode_sync, ierr)
    call adios2_put(eng, vi32, i32, adios2_mode_sync, ierr)
    call adios2_put(eng, vi64, i64, adios2_mode_sync, ierr)
    call adios2_put(eng, vf, f64, adios2_mode_sync, ierr)
    call adios2_put(eng, vs, s, adios2_mode_sync, ierr)
    call adios2_put(eng, vn, sn, adios2_mode_sync, ierr)
    call adios2_put(eng, vb2, b2, adios2_mode_sync, ierr)
    call adios2_put(eng, vi322, i322, adios2_mode_sync, ierr)
    call adios2_put(eng, vs2, s2, adios2_mode_sync, ierr)
    call adios2_put(eng, vn2, sn2, adios2_mode_sync, ierr)
    if (ierr /= 0) stat = ierr
    call close_write(eng, stat)
  end subroutine

  subroutine read_message(eng, io, items, stat)
    type(adios2_engine), intent(in) :: eng
    type(adios2_io), intent(in) :: io
    type(fixture_t), intent(inout) :: items(:)
    integer, intent(out) :: stat
    integer :: n, i, ierr
    integer(kind=1), allocatable :: b(:), b2(:), s(:), s2(:)
    integer(kind=4), allocatable :: i32(:), i322(:), sn(:), sn2(:)
    integer(kind=8), allocatable :: i64(:)
    real(kind=8), allocatable :: f64(:)
    n = size(items)
    allocate(b(n), b2(n), s(n * v2_str), s2(n * v2_str))
    allocate(i32(n), i322(n), sn(n), sn2(n), i64(n), f64(n))
    call get_i1(eng, io, "f_bool", b, stat)
    call get_i4a(eng, io, "f_int32", i32, ierr)
    call get_i8(eng, io, "f_int64", i64, ierr)
    call get_r8(eng, io, "f_float64", f64, ierr)
    call get_i1(eng, io, "f_string", s, ierr)
    call get_i4a(eng, io, "f_string_n", sn, ierr)
    call get_i1(eng, io, "f_bool_2", b2, ierr)
    call get_i4a(eng, io, "f_int32_2", i322, ierr)
    call get_i1(eng, io, "f_string_2", s2, ierr)
    call get_i4a(eng, io, "f_string_2_n", sn2, ierr)
    if (stat /= 0 .or. ierr /= 0) then
      stat = 1
      return
    end if
    do i = 1, n
      items(i)%message%f_bool = b(i) /= 0_1
      items(i)%message%f_bool_2 = b2(i) /= 0_1
      items(i)%message%f_int32 = int(i32(i), int32)
      items(i)%message%f_int32_2 = int(i322(i), int32)
      items(i)%message%f_int64 = int(i64(i), int64)
      items(i)%message%f_float64 = real(f64(i), real64)
      call unpack_text(items(i)%message%f_string, items(i)%message%f_string_n, &
           s((i - 1) * v2_str + 1 : i * v2_str), int(sn(i)))
      call unpack_text(items(i)%message%f_string_2, items(i)%message%f_string_2_n, &
           s2((i - 1) * v2_str + 1 : i * v2_str), int(sn2(i)))
    end do
  end subroutine

  subroutine write_document(io, path, items, stat)
    type(adios2_io), intent(in) :: io
    character(len=*), intent(in) :: path
    type(fixture_t), intent(in) :: items(:)
    integer, intent(out) :: stat
    type(adios2_engine) :: eng
    type(adios2_variable) :: vk, vid, vidn, vst, vreg, vregn, vver, vic
    type(adios2_variable) :: vsku, vskun, vqty, vprice
    integer :: n, i, k, m, ierr, base
    integer(kind=4) :: kind4
    integer(kind=1), allocatable :: idb(:), regb(:), sku(:)
    integer(kind=4), allocatable :: idn(:), regn(:), status(:), version(:), ic(:), skun(:), qty(:)
    integer(kind=8), allocatable :: price(:)
    n = size(items)
    m = 0
    do i = 1, n
      if (items(i)%document%item_count > m) m = items(i)%document%item_count
    end do
    kind4 = int(kind_document, kind=4)
    call def_scalar_i4(io, vk, "kind", stat)
    call def_1d(io, vid, "id", adios2_type_integer1, n * v2_str, ierr)
    call def_1d(io, vidn, "id_n", adios2_type_integer4, n, ierr)
    call def_1d(io, vst, "status", adios2_type_integer4, n, ierr)
    call def_1d(io, vreg, "region", adios2_type_integer1, n * v2_str, ierr)
    call def_1d(io, vregn, "region_n", adios2_type_integer4, n, ierr)
    call def_1d(io, vver, "version", adios2_type_integer4, n, ierr)
    call def_1d(io, vic, "item_count", adios2_type_integer4, n, ierr)
    if (m > 0) then
      call def_1d(io, vsku, "sku", adios2_type_integer1, n * m * v2_str, ierr)
      call def_1d(io, vskun, "sku_n", adios2_type_integer4, n * m, ierr)
      call def_1d(io, vqty, "qty", adios2_type_integer4, n * m, ierr)
      call def_1d(io, vprice, "price_minor", adios2_type_integer8, n * m, ierr)
    end if
    if (stat /= 0 .or. ierr /= 0) then
      stat = 1
      return
    end if
    allocate(idb(n * v2_str), regb(n * v2_str))
    allocate(idn(n), regn(n), status(n), version(n), ic(n))
    if (m > 0) then
      allocate(sku(n * m * v2_str), skun(n * m), qty(n * m), price(n * m))
      sku = 0_1
      skun = 0_4
      qty = 0_4
      price = 0_8
    end if
    do i = 1, n
      call pack_text_1d(idb((i - 1) * v2_str + 1 : i * v2_str), &
           items(i)%document%id, items(i)%document%id_n)
      call pack_text_1d(regb((i - 1) * v2_str + 1 : i * v2_str), &
           items(i)%document%region, items(i)%document%region_n)
      idn(i) = int(items(i)%document%id_n, kind=4)
      regn(i) = int(items(i)%document%region_n, kind=4)
      status(i) = int(items(i)%document%status, kind=4)
      version(i) = int(items(i)%document%version, kind=4)
      ic(i) = int(items(i)%document%item_count, kind=4)
      if (m > 0) then
        do k = 1, items(i)%document%item_count
          base = ((i - 1) * m + (k - 1)) * v2_str
          call pack_text_1d(sku(base + 1 : base + v2_str), &
               items(i)%document%items(k)%sku, items(i)%document%items(k)%sku_n)
          skun((i - 1) * m + k) = int(items(i)%document%items(k)%sku_n, kind=4)
          qty((i - 1) * m + k) = int(items(i)%document%items(k)%qty, kind=4)
          price((i - 1) * m + k) = int(items(i)%document%items(k)%price_minor, kind=8)
        end do
      end if
    end do
    call open_write(io, path, eng, stat)
    if (stat /= 0) return
    call adios2_put(eng, vk, kind4, adios2_mode_sync, stat)
    call adios2_put(eng, vid, idb, adios2_mode_sync, ierr)
    call adios2_put(eng, vidn, idn, adios2_mode_sync, ierr)
    call adios2_put(eng, vst, status, adios2_mode_sync, ierr)
    call adios2_put(eng, vreg, regb, adios2_mode_sync, ierr)
    call adios2_put(eng, vregn, regn, adios2_mode_sync, ierr)
    call adios2_put(eng, vver, version, adios2_mode_sync, ierr)
    call adios2_put(eng, vic, ic, adios2_mode_sync, ierr)
    if (m > 0) then
      call adios2_put(eng, vsku, sku, adios2_mode_sync, ierr)
      call adios2_put(eng, vskun, skun, adios2_mode_sync, ierr)
      call adios2_put(eng, vqty, qty, adios2_mode_sync, ierr)
      call adios2_put(eng, vprice, price, adios2_mode_sync, ierr)
    end if
    if (ierr /= 0) stat = ierr
    call close_write(eng, stat)
  end subroutine

  subroutine read_document(eng, io, items, stat)
    type(adios2_engine), intent(in) :: eng
    type(adios2_io), intent(in) :: io
    type(fixture_t), intent(inout) :: items(:)
    integer, intent(out) :: stat
    integer :: n, i, k, m, ierr, base
    integer(kind=1), allocatable :: idb(:), regb(:), sku(:)
    integer(kind=4), allocatable :: idn(:), regn(:), status(:), version(:), ic(:), skun(:), qty(:)
    integer(kind=8), allocatable :: price(:)
    n = size(items)
    allocate(idb(n * v2_str), regb(n * v2_str))
    allocate(idn(n), regn(n), status(n), version(n), ic(n))
    call get_i1(eng, io, "id", idb, stat)
    call get_i4a(eng, io, "id_n", idn, ierr)
    call get_i4a(eng, io, "status", status, ierr)
    call get_i1(eng, io, "region", regb, ierr)
    call get_i4a(eng, io, "region_n", regn, ierr)
    call get_i4a(eng, io, "version", version, ierr)
    call get_i4a(eng, io, "item_count", ic, ierr)
    if (stat /= 0 .or. ierr /= 0) then
      stat = 1
      return
    end if
    m = 0
    do i = 1, n
      if (int(ic(i)) > m) m = int(ic(i))
    end do
    if (m > 0) then
      allocate(sku(n * m * v2_str), skun(n * m), qty(n * m), price(n * m))
      call get_i1(eng, io, "sku", sku, stat)
      call get_i4a(eng, io, "sku_n", skun, ierr)
      call get_i4a(eng, io, "qty", qty, ierr)
      call get_i8(eng, io, "price_minor", price, ierr)
      if (stat /= 0 .or. ierr /= 0) then
        stat = 1
        return
      end if
    end if
    do i = 1, n
      call unpack_text(items(i)%document%id, items(i)%document%id_n, &
           idb((i - 1) * v2_str + 1 : i * v2_str), int(idn(i)))
      call unpack_text(items(i)%document%region, items(i)%document%region_n, &
           regb((i - 1) * v2_str + 1 : i * v2_str), int(regn(i)))
      items(i)%document%status = int(status(i), int32)
      items(i)%document%version = int(version(i), int32)
      items(i)%document%item_count = int(ic(i))
      if (items(i)%document%item_count > v2_max_children) items(i)%document%item_count = v2_max_children
      if (m > 0) then
        do k = 1, items(i)%document%item_count
          base = ((i - 1) * m + (k - 1)) * v2_str
          call unpack_text(items(i)%document%items(k)%sku, items(i)%document%items(k)%sku_n, &
               sku(base + 1 : base + v2_str), int(skun((i - 1) * m + k)))
          items(i)%document%items(k)%qty = int(qty((i - 1) * m + k), int32)
          items(i)%document%items(k)%price_minor = int(price((i - 1) * m + k), int64)
        end do
      end if
    end do
    stat = 0
  end subroutine

  subroutine write_telemetry(io, path, items, stat)
    type(adios2_io), intent(in) :: io
    character(len=*), intent(in) :: path
    type(fixture_t), intent(in) :: items(:)
    integer, intent(out) :: stat
    type(adios2_engine) :: eng
    type(adios2_variable) :: vk, vsrc, vsrcn, vts, vtc, vtn, vtags, vvc, vvals
    integer :: n, i, k, mt, mp, ierr, base
    integer(kind=4) :: kind4
    integer(kind=1), allocatable :: src(:), tags(:)
    integer(kind=4), allocatable :: srcn(:), tc(:), tn(:), vc(:)
    integer(kind=8), allocatable :: ts(:)
    real(kind=8), allocatable :: vals(:)
    n = size(items)
    mt = 0
    mp = 0
    do i = 1, n
      if (items(i)%telemetry%tag_count > mt) mt = items(i)%telemetry%tag_count
      if (items(i)%telemetry%value_count > mp) mp = items(i)%telemetry%value_count
    end do
    kind4 = int(kind_telemetry, kind=4)
    call def_scalar_i4(io, vk, "kind", stat)
    call def_1d(io, vsrc, "source", adios2_type_integer1, n * v2_str, ierr)
    call def_1d(io, vsrcn, "source_n", adios2_type_integer4, n, ierr)
    call def_1d(io, vts, "ts", adios2_type_integer8, n, ierr)
    call def_1d(io, vtc, "tag_count", adios2_type_integer4, n, ierr)
    call def_1d(io, vvc, "value_count", adios2_type_integer4, n, ierr)
    if (mt > 0) then
      call def_1d(io, vtags, "tags", adios2_type_integer1, n * mt * v2_str, ierr)
      call def_1d(io, vtn, "tag_n", adios2_type_integer4, n * mt, ierr)
    end if
    if (mp > 0) call def_1d(io, vvals, "values", adios2_type_real8, n * mp, ierr)
    if (stat /= 0 .or. ierr /= 0) then
      stat = 1
      return
    end if
    allocate(src(n * v2_str), srcn(n), ts(n), tc(n), vc(n))
    if (mt > 0) then
      allocate(tags(n * mt * v2_str), tn(n * mt))
      tags = 0_1
      tn = 0_4
    end if
    if (mp > 0) then
      allocate(vals(n * mp))
      vals = 0.0_8
    end if
    do i = 1, n
      call pack_text_1d(src((i - 1) * v2_str + 1 : i * v2_str), &
           items(i)%telemetry%source, items(i)%telemetry%source_n)
      srcn(i) = int(items(i)%telemetry%source_n, kind=4)
      ts(i) = int(items(i)%telemetry%ts, kind=8)
      tc(i) = int(items(i)%telemetry%tag_count, kind=4)
      vc(i) = int(items(i)%telemetry%value_count, kind=4)
      if (mt > 0) then
        do k = 1, items(i)%telemetry%tag_count
          base = ((i - 1) * mt + (k - 1)) * v2_str
          call pack_text_1d(tags(base + 1 : base + v2_str), &
               items(i)%telemetry%tags(k), items(i)%telemetry%tag_n(k))
          tn((i - 1) * mt + k) = int(items(i)%telemetry%tag_n(k), kind=4)
        end do
      end if
      if (mp > 0) then
        do k = 1, items(i)%telemetry%value_count
          vals((i - 1) * mp + k) = real(items(i)%telemetry%values(k), kind=8)
        end do
      end if
    end do
    call open_write(io, path, eng, stat)
    if (stat /= 0) return
    call adios2_put(eng, vk, kind4, adios2_mode_sync, stat)
    call adios2_put(eng, vsrc, src, adios2_mode_sync, ierr)
    call adios2_put(eng, vsrcn, srcn, adios2_mode_sync, ierr)
    call adios2_put(eng, vts, ts, adios2_mode_sync, ierr)
    call adios2_put(eng, vtc, tc, adios2_mode_sync, ierr)
    call adios2_put(eng, vvc, vc, adios2_mode_sync, ierr)
    if (mt > 0) then
      call adios2_put(eng, vtags, tags, adios2_mode_sync, ierr)
      call adios2_put(eng, vtn, tn, adios2_mode_sync, ierr)
    end if
    if (mp > 0) call adios2_put(eng, vvals, vals, adios2_mode_sync, ierr)
    if (ierr /= 0) stat = ierr
    call close_write(eng, stat)
  end subroutine

  subroutine read_telemetry(eng, io, items, stat)
    type(adios2_engine), intent(in) :: eng
    type(adios2_io), intent(in) :: io
    type(fixture_t), intent(inout) :: items(:)
    integer, intent(out) :: stat
    integer :: n, i, k, mt, mp, ierr, base
    integer(kind=1), allocatable :: src(:), tags(:)
    integer(kind=4), allocatable :: srcn(:), tc(:), tn(:), vc(:)
    integer(kind=8), allocatable :: ts(:)
    real(kind=8), allocatable :: vals(:)
    n = size(items)
    allocate(src(n * v2_str), srcn(n), ts(n), tc(n), vc(n))
    call get_i1(eng, io, "source", src, stat)
    call get_i4a(eng, io, "source_n", srcn, ierr)
    call get_i8(eng, io, "ts", ts, ierr)
    call get_i4a(eng, io, "tag_count", tc, ierr)
    call get_i4a(eng, io, "value_count", vc, ierr)
    if (stat /= 0 .or. ierr /= 0) then
      stat = 1
      return
    end if
    mt = 0
    mp = 0
    do i = 1, n
      if (int(tc(i)) > mt) mt = int(tc(i))
      if (int(vc(i)) > mp) mp = int(vc(i))
    end do
    if (mt > v2_max_tags) mt = v2_max_tags
    if (mp > v2_max_points) mp = v2_max_points
    if (mt > 0) then
      allocate(tags(n * mt * v2_str), tn(n * mt))
      call get_i1(eng, io, "tags", tags, stat)
      call get_i4a(eng, io, "tag_n", tn, ierr)
      if (stat /= 0 .or. ierr /= 0) then
        stat = 1
        return
      end if
    end if
    if (mp > 0) then
      allocate(vals(n * mp))
      call get_r8(eng, io, "values", vals, stat)
      if (stat /= 0) return
    end if
    do i = 1, n
      call unpack_text(items(i)%telemetry%source, items(i)%telemetry%source_n, &
           src((i - 1) * v2_str + 1 : i * v2_str), int(srcn(i)))
      items(i)%telemetry%ts = int(ts(i), int64)
      items(i)%telemetry%tag_count = min(int(tc(i)), v2_max_tags)
      items(i)%telemetry%value_count = min(int(vc(i)), v2_max_points)
      if (mt > 0) then
        do k = 1, items(i)%telemetry%tag_count
          base = ((i - 1) * mt + (k - 1)) * v2_str
          call unpack_text(items(i)%telemetry%tags(k), items(i)%telemetry%tag_n(k), &
               tags(base + 1 : base + v2_str), int(tn((i - 1) * mt + k)))
        end do
      end if
      if (mp > 0) then
        do k = 1, items(i)%telemetry%value_count
          items(i)%telemetry%values(k) = real(vals((i - 1) * mp + k), real64)
        end do
      end if
    end do
    stat = 0
  end subroutine

  subroutine write_strings(io, path, items, stat)
    type(adios2_io), intent(in) :: io
    character(len=*), intent(in) :: path
    type(fixture_t), intent(in) :: items(:)
    integer, intent(out) :: stat
    type(adios2_engine) :: eng
    type(adios2_variable) :: vk, vc, vit, vin
    integer :: n, i, k, m, ierr, base
    integer(kind=4) :: kind4
    integer(kind=1), allocatable :: raw(:)
    integer(kind=4), allocatable :: count(:), ns(:)
    n = size(items)
    m = 0
    do i = 1, n
      if (items(i)%strings%count > m) m = items(i)%strings%count
    end do
    kind4 = int(kind_strings, kind=4)
    call def_scalar_i4(io, vk, "kind", stat)
    call def_1d(io, vc, "count", adios2_type_integer4, n, ierr)
    if (m > 0) then
      call def_1d(io, vit, "items", adios2_type_integer1, n * m * v2_str, ierr)
      call def_1d(io, vin, "item_n", adios2_type_integer4, n * m, ierr)
    end if
    if (stat /= 0 .or. ierr /= 0) then
      stat = 1
      return
    end if
    allocate(count(n))
    if (m > 0) then
      allocate(raw(n * m * v2_str), ns(n * m))
      raw = 0_1
      ns = 0_4
    end if
    do i = 1, n
      count(i) = int(items(i)%strings%count, kind=4)
      if (m > 0) then
        do k = 1, items(i)%strings%count
          base = ((i - 1) * m + (k - 1)) * v2_str
          call pack_text_1d(raw(base + 1 : base + v2_str), &
               items(i)%strings%items(k), items(i)%strings%item_n(k))
          ns((i - 1) * m + k) = int(items(i)%strings%item_n(k), kind=4)
        end do
      end if
    end do
    call open_write(io, path, eng, stat)
    if (stat /= 0) return
    call adios2_put(eng, vk, kind4, adios2_mode_sync, stat)
    call adios2_put(eng, vc, count, adios2_mode_sync, ierr)
    if (m > 0) then
      call adios2_put(eng, vit, raw, adios2_mode_sync, ierr)
      call adios2_put(eng, vin, ns, adios2_mode_sync, ierr)
    end if
    if (ierr /= 0) stat = ierr
    call close_write(eng, stat)
  end subroutine

  subroutine read_strings(eng, io, items, stat)
    type(adios2_engine), intent(in) :: eng
    type(adios2_io), intent(in) :: io
    type(fixture_t), intent(inout) :: items(:)
    integer, intent(out) :: stat
    integer :: n, i, k, m, ierr, base
    integer(kind=1), allocatable :: raw(:)
    integer(kind=4), allocatable :: count(:), ns(:)
    n = size(items)
    allocate(count(n))
    call get_i4a(eng, io, "count", count, stat)
    if (stat /= 0) return
    m = 0
    do i = 1, n
      if (int(count(i)) > m) m = int(count(i))
    end do
    if (m > v2_max_strings) m = v2_max_strings
    if (m > 0) then
      allocate(raw(n * m * v2_str), ns(n * m))
      call get_i1(eng, io, "items", raw, stat)
      call get_i4a(eng, io, "item_n", ns, ierr)
      if (stat /= 0 .or. ierr /= 0) then
        stat = 1
        return
      end if
    end if
    do i = 1, n
      items(i)%strings%count = min(int(count(i)), v2_max_strings)
      if (m > 0) then
        do k = 1, items(i)%strings%count
          base = ((i - 1) * m + (k - 1)) * v2_str
          call unpack_text(items(i)%strings%items(k), items(i)%strings%item_n(k), &
               raw(base + 1 : base + v2_str), int(ns((i - 1) * m + k)))
        end do
      end if
    end do
    stat = 0
  end subroutine

  subroutine write_event(io, path, items, stat)
    type(adios2_io), intent(in) :: io
    character(len=*), intent(in) :: path
    type(fixture_t), intent(in) :: items(:)
    integer, intent(out) :: stat
    type(adios2_engine) :: eng
    type(adios2_variable) :: vk, veid, veidn, vet, vetn, voc, vpr, vprn, vac
    type(adios2_variable) :: vkey, vkeyn, vval, vvaln
    integer :: n, i, k, m, ierr, base
    integer(kind=4) :: kind4
    integer(kind=1), allocatable :: eid(:), et(:), pr(:), key(:), val(:)
    integer(kind=4), allocatable :: eidn(:), etn(:), prn(:), ac(:), keyn(:), valn(:)
    integer(kind=8), allocatable :: oc(:)
    n = size(items)
    m = 0
    do i = 1, n
      if (items(i)%event%attr_count > m) m = items(i)%event%attr_count
    end do
    kind4 = int(kind_event, kind=4)
    call def_scalar_i4(io, vk, "kind", stat)
    call def_1d(io, veid, "event_id", adios2_type_integer1, n * v2_str, ierr)
    call def_1d(io, veidn, "event_id_n", adios2_type_integer4, n, ierr)
    call def_1d(io, vet, "event_type", adios2_type_integer1, n * v2_str, ierr)
    call def_1d(io, vetn, "event_type_n", adios2_type_integer4, n, ierr)
    call def_1d(io, voc, "occurred_at", adios2_type_integer8, n, ierr)
    call def_1d(io, vpr, "producer", adios2_type_integer1, n * v2_str, ierr)
    call def_1d(io, vprn, "producer_n", adios2_type_integer4, n, ierr)
    call def_1d(io, vac, "attr_count", adios2_type_integer4, n, ierr)
    if (m > 0) then
      call def_1d(io, vkey, "key", adios2_type_integer1, n * m * v2_str, ierr)
      call def_1d(io, vkeyn, "key_n", adios2_type_integer4, n * m, ierr)
      call def_1d(io, vval, "value", adios2_type_integer1, n * m * v2_str, ierr)
      call def_1d(io, vvaln, "value_n", adios2_type_integer4, n * m, ierr)
    end if
    if (stat /= 0 .or. ierr /= 0) then
      stat = 1
      return
    end if
    allocate(eid(n * v2_str), et(n * v2_str), pr(n * v2_str))
    allocate(eidn(n), etn(n), prn(n), ac(n), oc(n))
    if (m > 0) then
      allocate(key(n * m * v2_str), val(n * m * v2_str), keyn(n * m), valn(n * m))
      key = 0_1
      val = 0_1
      keyn = 0_4
      valn = 0_4
    end if
    do i = 1, n
      call pack_text_1d(eid((i - 1) * v2_str + 1 : i * v2_str), &
           items(i)%event%event_id, items(i)%event%event_id_n)
      call pack_text_1d(et((i - 1) * v2_str + 1 : i * v2_str), &
           items(i)%event%event_type, items(i)%event%event_type_n)
      call pack_text_1d(pr((i - 1) * v2_str + 1 : i * v2_str), &
           items(i)%event%producer, items(i)%event%producer_n)
      eidn(i) = int(items(i)%event%event_id_n, kind=4)
      etn(i) = int(items(i)%event%event_type_n, kind=4)
      prn(i) = int(items(i)%event%producer_n, kind=4)
      oc(i) = int(items(i)%event%occurred_at, kind=8)
      ac(i) = int(items(i)%event%attr_count, kind=4)
      if (m > 0) then
        do k = 1, items(i)%event%attr_count
          base = ((i - 1) * m + (k - 1)) * v2_str
          call pack_text_1d(key(base + 1 : base + v2_str), &
               items(i)%event%attrs(k)%key, items(i)%event%attrs(k)%key_n)
          call pack_text_1d(val(base + 1 : base + v2_str), &
               items(i)%event%attrs(k)%value, items(i)%event%attrs(k)%value_n)
          keyn((i - 1) * m + k) = int(items(i)%event%attrs(k)%key_n, kind=4)
          valn((i - 1) * m + k) = int(items(i)%event%attrs(k)%value_n, kind=4)
        end do
      end if
    end do
    call open_write(io, path, eng, stat)
    if (stat /= 0) return
    call adios2_put(eng, vk, kind4, adios2_mode_sync, stat)
    call adios2_put(eng, veid, eid, adios2_mode_sync, ierr)
    call adios2_put(eng, veidn, eidn, adios2_mode_sync, ierr)
    call adios2_put(eng, vet, et, adios2_mode_sync, ierr)
    call adios2_put(eng, vetn, etn, adios2_mode_sync, ierr)
    call adios2_put(eng, voc, oc, adios2_mode_sync, ierr)
    call adios2_put(eng, vpr, pr, adios2_mode_sync, ierr)
    call adios2_put(eng, vprn, prn, adios2_mode_sync, ierr)
    call adios2_put(eng, vac, ac, adios2_mode_sync, ierr)
    if (m > 0) then
      call adios2_put(eng, vkey, key, adios2_mode_sync, ierr)
      call adios2_put(eng, vkeyn, keyn, adios2_mode_sync, ierr)
      call adios2_put(eng, vval, val, adios2_mode_sync, ierr)
      call adios2_put(eng, vvaln, valn, adios2_mode_sync, ierr)
    end if
    if (ierr /= 0) stat = ierr
    call close_write(eng, stat)
  end subroutine

  subroutine read_event(eng, io, items, stat)
    type(adios2_engine), intent(in) :: eng
    type(adios2_io), intent(in) :: io
    type(fixture_t), intent(inout) :: items(:)
    integer, intent(out) :: stat
    integer :: n, i, k, m, ierr, base
    integer(kind=1), allocatable :: eid(:), et(:), pr(:), key(:), val(:)
    integer(kind=4), allocatable :: eidn(:), etn(:), prn(:), ac(:), keyn(:), valn(:)
    integer(kind=8), allocatable :: oc(:)
    n = size(items)
    allocate(eid(n * v2_str), et(n * v2_str), pr(n * v2_str))
    allocate(eidn(n), etn(n), prn(n), ac(n), oc(n))
    call get_i1(eng, io, "event_id", eid, stat)
    call get_i4a(eng, io, "event_id_n", eidn, ierr)
    call get_i1(eng, io, "event_type", et, ierr)
    call get_i4a(eng, io, "event_type_n", etn, ierr)
    call get_i8(eng, io, "occurred_at", oc, ierr)
    call get_i1(eng, io, "producer", pr, ierr)
    call get_i4a(eng, io, "producer_n", prn, ierr)
    call get_i4a(eng, io, "attr_count", ac, ierr)
    if (stat /= 0 .or. ierr /= 0) then
      stat = 1
      return
    end if
    m = 0
    do i = 1, n
      if (int(ac(i)) > m) m = int(ac(i))
    end do
    if (m > v2_max_attrs) m = v2_max_attrs
    if (m > 0) then
      allocate(key(n * m * v2_str), val(n * m * v2_str), keyn(n * m), valn(n * m))
      call get_i1(eng, io, "key", key, stat)
      call get_i4a(eng, io, "key_n", keyn, ierr)
      call get_i1(eng, io, "value", val, ierr)
      call get_i4a(eng, io, "value_n", valn, ierr)
      if (stat /= 0 .or. ierr /= 0) then
        stat = 1
        return
      end if
    end if
    do i = 1, n
      call unpack_text(items(i)%event%event_id, items(i)%event%event_id_n, &
           eid((i - 1) * v2_str + 1 : i * v2_str), int(eidn(i)))
      call unpack_text(items(i)%event%event_type, items(i)%event%event_type_n, &
           et((i - 1) * v2_str + 1 : i * v2_str), int(etn(i)))
      call unpack_text(items(i)%event%producer, items(i)%event%producer_n, &
           pr((i - 1) * v2_str + 1 : i * v2_str), int(prn(i)))
      items(i)%event%occurred_at = int(oc(i), int64)
      items(i)%event%attr_count = min(int(ac(i)), v2_max_attrs)
      if (m > 0) then
        do k = 1, items(i)%event%attr_count
          base = ((i - 1) * m + (k - 1)) * v2_str
          call unpack_text(items(i)%event%attrs(k)%key, items(i)%event%attrs(k)%key_n, &
               key(base + 1 : base + v2_str), int(keyn((i - 1) * m + k)))
          call unpack_text(items(i)%event%attrs(k)%value, items(i)%event%attrs(k)%value_n, &
               val(base + 1 : base + v2_str), int(valn((i - 1) * m + k)))
        end do
      end if
    end do
    stat = 0
  end subroutine

  subroutine get_i1(eng, io, name, buf, stat)
    type(adios2_engine), intent(in) :: eng
    type(adios2_io), intent(in) :: io
    character(len=*), intent(in) :: name
    integer(kind=1), intent(out) :: buf(:)
    integer, intent(out) :: stat
    type(adios2_variable) :: var
    call adios2_inquire_variable(var, io, name, stat)
    if (stat /= 0) return
    call adios2_get(eng, var, buf, adios2_mode_sync, stat)
  end subroutine

  subroutine get_i4a(eng, io, name, buf, stat)
    type(adios2_engine), intent(in) :: eng
    type(adios2_io), intent(in) :: io
    character(len=*), intent(in) :: name
    integer(kind=4), intent(out) :: buf(:)
    integer, intent(out) :: stat
    type(adios2_variable) :: var
    call adios2_inquire_variable(var, io, name, stat)
    if (stat /= 0) return
    call adios2_get(eng, var, buf, adios2_mode_sync, stat)
  end subroutine

  subroutine get_i8(eng, io, name, buf, stat)
    type(adios2_engine), intent(in) :: eng
    type(adios2_io), intent(in) :: io
    character(len=*), intent(in) :: name
    integer(kind=8), intent(out) :: buf(:)
    integer, intent(out) :: stat
    type(adios2_variable) :: var
    call adios2_inquire_variable(var, io, name, stat)
    if (stat /= 0) return
    call adios2_get(eng, var, buf, adios2_mode_sync, stat)
  end subroutine

  subroutine get_r8(eng, io, name, buf, stat)
    type(adios2_engine), intent(in) :: eng
    type(adios2_io), intent(in) :: io
    character(len=*), intent(in) :: name
    real(kind=8), intent(out) :: buf(:)
    integer, intent(out) :: stat
    type(adios2_variable) :: var
    call adios2_inquire_variable(var, io, name, stat)
    if (stat /= 0) return
    call adios2_get(eng, var, buf, adios2_mode_sync, stat)
  end subroutine

end module ser_adios2
