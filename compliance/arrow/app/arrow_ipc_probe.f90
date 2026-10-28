program arrow_ipc_probe
  ! gld-arrow-fortran publishes Arrow C Data export/import only.
  ! This program links that library and prints the version it actually
  ! resolved. It does not parse an IPC byte stream: the module has no
  ! IPC entry point, and forging an ArrowArray from those bytes would
  ! not be a parser.
  use gld_arrow, only: ARROW_VERSION, arrow_host_little_endian
  implicit none
  character(len=8) :: endian

  if (arrow_host_little_endian()) then
    endian = "true"
  else
    endian = "false"
  end if
  write (*, "(A)") "version=" // ARROW_VERSION
  write (*, "(A)") "little_endian=" // trim(endian)
end program arrow_ipc_probe
