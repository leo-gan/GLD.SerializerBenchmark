module ser_tomlf
  use tomlf, only: toml_table, toml_error, toml_serialize, toml_loads
  use bench_data
  use ser_tree
  implicit none
  private
  public :: tomlf_name, tomlf_version, tomlf_write, tomlf_read

  character(len=*), parameter :: tomlf_name = "toml-f"
  character(len=*), parameter :: tomlf_version = "0.5.2"

contains

  subroutine tomlf_write(items, text, stat)
    type(fixture_t), intent(in) :: items(:)
    character(len=:), allocatable, intent(out) :: text
    integer, intent(out) :: stat
    type(toml_table), allocatable :: table
    call tree_from_fixtures(items, table, stat)
    if (stat /= 0) return
    text = toml_serialize(table)
    if (.not. allocated(text)) stat = 1
  end subroutine

  subroutine tomlf_read(text, expected_n, items, stat)
    character(len=*), intent(in) :: text
    integer, intent(in) :: expected_n
    type(fixture_t), allocatable, intent(out) :: items(:)
    integer, intent(out) :: stat
    type(toml_table), allocatable :: table
    type(toml_error), allocatable :: error
    stat = 0
    call toml_loads(table, text, error=error)
    if (allocated(error) .or. .not. allocated(table)) then
      stat = 1
      return
    end if
    call fixtures_from_tree(table, expected_n, items, stat)
  end subroutine

end module
