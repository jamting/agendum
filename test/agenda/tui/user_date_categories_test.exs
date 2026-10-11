defmodule Agenda.TUI.UserDateCategoriesTest do
  @moduledoc "Date categories the user makes, in the TUI (R6a; User's Guide 7-2 to 7-4)."
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.Core
  alias Agenda.Core.Database
  alias Agenda.TUI.CategoryScreens

  @today ~D[2026-10-08]

  defp choose_type(state) do
    index = Enum.find_index(CategoryScreens.props_fields(), &(&1 == :type))
    state = Agenda.TUI.State.put_mode(state, %{Agenda.TUI.State.mode(state) | cursor: index})
    press(state, :enter)
  end

  # A Bills section with a Due column, and the items heat and rent; the
  # cursor starts on heat's Due cell.
  setup do
    db = Core.new_file()
    {:ok, db, bills} = Core.add_category(db, db.main_id, "Bills")
    {:ok, db, due} = Core.add_category(db, db.main_id, "Due")
    view = hd(db.view_order)
    db = Core.set_section_category(db, view, 0, bills)

    db =
      Enum.reduce(["heat", "rent"], db, fn text, db ->
        {db, _} = Core.add_item(db, text, @today, section: bills)
        db
      end)

    %{state: start(db), due: due, view: view}
  end

  test "Type offers Numeric and Date; Date converts at once when nothing is affected",
       %{state: state, due: due} do
    state = state |> CategoryScreens.open_props(due) |> choose_type()
    text = screen(state)
    assert text =~ "Category type: Due"
    assert text =~ "Numeric"
    assert text =~ "Date"

    state = press(state, "d")
    assert state.db.categories[due].kind == :date
    assert screen(state) =~ ~r/Type\s+: Date/
  end

  test "with children, it asks first and says what is dropped", %{state: state, due: due} do
    {:ok, db, _} = Core.add_category(state.db, due, "after the meeting")
    state = %{state | db: db} |> CategoryScreens.open_props(due) |> choose_type() |> press("d")

    assert screen(state) =~
             "Make Due a date category? children become dates; dropped: after the meeting (Y/N)"

    state = press(state, "y")
    assert state.db.categories[due].kind == :date
  end

  test "a date column of it takes a date and a time", %{state: state, due: due, view: view} do
    {:ok, db} = Core.make_date(state.db, due, @today)
    db = Core.add_column(db, view, due, 1, 16)
    state = %{state | db: db} |> press([:down, :right, :right, "next friday 3pm", :enter])

    heat = Enum.find(Map.values(state.db.items), &(&1.text == "heat")).id
    assert Database.item_date(state.db, heat, due) == ~D[2026-10-16]
    assert screen(state) =~ ~r/heat\s+2026-10-16 15:00/
  end
end
