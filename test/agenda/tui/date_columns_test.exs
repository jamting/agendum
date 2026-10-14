defmodule Agenda.TUI.DateColumnsTest do
  @moduledoc """
  A date column's own display format: View ▸ Column ▸ Properties on a date
  column (R41a; User's Guide 6-19 to 6-22).
  """
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.Core
  alias Agenda.TUI.{History, State}

  # Column Properties of a date column: Column head, Category type, Width,
  # Link, then Settings and Display date and/or time (R55, R41a)
  @to_show [{:f, 10}, "v", "c", "p"] ++ List.duplicate(:down, 5)

  @today ~D[2026-10-08]

  # A Calls section with the columns When and People; the cursor starts on
  # "Call Anna"'s When cell.
  setup do
    db = Core.new_file()
    {:ok, db, calls} = Core.add_category(db, db.main_id, "Calls")
    {:ok, db, people} = Core.add_category(db, db.main_id, "People")
    view = hd(db.view_order)
    db = Core.set_section_category(db, view, 0, calls)
    db = Core.add_column(db, view, people, {0, 1})
    {db, _} = Core.add_item(db, "Call Anna tomorrow at 2pm", @today, section: calls)
    state = db |> start() |> press([:down, :right])
    %{state: state, view: view}
  end

  defp column(state, view), do: hd(Agenda.Core.View.columns(state.db.views[view], 0))

  test "opens a box of the date settings, using the global defaults", %{state: state} do
    state = press(state, [{:f, 10}, "v", "c", "p"])
    assert %{type: :column_props} = State.mode(state)
    text = screen(state)
    assert text =~ ~r/Column head: +When +Category type: +Date/
    assert text =~ "Date Column Properties"
    assert text =~ ~r/Settings: +Global defaults/
    assert text =~ ~r/Display date and\/or time: +Date time/
    assert text =~ ~r/Date format: +YYYYMMDD/
    assert text =~ "Formatted Sample"
    assert text =~ "1990-11-13 15:25"
  end

  test "changing a setting makes them the column's own", %{state: state, view: view} do
    # Display date/time -> Date only, then (past Clock, day of week and
    # am/pm) Date format back to Relative
    state = press(state, @to_show ++ [" ", :down, :down, :down, :down, :left, :left])
    assert column(state, view).date.show == :date
    assert column(state, view).date.order == :relative
    assert screen(state) =~ ~r/Settings: +Local settings/

    state = press(state, :enter)
    assert state.modes == []
    assert screen(state) =~ ~r/Tomorrow/
    assert state.db.date_format == %Core.DateFormat{}
  end

  test "Settings goes back to the global defaults", %{state: state, view: view} do
    state = press(state, @to_show ++ [" ", :up, " "])
    assert column(state, view).date == nil
    assert screen(state) =~ ~r/Settings: +Global defaults/
    assert screen(press(state, :esc)) =~ "2026-10-09 14:00"
  end

  test "each change is one undo step", %{state: state, view: view} do
    state = press(state, @to_show ++ [" ", " ", :esc])
    assert column(state, view).date.show == :time_date
    state = History.undo(state)
    assert column(state, view).date.show == :date
  end

  test "the file's format still changes columns using the global defaults", %{state: state} do
    state =
      press(state, [{:f, 10}, "f", "p", :down, " ", " ", :down, :down, " ", :esc, :esc, :esc])

    assert screen(state) =~ "26-10-09 14:00"
  end

  test "Column Properties on a standard column has no date part (R55)", %{state: state} do
    state = press(state, [:right, {:f, 10}, "v", "c", "p"])
    assert %{type: :column_props} = State.mode(state)
    refute screen(state) =~ "Date Column Properties"
  end
end
