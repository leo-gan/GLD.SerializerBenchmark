module ser_tree
  ! Build and read a suite value as a TOML Fortran table.
  ! jonquil serializes that table as JSON. toml-f serializes it as TOML.
  ! N>1 is a table with key "records" holding an array of tables, because a
  ! TOML document cannot be a bare array. JSON uses the same shape so one
  ! reader serves both.
  use, intrinsic :: iso_fortran_env, only: int32, int64, real64
  use tomlf, only: toml_table, toml_array, add_table, add_array, set_value, get_value, len
  use bench_data
  implicit none
  private
  public :: tree_from_fixtures, fixtures_from_tree

contains

  subroutine tree_from_fixtures(items, table, stat)
    type(fixture_t), intent(in) :: items(:)
    type(toml_table), allocatable, intent(out) :: table
    integer, intent(out) :: stat
    type(toml_array), pointer :: records
    type(toml_table), pointer :: child
    integer :: i
    stat = 0
    table = toml_table()
    if (size(items) == 1) then
      call fill_table(table, items(1), stat)
      return
    end if
    call add_array(table, "records", records)
    do i = 1, size(items)
      call add_table(records, child)
      call fill_table(child, items(i), stat)
      if (stat /= 0) return
    end do
  end subroutine

  subroutine fixtures_from_tree(table, expected_n, items, stat)
    type(toml_table), intent(inout) :: table
    integer, intent(in) :: expected_n
    type(fixture_t), allocatable, intent(out) :: items(:)
    integer, intent(out) :: stat
    type(toml_array), pointer :: records
    type(toml_table), pointer :: child
    integer :: i, n, st
    stat = 0
    n = expected_n
    if (n < 1) n = 1
    allocate(items(n))
    if (n == 1) then
      call read_table(table, items(1), stat)
      return
    end if
    call get_value(table, "records", records, stat=st)
    if (st /= 0 .or. .not. associated(records)) then
      stat = 1
      return
    end if
    if (len(records) /= n) then
      stat = 1
      return
    end if
    do i = 1, n
      call get_value(records, i, child, stat=st)
      if (st /= 0 .or. .not. associated(child)) then
        stat = 1
        return
      end if
      call read_table(child, items(i), stat)
      if (stat /= 0) return
    end do
  end subroutine

  subroutine fill_table(table, fx, stat)
    type(toml_table), intent(inout) :: table
    type(fixture_t), intent(in) :: fx
    integer, intent(out) :: stat
    type(toml_table), pointer :: meta, item
    type(toml_array), pointer :: items, tags, values, attrs
    integer :: i
    stat = 0
    call set_value(table, "kind", fx%kind_id)
    select case (fx%kind_id)
    case (kind_message)
      call set_value(table, "f_bool", fx%message%f_bool)
      call set_value(table, "f_int32", int(fx%message%f_int32))
      call set_value(table, "f_int64", fx%message%f_int64)
      call set_value(table, "f_float64", fx%message%f_float64)
      call set_value(table, "f_string", text_of(fx%message%f_string, fx%message%f_string_n))
      call set_value(table, "f_bool_2", fx%message%f_bool_2)
      call set_value(table, "f_int32_2", int(fx%message%f_int32_2))
      call set_value(table, "f_string_2", text_of(fx%message%f_string_2, fx%message%f_string_2_n))
    case (kind_document)
      call set_value(table, "id", text_of(fx%document%id, fx%document%id_n))
      call set_value(table, "status", int(fx%document%status))
      call add_table(table, "meta", meta)
      call set_value(meta, "region", text_of(fx%document%region, fx%document%region_n))
      call set_value(meta, "version", int(fx%document%version))
      call add_array(table, "items", items)
      do i = 1, fx%document%item_count
        call add_table(items, item)
        call set_value(item, "sku", text_of(fx%document%items(i)%sku, fx%document%items(i)%sku_n))
        call set_value(item, "qty", int(fx%document%items(i)%qty))
        call set_value(item, "price_minor", fx%document%items(i)%price_minor)
      end do
    case (kind_telemetry)
      call set_value(table, "source", text_of(fx%telemetry%source, fx%telemetry%source_n))
      call set_value(table, "ts", fx%telemetry%ts)
      call add_array(table, "tags", tags)
      do i = 1, fx%telemetry%tag_count
        call set_value(tags, i, text_of(fx%telemetry%tags(i), fx%telemetry%tag_n(i)))
      end do
      call add_array(table, "values", values)
      do i = 1, fx%telemetry%value_count
        call set_value(values, i, fx%telemetry%values(i))
      end do
    case (kind_strings)
      call add_array(table, "items", items)
      do i = 1, fx%strings%count
        call set_value(items, i, text_of(fx%strings%items(i), fx%strings%item_n(i)))
      end do
    case (kind_event)
      call set_value(table, "event_id", text_of(fx%event%event_id, fx%event%event_id_n))
      call set_value(table, "event_type", text_of(fx%event%event_type, fx%event%event_type_n))
      call set_value(table, "occurred_at", fx%event%occurred_at)
      call set_value(table, "producer", text_of(fx%event%producer, fx%event%producer_n))
      call add_array(table, "attrs", attrs)
      do i = 1, fx%event%attr_count
        call add_table(attrs, item)
        call set_value(item, "key", text_of(fx%event%attrs(i)%key, fx%event%attrs(i)%key_n))
        call set_value(item, "value", text_of(fx%event%attrs(i)%value, fx%event%attrs(i)%value_n))
      end do
    case default
      stat = 1
    end select
  end subroutine

  subroutine read_table(table, fx, stat)
    type(toml_table), intent(inout) :: table
    type(fixture_t), intent(out) :: fx
    integer, intent(out) :: stat
    type(toml_table), pointer :: meta, item
    type(toml_array), pointer :: items, tags, values, attrs
    character(len=:), allocatable :: s
    integer :: i, st, kind_id, n, qty
    integer(int64) :: i64
    real(real64) :: r
    logical :: b
    stat = 0
    call get_value(table, "kind", kind_id, stat=st)
    if (st /= 0) then
      stat = 1
      return
    end if
    fx%kind_id = kind_id
    select case (kind_id)
    case (kind_message)
      call get_value(table, "f_bool", b, stat=st)
      if (st /= 0) then
        stat = 1
        return
      end if
      fx%message%f_bool = b
      call get_value(table, "f_int32", i, stat=st)
      if (st /= 0) then
        stat = 1
        return
      end if
      fx%message%f_int32 = int(i, int32)
      call get_value(table, "f_int64", i64, stat=st)
      if (st /= 0) then
        stat = 1
        return
      end if
      fx%message%f_int64 = i64
      call get_value(table, "f_float64", r, stat=st)
      if (st /= 0) then
        stat = 1
        return
      end if
      fx%message%f_float64 = r
      call get_value(table, "f_string", s, stat=st)
      if (st /= 0) then
        stat = 1
        return
      end if
      call store_text(fx%message%f_string, fx%message%f_string_n, s)
      call get_value(table, "f_bool_2", b, stat=st)
      if (st /= 0) then
        stat = 1
        return
      end if
      fx%message%f_bool_2 = b
      call get_value(table, "f_int32_2", i, stat=st)
      if (st /= 0) then
        stat = 1
        return
      end if
      fx%message%f_int32_2 = int(i, int32)
      call get_value(table, "f_string_2", s, stat=st)
      if (st /= 0) then
        stat = 1
        return
      end if
      call store_text(fx%message%f_string_2, fx%message%f_string_2_n, s)
    case (kind_document)
      call get_value(table, "id", s, stat=st)
      if (st /= 0) then
        stat = 1
        return
      end if
      call store_text(fx%document%id, fx%document%id_n, s)
      call get_value(table, "status", i, stat=st)
      if (st /= 0) then
        stat = 1
        return
      end if
      fx%document%status = int(i, int32)
      call get_value(table, "meta", meta, stat=st)
      if (st /= 0 .or. .not. associated(meta)) then
        stat = 1
        return
      end if
      call get_value(meta, "region", s, stat=st)
      if (st /= 0) then
        stat = 1
        return
      end if
      call store_text(fx%document%region, fx%document%region_n, s)
      call get_value(meta, "version", i, stat=st)
      if (st /= 0) then
        stat = 1
        return
      end if
      fx%document%version = int(i, int32)
      call get_value(table, "items", items, stat=st)
      if (st /= 0 .or. .not. associated(items)) then
        stat = 1
        return
      end if
      n = len(items)
      if (n < 0 .or. n > v2_max_children) then
        stat = 1
        return
      end if
      fx%document%item_count = n
      do i = 1, n
        call get_value(items, i, item, stat=st)
        if (st /= 0 .or. .not. associated(item)) then
          stat = 1
          return
        end if
        call get_value(item, "sku", s, stat=st)
        if (st /= 0) then
          stat = 1
          return
        end if
        call store_text(fx%document%items(i)%sku, fx%document%items(i)%sku_n, s)
        call get_value(item, "qty", qty, stat=st)
        if (st /= 0) then
          stat = 1
          return
        end if
        fx%document%items(i)%qty = int(qty, int32)
        call get_value(item, "price_minor", i64, stat=st)
        if (st /= 0) then
          stat = 1
          return
        end if
        fx%document%items(i)%price_minor = i64
      end do
    case (kind_telemetry)
      call get_value(table, "source", s, stat=st)
      if (st /= 0) then
        stat = 1
        return
      end if
      call store_text(fx%telemetry%source, fx%telemetry%source_n, s)
      call get_value(table, "ts", i64, stat=st)
      if (st /= 0) then
        stat = 1
        return
      end if
      fx%telemetry%ts = i64
      call get_value(table, "tags", tags, stat=st)
      if (st /= 0 .or. .not. associated(tags)) then
        stat = 1
        return
      end if
      n = len(tags)
      if (n < 0 .or. n > v2_max_tags) then
        stat = 1
        return
      end if
      fx%telemetry%tag_count = n
      do i = 1, n
        call get_value(tags, i, s, stat=st)
        if (st /= 0) then
          stat = 1
          return
        end if
        call store_text(fx%telemetry%tags(i), fx%telemetry%tag_n(i), s)
      end do
      call get_value(table, "values", values, stat=st)
      if (st /= 0 .or. .not. associated(values)) then
        stat = 1
        return
      end if
      n = len(values)
      if (n < 0 .or. n > v2_max_points) then
        stat = 1
        return
      end if
      fx%telemetry%value_count = n
      do i = 1, n
        call get_value(values, i, r, stat=st)
        if (st /= 0) then
          stat = 1
          return
        end if
        fx%telemetry%values(i) = r
      end do
    case (kind_strings)
      call get_value(table, "items", items, stat=st)
      if (st /= 0 .or. .not. associated(items)) then
        stat = 1
        return
      end if
      n = len(items)
      if (n < 0 .or. n > v2_max_strings) then
        stat = 1
        return
      end if
      fx%strings%count = n
      do i = 1, n
        call get_value(items, i, s, stat=st)
        if (st /= 0) then
          stat = 1
          return
        end if
        call store_text(fx%strings%items(i), fx%strings%item_n(i), s)
      end do
    case (kind_event)
      call get_value(table, "event_id", s, stat=st)
      if (st /= 0) then
        stat = 1
        return
      end if
      call store_text(fx%event%event_id, fx%event%event_id_n, s)
      call get_value(table, "event_type", s, stat=st)
      if (st /= 0) then
        stat = 1
        return
      end if
      call store_text(fx%event%event_type, fx%event%event_type_n, s)
      call get_value(table, "occurred_at", i64, stat=st)
      if (st /= 0) then
        stat = 1
        return
      end if
      fx%event%occurred_at = i64
      call get_value(table, "producer", s, stat=st)
      if (st /= 0) then
        stat = 1
        return
      end if
      call store_text(fx%event%producer, fx%event%producer_n, s)
      call get_value(table, "attrs", attrs, stat=st)
      if (st /= 0 .or. .not. associated(attrs)) then
        stat = 1
        return
      end if
      n = len(attrs)
      if (n < 0 .or. n > v2_max_attrs) then
        stat = 1
        return
      end if
      fx%event%attr_count = n
      do i = 1, n
        call get_value(attrs, i, item, stat=st)
        if (st /= 0 .or. .not. associated(item)) then
          stat = 1
          return
        end if
        call get_value(item, "key", s, stat=st)
        if (st /= 0) then
          stat = 1
          return
        end if
        call store_text(fx%event%attrs(i)%key, fx%event%attrs(i)%key_n, s)
        call get_value(item, "value", s, stat=st)
        if (st /= 0) then
          stat = 1
          return
        end if
        call store_text(fx%event%attrs(i)%value, fx%event%attrs(i)%value_n, s)
      end do
    case default
      stat = 1
    end select
  end subroutine

end module
