module ser_json_fortran
  use, intrinsic :: iso_fortran_env, only: int32, int64, real64
  use json_module, only: json_core, json_value, json_IK, json_RK
  use bench_data
  implicit none
  private
  public :: jf_name, jf_version, jf_write, jf_read

  character(len=*), parameter :: jf_name = "json-fortran"
  character(len=*), parameter :: jf_version = "9.3.1"

contains

  subroutine add_i64(core, node, key, value)
    type(json_core), intent(inout) :: core
    type(json_value), pointer, intent(in) :: node
    character(len=*), intent(in) :: key
    integer(int64), intent(in) :: value
    ! json-fortran's default integer kind is int32. Values that fit stay JSON
    ! integers. Larger ones, such as epoch milliseconds, are JSON numbers.
    ! They are exactly representable in float64 below 2^53.
    ! -DINT64 makes json_IK int64, so epoch milliseconds stay JSON integers.
    if (json_IK == int64 .or. (value >= -2147483648_int64 .and. value <= 2147483647_int64)) then
      call core%add(node, key, int(value, json_IK))
    else
      call core%add(node, key, real(value, json_RK))
    end if
  end subroutine

  function get_i64(core, node, key, stat) result(value)
    type(json_core), intent(inout) :: core
    type(json_value), pointer, intent(in) :: node
    character(len=*), intent(in) :: key
    integer, intent(inout) :: stat
    integer(int64) :: value
    integer(json_IK) :: ik
    real(json_RK) :: rk
    logical :: found
    value = 0
    if (stat /= 0) return
    call core%get(node, key, ik, found)
    if (found .and. .not. core%failed()) then
      value = int(ik, int64)
      return
    end if
    call core%clear_exceptions()
    call core%get(node, key, rk, found)
    if (.not. found) then
      stat = 1
      return
    end if
    value = nint(real(rk, real64), int64)
  end function

  subroutine jf_write(items, text, stat)
    type(fixture_t), intent(in) :: items(:)
    character(len=:), allocatable, intent(out) :: text
    integer, intent(out) :: stat
    type(json_core) :: core
    type(json_value), pointer :: root, child
    integer :: i
    stat = 0
    root => null()
    call core%initialize(no_whitespace=.true., strict_type_checking=.true.)
    if (size(items) == 1) then
      call write_record(core, root, items(1), stat)
    else
      call core%create_object(root, "")
      call core%add(root, "kind", int(items(1)%kind_id, json_IK))
      call core%create_array(child, "records")
      call core%add(root, child)
      do i = 1, size(items)
        call append_record(core, child, items(i), stat)
        if (stat /= 0) exit
      end do
    end if
    if (stat == 0) call core%serialize(root, text)
    if (stat /= 0 .or. core%failed() .or. .not. allocated(text)) stat = 1
    if (associated(root)) call core%destroy(root)
  end subroutine

  subroutine jf_read(text, expected_n, items, stat)
    character(len=*), intent(in) :: text
    integer, intent(in) :: expected_n
    type(fixture_t), allocatable, intent(out) :: items(:)
    integer, intent(out) :: stat
    type(json_core) :: core
    type(json_value), pointer :: root, records, child
    logical :: found
    integer :: i, n, kind_id
    integer(json_IK) :: ik, nk
    stat = 0
    root => null()
    call core%initialize(strict_type_checking=.true.)
    call core%deserialize(root, text)
    if (core%failed() .or. .not. associated(root)) then
      stat = 1
      return
    end if
    n = expected_n
    if (n < 1) n = 1
    allocate(items(n))
    if (n == 1) then
      call read_record(core, root, items(1), stat)
    else
      call core%get(root, "records", records, found)
      if (.not. found) then
        stat = 1
      else
        do i = 1, n
          call core%get_child(records, int(i, json_IK), child, found)
          if (.not. found) then
            stat = 1
            exit
          end if
          call read_record(core, child, items(i), stat)
          if (stat /= 0) exit
        end do
      end if
      if (stat == 0) then
        call core%get(root, "kind", ik, found)
        if (.not. found) stat = 1
        kind_id = int(ik)
        if (kind_id /= items(1)%kind_id) stat = 1
      end if
    end if
    if (associated(root)) call core%destroy(root)
  end subroutine

  subroutine append_record(core, arr, fx, stat)
    type(json_core), intent(inout) :: core
    type(json_value), pointer, intent(in) :: arr
    type(fixture_t), intent(in) :: fx
    integer, intent(out) :: stat
    type(json_value), pointer :: child
    call write_record(core, child, fx, stat)
    if (stat /= 0) return
    call core%add(arr, child)
    if (core%failed()) stat = 1
  end subroutine

  subroutine write_record(core, node, fx, stat)
    type(json_core), intent(inout) :: core
    type(json_value), pointer, intent(out) :: node
    type(fixture_t), intent(in) :: fx
    integer, intent(out) :: stat
    type(json_value), pointer :: meta, items, item, tags, values, attrs
    integer :: i
    stat = 0
    node => null()
    call core%create_object(node, "")
    call core%add(node, "kind", int(fx%kind_id, json_IK))
    select case (fx%kind_id)
    case (kind_message)
      call core%add(node, "f_bool", fx%message%f_bool)
      call core%add(node, "f_int32", int(fx%message%f_int32, json_IK))
      call add_i64(core, node, "f_int64", fx%message%f_int64)
      call core%add(node, "f_float64", real(fx%message%f_float64, json_RK))
      call core%add(node, "f_string", text_of(fx%message%f_string, fx%message%f_string_n))
      call core%add(node, "f_bool_2", fx%message%f_bool_2)
      call core%add(node, "f_int32_2", int(fx%message%f_int32_2, json_IK))
      call core%add(node, "f_string_2", text_of(fx%message%f_string_2, fx%message%f_string_2_n))
    case (kind_document)
      call core%add(node, "id", text_of(fx%document%id, fx%document%id_n))
      call core%add(node, "status", int(fx%document%status, json_IK))
      call core%create_object(meta, "meta")
      call core%add(node, meta)
      call core%add(meta, "region", text_of(fx%document%region, fx%document%region_n))
      call core%add(meta, "version", int(fx%document%version, json_IK))
      call core%create_array(items, "items")
      call core%add(node, items)
      do i = 1, fx%document%item_count
        call core%create_object(item, "")
        call core%add(items, item)
        call core%add(item, "sku", text_of(fx%document%items(i)%sku, fx%document%items(i)%sku_n))
        call core%add(item, "qty", int(fx%document%items(i)%qty, json_IK))
        call add_i64(core, item, "price_minor", fx%document%items(i)%price_minor)
      end do
    case (kind_telemetry)
      call core%add(node, "source", text_of(fx%telemetry%source, fx%telemetry%source_n))
      call add_i64(core, node, "ts", fx%telemetry%ts)
      call core%create_array(tags, "tags")
      call core%add(node, tags)
      do i = 1, fx%telemetry%tag_count
        call core%add(tags, "", text_of(fx%telemetry%tags(i), fx%telemetry%tag_n(i)))
      end do
      call core%create_array(values, "values")
      call core%add(node, values)
      do i = 1, fx%telemetry%value_count
        call core%add(values, "", real(fx%telemetry%values(i), json_RK))
      end do
    case (kind_strings)
      call core%create_array(items, "items")
      call core%add(node, items)
      do i = 1, fx%strings%count
        call core%add(items, "", text_of(fx%strings%items(i), fx%strings%item_n(i)))
      end do
    case (kind_event)
      call core%add(node, "event_id", text_of(fx%event%event_id, fx%event%event_id_n))
      call core%add(node, "event_type", text_of(fx%event%event_type, fx%event%event_type_n))
      call add_i64(core, node, "occurred_at", fx%event%occurred_at)
      call core%add(node, "producer", text_of(fx%event%producer, fx%event%producer_n))
      call core%create_array(attrs, "attrs")
      call core%add(node, attrs)
      do i = 1, fx%event%attr_count
        call core%create_object(item, "")
        call core%add(attrs, item)
        call core%add(item, "key", text_of(fx%event%attrs(i)%key, fx%event%attrs(i)%key_n))
        call core%add(item, "value", text_of(fx%event%attrs(i)%value, fx%event%attrs(i)%value_n))
      end do
    case default
      stat = 1
    end select
    if (core%failed()) stat = 1
  end subroutine

  subroutine read_record(core, node, fx, stat)
    type(json_core), intent(inout) :: core
    type(json_value), pointer, intent(in) :: node
    type(fixture_t), intent(out) :: fx
    integer, intent(out) :: stat
    type(json_value), pointer :: meta, items, item, tags, values, attrs
    logical :: found, b
    integer :: i, n
    integer(json_IK) :: ik, nk
    real(json_RK) :: rk
    character(len=:), allocatable :: s
    stat = 0
    call core%get(node, "kind", ik, found)
    if (.not. found) then
      stat = 1
      return
    end if
    fx%kind_id = int(ik)
    select case (fx%kind_id)
    case (kind_message)
      call core%get(node, "f_bool", b, found)
      if (.not. found) then
        stat = 1
        return
      end if
      fx%message%f_bool = b
      call core%get(node, "f_int32", ik, found)
      if (.not. found) then
        stat = 1
        return
      end if
      fx%message%f_int32 = int(ik, int32)
      fx%message%f_int64 = get_i64(core, node, "f_int64", stat)
      if (stat /= 0) return
      call core%get(node, "f_float64", rk, found)
      if (.not. found) then
        stat = 1
        return
      end if
      fx%message%f_float64 = real(rk, real64)
      call core%get(node, "f_string", s, found)
      if (.not. found) then
        stat = 1
        return
      end if
      call store_text(fx%message%f_string, fx%message%f_string_n, s)
      call core%get(node, "f_bool_2", b, found)
      if (.not. found) then
        stat = 1
        return
      end if
      fx%message%f_bool_2 = b
      call core%get(node, "f_int32_2", ik, found)
      if (.not. found) then
        stat = 1
        return
      end if
      fx%message%f_int32_2 = int(ik, int32)
      call core%get(node, "f_string_2", s, found)
      if (.not. found) then
        stat = 1
        return
      end if
      call store_text(fx%message%f_string_2, fx%message%f_string_2_n, s)
    case (kind_document)
      call core%get(node, "id", s, found)
      if (.not. found) then
        stat = 1
        return
      end if
      call store_text(fx%document%id, fx%document%id_n, s)
      call core%get(node, "status", ik, found)
      if (.not. found) then
        stat = 1
        return
      end if
      fx%document%status = int(ik, int32)
      call core%get(node, "meta", meta, found)
      if (.not. found) then
        stat = 1
        return
      end if
      call core%get(meta, "region", s, found)
      if (.not. found) then
        stat = 1
        return
      end if
      call store_text(fx%document%region, fx%document%region_n, s)
      call core%get(meta, "version", ik, found)
      if (.not. found) then
        stat = 1
        return
      end if
      fx%document%version = int(ik, int32)
      call core%get(node, "items", items, found)
      if (.not. found) then
        stat = 1
        return
      end if
      call core%info(items, n_children=nk)
      n = int(nk)
      if (n < 0 .or. n > v2_max_children) then
        stat = 1
        return
      end if
      fx%document%item_count = n
      do i = 1, n
        call core%get_child(items, int(i, json_IK), item, found)
        if (.not. found) then
          stat = 1
          return
        end if
        call core%get(item, "sku", s, found)
        if (.not. found) then
          stat = 1
          return
        end if
        call store_text(fx%document%items(i)%sku, fx%document%items(i)%sku_n, s)
        call core%get(item, "qty", ik, found)
        if (.not. found) then
          stat = 1
          return
        end if
        fx%document%items(i)%qty = int(ik, int32)
        fx%document%items(i)%price_minor = get_i64(core, item, "price_minor", stat)
        if (stat /= 0) return
      end do
    case (kind_telemetry)
      call core%get(node, "source", s, found)
      if (.not. found) then
        stat = 1
        return
      end if
      call store_text(fx%telemetry%source, fx%telemetry%source_n, s)
      fx%telemetry%ts = get_i64(core, node, "ts", stat)
      if (stat /= 0) return
      call core%get(node, "tags", tags, found)
      if (.not. found) then
        stat = 1
        return
      end if
      call core%info(tags, n_children=nk)
      n = int(nk)
      if (n < 0 .or. n > v2_max_tags) then
        stat = 1
        return
      end if
      fx%telemetry%tag_count = n
      do i = 1, n
        call core%get_child(tags, int(i, json_IK), item, found)
        if (.not. found) then
          stat = 1
          return
        end if
        call core%get(item, s)
        if (core%failed() .or. .not. allocated(s)) then
          stat = 1
          return
        end if
        call store_text(fx%telemetry%tags(i), fx%telemetry%tag_n(i), s)
      end do
      call core%get(node, "values", values, found)
      if (.not. found) then
        stat = 1
        return
      end if
      call core%info(values, n_children=nk)
      n = int(nk)
      if (n < 0 .or. n > v2_max_points) then
        stat = 1
        return
      end if
      fx%telemetry%value_count = n
      do i = 1, n
        call core%get_child(values, int(i, json_IK), item, found)
        if (.not. found) then
          stat = 1
          return
        end if
        call core%get(item, rk)
        if (core%failed()) then
          stat = 1
          return
        end if
        fx%telemetry%values(i) = real(rk, real64)
      end do
    case (kind_strings)
      call core%get(node, "items", items, found)
      if (.not. found) then
        stat = 1
        return
      end if
      call core%info(items, n_children=nk)
      n = int(nk)
      if (n < 0 .or. n > v2_max_strings) then
        stat = 1
        return
      end if
      fx%strings%count = n
      do i = 1, n
        call core%get_child(items, int(i, json_IK), item, found)
        if (.not. found) then
          stat = 1
          return
        end if
        call core%get(item, s)
        if (core%failed() .or. .not. allocated(s)) then
          stat = 1
          return
        end if
        call store_text(fx%strings%items(i), fx%strings%item_n(i), s)
      end do
    case (kind_event)
      call core%get(node, "event_id", s, found)
      if (.not. found) then
        stat = 1
        return
      end if
      call store_text(fx%event%event_id, fx%event%event_id_n, s)
      call core%get(node, "event_type", s, found)
      if (.not. found) then
        stat = 1
        return
      end if
      call store_text(fx%event%event_type, fx%event%event_type_n, s)
      fx%event%occurred_at = get_i64(core, node, "occurred_at", stat)
      if (stat /= 0) return
      call core%get(node, "producer", s, found)
      if (.not. found) then
        stat = 1
        return
      end if
      call store_text(fx%event%producer, fx%event%producer_n, s)
      call core%get(node, "attrs", attrs, found)
      if (.not. found) then
        stat = 1
        return
      end if
      call core%info(attrs, n_children=nk)
      n = int(nk)
      if (n < 0 .or. n > v2_max_attrs) then
        stat = 1
        return
      end if
      fx%event%attr_count = n
      do i = 1, n
        call core%get_child(attrs, int(i, json_IK), item, found)
        if (.not. found) then
          stat = 1
          return
        end if
        call core%get(item, "key", s, found)
        if (.not. found) then
          stat = 1
          return
        end if
        call store_text(fx%event%attrs(i)%key, fx%event%attrs(i)%key_n, s)
        call core%get(item, "value", s, found)
        if (.not. found) then
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
