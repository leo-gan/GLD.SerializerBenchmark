module ser_rojff
  use, intrinsic :: iso_fortran_env, only: int32, int64, real64
  use rojff, only: json_object_t, json_object_unsafe, json_member_t, json_member_unsafe, json_bool_t, &
       json_integer_t, json_number_t, json_string_t, json_string_unsafe, json_array_t, json_element_t, &
       json_value_t, fallible_json_value_t, parse_json_from_string
  use bench_data
  implicit none
  private
  public :: rojff_name, rojff_version, rojff_write, rojff_read

  character(len=*), parameter :: rojff_name = "rojff"
  character(len=*), parameter :: rojff_version = "9f68e5aa4c12"

contains

  subroutine rojff_write(items, text, stat)
    type(fixture_t), intent(in) :: items(:)
    character(len=:), allocatable, intent(out) :: text
    integer, intent(out) :: stat
    type(json_object_t) :: root
    type(json_element_t), allocatable :: els(:)
    integer :: i
    stat = 0
    if (size(items) == 1) then
      root = record_object(items(1), stat)
    else
      allocate(els(size(items)))
      do i = 1, size(items)
        els(i) = json_element_t(record_object(items(i), stat))
        if (stat /= 0) return
      end do
      root = json_object_unsafe([ &
           json_member_unsafe("kind", json_integer_t(items(1)%kind_id)), &
           json_member_unsafe("records", json_array_t(els))])
    end if
    if (stat /= 0) return
    text = root%to_compact_string()
    if (.not. allocated(text)) stat = 1
  end subroutine

  subroutine rojff_read(text, expected_n, items, stat)
    character(len=*), intent(in) :: text
    integer, intent(in) :: expected_n
    type(fixture_t), allocatable, intent(out) :: items(:)
    integer, intent(out) :: stat
    type(fallible_json_value_t) :: parsed
    integer :: n
    stat = 0
    parsed = parse_json_from_string(text)
    if (parsed%failed()) then
      stat = 1
      return
    end if
    n = expected_n
    if (n < 1) n = 1
    allocate(items(n))
    select type (root => parsed%value_)
    type is (json_object_t)
      if (n == 1) then
        call read_object(root, items(1), stat)
      else
        call read_batch(root, items, stat)
      end if
    class default
      stat = 1
    end select
  end subroutine

  function record_object(fx, stat) result(obj)
    type(fixture_t), intent(in) :: fx
    integer, intent(inout) :: stat
    type(json_object_t) :: obj
    type(json_member_t), allocatable :: members(:)
    type(json_element_t), allocatable :: els(:)
    type(json_member_t) :: meta(2), pair(2)
    integer :: i, n
    if (stat /= 0) return
    select case (fx%kind_id)
    case (kind_message)
      allocate(members(9))
      members(1) = json_member_unsafe("kind", json_integer_t(fx%kind_id))
      members(2) = json_member_unsafe("f_bool", json_bool_t(fx%message%f_bool))
      members(3) = json_member_unsafe("f_int32", json_integer_t(int(fx%message%f_int32)))
      members(4) = i64_member("f_int64", fx%message%f_int64)
      members(5) = json_member_unsafe("f_float64", json_number_t(fx%message%f_float64))
      members(6) = json_member_unsafe("f_string", json_string_unsafe(text_of(fx%message%f_string, fx%message%f_string_n)))
      members(7) = json_member_unsafe("f_bool_2", json_bool_t(fx%message%f_bool_2))
      members(8) = json_member_unsafe("f_int32_2", json_integer_t(int(fx%message%f_int32_2)))
      members(9) = json_member_unsafe("f_string_2", json_string_unsafe(text_of(fx%message%f_string_2, fx%message%f_string_2_n)))
    case (kind_document)
      meta(1) = json_member_unsafe("region", json_string_unsafe(text_of(fx%document%region, fx%document%region_n)))
      meta(2) = json_member_unsafe("version", json_integer_t(int(fx%document%version)))
      n = fx%document%item_count
      allocate(els(n))
      do i = 1, n
        pair(1) = json_member_unsafe("sku", json_string_unsafe(text_of(fx%document%items(i)%sku, fx%document%items(i)%sku_n)))
        pair(2) = json_member_unsafe("qty", json_integer_t(int(fx%document%items(i)%qty)))
        els(i) = json_element_t(json_object_unsafe([ &
             pair(1), pair(2), &
             i64_member("price_minor", fx%document%items(i)%price_minor)]))
      end do
      allocate(members(5))
      members(1) = json_member_unsafe("kind", json_integer_t(fx%kind_id))
      members(2) = json_member_unsafe("id", json_string_unsafe(text_of(fx%document%id, fx%document%id_n)))
      members(3) = json_member_unsafe("status", json_integer_t(int(fx%document%status)))
      members(4) = json_member_unsafe("meta", json_object_unsafe(meta))
      members(5) = json_member_unsafe("items", json_array_t(els))
    case (kind_telemetry)
      n = fx%telemetry%tag_count
      allocate(els(max(n, 1)))
      do i = 1, n
        els(i) = json_element_t(json_string_unsafe(text_of(fx%telemetry%tags(i), fx%telemetry%tag_n(i))))
      end do
      allocate(members(5))
      members(1) = json_member_unsafe("kind", json_integer_t(fx%kind_id))
      members(2) = json_member_unsafe("source", json_string_unsafe(text_of(fx%telemetry%source, fx%telemetry%source_n)))
      members(3) = i64_member("ts", fx%telemetry%ts)
      if (n == 0) then
        members(4) = json_member_unsafe("tags", json_array_t(empty_elements()))
      else
        members(4) = json_member_unsafe("tags", json_array_t(els(1:n)))
      end if
      deallocate(els)
      n = fx%telemetry%value_count
      allocate(els(max(n, 1)))
      do i = 1, n
        els(i) = json_element_t(json_number_t(fx%telemetry%values(i)))
      end do
      if (n == 0) then
        members(5) = json_member_unsafe("values", json_array_t(empty_elements()))
      else
        members(5) = json_member_unsafe("values", json_array_t(els(1:n)))
      end if
    case (kind_strings)
      n = fx%strings%count
      allocate(els(max(n, 1)))
      do i = 1, n
        els(i) = json_element_t(json_string_unsafe(text_of(fx%strings%items(i), fx%strings%item_n(i))))
      end do
      allocate(members(2))
      members(1) = json_member_unsafe("kind", json_integer_t(fx%kind_id))
      if (n == 0) then
        members(2) = json_member_unsafe("items", json_array_t(empty_elements()))
      else
        members(2) = json_member_unsafe("items", json_array_t(els(1:n)))
      end if
    case (kind_event)
      n = fx%event%attr_count
      allocate(els(max(n, 1)))
      do i = 1, n
        pair(1) = json_member_unsafe("key", json_string_unsafe(text_of(fx%event%attrs(i)%key, fx%event%attrs(i)%key_n)))
        pair(2) = json_member_unsafe("value", json_string_unsafe(text_of(fx%event%attrs(i)%value, fx%event%attrs(i)%value_n)))
        els(i) = json_element_t(json_object_unsafe(pair))
      end do
      allocate(members(6))
      members(1) = json_member_unsafe("kind", json_integer_t(fx%kind_id))
      members(2) = json_member_unsafe("event_id", json_string_unsafe(text_of(fx%event%event_id, fx%event%event_id_n)))
      members(3) = json_member_unsafe("event_type", json_string_unsafe(text_of(fx%event%event_type, fx%event%event_type_n)))
      members(4) = i64_member("occurred_at", fx%event%occurred_at)
      members(5) = json_member_unsafe("producer", json_string_unsafe(text_of(fx%event%producer, fx%event%producer_n)))
      if (n == 0) then
        members(6) = json_member_unsafe("attrs", json_array_t(empty_elements()))
      else
        members(6) = json_member_unsafe("attrs", json_array_t(els(1:n)))
      end if
    case default
      stat = 1
      allocate(members(0))
    end select
    if (stat == 0) obj = json_object_unsafe(members)
  end function

  function empty_elements() result(els)
    type(json_element_t), allocatable :: els(:)
    allocate(els(0))
  end function

  function i64_member(key, value) result(member)
    character(len=*), intent(in) :: key
    integer(int64), intent(in) :: value
    type(json_member_t) :: member
    if (value >= -2147483648_int64 .and. value <= 2147483647_int64) then
      member = json_member_unsafe(key, json_integer_t(int(value)))
    else
      member = json_member_unsafe(key, json_number_t(real(value, real64)))
    end if
  end function

  function require_i64(obj, key, stat) result(v)
    type(json_object_t), intent(in) :: obj
    character(len=*), intent(in) :: key
    integer, intent(inout) :: stat
    integer(int64) :: v
    type(fallible_json_value_t) :: got
    v = 0
    if (stat /= 0) return
    got = obj%get(key)
    if (got%failed()) then
      stat = 1
      return
    end if
    select type (el => got%value_)
    type is (json_integer_t)
      v = int(el%number, int64)
    type is (json_number_t)
      v = nint(real(el%number, real64), int64)
    class default
      stat = 1
    end select
  end function

  subroutine read_object(obj, fx, stat)
    type(json_object_t), intent(in) :: obj
    type(fixture_t), intent(out) :: fx
    integer, intent(out) :: stat
    stat = 0
    fx%kind_id = require_int(obj, "kind", stat)
    if (stat /= 0) return
    select case (fx%kind_id)
    case (kind_message)
      fx%message%f_bool = require_bool(obj, "f_bool", stat)
      fx%message%f_int32 = int(require_int(obj, "f_int32", stat), int32)
      fx%message%f_int64 = require_i64(obj, "f_int64", stat)
      fx%message%f_float64 = require_real(obj, "f_float64", stat)
      call store_text(fx%message%f_string, fx%message%f_string_n, require_string(obj, "f_string", stat))
      fx%message%f_bool_2 = require_bool(obj, "f_bool_2", stat)
      fx%message%f_int32_2 = int(require_int(obj, "f_int32_2", stat), int32)
      call store_text(fx%message%f_string_2, fx%message%f_string_2_n, require_string(obj, "f_string_2", stat))
    case (kind_document)
      call store_text(fx%document%id, fx%document%id_n, require_string(obj, "id", stat))
      fx%document%status = int(require_int(obj, "status", stat), int32)
      call read_meta(obj, fx, stat)
      call read_items(obj, fx, stat)
    case (kind_telemetry)
      call store_text(fx%telemetry%source, fx%telemetry%source_n, require_string(obj, "source", stat))
      fx%telemetry%ts = require_i64(obj, "ts", stat)
      call read_string_array(obj, "tags", fx%telemetry%tags, fx%telemetry%tag_n, fx%telemetry%tag_count, v2_max_tags, stat)
      call read_real_array(obj, fx, stat)
    case (kind_strings)
      call read_string_array(obj, "items", fx%strings%items, fx%strings%item_n, fx%strings%count, v2_max_strings, stat)
    case (kind_event)
      call store_text(fx%event%event_id, fx%event%event_id_n, require_string(obj, "event_id", stat))
      call store_text(fx%event%event_type, fx%event%event_type_n, require_string(obj, "event_type", stat))
      fx%event%occurred_at = require_i64(obj, "occurred_at", stat)
      call store_text(fx%event%producer, fx%event%producer_n, require_string(obj, "producer", stat))
      call read_attrs(obj, fx, stat)
    case default
      stat = 1
    end select
  end subroutine

  subroutine read_batch(root, items, stat)
    type(json_object_t), intent(in) :: root
    type(fixture_t), intent(inout) :: items(:)
    integer, intent(out) :: stat
    type(fallible_json_value_t) :: got
    integer :: i
    stat = 0
    got = root%get("records")
    if (got%failed()) then
      stat = 1
      return
    end if
    select type (arr => got%value_)
    type is (json_array_t)
      if (size(arr%elements) /= size(items)) then
        stat = 1
        return
      end if
      do i = 1, size(items)
        select type (child => arr%elements(i)%json)
        type is (json_object_t)
          call read_object(child, items(i), stat)
          if (stat /= 0) return
        class default
          stat = 1
          return
        end select
      end do
    class default
      stat = 1
    end select
  end subroutine

  subroutine read_meta(obj, fx, stat)
    type(json_object_t), intent(in) :: obj
    type(fixture_t), intent(inout) :: fx
    integer, intent(inout) :: stat
    type(fallible_json_value_t) :: got
    if (stat /= 0) return
    got = obj%get("meta")
    if (got%failed()) then
      stat = 1
      return
    end if
    select type (meta => got%value_)
    type is (json_object_t)
      call store_text(fx%document%region, fx%document%region_n, require_string(meta, "region", stat))
      fx%document%version = int(require_int(meta, "version", stat), int32)
    class default
      stat = 1
    end select
  end subroutine

  subroutine read_items(obj, fx, stat)
    type(json_object_t), intent(in) :: obj
    type(fixture_t), intent(inout) :: fx
    integer, intent(inout) :: stat
    type(fallible_json_value_t) :: got
    integer :: i, n
    if (stat /= 0) return
    got = obj%get("items")
    if (got%failed()) then
      stat = 1
      return
    end if
    select type (arr => got%value_)
    type is (json_array_t)
      n = size(arr%elements)
      if (n > v2_max_children) then
        stat = 1
        return
      end if
      fx%document%item_count = n
      do i = 1, n
        select type (item => arr%elements(i)%json)
        type is (json_object_t)
          call store_text(fx%document%items(i)%sku, fx%document%items(i)%sku_n, require_string(item, "sku", stat))
          fx%document%items(i)%qty = int(require_int(item, "qty", stat), int32)
          fx%document%items(i)%price_minor = require_i64(item, "price_minor", stat)
        class default
          stat = 1
          return
        end select
      end do
    class default
      stat = 1
    end select
  end subroutine

  subroutine read_string_array(obj, key, dst, lens, count, limit, stat)
    type(json_object_t), intent(in) :: obj
    character(len=*), intent(in) :: key
    character(len=*), intent(out) :: dst(:)
    integer, intent(out) :: lens(:)
    integer, intent(out) :: count
    integer, intent(in) :: limit
    integer, intent(inout) :: stat
    type(fallible_json_value_t) :: got
    integer :: i, n
    count = 0
    if (stat /= 0) return
    got = obj%get(key)
    if (got%failed()) then
      stat = 1
      return
    end if
    select type (arr => got%value_)
    type is (json_array_t)
      n = size(arr%elements)
      if (n > limit) then
        stat = 1
        return
      end if
      count = n
      do i = 1, n
        select type (el => arr%elements(i)%json)
        type is (json_string_t)
          call store_text(dst(i), lens(i), el%string)
        class default
          stat = 1
          return
        end select
      end do
    class default
      stat = 1
    end select
  end subroutine

  subroutine read_real_array(obj, fx, stat)
    type(json_object_t), intent(in) :: obj
    type(fixture_t), intent(inout) :: fx
    integer, intent(inout) :: stat
    type(fallible_json_value_t) :: got
    integer :: i, n
    if (stat /= 0) return
    got = obj%get("values")
    if (got%failed()) then
      stat = 1
      return
    end if
    select type (arr => got%value_)
    type is (json_array_t)
      n = size(arr%elements)
      if (n > v2_max_points) then
        stat = 1
        return
      end if
      fx%telemetry%value_count = n
      do i = 1, n
        select type (el => arr%elements(i)%json)
        type is (json_number_t)
          fx%telemetry%values(i) = real(el%number, real64)
        class default
          stat = 1
          return
        end select
      end do
    class default
      stat = 1
    end select
  end subroutine

  subroutine read_attrs(obj, fx, stat)
    type(json_object_t), intent(in) :: obj
    type(fixture_t), intent(inout) :: fx
    integer, intent(inout) :: stat
    type(fallible_json_value_t) :: got
    integer :: i, n
    if (stat /= 0) return
    got = obj%get("attrs")
    if (got%failed()) then
      stat = 1
      return
    end if
    select type (arr => got%value_)
    type is (json_array_t)
      n = size(arr%elements)
      if (n > v2_max_attrs) then
        stat = 1
        return
      end if
      fx%event%attr_count = n
      do i = 1, n
        select type (item => arr%elements(i)%json)
        type is (json_object_t)
          call store_text(fx%event%attrs(i)%key, fx%event%attrs(i)%key_n, require_string(item, "key", stat))
          call store_text(fx%event%attrs(i)%value, fx%event%attrs(i)%value_n, require_string(item, "value", stat))
        class default
          stat = 1
          return
        end select
      end do
    class default
      stat = 1
    end select
  end subroutine

  function require_int(obj, key, stat) result(v)
    type(json_object_t), intent(in) :: obj
    character(len=*), intent(in) :: key
    integer, intent(inout) :: stat
    integer :: v
    type(fallible_json_value_t) :: got
    v = 0
    if (stat /= 0) return
    got = obj%get(key)
    if (got%failed()) then
      stat = 1
      return
    end if
    select type (el => got%value_)
    type is (json_integer_t)
      v = el%number
    class default
      stat = 1
    end select
  end function

  function require_bool(obj, key, stat) result(v)
    type(json_object_t), intent(in) :: obj
    character(len=*), intent(in) :: key
    integer, intent(inout) :: stat
    logical :: v
    type(fallible_json_value_t) :: got
    v = .false.
    if (stat /= 0) return
    got = obj%get(key)
    if (got%failed()) then
      stat = 1
      return
    end if
    select type (el => got%value_)
    type is (json_bool_t)
      v = el%bool
    class default
      stat = 1
    end select
  end function

  function require_real(obj, key, stat) result(v)
    type(json_object_t), intent(in) :: obj
    character(len=*), intent(in) :: key
    integer, intent(inout) :: stat
    real(real64) :: v
    type(fallible_json_value_t) :: got
    v = 0
    if (stat /= 0) return
    got = obj%get(key)
    if (got%failed()) then
      stat = 1
      return
    end if
    select type (el => got%value_)
    type is (json_number_t)
      v = real(el%number, real64)
    class default
      stat = 1
    end select
  end function

  function require_string(obj, key, stat) result(v)
    type(json_object_t), intent(in) :: obj
    character(len=*), intent(in) :: key
    integer, intent(inout) :: stat
    character(len=:), allocatable :: v
    type(fallible_json_value_t) :: got
    v = ""
    if (stat /= 0) return
    got = obj%get(key)
    if (got%failed()) then
      stat = 1
      return
    end if
    select type (el => got%value_)
    type is (json_string_t)
      if (allocated(el%string)) v = el%string
    class default
      stat = 1
    end select
  end function

end module
