module ser_kiln_asm
  ! gld-kiln-asm 0.2.0: pure x86-64 Assembly Kiln Wire Format v2 codec via ISO_C_BINDING.
  ! Covers suite (single + batch) and array (grid + strided grid_window).
  use, intrinsic :: iso_fortran_env, only: int8, int32, int64, real64
  use, intrinsic :: iso_c_binding, only: c_ptr, c_null_ptr, c_loc, c_f_pointer, c_associated, &
      c_sizeof, c_int8_t, c_int16_t, c_int32_t, c_int64_t, c_size_t, c_double
  use bench_data
  implicit none
  private

  public :: kiln_asm_name, kiln_asm_version, kiln_asm_prepare
  public :: kiln_asm_serialize, kiln_asm_deserialize
  public :: kiln_asm_write_grid, kiln_asm_read_grid, kiln_asm_read_window

  character(len=*), parameter :: kiln_asm_name = "gld-kiln-asm"
  character(len=*), parameter :: kiln_asm_version = "0.2.0"

  integer(c_int32_t), parameter :: KILN_OK = 0_c_int32_t
  integer(c_int16_t), parameter :: KILN_DTYPE_F64 = 1_c_int16_t
  integer(c_int64_t), parameter :: KILN_LARGE_CAP = 268435456_c_int64_t ! 2^28

  type, bind(C) :: kiln_arena_t
    type(c_ptr) :: base = c_null_ptr
    type(c_ptr) :: cur = c_null_ptr
    type(c_ptr) :: end_ptr = c_null_ptr
  end type

  type, bind(C) :: kiln_read_opts_t
    integer(c_int64_t) :: max_count = 0
    integer(c_int64_t) :: max_bytes = 0
    integer(c_int32_t) :: max_depth = 0
    integer(c_int32_t) :: flags = 0
  end type

  type, bind(C) :: kiln_result_t
    integer(c_int64_t) :: bytes = 0
    integer(c_int64_t) :: hash = 0
  end type

  type, bind(C) :: kiln_str_t
    type(c_ptr) :: ptr = c_null_ptr
    integer(c_int64_t) :: len = 0
  end type

  type, bind(C) :: kiln_list_t
    type(c_ptr) :: items = c_null_ptr
    integer(c_int64_t) :: count = 0
  end type

  type, bind(C) :: bench_message_t
    integer(c_int8_t) :: f_bool = 0
    integer(c_int32_t) :: f_int32 = 0
    integer(c_int64_t) :: f_int64 = 0
    real(c_double) :: f_float64 = 0.0_c_double
    type(kiln_str_t) :: f_string
    integer(c_int8_t) :: f_bool_2 = 0
    integer(c_int32_t) :: f_int32_2 = 0
    type(kiln_str_t) :: f_string_2
  end type

  type, bind(C) :: bench_document_meta_t
    type(kiln_str_t) :: region
    integer(c_int32_t) :: version = 0
  end type

  type, bind(C) :: bench_document_item_t
    type(kiln_str_t) :: sku
    integer(c_int32_t) :: qty = 0
    integer(c_int64_t) :: price_minor = 0
  end type

  type, bind(C) :: bench_document_t
    type(kiln_str_t) :: id
    integer(c_int32_t) :: status = 0
    type(bench_document_meta_t) :: meta
    type(kiln_list_t) :: items
  end type

  type, bind(C) :: bench_telemetry_t
    type(kiln_str_t) :: source
    integer(c_int64_t) :: ts = 0
    type(kiln_list_t) :: tags
    type(kiln_list_t) :: values
  end type

  type, bind(C) :: bench_strings_t
    type(kiln_list_t) :: items
  end type

  type, bind(C) :: bench_event_attr_t
    type(kiln_str_t) :: key
    type(kiln_str_t) :: value
  end type

  type, bind(C) :: bench_event_t
    type(kiln_str_t) :: event_id
    type(kiln_str_t) :: event_type
    integer(c_int64_t) :: occurred_at = 0
    type(kiln_str_t) :: producer
    type(kiln_list_t) :: attrs
  end type

  type, bind(C) :: kiln_tensor_t
    type(c_ptr) :: name = c_null_ptr
    integer(c_int64_t) :: name_len = 0
    type(c_ptr) :: layout = c_null_ptr
    integer(c_int64_t) :: layout_len = 0
    type(c_ptr) :: data = c_null_ptr
    integer(c_int64_t) :: data_len = 0
    integer(c_int64_t) :: shape(8) = 0
    integer(c_int16_t) :: dtype = 0
    integer(c_int8_t) :: rank = 0
    integer(c_int8_t) :: pad0 = 0
    integer(c_int16_t) :: quant_scheme = 0
    integer(c_int16_t) :: quant_axis = -1_c_int16_t
    integer(c_int32_t) :: group_size = 0
    integer(c_int32_t) :: scale_index = -1_c_int32_t
    integer(c_int32_t) :: outer_index = -1_c_int32_t
    integer(c_int32_t) :: block_size = 0
    integer(c_int64_t) :: elem_count = 0
  end type

  type, bind(C) :: kiln_tensor_dir_t
    type(c_ptr) :: items = c_null_ptr
    integer(c_int64_t) :: count = 0
    integer(c_int64_t) :: block_length = 0
    integer(c_int32_t) :: flags = 0
    integer(c_int32_t) :: version = 0
  end type

  interface
    subroutine kiln_f_memcpy(dst, src, n) bind(C, name="kiln_f_memcpy")
      import :: c_ptr, c_size_t
      type(c_ptr), value :: dst, src
      integer(c_size_t), value :: n
    end subroutine

    subroutine kiln_f_ptr_add(base, offset, out_ptr) bind(C, name="kiln_f_ptr_add")
      import :: c_ptr, c_size_t
      type(c_ptr), value :: base
      integer(c_size_t), value :: offset
      type(c_ptr), intent(out) :: out_ptr
    end subroutine

    function kiln_asm_encode_bench_message(in_v, dst, cap, opts, res) &
        bind(C, name="kiln_asm_encode_bench_message") result(err)
      import :: c_ptr, c_size_t, c_int32_t, bench_message_t, kiln_result_t
      type(bench_message_t), intent(in) :: in_v
      type(c_ptr), value :: dst, opts
      integer(c_size_t), value :: cap
      type(kiln_result_t), intent(out) :: res
      integer(c_int32_t) :: err
    end function

    function kiln_asm_decode_bench_message(src, slen, out_v, arena, opts, res) &
        bind(C, name="kiln_asm_decode_bench_message") result(err)
      import :: c_ptr, c_size_t, c_int32_t, bench_message_t, kiln_arena_t, kiln_result_t
      type(c_ptr), value :: src, opts
      integer(c_size_t), value :: slen
      type(bench_message_t), intent(out) :: out_v
      type(kiln_arena_t), intent(inout) :: arena
      type(kiln_result_t), intent(out) :: res
      integer(c_int32_t) :: err
    end function

    function kiln_asm_encode_bench_message_batch(items, count, dst, cap, opts, res) &
        bind(C, name="kiln_asm_encode_bench_message_batch") result(err)
      import :: c_ptr, c_size_t, c_int32_t, kiln_result_t
      type(c_ptr), value :: items, dst, opts
      integer(c_size_t), value :: count, cap
      type(kiln_result_t), intent(out) :: res
      integer(c_int32_t) :: err
    end function

    function kiln_asm_decode_bench_message_batch(src, slen, out_items, out_count, arena, opts, res) &
        bind(C, name="kiln_asm_decode_bench_message_batch") result(err)
      import :: c_ptr, c_size_t, c_int32_t, kiln_arena_t, kiln_result_t
      type(c_ptr), value :: src, opts
      integer(c_size_t), value :: slen
      type(c_ptr), intent(out) :: out_items
      integer(c_size_t), intent(out) :: out_count
      type(kiln_arena_t), intent(inout) :: arena
      type(kiln_result_t), intent(out) :: res
      integer(c_int32_t) :: err
    end function

    function kiln_asm_encode_bench_document(in_v, dst, cap, opts, res) &
        bind(C, name="kiln_asm_encode_bench_document") result(err)
      import :: c_ptr, c_size_t, c_int32_t, bench_document_t, kiln_result_t
      type(bench_document_t), intent(in) :: in_v
      type(c_ptr), value :: dst, opts
      integer(c_size_t), value :: cap
      type(kiln_result_t), intent(out) :: res
      integer(c_int32_t) :: err
    end function

    function kiln_asm_decode_bench_document(src, slen, out_v, arena, opts, res) &
        bind(C, name="kiln_asm_decode_bench_document") result(err)
      import :: c_ptr, c_size_t, c_int32_t, bench_document_t, kiln_arena_t, kiln_result_t
      type(c_ptr), value :: src, opts
      integer(c_size_t), value :: slen
      type(bench_document_t), intent(out) :: out_v
      type(kiln_arena_t), intent(inout) :: arena
      type(kiln_result_t), intent(out) :: res
      integer(c_int32_t) :: err
    end function

    function kiln_asm_encode_bench_document_batch(items, count, dst, cap, opts, res) &
        bind(C, name="kiln_asm_encode_bench_document_batch") result(err)
      import :: c_ptr, c_size_t, c_int32_t, kiln_result_t
      type(c_ptr), value :: items, dst, opts
      integer(c_size_t), value :: count, cap
      type(kiln_result_t), intent(out) :: res
      integer(c_int32_t) :: err
    end function

    function kiln_asm_decode_bench_document_batch(src, slen, out_items, out_count, arena, opts, res) &
        bind(C, name="kiln_asm_decode_bench_document_batch") result(err)
      import :: c_ptr, c_size_t, c_int32_t, kiln_arena_t, kiln_result_t
      type(c_ptr), value :: src, opts
      integer(c_size_t), value :: slen
      type(c_ptr), intent(out) :: out_items
      integer(c_size_t), intent(out) :: out_count
      type(kiln_arena_t), intent(inout) :: arena
      type(kiln_result_t), intent(out) :: res
      integer(c_int32_t) :: err
    end function

    function kiln_asm_encode_bench_telemetry(in_v, dst, cap, opts, res) &
        bind(C, name="kiln_asm_encode_bench_telemetry") result(err)
      import :: c_ptr, c_size_t, c_int32_t, bench_telemetry_t, kiln_result_t
      type(bench_telemetry_t), intent(in) :: in_v
      type(c_ptr), value :: dst, opts
      integer(c_size_t), value :: cap
      type(kiln_result_t), intent(out) :: res
      integer(c_int32_t) :: err
    end function

    function kiln_asm_decode_bench_telemetry(src, slen, out_v, arena, opts, res) &
        bind(C, name="kiln_asm_decode_bench_telemetry") result(err)
      import :: c_ptr, c_size_t, c_int32_t, bench_telemetry_t, kiln_arena_t, kiln_result_t
      type(c_ptr), value :: src, opts
      integer(c_size_t), value :: slen
      type(bench_telemetry_t), intent(out) :: out_v
      type(kiln_arena_t), intent(inout) :: arena
      type(kiln_result_t), intent(out) :: res
      integer(c_int32_t) :: err
    end function

    function kiln_asm_encode_bench_telemetry_batch(items, count, dst, cap, opts, res) &
        bind(C, name="kiln_asm_encode_bench_telemetry_batch") result(err)
      import :: c_ptr, c_size_t, c_int32_t, kiln_result_t
      type(c_ptr), value :: items, dst, opts
      integer(c_size_t), value :: count, cap
      type(kiln_result_t), intent(out) :: res
      integer(c_int32_t) :: err
    end function

    function kiln_asm_decode_bench_telemetry_batch(src, slen, out_items, out_count, arena, opts, res) &
        bind(C, name="kiln_asm_decode_bench_telemetry_batch") result(err)
      import :: c_ptr, c_size_t, c_int32_t, kiln_arena_t, kiln_result_t
      type(c_ptr), value :: src, opts
      integer(c_size_t), value :: slen
      type(c_ptr), intent(out) :: out_items
      integer(c_size_t), intent(out) :: out_count
      type(kiln_arena_t), intent(inout) :: arena
      type(kiln_result_t), intent(out) :: res
      integer(c_int32_t) :: err
    end function

    function kiln_asm_encode_bench_strings(in_v, dst, cap, opts, res) &
        bind(C, name="kiln_asm_encode_bench_strings") result(err)
      import :: c_ptr, c_size_t, c_int32_t, bench_strings_t, kiln_result_t
      type(bench_strings_t), intent(in) :: in_v
      type(c_ptr), value :: dst, opts
      integer(c_size_t), value :: cap
      type(kiln_result_t), intent(out) :: res
      integer(c_int32_t) :: err
    end function

    function kiln_asm_decode_bench_strings(src, slen, out_v, arena, opts, res) &
        bind(C, name="kiln_asm_decode_bench_strings") result(err)
      import :: c_ptr, c_size_t, c_int32_t, bench_strings_t, kiln_arena_t, kiln_result_t
      type(c_ptr), value :: src, opts
      integer(c_size_t), value :: slen
      type(bench_strings_t), intent(out) :: out_v
      type(kiln_arena_t), intent(inout) :: arena
      type(kiln_result_t), intent(out) :: res
      integer(c_int32_t) :: err
    end function

    function kiln_asm_encode_bench_strings_batch(items, count, dst, cap, opts, res) &
        bind(C, name="kiln_asm_encode_bench_strings_batch") result(err)
      import :: c_ptr, c_size_t, c_int32_t, kiln_result_t
      type(c_ptr), value :: items, dst, opts
      integer(c_size_t), value :: count, cap
      type(kiln_result_t), intent(out) :: res
      integer(c_int32_t) :: err
    end function

    function kiln_asm_decode_bench_strings_batch(src, slen, out_items, out_count, arena, opts, res) &
        bind(C, name="kiln_asm_decode_bench_strings_batch") result(err)
      import :: c_ptr, c_size_t, c_int32_t, kiln_arena_t, kiln_result_t
      type(c_ptr), value :: src, opts
      integer(c_size_t), value :: slen
      type(c_ptr), intent(out) :: out_items
      integer(c_size_t), intent(out) :: out_count
      type(kiln_arena_t), intent(inout) :: arena
      type(kiln_result_t), intent(out) :: res
      integer(c_int32_t) :: err
    end function

    function kiln_asm_encode_bench_event(in_v, dst, cap, opts, res) &
        bind(C, name="kiln_asm_encode_bench_event") result(err)
      import :: c_ptr, c_size_t, c_int32_t, bench_event_t, kiln_result_t
      type(bench_event_t), intent(in) :: in_v
      type(c_ptr), value :: dst, opts
      integer(c_size_t), value :: cap
      type(kiln_result_t), intent(out) :: res
      integer(c_int32_t) :: err
    end function

    function kiln_asm_decode_bench_event(src, slen, out_v, arena, opts, res) &
        bind(C, name="kiln_asm_decode_bench_event") result(err)
      import :: c_ptr, c_size_t, c_int32_t, bench_event_t, kiln_arena_t, kiln_result_t
      type(c_ptr), value :: src, opts
      integer(c_size_t), value :: slen
      type(bench_event_t), intent(out) :: out_v
      type(kiln_arena_t), intent(inout) :: arena
      type(kiln_result_t), intent(out) :: res
      integer(c_int32_t) :: err
    end function

    function kiln_asm_encode_bench_event_batch(items, count, dst, cap, opts, res) &
        bind(C, name="kiln_asm_encode_bench_event_batch") result(err)
      import :: c_ptr, c_size_t, c_int32_t, kiln_result_t
      type(c_ptr), value :: items, dst, opts
      integer(c_size_t), value :: count, cap
      type(kiln_result_t), intent(out) :: res
      integer(c_int32_t) :: err
    end function

    function kiln_asm_decode_bench_event_batch(src, slen, out_items, out_count, arena, opts, res) &
        bind(C, name="kiln_asm_decode_bench_event_batch") result(err)
      import :: c_ptr, c_size_t, c_int32_t, kiln_arena_t, kiln_result_t
      type(c_ptr), value :: src, opts
      integer(c_size_t), value :: slen
      type(c_ptr), intent(out) :: out_items
      integer(c_size_t), intent(out) :: out_count
      type(kiln_arena_t), intent(inout) :: arena
      type(kiln_result_t), intent(out) :: res
      integer(c_int32_t) :: err
    end function

    function kiln_asm_encode_tensors(in_dir, dst, cap, opts, res) &
        bind(C, name="kiln_asm_encode_tensors") result(err)
      import :: c_ptr, c_size_t, c_int32_t, kiln_tensor_dir_t, kiln_result_t
      type(kiln_tensor_dir_t), intent(in) :: in_dir
      type(c_ptr), value :: dst, opts
      integer(c_size_t), value :: cap
      type(kiln_result_t), intent(out) :: res
      integer(c_int32_t) :: err
    end function

    function kiln_asm_decode_tensors(src, slen, out_dir, arena, opts, res) &
        bind(C, name="kiln_asm_decode_tensors") result(err)
      import :: c_ptr, c_size_t, c_int32_t, kiln_tensor_dir_t, kiln_arena_t, kiln_result_t
      type(c_ptr), value :: src, opts
      integer(c_size_t), value :: slen
      type(kiln_tensor_dir_t), intent(out) :: out_dir
      type(kiln_arena_t), intent(inout) :: arena
      type(kiln_result_t), intent(out) :: res
      integer(c_int32_t) :: err
    end function
  end interface

  ! Reusable decode bump arena & encode scratch arrays (avoid per-trial allocations).
  integer(c_int8_t), allocatable, target, save :: arena_mem(:)
  type(bench_message_t), allocatable, target, save :: msg_buf(:)
  type(bench_document_t), allocatable, target, save :: doc_buf(:)
  type(bench_document_item_t), allocatable, target, save :: doc_item_buf(:)
  type(bench_telemetry_t), allocatable, target, save :: tel_buf(:)
  type(bench_strings_t), allocatable, target, save :: strs_buf(:)
  type(kiln_str_t), allocatable, target, save :: str_pool(:)
  type(bench_event_t), allocatable, target, save :: ev_buf(:)
  type(bench_event_attr_t), allocatable, target, save :: ev_attr_buf(:)

  type(kiln_read_opts_t), target, save :: large_opts = &
      kiln_read_opts_t(KILN_LARGE_CAP, KILN_LARGE_CAP, 0_c_int32_t, 0_c_int32_t)

contains

  subroutine ensure_arena(need)
    integer(c_size_t), intent(in) :: need
    integer(c_size_t) :: cap
    cap = max(need, 4_c_size_t * 1024_c_size_t * 1024_c_size_t)
    if (.not. allocated(arena_mem)) then
      allocate(arena_mem(cap))
    else if (int(size(arena_mem), c_size_t) < cap) then
      deallocate(arena_mem)
      allocate(arena_mem(cap))
    end if
  end subroutine

  subroutine reset_arena(arena, need)
    type(kiln_arena_t), intent(out) :: arena
    integer(c_size_t), intent(in) :: need
    integer(c_size_t) :: cap
    call ensure_arena(need)
    cap = int(size(arena_mem), c_size_t)
    arena%base = c_loc(arena_mem(1))
    arena%cur = arena%base
    call kiln_f_ptr_add(arena%base, cap, arena%end_ptr)
  end subroutine

  subroutine kiln_asm_prepare(stat)
    integer, intent(out) :: stat
    type(kiln_arena_t) :: a
    type(kiln_read_opts_t) :: o
    type(kiln_result_t) :: r
    type(kiln_str_t) :: s
    type(kiln_tensor_t) :: t
    type(kiln_tensor_dir_t) :: td
    type(bench_message_t) :: m
    type(bench_document_meta_t) :: dm
    type(bench_document_item_t) :: di
    type(bench_document_t) :: d
    type(bench_telemetry_t) :: tel
    type(bench_strings_t) :: st
    type(bench_event_attr_t) :: ea
    type(bench_event_t) :: ev

    stat = 0
    if (c_sizeof(a) /= 24 .or. c_sizeof(o) /= 24 .or. c_sizeof(r) /= 16 &
        .or. c_sizeof(s) /= 16 .or. c_sizeof(t) /= 144 .or. c_sizeof(td) /= 32 &
        .or. c_sizeof(m) /= 64 .or. c_sizeof(dm) /= 24 .or. c_sizeof(di) /= 32 &
        .or. c_sizeof(d) /= 64 .or. c_sizeof(tel) /= 56 .or. c_sizeof(st) /= 16 &
        .or. c_sizeof(ea) /= 32 .or. c_sizeof(ev) /= 72) then
      stat = 1
      return
    end if
    call ensure_arena(4_c_size_t * 1024_c_size_t * 1024_c_size_t)
  end subroutine

  function make_kstr(text, n) result(ks)
    character(len=v2_str), intent(in), target :: text
    integer, intent(in) :: n
    type(kiln_str_t) :: ks
    if (n <= 0) then
      ks%ptr = c_null_ptr
      ks%len = 0_c_int64_t
    else
      ks%ptr = c_loc(text(1:1))
      ks%len = int(n, c_int64_t)
    end if
  end function

  subroutine copy_kstr(ks, dst, n, stat)
    type(kiln_str_t), intent(in) :: ks
    character(len=v2_str), intent(out), target :: dst
    integer, intent(out) :: n, stat
    if (ks%len < 0 .or. ks%len > int(v2_str, c_int64_t)) then
      n = 0
      dst = ""
      stat = 1
      return
    end if
    n = int(ks%len)
    if (n > 0) then
      if (.not. c_associated(ks%ptr)) then
        n = 0
        dst = ""
        stat = 1
        return
      end if
      call kiln_f_memcpy(c_loc(dst(1:1)), ks%ptr, int(n, c_size_t))
    end if
    stat = 0
  end subroutine

  subroutine fill_msg(src, dst)
    type(message_t), intent(in), target :: src
    type(bench_message_t), intent(out) :: dst
    if (src%f_bool) then
      dst%f_bool = 1_c_int8_t
    else
      dst%f_bool = 0_c_int8_t
    end if
    dst%f_int32 = src%f_int32
    dst%f_int64 = src%f_int64
    dst%f_float64 = src%f_float64
    dst%f_string = make_kstr(src%f_string, src%f_string_n)
    if (src%f_bool_2) then
      dst%f_bool_2 = 1_c_int8_t
    else
      dst%f_bool_2 = 0_c_int8_t
    end if
    dst%f_int32_2 = src%f_int32_2
    dst%f_string_2 = make_kstr(src%f_string_2, src%f_string_2_n)
  end subroutine

  subroutine read_msg(src, dst, stat)
    type(bench_message_t), intent(in) :: src
    type(message_t), intent(out), target :: dst
    integer, intent(out) :: stat
    dst%f_bool = src%f_bool /= 0_c_int8_t
    dst%f_int32 = src%f_int32
    dst%f_int64 = src%f_int64
    dst%f_float64 = src%f_float64
    call copy_kstr(src%f_string, dst%f_string, dst%f_string_n, stat)
    if (stat /= 0) return
    dst%f_bool_2 = src%f_bool_2 /= 0_c_int8_t
    dst%f_int32_2 = src%f_int32_2
    call copy_kstr(src%f_string_2, dst%f_string_2, dst%f_string_2_n, stat)
  end subroutine

  subroutine fill_doc(src, dst, pool, pos)
    type(document_t), intent(in), target :: src
    type(bench_document_t), intent(out) :: dst
    type(bench_document_item_t), intent(inout), target :: pool(:)
    integer, intent(inout) :: pos
    integer :: j, nitem
    dst%id = make_kstr(src%id, src%id_n)
    dst%status = src%status
    dst%meta%region = make_kstr(src%region, src%region_n)
    dst%meta%version = src%version
    nitem = src%item_count
    dst%items%count = int(nitem, c_int64_t)
    if (nitem > 0) then
      dst%items%items = c_loc(pool(pos))
      do j = 1, nitem
        pool(pos + j - 1)%sku = make_kstr(src%items(j)%sku, src%items(j)%sku_n)
        pool(pos + j - 1)%qty = src%items(j)%qty
        pool(pos + j - 1)%price_minor = src%items(j)%price_minor
      end do
      pos = pos + nitem
    else
      dst%items%items = c_null_ptr
    end if
  end subroutine

  subroutine read_doc(src, dst, stat)
    type(bench_document_t), intent(in) :: src
    type(document_t), intent(out), target :: dst
    integer, intent(out) :: stat
    type(bench_document_item_t), pointer :: c_items(:)
    integer :: j, nitem
    call copy_kstr(src%id, dst%id, dst%id_n, stat)
    if (stat /= 0) return
    dst%status = src%status
    call copy_kstr(src%meta%region, dst%region, dst%region_n, stat)
    if (stat /= 0) return
    dst%version = src%meta%version
    if (src%items%count < 0 .or. src%items%count > int(v2_max_children, c_int64_t)) then
      stat = 1
      return
    end if
    nitem = int(src%items%count)
    dst%item_count = nitem
    if (nitem > 0) then
      if (.not. c_associated(src%items%items)) then
        stat = 1
        return
      end if
      call c_f_pointer(src%items%items, c_items, [nitem])
      do j = 1, nitem
        call copy_kstr(c_items(j)%sku, dst%items(j)%sku, dst%items(j)%sku_n, stat)
        if (stat /= 0) return
        dst%items(j)%qty = c_items(j)%qty
        dst%items(j)%price_minor = c_items(j)%price_minor
      end do
    end if
    stat = 0
  end subroutine

  subroutine fill_tel(src, dst, pool, pos)
    type(telemetry_t), intent(in), target :: src
    type(bench_telemetry_t), intent(out) :: dst
    type(kiln_str_t), intent(inout), target :: pool(:)
    integer, intent(inout) :: pos
    integer :: j, ntags, nvals
    dst%source = make_kstr(src%source, src%source_n)
    dst%ts = src%ts
    ntags = src%tag_count
    dst%tags%count = int(ntags, c_int64_t)
    if (ntags > 0) then
      dst%tags%items = c_loc(pool(pos))
      do j = 1, ntags
        pool(pos + j - 1) = make_kstr(src%tags(j), src%tag_n(j))
      end do
      pos = pos + ntags
    else
      dst%tags%items = c_null_ptr
    end if
    nvals = src%value_count
    dst%values%count = int(nvals, c_int64_t)
    if (nvals > 0) then
      dst%values%items = c_loc(src%values(1))
    else
      dst%values%items = c_null_ptr
    end if
  end subroutine

  subroutine read_tel(src, dst, stat)
    type(bench_telemetry_t), intent(in) :: src
    type(telemetry_t), intent(out), target :: dst
    integer, intent(out) :: stat
    type(kiln_str_t), pointer :: c_tags(:)
    integer :: j, ntags, nvals
    call copy_kstr(src%source, dst%source, dst%source_n, stat)
    if (stat /= 0) return
    dst%ts = src%ts
    if (src%tags%count < 0 .or. src%tags%count > int(v2_max_tags, c_int64_t)) then
      stat = 1
      return
    end if
    if (src%values%count < 0 .or. src%values%count > int(v2_max_points, c_int64_t)) then
      stat = 1
      return
    end if
    ntags = int(src%tags%count)
    dst%tag_count = ntags
    if (ntags > 0) then
      if (.not. c_associated(src%tags%items)) then
        stat = 1
        return
      end if
      call c_f_pointer(src%tags%items, c_tags, [ntags])
      do j = 1, ntags
        call copy_kstr(c_tags(j), dst%tags(j), dst%tag_n(j), stat)
        if (stat /= 0) return
      end do
    end if
    nvals = int(src%values%count)
    dst%value_count = nvals
    if (nvals > 0) then
      if (.not. c_associated(src%values%items)) then
        stat = 1
        return
      end if
      ! Decoded list<f64> points into 4-byte-aligned wire bytes; memcpy is alignment-safe.
      call kiln_f_memcpy(c_loc(dst%values(1)), src%values%items, int(nvals, c_size_t) * 8_c_size_t)
    end if
    stat = 0
  end subroutine

  subroutine fill_strs(src, dst, pool, pos)
    type(strings_t), intent(in), target :: src
    type(bench_strings_t), intent(out) :: dst
    type(kiln_str_t), intent(inout), target :: pool(:)
    integer, intent(inout) :: pos
    integer :: j, nitem
    nitem = src%count
    dst%items%count = int(nitem, c_int64_t)
    if (nitem > 0) then
      dst%items%items = c_loc(pool(pos))
      do j = 1, nitem
        pool(pos + j - 1) = make_kstr(src%items(j), src%item_n(j))
      end do
      pos = pos + nitem
    else
      dst%items%items = c_null_ptr
    end if
  end subroutine

  subroutine read_strs(src, dst, stat)
    type(bench_strings_t), intent(in) :: src
    type(strings_t), intent(out), target :: dst
    integer, intent(out) :: stat
    type(kiln_str_t), pointer :: c_items(:)
    integer :: j, nitem
    if (src%items%count < 0 .or. src%items%count > int(v2_max_strings, c_int64_t)) then
      stat = 1
      return
    end if
    nitem = int(src%items%count)
    dst%count = nitem
    if (nitem > 0) then
      if (.not. c_associated(src%items%items)) then
        stat = 1
        return
      end if
      call c_f_pointer(src%items%items, c_items, [nitem])
      do j = 1, nitem
        call copy_kstr(c_items(j), dst%items(j), dst%item_n(j), stat)
        if (stat /= 0) return
      end do
    end if
    stat = 0
  end subroutine

  subroutine fill_ev(src, dst, pool, pos)
    type(event_t), intent(in), target :: src
    type(bench_event_t), intent(out) :: dst
    type(bench_event_attr_t), intent(inout), target :: pool(:)
    integer, intent(inout) :: pos
    integer :: j, nattr
    dst%event_id = make_kstr(src%event_id, src%event_id_n)
    dst%event_type = make_kstr(src%event_type, src%event_type_n)
    dst%occurred_at = src%occurred_at
    dst%producer = make_kstr(src%producer, src%producer_n)
    nattr = src%attr_count
    dst%attrs%count = int(nattr, c_int64_t)
    if (nattr > 0) then
      dst%attrs%items = c_loc(pool(pos))
      do j = 1, nattr
        pool(pos + j - 1)%key = make_kstr(src%attrs(j)%key, src%attrs(j)%key_n)
        pool(pos + j - 1)%value = make_kstr(src%attrs(j)%value, src%attrs(j)%value_n)
      end do
      pos = pos + nattr
    else
      dst%attrs%items = c_null_ptr
    end if
  end subroutine

  subroutine read_ev(src, dst, stat)
    type(bench_event_t), intent(in) :: src
    type(event_t), intent(out), target :: dst
    integer, intent(out) :: stat
    type(bench_event_attr_t), pointer :: c_attrs(:)
    integer :: j, nattr
    call copy_kstr(src%event_id, dst%event_id, dst%event_id_n, stat)
    if (stat /= 0) return
    call copy_kstr(src%event_type, dst%event_type, dst%event_type_n, stat)
    if (stat /= 0) return
    dst%occurred_at = src%occurred_at
    call copy_kstr(src%producer, dst%producer, dst%producer_n, stat)
    if (stat /= 0) return
    if (src%attrs%count < 0 .or. src%attrs%count > int(v2_max_attrs, c_int64_t)) then
      stat = 1
      return
    end if
    nattr = int(src%attrs%count)
    dst%attr_count = nattr
    if (nattr > 0) then
      if (.not. c_associated(src%attrs%items)) then
        stat = 1
        return
      end if
      call c_f_pointer(src%attrs%items, c_attrs, [nattr])
      do j = 1, nattr
        call copy_kstr(c_attrs(j)%key, dst%attrs(j)%key, dst%attrs(j)%key_n, stat)
        if (stat /= 0) return
        call copy_kstr(c_attrs(j)%value, dst%attrs(j)%value, dst%attrs(j)%value_n, stat)
        if (stat /= 0) return
      end do
    end if
    stat = 0
  end subroutine

  subroutine kiln_asm_serialize(items, buf, out_len, stat)
    type(fixture_t), intent(in), target :: items(:)
    integer(int8), intent(out), target :: buf(:)
    integer, intent(out) :: out_len, stat
    integer :: n, i, total, pos
    integer(c_int32_t) :: err
    type(kiln_result_t) :: res
    type(bench_message_t) :: msg
    type(bench_document_t) :: doc
    type(bench_document_item_t), target :: doc_items(v2_max_children)
    type(bench_telemetry_t) :: tel
    type(kiln_str_t), target :: tag_items(v2_max_tags)
    type(bench_strings_t) :: strs
    type(kiln_str_t), target :: str_items(v2_max_strings)
    type(bench_event_t) :: ev
    type(bench_event_attr_t), target :: ev_attrs(v2_max_attrs)
    integer(c_size_t) :: cap

    out_len = 0
    stat = 1
    n = size(items)
    if (n < 1 .or. size(buf) < 1) return
    cap = int(size(buf), c_size_t)
    err = 1_c_int32_t

    select case (items(1)%kind_id)
    case (kind_message)
      if (n == 1) then
        call fill_msg(items(1)%message, msg)
        err = kiln_asm_encode_bench_message(msg, c_loc(buf(1)), cap, c_null_ptr, res)
      else
        if (.not. allocated(msg_buf)) then
          allocate(msg_buf(n))
        else if (size(msg_buf) < n) then
          deallocate(msg_buf)
          allocate(msg_buf(n))
        end if
        do i = 1, n
          call fill_msg(items(i)%message, msg_buf(i))
        end do
        err = kiln_asm_encode_bench_message_batch( &
            c_loc(msg_buf(1)), int(n, c_size_t), c_loc(buf(1)), cap, c_null_ptr, res)
      end if

    case (kind_document)
      if (n == 1) then
        pos = 1
        call fill_doc(items(1)%document, doc, doc_items, pos)
        err = kiln_asm_encode_bench_document(doc, c_loc(buf(1)), cap, c_null_ptr, res)
      else
        total = 0
        do i = 1, n
          total = total + items(i)%document%item_count
        end do
        if (.not. allocated(doc_buf)) then
          allocate(doc_buf(n))
        else if (size(doc_buf) < n) then
          deallocate(doc_buf)
          allocate(doc_buf(n))
        end if
        total = max(total, 1)
        if (.not. allocated(doc_item_buf)) then
          allocate(doc_item_buf(total))
        else if (size(doc_item_buf) < total) then
          deallocate(doc_item_buf)
          allocate(doc_item_buf(total))
        end if
        pos = 1
        do i = 1, n
          call fill_doc(items(i)%document, doc_buf(i), doc_item_buf, pos)
        end do
        err = kiln_asm_encode_bench_document_batch( &
            c_loc(doc_buf(1)), int(n, c_size_t), c_loc(buf(1)), cap, c_null_ptr, res)
      end if

    case (kind_telemetry)
      if (n == 1) then
        pos = 1
        call fill_tel(items(1)%telemetry, tel, tag_items, pos)
        err = kiln_asm_encode_bench_telemetry(tel, c_loc(buf(1)), cap, c_null_ptr, res)
      else
        total = 0
        do i = 1, n
          total = total + items(i)%telemetry%tag_count
        end do
        if (.not. allocated(tel_buf)) then
          allocate(tel_buf(n))
        else if (size(tel_buf) < n) then
          deallocate(tel_buf)
          allocate(tel_buf(n))
        end if
        total = max(total, 1)
        if (.not. allocated(str_pool)) then
          allocate(str_pool(total))
        else if (size(str_pool) < total) then
          deallocate(str_pool)
          allocate(str_pool(total))
        end if
        pos = 1
        do i = 1, n
          call fill_tel(items(i)%telemetry, tel_buf(i), str_pool, pos)
        end do
        err = kiln_asm_encode_bench_telemetry_batch( &
            c_loc(tel_buf(1)), int(n, c_size_t), c_loc(buf(1)), cap, c_null_ptr, res)
      end if

    case (kind_strings)
      if (n == 1) then
        pos = 1
        call fill_strs(items(1)%strings, strs, str_items, pos)
        err = kiln_asm_encode_bench_strings(strs, c_loc(buf(1)), cap, c_null_ptr, res)
      else
        total = 0
        do i = 1, n
          total = total + items(i)%strings%count
        end do
        if (.not. allocated(strs_buf)) then
          allocate(strs_buf(n))
        else if (size(strs_buf) < n) then
          deallocate(strs_buf)
          allocate(strs_buf(n))
        end if
        total = max(total, 1)
        if (.not. allocated(str_pool)) then
          allocate(str_pool(total))
        else if (size(str_pool) < total) then
          deallocate(str_pool)
          allocate(str_pool(total))
        end if
        pos = 1
        do i = 1, n
          call fill_strs(items(i)%strings, strs_buf(i), str_pool, pos)
        end do
        err = kiln_asm_encode_bench_strings_batch( &
            c_loc(strs_buf(1)), int(n, c_size_t), c_loc(buf(1)), cap, c_null_ptr, res)
      end if

    case (kind_event)
      if (n == 1) then
        pos = 1
        call fill_ev(items(1)%event, ev, ev_attrs, pos)
        err = kiln_asm_encode_bench_event(ev, c_loc(buf(1)), cap, c_null_ptr, res)
      else
        total = 0
        do i = 1, n
          total = total + items(i)%event%attr_count
        end do
        if (.not. allocated(ev_buf)) then
          allocate(ev_buf(n))
        else if (size(ev_buf) < n) then
          deallocate(ev_buf)
          allocate(ev_buf(n))
        end if
        total = max(total, 1)
        if (.not. allocated(ev_attr_buf)) then
          allocate(ev_attr_buf(total))
        else if (size(ev_attr_buf) < total) then
          deallocate(ev_attr_buf)
          allocate(ev_attr_buf(total))
        end if
        pos = 1
        do i = 1, n
          call fill_ev(items(i)%event, ev_buf(i), ev_attr_buf, pos)
        end do
        err = kiln_asm_encode_bench_event_batch( &
            c_loc(ev_buf(1)), int(n, c_size_t), c_loc(buf(1)), cap, c_null_ptr, res)
      end if

    case default
      return
    end select

    if (err /= KILN_OK) return
    out_len = int(res%bytes)
    stat = 0
  end subroutine

  subroutine kiln_asm_deserialize(buf, nbytes, kind_id, expect_n, items, stat)
    integer(int8), intent(in), target :: buf(:)
    integer, intent(in) :: nbytes, kind_id, expect_n
    type(fixture_t), allocatable, intent(out), target :: items(:)
    integer, intent(out) :: stat
    type(kiln_arena_t) :: arena
    type(kiln_result_t) :: res
    integer(c_int32_t) :: err
    type(c_ptr) :: out_ptr
    integer(c_size_t) :: out_cnt, slen, need_arena
    integer :: i, n
    type(bench_message_t) :: msg
    type(bench_message_t), pointer :: c_msgs(:)
    type(bench_document_t) :: doc
    type(bench_document_t), pointer :: c_docs(:)
    type(bench_telemetry_t) :: tel
    type(bench_telemetry_t), pointer :: c_tels(:)
    type(bench_strings_t) :: strs
    type(bench_strings_t), pointer :: c_strs(:)
    type(bench_event_t) :: ev
    type(bench_event_t), pointer :: c_evs(:)

    stat = 1
    if (nbytes < 1 .or. nbytes > size(buf) .or. expect_n < 1) return
    slen = int(nbytes, c_size_t)
    need_arena = max(int(expect_n, c_size_t) * 2048_c_size_t, 262144_c_size_t)
    call reset_arena(arena, need_arena)

    select case (kind_id)
    case (kind_message)
      if (expect_n == 1) then
        err = kiln_asm_decode_bench_message(c_loc(buf(1)), slen, msg, arena, c_null_ptr, res)
        if (err /= KILN_OK) return
        allocate(items(1))
        items(1)%kind_id = kind_message
        call read_msg(msg, items(1)%message, stat)
      else
        err = kiln_asm_decode_bench_message_batch( &
            c_loc(buf(1)), slen, out_ptr, out_cnt, arena, c_null_ptr, res)
        if (err /= KILN_OK .or. int(out_cnt) /= expect_n) return
        n = int(out_cnt)
        call c_f_pointer(out_ptr, c_msgs, [n])
        allocate(items(n))
        do i = 1, n
          items(i)%kind_id = kind_message
          call read_msg(c_msgs(i), items(i)%message, stat)
          if (stat /= 0) return
        end do
      end if

    case (kind_document)
      if (expect_n == 1) then
        err = kiln_asm_decode_bench_document(c_loc(buf(1)), slen, doc, arena, c_null_ptr, res)
        if (err /= KILN_OK) return
        allocate(items(1))
        items(1)%kind_id = kind_document
        call read_doc(doc, items(1)%document, stat)
      else
        err = kiln_asm_decode_bench_document_batch( &
            c_loc(buf(1)), slen, out_ptr, out_cnt, arena, c_null_ptr, res)
        if (err /= KILN_OK .or. int(out_cnt) /= expect_n) return
        n = int(out_cnt)
        call c_f_pointer(out_ptr, c_docs, [n])
        allocate(items(n))
        do i = 1, n
          items(i)%kind_id = kind_document
          call read_doc(c_docs(i), items(i)%document, stat)
          if (stat /= 0) return
        end do
      end if

    case (kind_telemetry)
      if (expect_n == 1) then
        err = kiln_asm_decode_bench_telemetry(c_loc(buf(1)), slen, tel, arena, c_null_ptr, res)
        if (err /= KILN_OK) return
        allocate(items(1))
        items(1)%kind_id = kind_telemetry
        call read_tel(tel, items(1)%telemetry, stat)
      else
        err = kiln_asm_decode_bench_telemetry_batch( &
            c_loc(buf(1)), slen, out_ptr, out_cnt, arena, c_null_ptr, res)
        if (err /= KILN_OK .or. int(out_cnt) /= expect_n) return
        n = int(out_cnt)
        call c_f_pointer(out_ptr, c_tels, [n])
        allocate(items(n))
        do i = 1, n
          items(i)%kind_id = kind_telemetry
          call read_tel(c_tels(i), items(i)%telemetry, stat)
          if (stat /= 0) return
        end do
      end if

    case (kind_strings)
      if (expect_n == 1) then
        err = kiln_asm_decode_bench_strings(c_loc(buf(1)), slen, strs, arena, c_null_ptr, res)
        if (err /= KILN_OK) return
        allocate(items(1))
        items(1)%kind_id = kind_strings
        call read_strs(strs, items(1)%strings, stat)
      else
        err = kiln_asm_decode_bench_strings_batch( &
            c_loc(buf(1)), slen, out_ptr, out_cnt, arena, c_null_ptr, res)
        if (err /= KILN_OK .or. int(out_cnt) /= expect_n) return
        n = int(out_cnt)
        call c_f_pointer(out_ptr, c_strs, [n])
        allocate(items(n))
        do i = 1, n
          items(i)%kind_id = kind_strings
          call read_strs(c_strs(i), items(i)%strings, stat)
          if (stat /= 0) return
        end do
      end if

    case (kind_event)
      if (expect_n == 1) then
        err = kiln_asm_decode_bench_event(c_loc(buf(1)), slen, ev, arena, c_null_ptr, res)
        if (err /= KILN_OK) return
        allocate(items(1))
        items(1)%kind_id = kind_event
        call read_ev(ev, items(1)%event, stat)
      else
        err = kiln_asm_decode_bench_event_batch( &
            c_loc(buf(1)), slen, out_ptr, out_cnt, arena, c_null_ptr, res)
        if (err /= KILN_OK .or. int(out_cnt) /= expect_n) return
        n = int(out_cnt)
        call c_f_pointer(out_ptr, c_evs, [n])
        allocate(items(n))
        do i = 1, n
          items(i)%kind_id = kind_event
          call read_ev(c_evs(i), items(i)%event, stat)
          if (stat /= 0) return
        end do
      end if

    case default
      return
    end select
  end subroutine

  subroutine kiln_asm_write_grid(values, buf, out_len, stat)
    ! Fortran column-major values(nx, ny) stores x contiguous, y outer — identical to C row-major [ny, nx].
    real(real64), intent(in), target :: values(:, :)
    integer(int8), intent(out), target :: buf(:)
    integer, intent(out) :: out_len, stat
    type(kiln_tensor_t), target :: t
    type(kiln_tensor_dir_t) :: dir
    type(kiln_result_t) :: res
    integer(c_int32_t) :: err
    integer :: nx, ny
    integer(c_int64_t) :: nbytes

    out_len = 0
    stat = 1
    nx = size(values, 1)
    ny = size(values, 2)
    if (nx < 1 .or. ny < 1 .or. size(buf) < 64) return

    nbytes = int(nx, c_int64_t) * int(ny, c_int64_t) * 8_c_int64_t
    t%name = c_null_ptr
    t%name_len = 0
    t%layout = c_null_ptr
    t%layout_len = 0
    t%data = c_loc(values(1, 1))
    t%data_len = nbytes
    t%shape = 0
    t%shape(1) = int(ny, c_int64_t)
    t%shape(2) = int(nx, c_int64_t)
    t%dtype = KILN_DTYPE_F64
    t%rank = 2_c_int8_t
    t%pad0 = 0_c_int8_t
    t%quant_scheme = 0_c_int16_t
    t%quant_axis = -1_c_int16_t
    t%group_size = 0_c_int32_t
    t%scale_index = -1_c_int32_t
    t%outer_index = -1_c_int32_t
    t%block_size = 0_c_int32_t
    t%elem_count = 0_c_int64_t

    dir%items = c_loc(t)
    dir%count = 1_c_int64_t
    dir%block_length = 0_c_int64_t
    dir%flags = 2_c_int32_t
    dir%version = 2_c_int32_t

    err = kiln_asm_encode_tensors(dir, c_loc(buf(1)), int(size(buf), c_size_t), c_loc(large_opts), res)
    if (err /= KILN_OK) return
    out_len = int(res%bytes)
    stat = 0
  end subroutine

  subroutine kiln_asm_read_grid(buf, nbytes, values, stat)
    integer(int8), intent(in), target :: buf(:)
    integer, intent(in) :: nbytes
    real(real64), intent(out), target :: values(:, :)
    integer, intent(out) :: stat
    type(kiln_arena_t) :: arena
    type(kiln_tensor_dir_t) :: dir
    type(kiln_tensor_t), pointer :: ts(:)
    type(kiln_result_t) :: res
    integer(c_int32_t) :: err
    integer :: nx, ny
    integer(c_int64_t) :: expect_bytes

    stat = 1
    if (nbytes < 64 .or. nbytes > size(buf)) return
    call reset_arena(arena, 65536_c_size_t)
    err = kiln_asm_decode_tensors( &
        c_loc(buf(1)), int(nbytes, c_size_t), dir, arena, c_loc(large_opts), res)
    if (err /= KILN_OK .or. dir%count /= 1_c_int64_t .or. .not. c_associated(dir%items)) return
    call c_f_pointer(dir%items, ts, [1])
    nx = size(values, 1)
    ny = size(values, 2)
    expect_bytes = int(nx, c_int64_t) * int(ny, c_int64_t) * 8_c_int64_t
    if (ts(1)%dtype /= KILN_DTYPE_F64 .or. ts(1)%rank /= 2_c_int8_t) return
    if (ts(1)%shape(1) /= int(ny, c_int64_t) .or. ts(1)%shape(2) /= int(nx, c_int64_t)) return
    if (ts(1)%data_len /= expect_bytes .or. .not. c_associated(ts(1)%data)) return
    call kiln_f_memcpy(c_loc(values(1, 1)), ts(1)%data, int(expect_bytes, c_size_t))
    stat = 0
  end subroutine

  subroutine kiln_asm_read_window(buf, nbytes, x0, y0, wx, wy, window, stat)
    ! Strided interior window read directly from decoded KLNT payload pointer (no full-grid copy).
    integer(int8), intent(in), target :: buf(:)
    integer, intent(in) :: nbytes, x0, y0, wx, wy
    real(real64), intent(out), target :: window(:, :)
    integer, intent(out) :: stat
    type(kiln_arena_t) :: arena
    type(kiln_tensor_dir_t) :: dir
    type(kiln_tensor_t), pointer :: ts(:)
    type(kiln_result_t) :: res
    type(c_ptr) :: src_row
    integer(c_int32_t) :: err
    integer(c_int64_t) :: nx, ny, row_off
    integer(c_size_t) :: row_bytes
    integer :: r

    stat = 1
    if (nbytes < 64 .or. nbytes > size(buf)) return
    if (x0 < 0 .or. y0 < 0 .or. wx < 1 .or. wy < 1) return
    if (wx /= size(window, 1) .or. wy /= size(window, 2)) return
    call reset_arena(arena, 65536_c_size_t)
    err = kiln_asm_decode_tensors( &
        c_loc(buf(1)), int(nbytes, c_size_t), dir, arena, c_loc(large_opts), res)
    if (err /= KILN_OK .or. dir%count /= 1_c_int64_t .or. .not. c_associated(dir%items)) return
    call c_f_pointer(dir%items, ts, [1])
    if (ts(1)%dtype /= KILN_DTYPE_F64 .or. ts(1)%rank /= 2_c_int8_t) return
    ny = ts(1)%shape(1)
    nx = ts(1)%shape(2)
    if (int(x0 + wx, c_int64_t) > nx .or. int(y0 + wy, c_int64_t) > ny) return
    if (ts(1)%data_len /= nx * ny * 8_c_int64_t .or. .not. c_associated(ts(1)%data)) return
    row_bytes = int(wx, c_size_t) * 8_c_size_t
    do r = 0, wy - 1
      row_off = (int(y0 + r, c_int64_t) * nx + int(x0, c_int64_t)) * 8_c_int64_t
      call kiln_f_ptr_add(ts(1)%data, int(row_off, c_size_t), src_row)
      call kiln_f_memcpy(c_loc(window(1, r + 1)), src_row, row_bytes)
    end do
    stat = 0
  end subroutine

end module ser_kiln_asm
