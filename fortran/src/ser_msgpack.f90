module ser_msgpack
  use, intrinsic :: iso_fortran_env, only: int8, int32, int64, real64
  use messagepack, only: msgpack, mp_map_type, mp_arr_type, mp_str_type, mp_int_type, &
       mp_bool_type, mp_float_type, mp_value_type
  use bench_data
  implicit none
  private
  public :: mp_name, mp_version, mp_write, mp_read

  character(len=*), parameter :: mp_name = "fortran-messagepack"
  character(len=*), parameter :: mp_version = "0.3.1"

contains

  subroutine mp_write(items, payload, stat)
    type(fixture_t), intent(in) :: items(:)
    integer(int8), allocatable, intent(out) :: payload(:)
    integer, intent(out) :: stat
    type(msgpack) :: mp
    class(mp_value_type), allocatable :: root
    integer(int8), allocatable :: buffer(:)
    integer :: i
    stat = 0
    mp = msgpack()
    if (size(items) == 1) then
      root = record_map(items(1))
    else
      root = batch_map(items, stat)
      if (stat /= 0) return
    end if
    call mp%pack_alloc(root, buffer)
    if (mp%failed() .or. .not. allocated(buffer)) then
      stat = 1
      return
    end if
    payload = buffer
  end subroutine

  subroutine mp_read(payload, expected_n, items, stat)
    integer(int8), intent(in) :: payload(:)
    integer, intent(in) :: expected_n
    type(fixture_t), allocatable, intent(out) :: items(:)
    integer, intent(out) :: stat
    type(msgpack) :: mp
    class(mp_value_type), allocatable :: root
    integer :: n
    stat = 0
    mp = msgpack()
    call mp%extra_bytes_is_error(.true.)
    call mp%unpack(payload, root)
    if (mp%failed() .or. .not. allocated(root)) then
      stat = 1
      return
    end if
    n = expected_n
    if (n < 1) n = 1
    allocate(items(n))
    select type (root)
    type is (mp_map_type)
      if (n == 1) then
        call read_map(root, items(1), stat)
      else
        call read_batch(root, items, stat)
      end if
    class default
      stat = 1
    end select
  end subroutine

  function record_map(fx) result(obj)
    type(fixture_t), intent(in) :: fx
    type(mp_map_type) :: obj
    type(mp_arr_type) :: arr
    type(mp_map_type) :: child
    integer :: i, n
    select case (fx%kind_id)
    case (kind_message)
      obj = mp_map_type(9_int64)
      call put_int(obj, 1, "kind", int(fx%kind_id, int64))
      call put_bool(obj, 2, "f_bool", fx%message%f_bool)
      call put_int(obj, 3, "f_int32", int(fx%message%f_int32, int64))
      call put_int(obj, 4, "f_int64", fx%message%f_int64)
      call put_real(obj, 5, "f_float64", fx%message%f_float64)
      call put_str(obj, 6, "f_string", text_of(fx%message%f_string, fx%message%f_string_n))
      call put_bool(obj, 7, "f_bool_2", fx%message%f_bool_2)
      call put_int(obj, 8, "f_int32_2", int(fx%message%f_int32_2, int64))
      call put_str(obj, 9, "f_string_2", text_of(fx%message%f_string_2, fx%message%f_string_2_n))
    case (kind_document)
      obj = mp_map_type(5_int64)
      call put_int(obj, 1, "kind", int(fx%kind_id, int64))
      call put_str(obj, 2, "id", text_of(fx%document%id, fx%document%id_n))
      call put_int(obj, 3, "status", int(fx%document%status, int64))
      child = mp_map_type(2_int64)
      call put_str(child, 1, "region", text_of(fx%document%region, fx%document%region_n))
      call put_int(child, 2, "version", int(fx%document%version, int64))
      obj%keys(4)%obj = mp_str_type("meta")
      obj%values(4)%obj = child
      n = fx%document%item_count
      arr = mp_arr_type(int(n, int64))
      do i = 1, n
        child = mp_map_type(3_int64)
        call put_str(child, 1, "sku", text_of(fx%document%items(i)%sku, fx%document%items(i)%sku_n))
        call put_int(child, 2, "qty", int(fx%document%items(i)%qty, int64))
        call put_int(child, 3, "price_minor", fx%document%items(i)%price_minor)
        arr%values(i)%obj = child
      end do
      obj%keys(5)%obj = mp_str_type("items")
      obj%values(5)%obj = arr
    case (kind_telemetry)
      obj = mp_map_type(5_int64)
      call put_int(obj, 1, "kind", int(fx%kind_id, int64))
      call put_str(obj, 2, "source", text_of(fx%telemetry%source, fx%telemetry%source_n))
      call put_int(obj, 3, "ts", fx%telemetry%ts)
      n = fx%telemetry%tag_count
      arr = mp_arr_type(int(n, int64))
      do i = 1, n
        arr%values(i)%obj = mp_str_type(text_of(fx%telemetry%tags(i), fx%telemetry%tag_n(i)))
      end do
      obj%keys(4)%obj = mp_str_type("tags")
      obj%values(4)%obj = arr
      n = fx%telemetry%value_count
      arr = mp_arr_type(int(n, int64))
      do i = 1, n
        arr%values(i)%obj = mp_float_type(fx%telemetry%values(i))
      end do
      obj%keys(5)%obj = mp_str_type("values")
      obj%values(5)%obj = arr
    case (kind_strings)
      obj = mp_map_type(2_int64)
      call put_int(obj, 1, "kind", int(fx%kind_id, int64))
      n = fx%strings%count
      arr = mp_arr_type(int(n, int64))
      do i = 1, n
        arr%values(i)%obj = mp_str_type(text_of(fx%strings%items(i), fx%strings%item_n(i)))
      end do
      obj%keys(2)%obj = mp_str_type("items")
      obj%values(2)%obj = arr
    case (kind_event)
      obj = mp_map_type(6_int64)
      call put_int(obj, 1, "kind", int(fx%kind_id, int64))
      call put_str(obj, 2, "event_id", text_of(fx%event%event_id, fx%event%event_id_n))
      call put_str(obj, 3, "event_type", text_of(fx%event%event_type, fx%event%event_type_n))
      call put_int(obj, 4, "occurred_at", fx%event%occurred_at)
      call put_str(obj, 5, "producer", text_of(fx%event%producer, fx%event%producer_n))
      n = fx%event%attr_count
      arr = mp_arr_type(int(n, int64))
      do i = 1, n
        child = mp_map_type(2_int64)
        call put_str(child, 1, "key", text_of(fx%event%attrs(i)%key, fx%event%attrs(i)%key_n))
        call put_str(child, 2, "value", text_of(fx%event%attrs(i)%value, fx%event%attrs(i)%value_n))
        arr%values(i)%obj = child
      end do
      obj%keys(6)%obj = mp_str_type("attrs")
      obj%values(6)%obj = arr
    case default
      obj = mp_map_type(0_int64)
    end select
  end function

  function batch_map(items, stat) result(obj)
    type(fixture_t), intent(in) :: items(:)
    integer, intent(out) :: stat
    type(mp_map_type) :: obj
    type(mp_arr_type) :: arr
    integer :: i
    stat = 0
    obj = mp_map_type(2_int64)
    call put_int(obj, 1, "kind", int(items(1)%kind_id, int64))
    arr = mp_arr_type(int(size(items), int64))
    do i = 1, size(items)
      arr%values(i)%obj = record_map(items(i))
    end do
    obj%keys(2)%obj = mp_str_type("records")
    obj%values(2)%obj = arr
  end function

  subroutine put_int(map, i, key, value)
    type(mp_map_type), intent(inout) :: map
    integer, intent(in) :: i
    character(len=*), intent(in) :: key
    integer(int64), intent(in) :: value
    map%keys(i)%obj = mp_str_type(key)
    map%values(i)%obj = mp_int_type(value)
  end subroutine

  subroutine put_bool(map, i, key, value)
    type(mp_map_type), intent(inout) :: map
    integer, intent(in) :: i
    character(len=*), intent(in) :: key
    logical, intent(in) :: value
    map%keys(i)%obj = mp_str_type(key)
    map%values(i)%obj = mp_bool_type(value)
  end subroutine

  subroutine put_real(map, i, key, value)
    type(mp_map_type), intent(inout) :: map
    integer, intent(in) :: i
    character(len=*), intent(in) :: key
    real(real64), intent(in) :: value
    map%keys(i)%obj = mp_str_type(key)
    map%values(i)%obj = mp_float_type(value)
  end subroutine

  subroutine put_str(map, i, key, value)
    type(mp_map_type), intent(inout) :: map
    integer, intent(in) :: i
    character(len=*), intent(in) :: key, value
    map%keys(i)%obj = mp_str_type(key)
    map%values(i)%obj = mp_str_type(value)
  end subroutine

  subroutine read_map(map, fx, stat)
    type(mp_map_type), intent(in) :: map
    type(fixture_t), intent(out) :: fx
    integer, intent(out) :: stat
    integer(int64) :: kind_id
    stat = 0
    kind_id = map_int(map, "kind", stat)
    if (stat /= 0) return
    fx%kind_id = int(kind_id)
    select case (fx%kind_id)
    case (kind_message)
      fx%message%f_bool = map_bool(map, "f_bool", stat)
      fx%message%f_int32 = int(map_int(map, "f_int32", stat), int32)
      fx%message%f_int64 = map_int(map, "f_int64", stat)
      fx%message%f_float64 = map_real(map, "f_float64", stat)
      call store_text(fx%message%f_string, fx%message%f_string_n, map_str(map, "f_string", stat))
      fx%message%f_bool_2 = map_bool(map, "f_bool_2", stat)
      fx%message%f_int32_2 = int(map_int(map, "f_int32_2", stat), int32)
      call store_text(fx%message%f_string_2, fx%message%f_string_2_n, map_str(map, "f_string_2", stat))
    case (kind_document)
      call store_text(fx%document%id, fx%document%id_n, map_str(map, "id", stat))
      fx%document%status = int(map_int(map, "status", stat), int32)
      call read_meta(map, fx, stat)
      call read_items(map, fx, stat)
    case (kind_telemetry)
      call store_text(fx%telemetry%source, fx%telemetry%source_n, map_str(map, "source", stat))
      fx%telemetry%ts = map_int(map, "ts", stat)
      call read_tags(map, fx, stat)
      call read_values(map, fx, stat)
    case (kind_strings)
      call read_strings(map, fx, stat)
    case (kind_event)
      call store_text(fx%event%event_id, fx%event%event_id_n, map_str(map, "event_id", stat))
      call store_text(fx%event%event_type, fx%event%event_type_n, map_str(map, "event_type", stat))
      fx%event%occurred_at = map_int(map, "occurred_at", stat)
      call store_text(fx%event%producer, fx%event%producer_n, map_str(map, "producer", stat))
      call read_attrs(map, fx, stat)
    case default
      stat = 1
    end select
  end subroutine

  subroutine read_batch(map, items, stat)
    type(mp_map_type), intent(in) :: map
    type(fixture_t), intent(inout) :: items(:)
    integer, intent(out) :: stat
    class(mp_value_type), allocatable :: raw
    integer :: i
    stat = 0
    call take(map, "records", raw, stat)
    if (stat /= 0) return
    select type (raw)
    type is (mp_arr_type)
      if (size(raw%values) /= size(items)) then
        stat = 1
        return
      end if
      do i = 1, size(items)
        select type (child => raw%values(i)%obj)
        type is (mp_map_type)
          call read_map(child, items(i), stat)
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

  subroutine read_meta(map, fx, stat)
    type(mp_map_type), intent(in) :: map
    type(fixture_t), intent(inout) :: fx
    integer, intent(inout) :: stat
    class(mp_value_type), allocatable :: raw
    if (stat /= 0) return
    call take(map, "meta", raw, stat)
    if (stat /= 0) return
    select type (raw)
    type is (mp_map_type)
      call store_text(fx%document%region, fx%document%region_n, map_str(raw, "region", stat))
      fx%document%version = int(map_int(raw, "version", stat), int32)
    class default
      stat = 1
    end select
  end subroutine

  subroutine read_items(map, fx, stat)
    type(mp_map_type), intent(in) :: map
    type(fixture_t), intent(inout) :: fx
    integer, intent(inout) :: stat
    class(mp_value_type), allocatable :: raw
    integer :: i, n
    if (stat /= 0) return
    call take(map, "items", raw, stat)
    if (stat /= 0) return
    select type (raw)
    type is (mp_arr_type)
      n = size(raw%values)
      if (n > v2_max_children) then
        stat = 1
        return
      end if
      fx%document%item_count = n
      do i = 1, n
        select type (item => raw%values(i)%obj)
        type is (mp_map_type)
          call store_text(fx%document%items(i)%sku, fx%document%items(i)%sku_n, map_str(item, "sku", stat))
          fx%document%items(i)%qty = int(map_int(item, "qty", stat), int32)
          fx%document%items(i)%price_minor = map_int(item, "price_minor", stat)
        class default
          stat = 1
          return
        end select
      end do
    class default
      stat = 1
    end select
  end subroutine

  subroutine read_tags(map, fx, stat)
    type(mp_map_type), intent(in) :: map
    type(fixture_t), intent(inout) :: fx
    integer, intent(inout) :: stat
    class(mp_value_type), allocatable :: raw
    integer :: i, n
    if (stat /= 0) return
    call take(map, "tags", raw, stat)
    if (stat /= 0) return
    select type (raw)
    type is (mp_arr_type)
      n = size(raw%values)
      if (n > v2_max_tags) then
        stat = 1
        return
      end if
      fx%telemetry%tag_count = n
      do i = 1, n
        select type (el => raw%values(i)%obj)
        type is (mp_str_type)
          call store_text(fx%telemetry%tags(i), fx%telemetry%tag_n(i), el%value)
        class default
          stat = 1
          return
        end select
      end do
    class default
      stat = 1
    end select
  end subroutine

  subroutine read_values(map, fx, stat)
    type(mp_map_type), intent(in) :: map
    type(fixture_t), intent(inout) :: fx
    integer, intent(inout) :: stat
    class(mp_value_type), allocatable :: raw
    integer :: i, n
    if (stat /= 0) return
    call take(map, "values", raw, stat)
    if (stat /= 0) return
    select type (raw)
    type is (mp_arr_type)
      n = size(raw%values)
      if (n > v2_max_points) then
        stat = 1
        return
      end if
      fx%telemetry%value_count = n
      do i = 1, n
        select type (el => raw%values(i)%obj)
        type is (mp_float_type)
          if (el%is_64) then
            fx%telemetry%values(i) = el%f64value
          else
            fx%telemetry%values(i) = real(el%f32value, real64)
          end if
        class default
          stat = 1
          return
        end select
      end do
    class default
      stat = 1
    end select
  end subroutine

  subroutine read_strings(map, fx, stat)
    type(mp_map_type), intent(in) :: map
    type(fixture_t), intent(inout) :: fx
    integer, intent(inout) :: stat
    class(mp_value_type), allocatable :: raw
    integer :: i, n
    if (stat /= 0) return
    call take(map, "items", raw, stat)
    if (stat /= 0) return
    select type (raw)
    type is (mp_arr_type)
      n = size(raw%values)
      if (n > v2_max_strings) then
        stat = 1
        return
      end if
      fx%strings%count = n
      do i = 1, n
        select type (el => raw%values(i)%obj)
        type is (mp_str_type)
          call store_text(fx%strings%items(i), fx%strings%item_n(i), el%value)
        class default
          stat = 1
          return
        end select
      end do
    class default
      stat = 1
    end select
  end subroutine

  subroutine read_attrs(map, fx, stat)
    type(mp_map_type), intent(in) :: map
    type(fixture_t), intent(inout) :: fx
    integer, intent(inout) :: stat
    class(mp_value_type), allocatable :: raw
    integer :: i, n
    if (stat /= 0) return
    call take(map, "attrs", raw, stat)
    if (stat /= 0) return
    select type (raw)
    type is (mp_arr_type)
      n = size(raw%values)
      if (n > v2_max_attrs) then
        stat = 1
        return
      end if
      fx%event%attr_count = n
      do i = 1, n
        select type (item => raw%values(i)%obj)
        type is (mp_map_type)
          call store_text(fx%event%attrs(i)%key, fx%event%attrs(i)%key_n, map_str(item, "key", stat))
          call store_text(fx%event%attrs(i)%value, fx%event%attrs(i)%value_n, map_str(item, "value", stat))
        class default
          stat = 1
          return
        end select
      end do
    class default
      stat = 1
    end select
  end subroutine

  subroutine take(map, key, raw, stat)
    type(mp_map_type), intent(in) :: map
    character(len=*), intent(in) :: key
    class(mp_value_type), allocatable, intent(out) :: raw
    integer, intent(inout) :: stat
    integer :: i
    if (stat /= 0) return
    do i = 1, size(map%keys)
      select type (k => map%keys(i)%obj)
      type is (mp_str_type)
        if (allocated(k%value)) then
          if (k%value == key) then
            raw = map%values(i)%obj
            return
          end if
        end if
      end select
    end do
    stat = 1
  end subroutine

  function map_int(map, key, stat) result(v)
    type(mp_map_type), intent(in) :: map
    character(len=*), intent(in) :: key
    integer, intent(inout) :: stat
    integer(int64) :: v
    class(mp_value_type), allocatable :: raw
    v = 0
    call take(map, key, raw, stat)
    if (stat /= 0) return
    select type (raw)
    type is (mp_int_type)
      v = raw%value
    class default
      stat = 1
    end select
  end function

  function map_bool(map, key, stat) result(v)
    type(mp_map_type), intent(in) :: map
    character(len=*), intent(in) :: key
    integer, intent(inout) :: stat
    logical :: v
    class(mp_value_type), allocatable :: raw
    v = .false.
    call take(map, key, raw, stat)
    if (stat /= 0) return
    select type (raw)
    type is (mp_bool_type)
      v = raw%value
    class default
      stat = 1
    end select
  end function

  function map_real(map, key, stat) result(v)
    type(mp_map_type), intent(in) :: map
    character(len=*), intent(in) :: key
    integer, intent(inout) :: stat
    real(real64) :: v
    class(mp_value_type), allocatable :: raw
    v = 0
    call take(map, key, raw, stat)
    if (stat /= 0) return
    select type (raw)
    type is (mp_float_type)
      if (raw%is_64) then
        v = raw%f64value
      else
        v = real(raw%f32value, real64)
      end if
    class default
      stat = 1
    end select
  end function

  function map_str(map, key, stat) result(v)
    type(mp_map_type), intent(in) :: map
    character(len=*), intent(in) :: key
    integer, intent(inout) :: stat
    character(len=:), allocatable :: v
    class(mp_value_type), allocatable :: raw
    v = ""
    call take(map, key, raw, stat)
    if (stat /= 0) return
    select type (raw)
    type is (mp_str_type)
      if (allocated(raw%value)) v = raw%value
    class default
      stat = 1
    end select
  end function

end module
