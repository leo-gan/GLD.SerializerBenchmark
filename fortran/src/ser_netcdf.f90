module ser_netcdf
  ! NetCDF Fortran API. NF90_DISKLESS keeps the file in memory and deletes it
  ! on close, so there is no buffer to read back and no byte size. This row
  ! times a real NetCDF-4 file and is published as file-only (stream/native).
  use, intrinsic :: iso_fortran_env, only: int8, int32, int64, real64
  use netcdf
  use bench_data
  implicit none
  private
  public :: nc_name, nc_version, nc_prepare, nc_write, nc_read, nc_remove

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

  subroutine nc_write(items, path, nbytes, stat)
    type(fixture_t), intent(in) :: items(:)
    character(len=*), intent(in) :: path
    integer(int64), intent(out) :: nbytes
    integer, intent(out) :: stat
    integer :: ncid, slen, rec, extra, err
    integer :: n, kind
    integer(int32) :: kind_s
    n = size(items)
    nbytes = 0
    kind = items(1)%kind_id
    call nc_remove(path)
    stat = nf90_create(path, ior(NF90_NETCDF4, NF90_CLOBBER), ncid)
    if (stat /= nf90_noerr) return
    err = nf90_def_dim(ncid, "slen", v2_str, slen)
    err = nf90_def_dim(ncid, "record", n, rec)
    extra = 0
    call def_kind(ncid, kind, items, slen, rec, extra, stat)
    if (stat == nf90_noerr) stat = nf90_enddef(ncid)
    if (stat == nf90_noerr) then
      kind_s = int(kind, int32)
      stat = nf90_put_att(ncid, NF90_GLOBAL, "kind", kind_s)
    end if
    if (stat == nf90_noerr) call put_kind(ncid, items, stat)
    err = nf90_close(ncid)
    if (stat == nf90_noerr .and. err /= nf90_noerr) stat = err
    if (stat == nf90_noerr) then
      inquire(file=path, size=nbytes)
      if (nbytes < 0) stat = 1
    else
      stat = 1
    end if
  end subroutine

  subroutine nc_read(path, expected_n, items, stat)
    character(len=*), intent(in) :: path
    integer, intent(in) :: expected_n
    type(fixture_t), allocatable, intent(out) :: items(:)
    integer, intent(out) :: stat
    integer :: ncid, n, kind
    integer(int32) :: kind_s
    n = expected_n
    if (n < 1) n = 1
    stat = nf90_open(path, NF90_NOWRITE, ncid)
    if (stat /= nf90_noerr) return
    kind_s = 0
    stat = nf90_get_att(ncid, NF90_GLOBAL, "kind", kind_s)
    if (stat /= nf90_noerr) then
      stat = nf90_close(ncid)
      return
    end if
    kind = int(kind_s)
    allocate(items(n))
    items%kind_id = kind
    call get_kind(ncid, items, stat)
    stat = nf90_close(ncid)
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

  subroutine def_kind(ncid, kind, items, slen, rec, extra, stat)
    integer, intent(in) :: ncid, kind, slen, rec
    type(fixture_t), intent(in) :: items(:)
    integer, intent(out) :: extra
    integer, intent(out) :: stat
    integer :: vid
    extra = 0
    stat = nf90_noerr
    select case (kind)
    case (kind_message)
      call def_chars(ncid, "f_string", slen, rec, vid, stat)
      call def_chars(ncid, "f_string_2", slen, rec, vid, stat)
      call def_num(ncid, "f_bool", NF90_BYTE, rec, stat)
      call def_num(ncid, "f_int32", NF90_INT, rec, stat)
      call def_num(ncid, "f_int64", NF90_INT64, rec, stat)
      call def_num(ncid, "f_float64", NF90_DOUBLE, rec, stat)
      call def_num(ncid, "f_bool_2", NF90_BYTE, rec, stat)
      call def_num(ncid, "f_int32_2", NF90_INT, rec, stat)
      call def_num(ncid, "f_string_n", NF90_INT, rec, stat)
      call def_num(ncid, "f_string_2_n", NF90_INT, rec, stat)
    case (kind_document)
      stat = nf90_def_dim(ncid, "child", max(1, max_items(items)), extra)
      call def_chars(ncid, "id", slen, rec, vid, stat)
      call def_chars(ncid, "region", slen, rec, vid, stat)
      call def_num(ncid, "id_n", NF90_INT, rec, stat)
      call def_num(ncid, "region_n", NF90_INT, rec, stat)
      call def_num(ncid, "status", NF90_INT, rec, stat)
      call def_num(ncid, "version", NF90_INT, rec, stat)
      call def_num(ncid, "item_count", NF90_INT, rec, stat)
      call def_num2(ncid, "qty", NF90_INT, extra, rec, stat)
      call def_num2(ncid, "price_minor", NF90_INT64, extra, rec, stat)
      call def_chars2(ncid, "sku", slen, extra, rec, stat)
      call def_num2(ncid, "sku_n", NF90_INT, extra, rec, stat)
    case (kind_telemetry)
      stat = nf90_def_dim(ncid, "tag", max(1, max_tags(items)), extra)
      call def_chars(ncid, "source", slen, rec, vid, stat)
      call def_num(ncid, "source_n", NF90_INT, rec, stat)
      call def_num(ncid, "ts", NF90_INT64, rec, stat)
      call def_num(ncid, "tag_count", NF90_INT, rec, stat)
      call def_num(ncid, "value_count", NF90_INT, rec, stat)
      call def_chars2(ncid, "tags", slen, extra, rec, stat)
      call def_num2(ncid, "tag_n", NF90_INT, extra, rec, stat)
      call def_values(ncid, items, rec, stat)
    case (kind_strings)
      stat = nf90_def_dim(ncid, "item", max(1, max_strs(items)), extra)
      call def_num(ncid, "count", NF90_INT, rec, stat)
      call def_chars2(ncid, "items", slen, extra, rec, stat)
      call def_num2(ncid, "item_n", NF90_INT, extra, rec, stat)
    case (kind_event)
      stat = nf90_def_dim(ncid, "attr", max(1, max_attrs(items)), extra)
      call def_chars(ncid, "event_id", slen, rec, vid, stat)
      call def_chars(ncid, "event_type", slen, rec, vid, stat)
      call def_chars(ncid, "producer", slen, rec, vid, stat)
      call def_num(ncid, "event_id_n", NF90_INT, rec, stat)
      call def_num(ncid, "event_type_n", NF90_INT, rec, stat)
      call def_num(ncid, "producer_n", NF90_INT, rec, stat)
      call def_num(ncid, "occurred_at", NF90_INT64, rec, stat)
      call def_num(ncid, "attr_count", NF90_INT, rec, stat)
      call def_chars2(ncid, "key", slen, extra, rec, stat)
      call def_chars2(ncid, "value", slen, extra, rec, stat)
      call def_num2(ncid, "key_n", NF90_INT, extra, rec, stat)
      call def_num2(ncid, "value_n", NF90_INT, extra, rec, stat)
    case default
      stat = 1
    end select
    if (stat /= nf90_noerr) stat = 1
  end subroutine

  subroutine def_num(ncid, name, xtype, rec, stat)
    integer, intent(in) :: ncid, xtype, rec
    character(len=*), intent(in) :: name
    integer, intent(inout) :: stat
    integer :: vid
    if (stat /= nf90_noerr) return
    stat = nf90_def_var(ncid, name, xtype, [rec], vid)
  end subroutine

  subroutine def_num2(ncid, name, xtype, inner, rec, stat)
    integer, intent(in) :: ncid, xtype, inner, rec
    character(len=*), intent(in) :: name
    integer, intent(inout) :: stat
    integer :: vid
    if (stat /= nf90_noerr) return
    stat = nf90_def_var(ncid, name, xtype, [inner, rec], vid)
  end subroutine

  subroutine def_chars(ncid, name, slen, rec, vid, stat)
    integer, intent(in) :: ncid, slen, rec
    character(len=*), intent(in) :: name
    integer, intent(out) :: vid
    integer, intent(inout) :: stat
    vid = 0
    if (stat /= nf90_noerr) return
    stat = nf90_def_var(ncid, name, NF90_CHAR, [slen, rec], vid)
  end subroutine

  subroutine def_chars2(ncid, name, slen, inner, rec, stat)
    integer, intent(in) :: ncid, slen, inner, rec
    character(len=*), intent(in) :: name
    integer, intent(inout) :: stat
    integer :: vid
    if (stat /= nf90_noerr) return
    stat = nf90_def_var(ncid, name, NF90_CHAR, [slen, inner, rec], vid)
  end subroutine

  subroutine def_values(ncid, items, rec, stat)
    integer, intent(in) :: ncid, rec
    type(fixture_t), intent(in) :: items(:)
    integer, intent(inout) :: stat
    integer :: dimid, vid, m
    if (stat /= nf90_noerr) return
    m = max(1, max_points(items))
    stat = nf90_def_dim(ncid, "point", m, dimid)
    if (stat /= nf90_noerr) return
    stat = nf90_def_var(ncid, "values", NF90_DOUBLE, [dimid, rec], vid)
  end subroutine

  subroutine put_kind(ncid, items, stat)
    integer, intent(in) :: ncid
    type(fixture_t), intent(in) :: items(:)
    integer, intent(inout) :: stat
    integer :: n, i
    n = size(items)
    select case (items(1)%kind_id)
    case (kind_message)
      call put_bytes(ncid, "f_bool", n, items, 1, stat)
      call put_i32s(ncid, "f_int32", n, items, 1, stat)
      call put_i64s(ncid, "f_int64", n, items, 1, stat)
      call put_f64s(ncid, "f_float64", n, items, stat)
      call put_one_text(ncid, "f_string", "f_string_n", n, items, 1, stat)
      call put_bytes(ncid, "f_bool_2", n, items, 2, stat)
      call put_i32s(ncid, "f_int32_2", n, items, 2, stat)
      call put_one_text(ncid, "f_string_2", "f_string_2_n", n, items, 2, stat)
    case (kind_document)
      call put_one_text(ncid, "id", "id_n", n, items, 3, stat)
      call put_one_text(ncid, "region", "region_n", n, items, 4, stat)
      call put_i32s(ncid, "status", n, items, 3, stat)
      call put_i32s(ncid, "version", n, items, 4, stat)
      call put_i32s(ncid, "item_count", n, items, 5, stat)
      call put_doc_items(ncid, items, stat)
    case (kind_telemetry)
      call put_one_text(ncid, "source", "source_n", n, items, 5, stat)
      call put_i64s(ncid, "ts", n, items, 2, stat)
      call put_i32s(ncid, "tag_count", n, items, 6, stat)
      call put_i32s(ncid, "value_count", n, items, 7, stat)
      call put_tel(ncid, items, stat)
    case (kind_strings)
      call put_i32s(ncid, "count", n, items, 8, stat)
      call put_str_items(ncid, items, stat)
    case (kind_event)
      call put_one_text(ncid, "event_id", "event_id_n", n, items, 6, stat)
      call put_one_text(ncid, "event_type", "event_type_n", n, items, 7, stat)
      call put_one_text(ncid, "producer", "producer_n", n, items, 8, stat)
      call put_i64s(ncid, "occurred_at", n, items, 3, stat)
      call put_i32s(ncid, "attr_count", n, items, 9, stat)
      call put_event_attrs(ncid, items, stat)
    end select
    if (stat /= nf90_noerr) stat = 1
  end subroutine

  subroutine put_bytes(ncid, name, n, items, which, stat)
    integer, intent(in) :: ncid, n, which
    character(len=*), intent(in) :: name
    type(fixture_t), intent(in) :: items(:)
    integer, intent(inout) :: stat
    integer :: vid, i
    integer(int8) :: buf(n)
    if (stat /= nf90_noerr) return
    do i = 1, n
      buf(i) = 0_int8
      if (which == 1 .and. items(i)%message%f_bool) buf(i) = 1_int8
      if (which == 2 .and. items(i)%message%f_bool_2) buf(i) = 1_int8
    end do
    stat = nf90_inq_varid(ncid, name, vid)
    if (stat == nf90_noerr) stat = nf90_put_var(ncid, vid, buf)
  end subroutine

  subroutine put_i32s(ncid, name, n, items, which, stat)
    integer, intent(in) :: ncid, n, which
    character(len=*), intent(in) :: name
    type(fixture_t), intent(in) :: items(:)
    integer, intent(inout) :: stat
    integer :: vid, i
    integer(int32) :: buf(n)
    if (stat /= nf90_noerr) return
    do i = 1, n
      select case (which)
      case (1); buf(i) = items(i)%message%f_int32
      case (2); buf(i) = items(i)%message%f_int32_2
      case (3); buf(i) = items(i)%document%status
      case (4); buf(i) = items(i)%document%version
      case (5); buf(i) = int(items(i)%document%item_count, int32)
      case (6); buf(i) = int(items(i)%telemetry%tag_count, int32)
      case (7); buf(i) = int(items(i)%telemetry%value_count, int32)
      case (8); buf(i) = int(items(i)%strings%count, int32)
      case (9); buf(i) = int(items(i)%event%attr_count, int32)
      end select
    end do
    stat = nf90_inq_varid(ncid, name, vid)
    if (stat == nf90_noerr) stat = nf90_put_var(ncid, vid, buf)
  end subroutine

  subroutine put_i64s(ncid, name, n, items, which, stat)
    integer, intent(in) :: ncid, n, which
    character(len=*), intent(in) :: name
    type(fixture_t), intent(in) :: items(:)
    integer, intent(inout) :: stat
    integer :: vid, i
    integer(int64) :: buf(n)
    if (stat /= nf90_noerr) return
    do i = 1, n
      if (which == 1) buf(i) = items(i)%message%f_int64
      if (which == 2) buf(i) = items(i)%telemetry%ts
      if (which == 3) buf(i) = items(i)%event%occurred_at
    end do
    stat = nf90_inq_varid(ncid, name, vid)
    if (stat == nf90_noerr) stat = nf90_put_var(ncid, vid, buf)
  end subroutine

  subroutine put_f64s(ncid, name, n, items, stat)
    integer, intent(in) :: ncid, n
    character(len=*), intent(in) :: name
    type(fixture_t), intent(in) :: items(:)
    integer, intent(inout) :: stat
    integer :: vid, i
    real(real64) :: buf(n)
    if (stat /= nf90_noerr) return
    do i = 1, n
      buf(i) = items(i)%message%f_float64
    end do
    stat = nf90_inq_varid(ncid, name, vid)
    if (stat == nf90_noerr) stat = nf90_put_var(ncid, vid, buf)
  end subroutine

  subroutine put_one_text(ncid, name, nname, n, items, which, stat)
    integer, intent(in) :: ncid, n, which
    character(len=*), intent(in) :: name, nname
    type(fixture_t), intent(in) :: items(:)
    integer, intent(inout) :: stat
    integer :: vid, i, m
    character(len=v2_str) :: buf(n)
    integer(int32) :: lens(n)
    if (stat /= nf90_noerr) return
    do i = 1, n
      call fill_one(items(i), which, buf(i), m)
      lens(i) = int(m, int32)
    end do
    stat = nf90_inq_varid(ncid, name, vid)
    if (stat == nf90_noerr) stat = nf90_put_var(ncid, vid, buf)
    if (stat /= nf90_noerr) return
    stat = nf90_inq_varid(ncid, nname, vid)
    if (stat == nf90_noerr) stat = nf90_put_var(ncid, vid, lens)
  end subroutine

  subroutine fill_one(fx, which, buf, n)
    type(fixture_t), intent(in) :: fx
    integer, intent(in) :: which
    character(len=v2_str), intent(out) :: buf
    integer, intent(out) :: n
    buf = ""
    n = 0
    select case (which)
    case (1); n = fx%message%f_string_n; if (n > 0) buf(1:n) = fx%message%f_string(1:n)
    case (2); n = fx%message%f_string_2_n; if (n > 0) buf(1:n) = fx%message%f_string_2(1:n)
    case (3); n = fx%document%id_n; if (n > 0) buf(1:n) = fx%document%id(1:n)
    case (4); n = fx%document%region_n; if (n > 0) buf(1:n) = fx%document%region(1:n)
    case (5); n = fx%telemetry%source_n; if (n > 0) buf(1:n) = fx%telemetry%source(1:n)
    case (6); n = fx%event%event_id_n; if (n > 0) buf(1:n) = fx%event%event_id(1:n)
    case (7); n = fx%event%event_type_n; if (n > 0) buf(1:n) = fx%event%event_type(1:n)
    case (8); n = fx%event%producer_n; if (n > 0) buf(1:n) = fx%event%producer(1:n)
    end select
    if (n < 0) n = 0
    if (n > v2_str) n = v2_str
  end subroutine

  subroutine put_doc_items(ncid, items, stat)
    integer, intent(in) :: ncid
    type(fixture_t), intent(in) :: items(:)
    integer, intent(inout) :: stat
    integer :: n, c, i, j, m, vid
    integer(int32), allocatable :: qty(:, :), sn(:, :)
    integer(int64), allocatable :: price(:, :)
    character(len=v2_str), allocatable :: sku(:, :)
    n = size(items)
    c = max(1, max_items(items))
    allocate(qty(c, n), price(c, n), sn(c, n), sku(c, n))
    qty = 0
    price = 0
    sn = 0
    sku = ""
    do i = 1, n
      do j = 1, items(i)%document%item_count
        qty(j, i) = items(i)%document%items(j)%qty
        price(j, i) = items(i)%document%items(j)%price_minor
        m = items(i)%document%items(j)%sku_n
        if (m < 0) m = 0
        if (m > v2_str) m = v2_str
        sn(j, i) = int(m, int32)
        if (m > 0) sku(j, i)(1:m) = items(i)%document%items(j)%sku(1:m)
      end do
    end do
    if (stat /= nf90_noerr) return
    stat = nf90_inq_varid(ncid, "qty", vid)
    if (stat == nf90_noerr) stat = nf90_put_var(ncid, vid, qty)
    if (stat == nf90_noerr) stat = nf90_inq_varid(ncid, "price_minor", vid)
    if (stat == nf90_noerr) stat = nf90_put_var(ncid, vid, price)
    if (stat == nf90_noerr) stat = nf90_inq_varid(ncid, "sku_n", vid)
    if (stat == nf90_noerr) stat = nf90_put_var(ncid, vid, sn)
    if (stat == nf90_noerr) stat = nf90_inq_varid(ncid, "sku", vid)
    if (stat == nf90_noerr) stat = nf90_put_var(ncid, vid, sku)
  end subroutine

  subroutine put_tel(ncid, items, stat)
    integer, intent(in) :: ncid
    type(fixture_t), intent(in) :: items(:)
    integer, intent(inout) :: stat
    integer :: n, t, p, i, j, m, vid
    integer(int32), allocatable :: tn(:, :)
    character(len=v2_str), allocatable :: tags(:, :)
    real(real64), allocatable :: values(:, :)
    n = size(items)
    t = max(1, max_tags(items))
    p = max(1, max_points(items))
    allocate(tn(t, n), tags(t, n), values(p, n))
    tn = 0
    tags = ""
    values = 0
    do i = 1, n
      do j = 1, items(i)%telemetry%tag_count
        m = items(i)%telemetry%tag_n(j)
        if (m < 0) m = 0
        if (m > v2_str) m = v2_str
        tn(j, i) = int(m, int32)
        if (m > 0) tags(j, i)(1:m) = items(i)%telemetry%tags(j)(1:m)
      end do
      do j = 1, items(i)%telemetry%value_count
        values(j, i) = items(i)%telemetry%values(j)
      end do
    end do
    if (stat /= nf90_noerr) return
    stat = nf90_inq_varid(ncid, "tag_n", vid)
    if (stat == nf90_noerr) stat = nf90_put_var(ncid, vid, tn)
    if (stat == nf90_noerr) stat = nf90_inq_varid(ncid, "tags", vid)
    if (stat == nf90_noerr) stat = nf90_put_var(ncid, vid, tags)
    if (stat == nf90_noerr) stat = nf90_inq_varid(ncid, "values", vid)
    if (stat == nf90_noerr) stat = nf90_put_var(ncid, vid, values)
  end subroutine

  subroutine put_str_items(ncid, items, stat)
    integer, intent(in) :: ncid
    type(fixture_t), intent(in) :: items(:)
    integer, intent(inout) :: stat
    integer :: n, c, i, j, m, vid
    integer(int32), allocatable :: lens(:, :)
    character(len=v2_str), allocatable :: buf(:, :)
    n = size(items)
    c = max(1, max_strs(items))
    allocate(lens(c, n), buf(c, n))
    lens = 0
    buf = ""
    do i = 1, n
      do j = 1, items(i)%strings%count
        m = items(i)%strings%item_n(j)
        if (m < 0) m = 0
        if (m > v2_str) m = v2_str
        lens(j, i) = int(m, int32)
        if (m > 0) buf(j, i)(1:m) = items(i)%strings%items(j)(1:m)
      end do
    end do
    if (stat /= nf90_noerr) return
    stat = nf90_inq_varid(ncid, "item_n", vid)
    if (stat == nf90_noerr) stat = nf90_put_var(ncid, vid, lens)
    if (stat == nf90_noerr) stat = nf90_inq_varid(ncid, "items", vid)
    if (stat == nf90_noerr) stat = nf90_put_var(ncid, vid, buf)
  end subroutine

  subroutine put_event_attrs(ncid, items, stat)
    integer, intent(in) :: ncid
    type(fixture_t), intent(in) :: items(:)
    integer, intent(inout) :: stat
    integer :: n, c, i, j, m, vid
    integer(int32), allocatable :: kn(:, :), vn(:, :)
    character(len=v2_str), allocatable :: keys(:, :), vals(:, :)
    n = size(items)
    c = max(1, max_attrs(items))
    allocate(kn(c, n), vn(c, n), keys(c, n), vals(c, n))
    kn = 0
    vn = 0
    keys = ""
    vals = ""
    do i = 1, n
      do j = 1, items(i)%event%attr_count
        m = items(i)%event%attrs(j)%key_n
        if (m < 0) m = 0
        if (m > v2_str) m = v2_str
        kn(j, i) = int(m, int32)
        if (m > 0) keys(j, i)(1:m) = items(i)%event%attrs(j)%key(1:m)
        m = items(i)%event%attrs(j)%value_n
        if (m < 0) m = 0
        if (m > v2_str) m = v2_str
        vn(j, i) = int(m, int32)
        if (m > 0) vals(j, i)(1:m) = items(i)%event%attrs(j)%value(1:m)
      end do
    end do
    if (stat /= nf90_noerr) return
    stat = nf90_inq_varid(ncid, "key_n", vid)
    if (stat == nf90_noerr) stat = nf90_put_var(ncid, vid, kn)
    if (stat == nf90_noerr) stat = nf90_inq_varid(ncid, "key", vid)
    if (stat == nf90_noerr) stat = nf90_put_var(ncid, vid, keys)
    if (stat == nf90_noerr) stat = nf90_inq_varid(ncid, "value_n", vid)
    if (stat == nf90_noerr) stat = nf90_put_var(ncid, vid, vn)
    if (stat == nf90_noerr) stat = nf90_inq_varid(ncid, "value", vid)
    if (stat == nf90_noerr) stat = nf90_put_var(ncid, vid, vals)
  end subroutine

  subroutine get_kind(ncid, items, stat)
    integer, intent(in) :: ncid
    type(fixture_t), intent(inout) :: items(:)
    integer, intent(inout) :: stat
    integer :: n
    n = size(items)
    select case (items(1)%kind_id)
    case (kind_message)
      call get_bytes(ncid, "f_bool", n, items, 1, stat)
      call get_i32s(ncid, "f_int32", n, items, 1, stat)
      call get_i64s(ncid, "f_int64", n, items, 1, stat)
      call get_f64s(ncid, "f_float64", n, items, stat)
      call get_one_text(ncid, "f_string", "f_string_n", n, items, 1, stat)
      call get_bytes(ncid, "f_bool_2", n, items, 2, stat)
      call get_i32s(ncid, "f_int32_2", n, items, 2, stat)
      call get_one_text(ncid, "f_string_2", "f_string_2_n", n, items, 2, stat)
    case (kind_document)
      call get_one_text(ncid, "id", "id_n", n, items, 3, stat)
      call get_one_text(ncid, "region", "region_n", n, items, 4, stat)
      call get_i32s(ncid, "status", n, items, 3, stat)
      call get_i32s(ncid, "version", n, items, 4, stat)
      call get_i32s(ncid, "item_count", n, items, 5, stat)
      call get_doc_items(ncid, items, stat)
    case (kind_telemetry)
      call get_one_text(ncid, "source", "source_n", n, items, 5, stat)
      call get_i64s(ncid, "ts", n, items, 2, stat)
      call get_i32s(ncid, "tag_count", n, items, 6, stat)
      call get_i32s(ncid, "value_count", n, items, 7, stat)
      call get_tel(ncid, items, stat)
    case (kind_strings)
      call get_i32s(ncid, "count", n, items, 8, stat)
      call get_str_items(ncid, items, stat)
    case (kind_event)
      call get_one_text(ncid, "event_id", "event_id_n", n, items, 6, stat)
      call get_one_text(ncid, "event_type", "event_type_n", n, items, 7, stat)
      call get_one_text(ncid, "producer", "producer_n", n, items, 8, stat)
      call get_i64s(ncid, "occurred_at", n, items, 3, stat)
      call get_i32s(ncid, "attr_count", n, items, 9, stat)
      call get_event_attrs(ncid, items, stat)
    case default
      stat = 1
    end select
  end subroutine

  subroutine get_bytes(ncid, name, n, items, which, stat)
    integer, intent(in) :: ncid, n, which
    character(len=*), intent(in) :: name
    type(fixture_t), intent(inout) :: items(:)
    integer, intent(inout) :: stat
    integer :: vid, i
    integer(int8) :: buf(n)
    if (stat /= nf90_noerr) return
    stat = nf90_inq_varid(ncid, name, vid)
    if (stat == nf90_noerr) stat = nf90_get_var(ncid, vid, buf)
    if (stat /= nf90_noerr) return
    do i = 1, n
      if (which == 1) items(i)%message%f_bool = buf(i) /= 0_int8
      if (which == 2) items(i)%message%f_bool_2 = buf(i) /= 0_int8
    end do
  end subroutine

  subroutine get_i32s(ncid, name, n, items, which, stat)
    integer, intent(in) :: ncid, n, which
    character(len=*), intent(in) :: name
    type(fixture_t), intent(inout) :: items(:)
    integer, intent(inout) :: stat
    integer :: vid, i
    integer(int32) :: buf(n)
    if (stat /= nf90_noerr) return
    stat = nf90_inq_varid(ncid, name, vid)
    if (stat == nf90_noerr) stat = nf90_get_var(ncid, vid, buf)
    if (stat /= nf90_noerr) return
    do i = 1, n
      select case (which)
      case (1); items(i)%message%f_int32 = buf(i)
      case (2); items(i)%message%f_int32_2 = buf(i)
      case (3); items(i)%document%status = buf(i)
      case (4); items(i)%document%version = buf(i)
      case (5); items(i)%document%item_count = int(buf(i))
      case (6); items(i)%telemetry%tag_count = int(buf(i))
      case (7); items(i)%telemetry%value_count = int(buf(i))
      case (8); items(i)%strings%count = int(buf(i))
      case (9); items(i)%event%attr_count = int(buf(i))
      end select
    end do
  end subroutine

  subroutine get_i64s(ncid, name, n, items, which, stat)
    integer, intent(in) :: ncid, n, which
    character(len=*), intent(in) :: name
    type(fixture_t), intent(inout) :: items(:)
    integer, intent(inout) :: stat
    integer :: vid, i
    integer(int64) :: buf(n)
    if (stat /= nf90_noerr) return
    stat = nf90_inq_varid(ncid, name, vid)
    if (stat == nf90_noerr) stat = nf90_get_var(ncid, vid, buf)
    if (stat /= nf90_noerr) return
    do i = 1, n
      if (which == 1) items(i)%message%f_int64 = buf(i)
      if (which == 2) items(i)%telemetry%ts = buf(i)
      if (which == 3) items(i)%event%occurred_at = buf(i)
    end do
  end subroutine

  subroutine get_f64s(ncid, name, n, items, stat)
    integer, intent(in) :: ncid, n
    character(len=*), intent(in) :: name
    type(fixture_t), intent(inout) :: items(:)
    integer, intent(inout) :: stat
    integer :: vid, i
    real(real64) :: buf(n)
    if (stat /= nf90_noerr) return
    stat = nf90_inq_varid(ncid, name, vid)
    if (stat == nf90_noerr) stat = nf90_get_var(ncid, vid, buf)
    if (stat /= nf90_noerr) return
    do i = 1, n
      items(i)%message%f_float64 = buf(i)
    end do
  end subroutine

  subroutine get_one_text(ncid, name, nname, n, items, which, stat)
    integer, intent(in) :: ncid, n, which
    character(len=*), intent(in) :: name, nname
    type(fixture_t), intent(inout) :: items(:)
    integer, intent(inout) :: stat
    integer :: vid, i, m
    character(len=v2_str) :: buf(n)
    integer(int32) :: lens(n)
    if (stat /= nf90_noerr) return
    stat = nf90_inq_varid(ncid, nname, vid)
    if (stat == nf90_noerr) stat = nf90_get_var(ncid, vid, lens)
    if (stat /= nf90_noerr) return
    stat = nf90_inq_varid(ncid, name, vid)
    if (stat == nf90_noerr) stat = nf90_get_var(ncid, vid, buf)
    if (stat /= nf90_noerr) return
    do i = 1, n
      m = int(lens(i))
      call apply_one(items(i), which, buf(i), m)
    end do
  end subroutine

  subroutine apply_one(fx, which, buf, n)
    type(fixture_t), intent(inout) :: fx
    integer, intent(in) :: which, n
    character(len=v2_str), intent(in) :: buf
    integer :: m
    m = n
    if (m < 0) m = 0
    if (m > v2_str) m = v2_str
    select case (which)
    case (1); call store_text(fx%message%f_string, fx%message%f_string_n, slice_text(buf, m))
    case (2); call store_text(fx%message%f_string_2, fx%message%f_string_2_n, slice_text(buf, m))
    case (3); call store_text(fx%document%id, fx%document%id_n, slice_text(buf, m))
    case (4); call store_text(fx%document%region, fx%document%region_n, slice_text(buf, m))
    case (5); call store_text(fx%telemetry%source, fx%telemetry%source_n, slice_text(buf, m))
    case (6); call store_text(fx%event%event_id, fx%event%event_id_n, slice_text(buf, m))
    case (7); call store_text(fx%event%event_type, fx%event%event_type_n, slice_text(buf, m))
    case (8); call store_text(fx%event%producer, fx%event%producer_n, slice_text(buf, m))
    end select
  end subroutine

  function slice_text(buf, n) result(text)
    character(len=v2_str), intent(in) :: buf
    integer, intent(in) :: n
    character(len=:), allocatable :: text
    if (n <= 0) then
      text = ""
    else
      text = buf(1:n)
    end if
  end function

  subroutine get_doc_items(ncid, items, stat)
    integer, intent(in) :: ncid
    type(fixture_t), intent(inout) :: items(:)
    integer, intent(inout) :: stat
    integer :: n, c, i, j, m, vid
    integer(int32), allocatable :: qty(:, :), sn(:, :)
    integer(int64), allocatable :: price(:, :)
    character(len=v2_str), allocatable :: sku(:, :)
    n = size(items)
    c = max(1, max_items(items))
    allocate(qty(c, n), price(c, n), sn(c, n), sku(c, n))
    if (stat /= nf90_noerr) return
    stat = nf90_inq_varid(ncid, "qty", vid)
    if (stat == nf90_noerr) stat = nf90_get_var(ncid, vid, qty)
    if (stat == nf90_noerr) stat = nf90_inq_varid(ncid, "price_minor", vid)
    if (stat == nf90_noerr) stat = nf90_get_var(ncid, vid, price)
    if (stat == nf90_noerr) stat = nf90_inq_varid(ncid, "sku_n", vid)
    if (stat == nf90_noerr) stat = nf90_get_var(ncid, vid, sn)
    if (stat == nf90_noerr) stat = nf90_inq_varid(ncid, "sku", vid)
    if (stat == nf90_noerr) stat = nf90_get_var(ncid, vid, sku)
    if (stat /= nf90_noerr) return
    do i = 1, n
      do j = 1, items(i)%document%item_count
        items(i)%document%items(j)%qty = qty(j, i)
        items(i)%document%items(j)%price_minor = price(j, i)
        m = int(sn(j, i))
        call store_text(items(i)%document%items(j)%sku, items(i)%document%items(j)%sku_n, &
             slice_text(sku(j, i), m))
      end do
    end do
  end subroutine

  subroutine get_tel(ncid, items, stat)
    integer, intent(in) :: ncid
    type(fixture_t), intent(inout) :: items(:)
    integer, intent(inout) :: stat
    integer :: n, t, p, i, j, m, vid
    integer(int32), allocatable :: tn(:, :)
    character(len=v2_str), allocatable :: tags(:, :)
    real(real64), allocatable :: values(:, :)
    n = size(items)
    t = max(1, max_tags(items))
    p = max(1, max_points(items))
    allocate(tn(t, n), tags(t, n), values(p, n))
    if (stat /= nf90_noerr) return
    stat = nf90_inq_varid(ncid, "tag_n", vid)
    if (stat == nf90_noerr) stat = nf90_get_var(ncid, vid, tn)
    if (stat == nf90_noerr) stat = nf90_inq_varid(ncid, "tags", vid)
    if (stat == nf90_noerr) stat = nf90_get_var(ncid, vid, tags)
    if (stat == nf90_noerr) stat = nf90_inq_varid(ncid, "values", vid)
    if (stat == nf90_noerr) stat = nf90_get_var(ncid, vid, values)
    if (stat /= nf90_noerr) return
    do i = 1, n
      do j = 1, items(i)%telemetry%tag_count
        m = int(tn(j, i))
        call store_text(items(i)%telemetry%tags(j), items(i)%telemetry%tag_n(j), slice_text(tags(j, i), m))
      end do
      do j = 1, items(i)%telemetry%value_count
        items(i)%telemetry%values(j) = values(j, i)
      end do
    end do
  end subroutine

  subroutine get_str_items(ncid, items, stat)
    integer, intent(in) :: ncid
    type(fixture_t), intent(inout) :: items(:)
    integer, intent(inout) :: stat
    integer :: n, c, i, j, m, vid
    integer(int32), allocatable :: lens(:, :)
    character(len=v2_str), allocatable :: buf(:, :)
    n = size(items)
    c = max(1, max_strs(items))
    allocate(lens(c, n), buf(c, n))
    if (stat /= nf90_noerr) return
    stat = nf90_inq_varid(ncid, "item_n", vid)
    if (stat == nf90_noerr) stat = nf90_get_var(ncid, vid, lens)
    if (stat == nf90_noerr) stat = nf90_inq_varid(ncid, "items", vid)
    if (stat == nf90_noerr) stat = nf90_get_var(ncid, vid, buf)
    if (stat /= nf90_noerr) return
    do i = 1, n
      do j = 1, items(i)%strings%count
        m = int(lens(j, i))
        call store_text(items(i)%strings%items(j), items(i)%strings%item_n(j), slice_text(buf(j, i), m))
      end do
    end do
  end subroutine

  subroutine get_event_attrs(ncid, items, stat)
    integer, intent(in) :: ncid
    type(fixture_t), intent(inout) :: items(:)
    integer, intent(inout) :: stat
    integer :: n, c, i, j, m, vid
    integer(int32), allocatable :: kn(:, :), vn(:, :)
    character(len=v2_str), allocatable :: keys(:, :), vals(:, :)
    n = size(items)
    c = max(1, max_attrs(items))
    allocate(kn(c, n), vn(c, n), keys(c, n), vals(c, n))
    if (stat /= nf90_noerr) return
    stat = nf90_inq_varid(ncid, "key_n", vid)
    if (stat == nf90_noerr) stat = nf90_get_var(ncid, vid, kn)
    if (stat == nf90_noerr) stat = nf90_inq_varid(ncid, "key", vid)
    if (stat == nf90_noerr) stat = nf90_get_var(ncid, vid, keys)
    if (stat == nf90_noerr) stat = nf90_inq_varid(ncid, "value_n", vid)
    if (stat == nf90_noerr) stat = nf90_get_var(ncid, vid, vn)
    if (stat == nf90_noerr) stat = nf90_inq_varid(ncid, "value", vid)
    if (stat == nf90_noerr) stat = nf90_get_var(ncid, vid, vals)
    if (stat /= nf90_noerr) return
    do i = 1, n
      do j = 1, items(i)%event%attr_count
        m = int(kn(j, i))
        call store_text(items(i)%event%attrs(j)%key, items(i)%event%attrs(j)%key_n, slice_text(keys(j, i), m))
        m = int(vn(j, i))
        call store_text(items(i)%event%attrs(j)%value, items(i)%event%attrs(j)%value_n, slice_text(vals(j, i), m))
      end do
    end do
  end subroutine

  function max_items(items) result(m)
    type(fixture_t), intent(in) :: items(:)
    integer :: m, i
    m = 0
    do i = 1, size(items)
      m = max(m, items(i)%document%item_count)
    end do
  end function

  function max_tags(items) result(m)
    type(fixture_t), intent(in) :: items(:)
    integer :: m, i
    m = 0
    do i = 1, size(items)
      m = max(m, items(i)%telemetry%tag_count)
    end do
  end function

  function max_points(items) result(m)
    type(fixture_t), intent(in) :: items(:)
    integer :: m, i
    m = 0
    do i = 1, size(items)
      m = max(m, items(i)%telemetry%value_count)
    end do
  end function

  function max_strs(items) result(m)
    type(fixture_t), intent(in) :: items(:)
    integer :: m, i
    m = 0
    do i = 1, size(items)
      m = max(m, items(i)%strings%count)
    end do
  end function

  function max_attrs(items) result(m)
    type(fixture_t), intent(in) :: items(:)
    integer :: m, i
    m = 0
    do i = 1, size(items)
      m = max(m, items(i)%event%attr_count)
    end do
  end function

end module
