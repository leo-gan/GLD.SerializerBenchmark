module csv_log
  use, intrinsic :: iso_fortran_env, only: int64, real64
  implicit none
  private
  public :: csv_open, csv_row, csv_error, csv_close

  integer :: data_unit = -1
  integer :: error_unit = -1
  character(len=1024) :: error_path = ""
  logical :: error_header = .false.

contains

  function opt_int(v) result(text)
    integer, intent(in) :: v
    character(len=32) :: text
    text = ""
    if (v >= 0) write(text, '(I0)') v
  end function

  function opt_size(v) result(text)
    integer(int64), intent(in) :: v
    character(len=32) :: text
    text = ""
    if (v > 0) write(text, '(I0)') v
  end function

  subroutine csv_open(path)
    character(len=*), intent(in) :: path
    integer :: ios
    open(newunit=data_unit, file=path, status="replace", action="write", iostat=ios)
    if (ios /= 0) then
      write(0, '(A)') "Cannot create log " // trim(path)
      error stop 1
    end if
    write(data_unit, '(A)') "Language,StringOrStream,TestDataName,Repetitions,RepetitionIndex," // &
         "SerializerName,SerializerVersion,TimeSer,TimeDeser,Size,TimeSerAndDeser," // &
         "OpPerSecSer,OpPerSecDeser,OpPerSecSerAndDeser,MemoryPeakBytes,FidelityScore," // &
         "DataTypeInstanceCount,TypeConfigHash,StreamMode,RunOrder,SchedulePosition,SizeGzip,SizeZstd"
    error_path = path
    call replace_suffix(error_path, ".csv", ".errors.csv")
  end subroutine

  subroutine replace_suffix(path, old, new)
    character(len=*), intent(inout) :: path
    character(len=*), intent(in) :: old, new
    integer :: n, k
    n = len_trim(path)
    k = len(old)
    if (n >= k .and. path(n - k + 1:n) == old) then
      path = path(1:n - k) // new
    else
      path = trim(path) // new
    end if
  end subroutine

  subroutine csv_row(mode, type_id, reps, rep, ser_name, ser_version, ser_ns, deser_ns, &
                     nbytes, instance_count, type_hash, run_order, schedule_position, gzip_n, zstd_n, &
                     stream_mode)
    character(len=*), intent(in) :: mode, type_id, ser_name, ser_version, type_hash
    integer, intent(in) :: reps, rep, instance_count, run_order, schedule_position
    integer(int64), intent(in) :: ser_ns, deser_ns, nbytes, gzip_n, zstd_n
    character(len=*), intent(in), optional :: stream_mode
    integer(int64) :: total
    real(real64) :: ops_s, ops_d, ops_t
    character(len=32) :: ro, sp, gz, zs, sm
    character(len=64) :: ser_txt, deser_txt, size_txt, tot_txt, ops_s_txt, ops_d_txt, ops_t_txt
    total = ser_ns + deser_ns
    ops_s = 0
    ops_d = 0
    ops_t = 0
    if (ser_ns > 0) ops_s = 1.0e9_real64 / real(ser_ns, real64)
    if (deser_ns > 0) ops_d = 1.0e9_real64 / real(deser_ns, real64)
    if (total > 0) ops_t = 1.0e9_real64 / real(total, real64)
    write(ser_txt, '(I0)') ser_ns
    write(deser_txt, '(I0)') deser_ns
    write(size_txt, '(I0)') nbytes
    write(tot_txt, '(I0)') total
    write(ops_s_txt, '(F0.6)') ops_s
    write(ops_d_txt, '(F0.6)') ops_d
    write(ops_t_txt, '(F0.6)') ops_t
    ro = opt_int(run_order)
    sp = opt_int(schedule_position)
    gz = opt_size(gzip_n)
    zs = opt_size(zstd_n)
    sm = ""
    if (present(stream_mode)) sm = stream_mode
    write(data_unit, '(A)') "fortran," // trim(mode) // "," // trim(type_id) // "," // &
         trim(i0(reps)) // "," // trim(i0(rep)) // "," // trim(ser_name) // "," // trim(ser_version) // "," // &
         trim(ser_txt) // "," // trim(deser_txt) // "," // trim(size_txt) // "," // trim(tot_txt) // "," // &
         trim(ops_s_txt) // "," // trim(ops_d_txt) // "," // trim(ops_t_txt) // ",0,1.0," // &
         trim(i0(instance_count)) // "," // trim(type_hash) // "," // trim(sm) // "," // &
         trim(ro) // "," // trim(sp) // "," // trim(gz) // "," // trim(zs)
    flush(data_unit)
  end subroutine

  function i0(v) result(text)
    integer, intent(in) :: v
    character(len=32) :: text
    write(text, '(I0)') v
  end function

  subroutine csv_error(type_id, ser_name, mode, rep, text)
    character(len=*), intent(in) :: type_id, ser_name, mode, text
    integer, intent(in) :: rep
    integer :: ios
    if (.not. error_header) then
      open(newunit=error_unit, file=trim(error_path), status="replace", action="write", iostat=ios)
      if (ios /= 0) return
      write(error_unit, '(A)') "TestDataName,SerializerName,StringOrStream,Repetition,ErrorText"
      error_header = .true.
    end if
    write(error_unit, '(A)') trim(type_id) // "," // trim(ser_name) // "," // trim(mode) // "," // &
         trim(i0(rep)) // "," // trim(text)
    flush(error_unit)
  end subroutine

  subroutine csv_close()
    if (data_unit >= 0) close(data_unit)
    if (error_header .and. error_unit >= 0) close(error_unit)
    data_unit = -1
    error_unit = -1
  end subroutine

end module
