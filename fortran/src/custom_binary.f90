module custom_binary
  use, intrinsic :: iso_fortran_env, only: int8, int32, int64, real64
  use bench_data
  implicit none
  private
  public :: cb_name, cb_version, cb_serialize, cb_deserialize

  character(len=*), parameter :: cb_name = "custom-binary"
  character(len=*), parameter :: cb_version = "v2-1.0"

contains

  function as_i32(bits) result(v)
    integer(int64), intent(in) :: bits
    integer(int32) :: v
    integer(int64) :: x
    x = iand(bits, int(z'FFFFFFFF', int64))
    if (btest(x, 31)) x = ior(x, shiftl(-1_int64, 32))
    v = int(x, int32)
  end function

  function u8_of(b) result(u)
    integer(int8), intent(in) :: b
    integer :: u
    u = iand(int(b, int32), 255)
  end function

  subroutine put_u8(buf, pos, v, stat)
    integer(int8), intent(inout) :: buf(:)
    integer, intent(inout) :: pos
    integer, intent(in) :: v
    integer, intent(out) :: stat
    if (pos > size(buf)) then
      stat = 1
      return
    end if
    buf(pos) = int(iand(v, 255), int8)
    pos = pos + 1
    stat = 0
  end subroutine

  subroutine get_u8(buf, nbytes, pos, v, stat)
    integer(int8), intent(in) :: buf(:)
    integer, intent(in) :: nbytes
    integer, intent(inout) :: pos
    integer, intent(out) :: v
    integer, intent(out) :: stat
    if (pos > nbytes .or. pos > size(buf)) then
      stat = 1
      return
    end if
    v = u8_of(buf(pos))
    pos = pos + 1
    stat = 0
  end subroutine

  subroutine put_int(buf, pos, bits, nbytes, stat)
    integer(int8), intent(inout) :: buf(:)
    integer, intent(inout) :: pos
    integer(int64), intent(in) :: bits
    integer, intent(in) :: nbytes
    integer, intent(out) :: stat
    integer :: i, st
    stat = 0
    do i = 0, nbytes - 1
      call put_u8(buf, pos, int(ibits(bits, 8 * i, 8)), st)
      if (st /= 0) then
        stat = st
        return
      end if
    end do
  end subroutine

  subroutine get_int(buf, nbytes, pos, nbits, bits, stat)
    integer(int8), intent(in) :: buf(:)
    integer, intent(in) :: nbytes, nbits
    integer, intent(inout) :: pos
    integer(int64), intent(out) :: bits
    integer, intent(out) :: stat
    integer :: i, b, st
    bits = 0_int64
    stat = 0
    do i = 0, nbits - 1
      call get_u8(buf, nbytes, pos, b, st)
      if (st /= 0) then
        stat = st
        return
      end if
      bits = ior(bits, shiftl(int(b, int64), 8 * i))
    end do
  end subroutine

  subroutine put_text(buf, pos, text, n, stat)
    integer(int8), intent(inout) :: buf(:)
    integer, intent(inout) :: pos
    character(len=*), intent(in) :: text
    integer, intent(in) :: n
    integer, intent(out) :: stat
    integer :: i, st
    call put_int(buf, pos, int(n, int64), 2, stat)
    if (stat /= 0) return
    do i = 1, n
      call put_u8(buf, pos, ichar(text(i:i)), st)
      if (st /= 0) then
        stat = st
        return
      end if
    end do
  end subroutine

  subroutine get_text(buf, nbytes, pos, text, n, stat)
    integer(int8), intent(in) :: buf(:)
    integer, intent(in) :: nbytes
    integer, intent(inout) :: pos
    character(len=*), intent(out) :: text
    integer, intent(out) :: n
    integer, intent(out) :: stat
    integer(int64) :: bits
    integer :: i, b, st
    text = ""
    call get_int(buf, nbytes, pos, 2, bits, stat)
    if (stat /= 0) return
    n = int(bits)
    if (n < 0 .or. n > len(text)) then
      stat = 1
      return
    end if
    do i = 1, n
      call get_u8(buf, nbytes, pos, b, st)
      if (st /= 0) then
        stat = st
        return
      end if
      text(i:i) = achar(b)
    end do
  end subroutine

  subroutine put_f64(buf, pos, v, stat)
    integer(int8), intent(inout) :: buf(:)
    integer, intent(inout) :: pos
    real(real64), intent(in) :: v
    integer, intent(out) :: stat
    integer(int64) :: bits
    bits = transfer(v, bits)
    call put_int(buf, pos, bits, 8, stat)
  end subroutine

  subroutine get_f64(buf, nbytes, pos, v, stat)
    integer(int8), intent(in) :: buf(:)
    integer, intent(in) :: nbytes
    integer, intent(inout) :: pos
    real(real64), intent(out) :: v
    integer, intent(out) :: stat
    integer(int64) :: bits
    call get_int(buf, nbytes, pos, 8, bits, stat)
    if (stat /= 0) return
    v = transfer(bits, v)
  end subroutine

  subroutine put_record(buf, pos, fx, stat)
    integer(int8), intent(inout) :: buf(:)
    integer, intent(inout) :: pos
    type(fixture_t), intent(in) :: fx
    integer, intent(out) :: stat
    integer :: i
    call put_u8(buf, pos, fx%kind_id, stat)
    if (stat /= 0) return
    select case (fx%kind_id)
    case (kind_message)
      call put_u8(buf, pos, merge(1, 0, fx%message%f_bool), stat)
      if (stat /= 0) return
      call put_int(buf, pos, int(fx%message%f_int32, int64), 4, stat)
      if (stat /= 0) return
      call put_int(buf, pos, fx%message%f_int64, 8, stat)
      if (stat /= 0) return
      call put_f64(buf, pos, fx%message%f_float64, stat)
      if (stat /= 0) return
      call put_text(buf, pos, fx%message%f_string, fx%message%f_string_n, stat)
      if (stat /= 0) return
      call put_u8(buf, pos, merge(1, 0, fx%message%f_bool_2), stat)
      if (stat /= 0) return
      call put_int(buf, pos, int(fx%message%f_int32_2, int64), 4, stat)
      if (stat /= 0) return
      call put_text(buf, pos, fx%message%f_string_2, fx%message%f_string_2_n, stat)
    case (kind_document)
      call put_text(buf, pos, fx%document%id, fx%document%id_n, stat)
      if (stat /= 0) return
      call put_int(buf, pos, int(fx%document%status, int64), 4, stat)
      if (stat /= 0) return
      call put_text(buf, pos, fx%document%region, fx%document%region_n, stat)
      if (stat /= 0) return
      call put_int(buf, pos, int(fx%document%version, int64), 4, stat)
      if (stat /= 0) return
      call put_int(buf, pos, int(fx%document%item_count, int64), 4, stat)
      if (stat /= 0) return
      do i = 1, fx%document%item_count
        call put_text(buf, pos, fx%document%items(i)%sku, fx%document%items(i)%sku_n, stat)
        if (stat /= 0) return
        call put_int(buf, pos, int(fx%document%items(i)%qty, int64), 4, stat)
        if (stat /= 0) return
        call put_int(buf, pos, fx%document%items(i)%price_minor, 8, stat)
        if (stat /= 0) return
      end do
    case (kind_telemetry)
      call put_text(buf, pos, fx%telemetry%source, fx%telemetry%source_n, stat)
      if (stat /= 0) return
      call put_int(buf, pos, fx%telemetry%ts, 8, stat)
      if (stat /= 0) return
      call put_int(buf, pos, int(fx%telemetry%tag_count, int64), 4, stat)
      if (stat /= 0) return
      do i = 1, fx%telemetry%tag_count
        call put_text(buf, pos, fx%telemetry%tags(i), fx%telemetry%tag_n(i), stat)
        if (stat /= 0) return
      end do
      call put_int(buf, pos, int(fx%telemetry%value_count, int64), 4, stat)
      if (stat /= 0) return
      do i = 1, fx%telemetry%value_count
        call put_f64(buf, pos, fx%telemetry%values(i), stat)
        if (stat /= 0) return
      end do
    case (kind_strings)
      call put_int(buf, pos, int(fx%strings%count, int64), 4, stat)
      if (stat /= 0) return
      do i = 1, fx%strings%count
        call put_text(buf, pos, fx%strings%items(i), fx%strings%item_n(i), stat)
        if (stat /= 0) return
      end do
    case (kind_event)
      call put_text(buf, pos, fx%event%event_id, fx%event%event_id_n, stat)
      if (stat /= 0) return
      call put_text(buf, pos, fx%event%event_type, fx%event%event_type_n, stat)
      if (stat /= 0) return
      call put_int(buf, pos, fx%event%occurred_at, 8, stat)
      if (stat /= 0) return
      call put_text(buf, pos, fx%event%producer, fx%event%producer_n, stat)
      if (stat /= 0) return
      call put_int(buf, pos, int(fx%event%attr_count, int64), 4, stat)
      if (stat /= 0) return
      do i = 1, fx%event%attr_count
        call put_text(buf, pos, fx%event%attrs(i)%key, fx%event%attrs(i)%key_n, stat)
        if (stat /= 0) return
        call put_text(buf, pos, fx%event%attrs(i)%value, fx%event%attrs(i)%value_n, stat)
        if (stat /= 0) return
      end do
    case default
      stat = 1
    end select
  end subroutine

  subroutine get_record(buf, nbytes, pos, fx, stat)
    integer(int8), intent(in) :: buf(:)
    integer, intent(in) :: nbytes
    integer, intent(inout) :: pos
    type(fixture_t), intent(out) :: fx
    integer, intent(out) :: stat
    integer :: kind_id, flag, i
    integer(int64) :: bits
    call get_u8(buf, nbytes, pos, kind_id, stat)
    if (stat /= 0) return
    fx%kind_id = kind_id
    select case (kind_id)
    case (kind_message)
      call get_u8(buf, nbytes, pos, flag, stat)
      if (stat /= 0) return
      fx%message%f_bool = flag /= 0
      call get_int(buf, nbytes, pos, 4, bits, stat)
      if (stat /= 0) return
      fx%message%f_int32 = as_i32(bits)
      call get_int(buf, nbytes, pos, 8, fx%message%f_int64, stat)
      if (stat /= 0) return
      call get_f64(buf, nbytes, pos, fx%message%f_float64, stat)
      if (stat /= 0) return
      call get_text(buf, nbytes, pos, fx%message%f_string, fx%message%f_string_n, stat)
      if (stat /= 0) return
      call get_u8(buf, nbytes, pos, flag, stat)
      if (stat /= 0) return
      fx%message%f_bool_2 = flag /= 0
      call get_int(buf, nbytes, pos, 4, bits, stat)
      if (stat /= 0) return
      fx%message%f_int32_2 = as_i32(bits)
      call get_text(buf, nbytes, pos, fx%message%f_string_2, fx%message%f_string_2_n, stat)
    case (kind_document)
      call get_text(buf, nbytes, pos, fx%document%id, fx%document%id_n, stat)
      if (stat /= 0) return
      call get_int(buf, nbytes, pos, 4, bits, stat)
      if (stat /= 0) return
      fx%document%status = as_i32(bits)
      call get_text(buf, nbytes, pos, fx%document%region, fx%document%region_n, stat)
      if (stat /= 0) return
      call get_int(buf, nbytes, pos, 4, bits, stat)
      if (stat /= 0) return
      fx%document%version = as_i32(bits)
      call get_int(buf, nbytes, pos, 4, bits, stat)
      if (stat /= 0) return
      fx%document%item_count = int(bits)
      if (fx%document%item_count < 0 .or. fx%document%item_count > v2_max_children) then
        stat = 1
        return
      end if
      do i = 1, fx%document%item_count
        call get_text(buf, nbytes, pos, fx%document%items(i)%sku, fx%document%items(i)%sku_n, stat)
        if (stat /= 0) return
        call get_int(buf, nbytes, pos, 4, bits, stat)
        if (stat /= 0) return
        fx%document%items(i)%qty = as_i32(bits)
        call get_int(buf, nbytes, pos, 8, fx%document%items(i)%price_minor, stat)
        if (stat /= 0) return
      end do
    case (kind_telemetry)
      call get_text(buf, nbytes, pos, fx%telemetry%source, fx%telemetry%source_n, stat)
      if (stat /= 0) return
      call get_int(buf, nbytes, pos, 8, fx%telemetry%ts, stat)
      if (stat /= 0) return
      call get_int(buf, nbytes, pos, 4, bits, stat)
      if (stat /= 0) return
      fx%telemetry%tag_count = int(bits)
      if (fx%telemetry%tag_count < 0 .or. fx%telemetry%tag_count > v2_max_tags) then
        stat = 1
        return
      end if
      do i = 1, fx%telemetry%tag_count
        call get_text(buf, nbytes, pos, fx%telemetry%tags(i), fx%telemetry%tag_n(i), stat)
        if (stat /= 0) return
      end do
      call get_int(buf, nbytes, pos, 4, bits, stat)
      if (stat /= 0) return
      fx%telemetry%value_count = int(bits)
      if (fx%telemetry%value_count < 0 .or. fx%telemetry%value_count > v2_max_points) then
        stat = 1
        return
      end if
      do i = 1, fx%telemetry%value_count
        call get_f64(buf, nbytes, pos, fx%telemetry%values(i), stat)
        if (stat /= 0) return
      end do
    case (kind_strings)
      call get_int(buf, nbytes, pos, 4, bits, stat)
      if (stat /= 0) return
      fx%strings%count = int(bits)
      if (fx%strings%count < 0 .or. fx%strings%count > v2_max_strings) then
        stat = 1
        return
      end if
      do i = 1, fx%strings%count
        call get_text(buf, nbytes, pos, fx%strings%items(i), fx%strings%item_n(i), stat)
        if (stat /= 0) return
      end do
    case (kind_event)
      call get_text(buf, nbytes, pos, fx%event%event_id, fx%event%event_id_n, stat)
      if (stat /= 0) return
      call get_text(buf, nbytes, pos, fx%event%event_type, fx%event%event_type_n, stat)
      if (stat /= 0) return
      call get_int(buf, nbytes, pos, 8, fx%event%occurred_at, stat)
      if (stat /= 0) return
      call get_text(buf, nbytes, pos, fx%event%producer, fx%event%producer_n, stat)
      if (stat /= 0) return
      call get_int(buf, nbytes, pos, 4, bits, stat)
      if (stat /= 0) return
      fx%event%attr_count = int(bits)
      if (fx%event%attr_count < 0 .or. fx%event%attr_count > v2_max_attrs) then
        stat = 1
        return
      end if
      do i = 1, fx%event%attr_count
        call get_text(buf, nbytes, pos, fx%event%attrs(i)%key, fx%event%attrs(i)%key_n, stat)
        if (stat /= 0) return
        call get_text(buf, nbytes, pos, fx%event%attrs(i)%value, fx%event%attrs(i)%value_n, stat)
        if (stat /= 0) return
      end do
    case default
      stat = 1
    end select
  end subroutine

  subroutine cb_serialize(items, buf, out_len, stat)
    type(fixture_t), intent(in) :: items(:)
    integer(int8), intent(out) :: buf(:)
    integer, intent(out) :: out_len, stat
    integer :: pos, i, n
    pos = 1
    n = size(items)
    if (n > 1) then
      call put_int(buf, pos, int(n, int64), 4, stat)
      if (stat /= 0) return
    end if
    do i = 1, n
      call put_record(buf, pos, items(i), stat)
      if (stat /= 0) return
    end do
    out_len = pos - 1
  end subroutine

  subroutine cb_deserialize(buf, nbytes, expected_n, items, stat)
    integer(int8), intent(in) :: buf(:)
    integer, intent(in) :: nbytes, expected_n
    type(fixture_t), allocatable, intent(out) :: items(:)
    integer, intent(out) :: stat
    integer :: pos, i, n
    integer(int64) :: bits
    pos = 1
    n = expected_n
    if (n < 1) n = 1
    if (n > 1) then
      call get_int(buf, nbytes, pos, 4, bits, stat)
      if (stat /= 0) return
      if (int(bits) /= n) then
        stat = 1
        return
      end if
    end if
    allocate(items(n))
    do i = 1, n
      call get_record(buf, nbytes, pos, items(i), stat)
      if (stat /= 0) return
    end do
  end subroutine

end module
