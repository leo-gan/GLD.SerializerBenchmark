program test_roundtrip
  use, intrinsic :: iso_fortran_env, only: int8, int64, real64
  use bench_data
  use custom_binary
  use schedule
  implicit none
  integer(int8) :: buf(8192)
  integer :: out_len, stat, nfail, i
  type(fixture_t) :: a(1), b(2), batch(3)
  type(fixture_t), allocatable :: got(:)

  nfail = 0
  if (.not. schedule_ok()) then
    write(0, '(A)') "FAIL schedule golden vector"
    nfail = nfail + 1
  end if

  a(1)%kind_id = kind_message
  a(1)%message%f_bool = .true.
  a(1)%message%f_int32 = -2
  a(1)%message%f_int64 = 9007199254740995_int64
  a(1)%message%f_float64 = -1.25_real64
  a(1)%message%f_string_n = 6
  a(1)%message%f_string(1:1) = "h"
  a(1)%message%f_string(2:2) = achar(195)
  a(1)%message%f_string(3:3) = achar(169)
  a(1)%message%f_string(4:6) = "llo"
  a(1)%message%f_bool_2 = .false.
  a(1)%message%f_int32_2 = 7
  a(1)%message%f_string_2_n = 1
  a(1)%message%f_string_2(1:1) = "z"
  call cb_serialize(a, buf, out_len, stat)
  if (stat /= 0) nfail = nfail + 1
  call cb_deserialize(buf, out_len, 1, got, stat)
  if (stat /= 0 .or. .not. allocated(got) .or. .not. fixtures_equal(a, got)) then
    write(0, '(A)') "FAIL utf-8 / int64 round trip"
    nfail = nfail + 1
  end if

  call make_one(b(1), kind_document, 42_int64, 0, 8, 32, 32, 4, 2)
  call make_one(b(2), kind_document, 42_int64, 1, 8, 32, 32, 4, 2)
  call cb_serialize(b, buf, out_len, stat)
  call cb_deserialize(buf, out_len, 2, got, stat)
  if (stat /= 0 .or. .not. allocated(got) .or. .not. fixtures_equal(b, got)) then
    write(0, '(A)') "FAIL document batch round trip"
    nfail = nfail + 1
  end if

  call make_one(a(1), kind_message, 42_int64, 0, 8, 32, 32, 4, 2)
  call make_one(b(1), kind_message, 42_int64, 0, 8, 32, 32, 4, 2)
  if (.not. fixtures_equal(a(1:1), b(1:1))) then
    write(0, '(A)') "FAIL make_one is not deterministic"
    nfail = nfail + 1
  end if

  ! Index 2 has f_bool false. A false flag must still compare equal.
  do i = 1, 3
    call make_one(batch(i), kind_message, 42_int64, i - 1, 8, 32, 32, 4, 2)
  end do
  call cb_serialize(batch, buf, out_len, stat)
  call cb_deserialize(buf, out_len, 3, got, stat)
  if (stat /= 0 .or. .not. allocated(got) .or. .not. fixtures_equal(batch, got)) then
    write(0, '(A)') "FAIL message batch round trip"
    nfail = nfail + 1
  end if

  if (nfail /= 0) error stop 1
  write(*, '(A)') "ok"
end program
