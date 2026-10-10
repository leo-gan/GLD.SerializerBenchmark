program ffi_bench
  ! Experiment 15. Not a leaderboard row. One document is copied into the C
  ! fixture inside the timer, then the C adapter runs. Names are the C runner's
  ! names and are not registered in benchmark_config.yaml.
  use, intrinsic :: iso_fortran_env, only: int32, int64, real64, int8
  use, intrinsic :: iso_c_binding, only: c_char, c_int, c_int8_t, c_int32_t, c_int64_t, c_size_t, c_ptr, c_loc, c_null_char
  use bench_data
  use csv_log
  implicit none

  integer, parameter :: nlib = 10
  integer, parameter :: buf_cap = 1024 * 1024
  character(len=16) :: names(nlib)
  character(len=32) :: versions(nlib)
  integer(int8), target :: payload(buf_cap)
  integer(int64) :: seed, clock_rate

  interface
    subroutine black_box_bytes(p, n) bind(C, name="black_box_bytes")
      import :: c_ptr, c_size_t
      type(c_ptr), value :: p
      integer(c_size_t), value :: n
    end subroutine
    subroutine gld_ffi_version(name, dst, cap) bind(C, name="gld_ffi_version")
      import :: c_char, c_int
      character(kind=c_char), intent(in) :: name(*)
      character(kind=c_char), intent(out) :: dst(*)
      integer(c_int), value :: cap
    end subroutine
    function gld_ffi_prep(name, id, status, region, version, nitems, sku, qty, price) &
        bind(C, name="gld_ffi_prep") result(rc)
      import :: c_char, c_int, c_int32_t, c_int64_t
      character(kind=c_char), intent(in) :: name(*), id(*), region(*), sku(*)
      integer(c_int32_t), value :: status, version, nitems
      integer(c_int32_t), intent(in) :: qty(*)
      integer(c_int64_t), intent(in) :: price(*)
      integer(c_int) :: rc
    end function
    function gld_ffi_ser(name, id, status, region, version, nitems, sku, qty, price, buf, cap, out_len) &
        bind(C, name="gld_ffi_ser") result(rc)
      import :: c_char, c_int, c_int32_t, c_int64_t, c_int8_t, c_size_t
      character(kind=c_char), intent(in) :: name(*), id(*), region(*), sku(*)
      integer(c_int32_t), value :: status, version, nitems
      integer(c_int32_t), intent(in) :: qty(*)
      integer(c_int64_t), intent(in) :: price(*)
      integer(c_int8_t), intent(out) :: buf(*)
      integer(c_size_t), value :: cap
      integer(c_size_t), intent(out) :: out_len
      integer(c_int) :: rc
    end function
    function gld_ffi_de(name, buf, len, id, status, region, version, nitems, sku, qty, price) &
        bind(C, name="gld_ffi_de") result(rc)
      import :: c_char, c_int, c_int32_t, c_int64_t, c_int8_t, c_size_t
      character(kind=c_char), intent(in) :: name(*)
      integer(c_int8_t), intent(in) :: buf(*)
      integer(c_size_t), value :: len
      character(kind=c_char), intent(out) :: id(*), region(*), sku(*)
      integer(c_int32_t), intent(out) :: status, version, nitems
      integer(c_int32_t), intent(out) :: qty(*)
      integer(c_int64_t), intent(out) :: price(*)
      integer(c_int) :: rc
    end function
  end interface

  call load_names()
  seed = read_seed()
  call system_clock(count_rate=clock_rate)
  call run()

contains

  subroutine load_names()
    character(kind=c_char) :: raw(32), cname(32)
    integer :: i, j
    names(1) = "yyjson"
    names(2) = "cJSON"
    names(3) = "mpack"
    names(4) = "tinycbor"
    names(5) = "nanopb"
    names(6) = "avro-c"
    names(7) = "libyaml"
    names(8) = "libbson"
    names(9) = "flatcc"
    names(10) = "ion-c"
    do i = 1, nlib
      call to_c(cname, names(i), len_trim(names(i)))
      raw = c_null_char
      call gld_ffi_version(cname, raw, 32)
      versions(i) = ""
      do j = 1, 32
        if (raw(j) == c_null_char) exit
        versions(i)(j:j) = raw(j)
      end do
    end do
  end subroutine

  function read_seed() result(v)
    integer(int64) :: v
    character(len=64) :: text
    integer :: ios, n
    v = 42_int64
    call get_environment_variable("BENCHMARK_SEED", text, length=n, status=ios)
    if (ios == 0 .and. n > 0) read(text(1:n), *, iostat=ios) v
  end function

  function arg_text(index) result(text)
    integer, intent(in) :: index
    character(len=512) :: text
    integer :: n
    text = ""
    if (index <= command_argument_count()) call get_command_argument(index, text, length=n)
  end function

  function elapsed_ns(t0, t1) result(ns)
    integer(int64), intent(in) :: t0, t1
    integer(int64) :: ns
    if (clock_rate == 1000000000_int64) then
      ns = t1 - t0
    else if (clock_rate > 0) then
      ns = nint((real(t1 - t0, real64) * 1.0e9_real64) / real(clock_rate, real64), int64)
    else
      ns = 0
    end if
  end function

  subroutine to_c(dst, src, n)
    character(kind=c_char), intent(out) :: dst(:)
    character(len=*), intent(in) :: src
    integer, intent(in) :: n
    integer :: j, m
    dst = c_null_char
    m = n
    if (m > size(dst) - 1) m = size(dst) - 1
    if (m > len(src)) m = len(src)
    if (m < 0) m = 0
    do j = 1, m
      dst(j) = src(j:j)
    end do
  end subroutine

  function same_c(src, n, raw) result(ok)
    character(len=*), intent(in) :: src
    integer, intent(in) :: n
    character(kind=c_char), intent(in) :: raw(:)
    logical :: ok
    integer :: j
    ok = .true.
    if (n < 0) then
      ok = .false.
      return
    end if
    do j = 1, n
      if (j > size(raw) .or. raw(j) /= src(j:j)) ok = .false.
    end do
    if (n + 1 <= size(raw) .and. raw(n + 1) /= c_null_char) ok = .false.
  end function

  subroutine run_cell(doc, n, type_hash, reps)
    type(document_t), intent(in) :: doc
    integer, intent(in) :: n, reps
    character(len=*), intent(in) :: type_hash
    character(kind=c_char) :: cname(32), id(v2_str), region(v2_str), sku(v2_str, v2_max_children)
    character(kind=c_char) :: id2(v2_str), region2(v2_str), sku2(v2_str, v2_max_children)
    integer(c_int32_t) :: qty(v2_max_children), qty2(v2_max_children), status, version, nitems, status2, version2
    integer(c_int64_t) :: price(v2_max_children), price2(v2_max_children)
    integer(c_size_t) :: out_len, cap
    integer(c_int) :: rc
    integer :: lib, rep, k, ro
    integer(int64) :: t0, t1, t2, gz, zs
    logical :: bad(nlib)
    bad = .false.
    cap = int(buf_cap, c_size_t)
    gz = 0
    zs = 0
    do lib = 1, nlib
      call to_c(cname, names(lib), len_trim(names(lib)))
      call pack_doc(doc, id, region, sku, qty, price, status, version, nitems)
      rc = gld_ffi_prep(cname, id, status, region, version, nitems, sku, qty, price)
      if (rc /= 0) then
        call csv_error("document", trim(names(lib)), "bytes", 0, "prepare failed")
        bad(lib) = .true.
      end if
    end do
    ro = 0
    do rep = 0, reps - 1
      do lib = 1, nlib
        if (bad(lib)) cycle
        call to_c(cname, names(lib), len_trim(names(lib)))
        call system_clock(t0)
        call pack_doc(doc, id, region, sku, qty, price, status, version, nitems)
        rc = gld_ffi_ser(cname, id, status, region, version, nitems, sku, qty, price, payload, cap, out_len)
        if (rc == 0) call black_box_bytes(c_loc(payload), out_len)
        call system_clock(t1)
        if (rc /= 0) then
          call csv_error("document", trim(names(lib)), "bytes", rep, "serialize failed")
          bad(lib) = .true.
          cycle
        end if
        nitems = 0
        rc = gld_ffi_de(cname, payload, out_len, id2, status2, region2, version2, nitems, sku2, qty2, price2)
        if (rc == 0) call black_box_bytes(c_loc(payload), out_len)
        call system_clock(t2)
        if (rc /= 0 .or. .not. same_doc(doc, id2, status2, region2, version2, nitems, sku2, qty2, price2)) then
          call csv_error("document", trim(names(lib)), "bytes", rep, "deserialize failed")
          bad(lib) = .true.
          cycle
        end if
        call csv_row("bytes", "document", reps, rep, trim(names(lib)), trim(versions(lib)), &
             elapsed_ns(t0, t1), elapsed_ns(t1, t2), int(out_len, int64), n, type_hash, ro, lib - 1, gz, zs)
        ro = ro + 1
      end do
    end do
    do lib = 1, nlib
      if (.not. bad(lib)) cycle
      do k = 1, 0
      end do
    end do
  end subroutine

  subroutine pack_doc(doc, id, region, sku, qty, price, status, version, nitems)
    type(document_t), intent(in) :: doc
    character(kind=c_char), intent(out) :: id(v2_str), region(v2_str), sku(v2_str, v2_max_children)
    integer(c_int32_t), intent(out) :: qty(v2_max_children), status, version, nitems
    integer(c_int64_t), intent(out) :: price(v2_max_children)
    integer :: k, m
    call to_c(id, doc%id, doc%id_n)
    call to_c(region, doc%region, doc%region_n)
    status = int(doc%status, c_int32_t)
    version = int(doc%version, c_int32_t)
    m = doc%item_count
    if (m > v2_max_children) m = v2_max_children
    nitems = int(m, c_int32_t)
    qty = 0
    price = 0
    sku = c_null_char
    do k = 1, m
      call to_c(sku(:, k), doc%items(k)%sku, doc%items(k)%sku_n)
      qty(k) = int(doc%items(k)%qty, c_int32_t)
      price(k) = int(doc%items(k)%price_minor, c_int64_t)
    end do
  end subroutine

  function same_doc(doc, id, status, region, version, nitems, sku, qty, price) result(ok)
    type(document_t), intent(in) :: doc
    character(kind=c_char), intent(in) :: id(v2_str), region(v2_str), sku(v2_str, v2_max_children)
    integer(c_int32_t), intent(in) :: status, version, nitems, qty(v2_max_children)
    integer(c_int64_t), intent(in) :: price(v2_max_children)
    logical :: ok
    integer :: k
    ok = same_c(doc%id, doc%id_n, id) .and. same_c(doc%region, doc%region_n, region)
    ok = ok .and. status == int(doc%status, c_int32_t) .and. version == int(doc%version, c_int32_t)
    ok = ok .and. nitems == int(doc%item_count, c_int32_t)
    if (.not. ok) return
    do k = 1, doc%item_count
      if (.not. same_c(doc%items(k)%sku, doc%items(k)%sku_n, sku(:, k))) ok = .false.
      if (qty(k) /= int(doc%items(k)%qty, c_int32_t)) ok = .false.
      if (price(k) /= int(doc%items(k)%price_minor, c_int64_t)) ok = .false.
    end do
  end function

  subroutine split_tabs(line, fields, nfields)
    character(len=*), intent(in) :: line
    character(len=128), intent(out) :: fields(8)
    integer, intent(out) :: nfields
    integer :: i, start, n
    nfields = 0
    fields = ""
    n = len_trim(line)
    start = 1
    do i = 1, n
      if (line(i:i) == achar(9)) then
        if (nfields >= 8) exit
        nfields = nfields + 1
        if (i > start) fields(nfields) = line(start:i - 1)
        start = i + 1
      end if
    end do
    if (start <= n .and. nfields < 8) then
      nfields = nfields + 1
      fields(nfields) = line(start:n)
    end if
  end subroutine

  subroutine run()
    character(len=512) :: reps_txt, tsv, log_dir, ts, csv_path
    character(len=1024) :: line
    character(len=128) :: fields(8)
    integer :: reps, unit, ios, nfields, n, children, points, str_count, attr_count, tag_count, cells
    type(fixture_t) :: item
    reps_txt = arg_text(1)
    tsv = arg_text(2)
    log_dir = arg_text(3)
    ts = arg_text(4)
    if (len_trim(reps_txt) == 0 .or. len_trim(tsv) == 0) error stop 2
    read(reps_txt, *, iostat=ios) reps
    if (ios /= 0 .or. reps < 1) error stop 2
    csv_path = trim(log_dir) // "/" // trim(ts) // ".csv"
    call csv_open(trim(csv_path))
    open(newunit=unit, file=trim(tsv), status="old", action="read", iostat=ios)
    if (ios /= 0) error stop 1
    cells = 0
    do
      read(unit, '(A)', iostat=ios) line
      if (ios /= 0) exit
      if (len_trim(line) == 0) cycle
      call split_tabs(line, fields, nfields)
      if (nfields < 3) cycle
      if (trim(fields(1)) /= "document") cycle
      read(fields(2), *, iostat=ios) n
      if (ios /= 0 .or. n /= 1) cycle
      points = 32
      children = 8
      str_count = 32
      attr_count = 4
      tag_count = 2
      if (nfields >= 4) read(fields(4), *, iostat=ios) points
      if (nfields >= 5) read(fields(5), *, iostat=ios) children
      if (nfields >= 6) read(fields(6), *, iostat=ios) str_count
      if (nfields >= 7) read(fields(7), *, iostat=ios) attr_count
      if (nfields >= 8) read(fields(8), *, iostat=ios) tag_count
      call make_one(item, kind_document, seed, 0, children, points, str_count, attr_count, tag_count)
      cells = cells + 1
      call run_cell(item%document, n, trim(fields(3)), reps)
    end do
    close(unit)
    call csv_close()
    write(*, '(A,I0,A,A)') "[PROGRESS] ffi complete (", cells, " cells) -> ", trim(csv_path)
  end subroutine

end program ffi_bench
