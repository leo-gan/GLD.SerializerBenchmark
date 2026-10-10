module schedule
  use, intrinsic :: iso_c_binding, only: c_int, c_int64_t, c_char, c_null_char
  implicit none
  private
  public :: schedule_seed, fisher_yates, schedule_is_none, schedule_record_run_order
  public :: schedule_ok

  interface
    function schedule_derive_seed(base_seed, type_id, instance_count, type_config_hash, mode, rep) &
        bind(C, name="schedule_derive_seed") result(seed)
      import :: c_int64_t, c_char, c_int
      integer(c_int64_t), value :: base_seed
      character(kind=c_char), intent(in) :: type_id(*)
      integer(c_int), value :: instance_count
      character(kind=c_char), intent(in) :: type_config_hash(*)
      character(kind=c_char), intent(in) :: mode(*)
      integer(c_int), value :: rep
      integer(c_int64_t) :: seed
    end function

    subroutine schedule_fisher_yates_indices(out, n, seed) bind(C, name="schedule_fisher_yates_indices")
      import :: c_int, c_int64_t
      integer(c_int), intent(out) :: out(*)
      integer(c_int), value :: n
      integer(c_int64_t), value :: seed
    end subroutine

    function schedule_verify_golden() bind(C, name="schedule_verify_golden") result(rc)
      import :: c_int
      integer(c_int) :: rc
    end function

    function fsched_is_none() bind(C, name="fsched_is_none") result(rc)
      import :: c_int
      integer(c_int) :: rc
    end function

    function fsched_record_run_order() bind(C, name="fsched_record_run_order") result(rc)
      import :: c_int
      integer(c_int) :: rc
    end function
  end interface

contains

  function c_string(text) result(buf)
    character(len=*), intent(in) :: text
    character(kind=c_char) :: buf(len_trim(text) + 1)
    integer :: i
    do i = 1, len_trim(text)
      buf(i) = text(i:i)
    end do
    buf(len_trim(text) + 1) = c_null_char
  end function

  function schedule_seed(base_seed, type_id, instance_count, type_config_hash, mode, rep) result(seed)
    integer(c_int64_t), intent(in) :: base_seed
    character(len=*), intent(in) :: type_id, type_config_hash, mode
    integer, intent(in) :: instance_count, rep
    integer(c_int64_t) :: seed
    seed = schedule_derive_seed(base_seed, c_string(type_id), int(instance_count, c_int), &
         c_string(type_config_hash), c_string(mode), int(rep, c_int))
  end function

  subroutine fisher_yates(order, n, seed)
    integer, intent(out) :: order(:)
    integer, intent(in) :: n
    integer(c_int64_t), intent(in) :: seed
    integer(c_int) :: raw(n)
    integer :: i
    if (n <= 0) return
    call schedule_fisher_yates_indices(raw, int(n, c_int), seed)
    do i = 1, n
      order(i) = int(raw(i)) + 1
    end do
  end subroutine

  function schedule_is_none() result(is_none)
    logical :: is_none
    is_none = fsched_is_none() /= 0
  end function

  function schedule_record_run_order() result(record)
    logical :: record
    record = fsched_record_run_order() /= 0
  end function

  function schedule_ok() result(ok)
    logical :: ok
    ok = schedule_verify_golden() == 0
  end function

end module
