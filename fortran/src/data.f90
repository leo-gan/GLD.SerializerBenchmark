module bench_data
  use, intrinsic :: iso_fortran_env, only: int8, int32, int64, real64
  implicit none
  private
  public :: fixture_t, message_t, document_t, telemetry_t, strings_t, event_t
  public :: kind_message, kind_document, kind_telemetry, kind_strings, kind_event
  public :: kind_grid, kind_grid_window
  public :: v2_str, v2_max_children, v2_max_points, v2_max_strings, v2_max_tags, v2_max_attrs
  public :: kind_from_name, make_one, make_grid, grid_equal, fixtures_equal, f64_close, text_of, store_text

  integer, parameter :: wide_k = selected_int_kind(38)
  integer, parameter :: v2_str = 48
  integer, parameter :: v2_max_children = 16
  integer, parameter :: v2_max_points = 512
  integer, parameter :: v2_max_strings = 64
  integer, parameter :: v2_max_tags = 8
  integer, parameter :: v2_max_attrs = 16
  integer, parameter :: kind_message = 0
  integer, parameter :: kind_document = 1
  integer, parameter :: kind_telemetry = 2
  integer, parameter :: kind_strings = 3
  integer, parameter :: kind_event = 4
  integer, parameter :: kind_grid = 5
  integer, parameter :: kind_grid_window = 6
  integer(int64), parameter :: base_ts_ms = 1704067200000_int64
  integer(int64), parameter :: golden = int(z'9E3779B97F4A7C15', int64)
  integer(int64), parameter :: fnv_prime = int(z'100000001B3', int64)

  type :: message_t
    logical :: f_bool = .false.
    integer(int32) :: f_int32 = 0
    integer(int64) :: f_int64 = 0
    real(real64) :: f_float64 = 0
    integer :: f_string_n = 0
    character(len=v2_str) :: f_string = ""
    logical :: f_bool_2 = .false.
    integer(int32) :: f_int32_2 = 0
    integer :: f_string_2_n = 0
    character(len=v2_str) :: f_string_2 = ""
  end type

  type :: document_item_t
    integer :: sku_n = 0
    character(len=v2_str) :: sku = ""
    integer(int32) :: qty = 0
    integer(int64) :: price_minor = 0
  end type

  type :: document_t
    integer :: id_n = 0
    character(len=v2_str) :: id = ""
    integer(int32) :: status = 0
    integer :: region_n = 0
    character(len=v2_str) :: region = ""
    integer(int32) :: version = 0
    integer :: item_count = 0
    type(document_item_t) :: items(v2_max_children)
  end type

  type :: telemetry_t
    integer :: source_n = 0
    character(len=v2_str) :: source = ""
    integer(int64) :: ts = 0
    integer :: tag_count = 0
    integer :: tag_n(v2_max_tags) = 0
    character(len=v2_str) :: tags(v2_max_tags) = ""
    integer :: value_count = 0
    real(real64) :: values(v2_max_points) = 0
  end type

  type :: strings_t
    integer :: count = 0
    integer :: item_n(v2_max_strings) = 0
    character(len=v2_str) :: items(v2_max_strings) = ""
  end type

  type :: event_attr_t
    integer :: key_n = 0
    character(len=v2_str) :: key = ""
    integer :: value_n = 0
    character(len=v2_str) :: value = ""
  end type

  type :: event_t
    integer :: event_id_n = 0
    character(len=v2_str) :: event_id = ""
    integer :: event_type_n = 0
    character(len=v2_str) :: event_type = ""
    integer(int64) :: occurred_at = 0
    integer :: producer_n = 0
    character(len=v2_str) :: producer = ""
    integer :: attr_count = 0
    type(event_attr_t) :: attrs(v2_max_attrs)
  end type

  type :: fixture_t
    integer :: kind_id = kind_message
    type(message_t) :: message
    type(document_t) :: document
    type(telemetry_t) :: telemetry
    type(strings_t) :: strings
    type(event_t) :: event
  end type

contains

  function text_of(s, n) result(t)
    character(len=*), intent(in) :: s
    integer, intent(in) :: n
    character(len=:), allocatable :: t
    integer :: m
    m = n
    if (m < 0) m = 0
    if (m > len(s)) m = len(s)
    if (m == 0) then
      t = ""
    else
      t = s(1:m)
    end if
  end function

  subroutine store_text(dst, n, raw)
    character(len=*), intent(out) :: dst
    integer, intent(out) :: n
    character(len=*), intent(in) :: raw
    n = min(len(raw), len(dst))
    dst = ""
    if (n > 0) dst(1:n) = raw(1:n)
  end subroutine

  function kind_from_name(name) result(kind_id)
    character(len=*), intent(in) :: name
    integer :: kind_id
    select case (trim(name))
    case ("message")
      kind_id = kind_message
    case ("document")
      kind_id = kind_document
    case ("telemetry")
      kind_id = kind_telemetry
    case ("strings")
      kind_id = kind_strings
    case ("event")
      kind_id = kind_event
    case ("grid")
      kind_id = kind_grid
    case ("grid_window")
      kind_id = kind_grid_window
    case default
      kind_id = -1
    end select
  end function

  subroutine make_grid(values, seed, kind_id, instance_index)
    ! y outer, x inner. values(x, y) matches catalog coordinate (x-1, y-1).
    real(real64), intent(out) :: values(:, :)
    integer(int64), intent(in) :: seed
    integer, intent(in) :: kind_id, instance_index
    integer :: ix, iy, nx, ny
    integer(int64) :: state
    nx = size(values, 1)
    ny = size(values, 2)
    state = mix_seed(seed, kind_id, instance_index)
    if (state == 0_int64) state = golden
    do iy = 1, ny
      do ix = 1, nx
        values(ix, iy) = rng_f64(state)
      end do
    end do
  end subroutine

  function grid_equal(a, b) result(ok)
    real(real64), intent(in) :: a(:, :), b(:, :)
    logical :: ok
    ok = size(a, 1) == size(b, 1) .and. size(a, 2) == size(b, 2)
    if (.not. ok) return
    ok = all(a == b)
  end function

  function u64_mod(bits, modulus) result(r)
    integer(int64), intent(in) :: bits, modulus
    integer(int64) :: r
    integer(wide_k) :: wide
    wide = bits
    if (bits < 0_int64) wide = wide + 2_wide_k**64
    r = int(mod(wide, int(modulus, wide_k)), int64)
  end function

  function rng_u64(state) result(x)
    integer(int64), intent(inout) :: state
    integer(int64) :: x
    x = state
    x = ieor(x, shiftl(x, 13))
    x = ieor(x, shiftr(x, 7))
    x = ieor(x, shiftl(x, 17))
    state = x
  end function

  function rng_int(state, lo, hi) result(v)
    integer(int64), intent(inout) :: state
    integer, intent(in) :: lo, hi
    integer :: v
    integer(int64) :: span
    if (hi <= lo) then
      v = lo
      return
    end if
    span = int(hi, int64) - int(lo, int64) + 1_int64
    v = lo + int(u64_mod(rng_u64(state), span))
  end function

  function rng_bool(state) result(v)
    integer(int64), intent(inout) :: state
    logical :: v
    v = iand(rng_u64(state), 1_int64) /= 0_int64
  end function

  function rng_f64(state) result(v)
    integer(int64), intent(inout) :: state
    real(real64) :: v
    integer(int64) :: bits
    bits = shiftr(rng_u64(state), 11)
    v = real(bits, real64) / real(2_int64**53, real64)
  end function

  subroutine rng_word(state, dst, n, min_l, max_l)
    integer(int64), intent(inout) :: state
    character(len=*), intent(out) :: dst
    integer, intent(out) :: n
    integer, intent(in) :: min_l, max_l
    character(len=*), parameter :: alphabet = "abcdefghijklmnopqrstuvwxyz"
    integer :: i, k, cap
    cap = len(dst)
    n = rng_int(state, min_l, max_l)
    if (n < 0) n = 0
    if (n > cap) n = cap
    dst = ""
    do i = 1, n
      k = 1 + int(u64_mod(rng_u64(state), 26_int64))
      dst(i:i) = alphabet(k:k)
    end do
  end subroutine

  function mix_seed(seed, kind_id, idx) result(h)
    integer(int64), intent(in) :: seed
    integer, intent(in) :: kind_id, idx
    integer(int64) :: h
    h = ieor(seed, golden * int(kind_id, int64))
    h = ieor(h, fnv_prime * int(idx, int64))
    if (h == 0_int64) h = 1_int64
  end function

  function clamp_count(v, limit) result(n)
    integer, intent(in) :: v, limit
    integer :: n
    n = v
    if (n < 0) n = 0
    if (n > limit) n = limit
  end function

  subroutine make_one(fx, kind_id, seed, instance_index, children, points, str_count, attr_count, tag_count)
    type(fixture_t), intent(out) :: fx
    integer, intent(in) :: kind_id, instance_index, children, points, str_count, attr_count, tag_count
    integer(int64), intent(in) :: seed
    integer(int64) :: state
    integer :: i, nchild, npoints, nstr, nattr, ntags
    state = mix_seed(seed, kind_id, instance_index)
    if (state == 0_int64) state = golden
    fx%kind_id = kind_id
    nchild = clamp_count(children, v2_max_children)
    npoints = clamp_count(points, v2_max_points)
    nstr = clamp_count(str_count, v2_max_strings)
    nattr = clamp_count(attr_count, v2_max_attrs)
    ntags = clamp_count(tag_count, v2_max_tags)

    select case (kind_id)
    case (kind_message)
      fx%message%f_bool = rng_bool(state)
      fx%message%f_int32 = int(rng_int(state, 0, 1000000), int32)
      fx%message%f_int64 = int(rng_int(state, 0, 1000000), int64)
      fx%message%f_float64 = rng_f64(state) * 1000.0_real64
      call rng_word(state, fx%message%f_string, fx%message%f_string_n, 3, 16)
      fx%message%f_bool_2 = rng_bool(state)
      fx%message%f_int32_2 = int(rng_int(state, 0, 1000000), int32)
      call rng_word(state, fx%message%f_string_2, fx%message%f_string_2_n, 3, 16)
    case (kind_document)
      call rng_word(state, fx%document%id, fx%document%id_n, 8, 12)
      fx%document%status = int(rng_int(state, 0, 5), int32)
      call rng_word(state, fx%document%region, fx%document%region_n, 2, 4)
      fx%document%version = int(rng_int(state, 1, 10), int32)
      fx%document%item_count = nchild
      do i = 1, nchild
        call rng_word(state, fx%document%items(i)%sku, fx%document%items(i)%sku_n, 3, 12)
        fx%document%items(i)%qty = int(rng_int(state, 1, 100), int32)
        fx%document%items(i)%price_minor = int(rng_int(state, 0, 100000), int64)
      end do
    case (kind_telemetry)
      call rng_word(state, fx%telemetry%source, fx%telemetry%source_n, 3, 10)
      fx%telemetry%ts = base_ts_ms + int(rng_int(state, 0, 86400000), int64)
      fx%telemetry%tag_count = ntags
      do i = 1, ntags
        call rng_word(state, fx%telemetry%tags(i), fx%telemetry%tag_n(i), 3, 10)
      end do
      fx%telemetry%value_count = npoints
      do i = 1, npoints
        fx%telemetry%values(i) = rng_f64(state) * 100.0_real64
      end do
    case (kind_strings)
      fx%strings%count = nstr
      do i = 1, nstr
        call rng_word(state, fx%strings%items(i), fx%strings%item_n(i), 3, 16)
      end do
    case (kind_event)
      call rng_word(state, fx%event%event_id, fx%event%event_id_n, 8, 12)
      call rng_word(state, fx%event%event_type, fx%event%event_type_n, 3, 12)
      fx%event%occurred_at = base_ts_ms + int(rng_int(state, 0, 86400000), int64)
      call rng_word(state, fx%event%producer, fx%event%producer_n, 3, 12)
      fx%event%attr_count = nattr
      do i = 1, nattr
        call rng_word(state, fx%event%attrs(i)%key, fx%event%attrs(i)%key_n, 3, 12)
        call rng_word(state, fx%event%attrs(i)%value, fx%event%attrs(i)%value_n, 3, 12)
      end do
    end select
  end subroutine

  function f64_close(a, b) result(ok)
    real(real64), intent(in) :: a, b
    logical :: ok
    real(real64) :: d, s
    d = abs(a - b)
    s = max(abs(a), abs(b))
    ok = d <= 1.0e-9_real64 .or. d <= 1.0e-6_real64 * (s + 1.0_real64)
  end function

  function same_text(a, an, b, bn) result(ok)
    character(len=*), intent(in) :: a, b
    integer, intent(in) :: an, bn
    logical :: ok
    ok = an == bn
    if (ok .and. an > 0) ok = a(1:an) == b(1:bn)
  end function

  function message_equal(a, b) result(ok)
    type(message_t), intent(in) :: a, b
    logical :: ok
    ! .eqv. binds looser than .and. Parentheses keep each field in the conjunction.
    ok = (a%f_bool .eqv. b%f_bool) .and. a%f_int32 == b%f_int32 .and. a%f_int64 == b%f_int64 &
         .and. f64_close(a%f_float64, b%f_float64) &
         .and. same_text(a%f_string, a%f_string_n, b%f_string, b%f_string_n) &
         .and. (a%f_bool_2 .eqv. b%f_bool_2) .and. a%f_int32_2 == b%f_int32_2 &
         .and. same_text(a%f_string_2, a%f_string_2_n, b%f_string_2, b%f_string_2_n)
  end function

  function document_equal(a, b) result(ok)
    type(document_t), intent(in) :: a, b
    logical :: ok
    integer :: i
    ok = same_text(a%id, a%id_n, b%id, b%id_n) .and. a%status == b%status &
         .and. same_text(a%region, a%region_n, b%region, b%region_n) &
         .and. a%version == b%version .and. a%item_count == b%item_count
    if (.not. ok) return
    do i = 1, a%item_count
      if (.not. same_text(a%items(i)%sku, a%items(i)%sku_n, b%items(i)%sku, b%items(i)%sku_n) &
          .or. a%items(i)%qty /= b%items(i)%qty &
          .or. a%items(i)%price_minor /= b%items(i)%price_minor) then
        ok = .false.
        return
      end if
    end do
  end function

  function telemetry_equal(a, b) result(ok)
    type(telemetry_t), intent(in) :: a, b
    logical :: ok
    integer :: i
    ok = same_text(a%source, a%source_n, b%source, b%source_n) .and. a%ts == b%ts &
         .and. a%tag_count == b%tag_count .and. a%value_count == b%value_count
    if (.not. ok) return
    do i = 1, a%tag_count
      if (.not. same_text(a%tags(i), a%tag_n(i), b%tags(i), b%tag_n(i))) then
        ok = .false.
        return
      end if
    end do
    do i = 1, a%value_count
      if (.not. f64_close(a%values(i), b%values(i))) then
        ok = .false.
        return
      end if
    end do
  end function

  function strings_equal(a, b) result(ok)
    type(strings_t), intent(in) :: a, b
    logical :: ok
    integer :: i
    ok = a%count == b%count
    if (.not. ok) return
    do i = 1, a%count
      if (.not. same_text(a%items(i), a%item_n(i), b%items(i), b%item_n(i))) then
        ok = .false.
        return
      end if
    end do
  end function

  function event_equal(a, b) result(ok)
    type(event_t), intent(in) :: a, b
    logical :: ok
    integer :: i
    ok = same_text(a%event_id, a%event_id_n, b%event_id, b%event_id_n) &
         .and. same_text(a%event_type, a%event_type_n, b%event_type, b%event_type_n) &
         .and. a%occurred_at == b%occurred_at &
         .and. same_text(a%producer, a%producer_n, b%producer, b%producer_n) &
         .and. a%attr_count == b%attr_count
    if (.not. ok) return
    do i = 1, a%attr_count
      if (.not. same_text(a%attrs(i)%key, a%attrs(i)%key_n, b%attrs(i)%key, b%attrs(i)%key_n) &
          .or. .not. same_text(a%attrs(i)%value, a%attrs(i)%value_n, b%attrs(i)%value, b%attrs(i)%value_n)) then
        ok = .false.
        return
      end if
    end do
  end function

  function fixture_equal(a, b) result(ok)
    type(fixture_t), intent(in) :: a, b
    logical :: ok
    if (a%kind_id /= b%kind_id) then
      ok = .false.
      return
    end if
    select case (a%kind_id)
    case (kind_message)
      ok = message_equal(a%message, b%message)
    case (kind_document)
      ok = document_equal(a%document, b%document)
    case (kind_telemetry)
      ok = telemetry_equal(a%telemetry, b%telemetry)
    case (kind_strings)
      ok = strings_equal(a%strings, b%strings)
    case (kind_event)
      ok = event_equal(a%event, b%event)
    case default
      ok = .false.
    end select
  end function

  function fixtures_equal(a, b) result(ok)
    type(fixture_t), intent(in) :: a(:), b(:)
    logical :: ok
    integer :: i
    ok = size(a) == size(b)
    if (.not. ok) return
    do i = 1, size(a)
      if (.not. fixture_equal(a(i), b(i))) then
        ok = .false.
        return
      end if
    end do
  end function

end module
