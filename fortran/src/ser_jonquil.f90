module ser_jonquil
  use jonquil, only: json_loads, json_dumps, json_error, json_value, cast_to_object
  use tomlf, only: toml_table
  use bench_data
  use ser_tree
  implicit none
  private
  public :: jonquil_name, jonquil_version, jonquil_write, jonquil_read

  character(len=*), parameter :: jonquil_name = "jonquil"
  character(len=*), parameter :: jonquil_version = "0.3.2"

contains

  subroutine jonquil_write(items, text, stat)
    type(fixture_t), intent(in) :: items(:)
    character(len=:), allocatable, intent(out) :: text
    integer, intent(out) :: stat
    type(toml_table), allocatable :: table
    type(json_error), allocatable :: error
    call tree_from_fixtures(items, table, stat)
    if (stat /= 0) return
    call json_dumps(table, text, error=error)
    if (allocated(error) .or. .not. allocated(text)) stat = 1
  end subroutine

  subroutine jonquil_read(text, expected_n, items, stat)
    character(len=*), intent(in) :: text
    integer, intent(in) :: expected_n
    type(fixture_t), allocatable, intent(out) :: items(:)
    integer, intent(out) :: stat
    class(json_value), allocatable :: value
    type(toml_table), pointer :: table
    type(json_error), allocatable :: error
    stat = 0
    call json_loads(value, text, error=error)
    if (allocated(error) .or. .not. allocated(value)) then
      stat = 1
      return
    end if
    table => cast_to_object(value)
    if (.not. associated(table)) then
      stat = 1
      return
    end if
    call fixtures_from_tree(table, expected_n, items, stat)
  end subroutine

end module
