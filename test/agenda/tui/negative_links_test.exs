defmodule Agenda.TUI.NegativeLinksTest do
  @moduledoc "Excludes in Category Properties: negative links (R9, not in Agenda 2.0)."
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.Core
  alias Agenda.Core.Database

  # Meetings is the last category in the manager.
  setup do
    %{state: start(quiet_meetings(Agenda.Sample.build(~D[2026-10-08])))}
  end

  defp cat(state, name), do: hd(Database.find_categories(state.db, name))

  defp open_excludes(state) do
    index =
      Enum.find_index(Agenda.TUI.CategoryScreens.Properties.props_fields(), &(&1 == :excludes))

    press(state, [{:f, 9}, :ctrl_end, {:f, 6}] ++ List.duplicate(:tab, index) ++ [" "])
  end

  test "ENTER on a category toggles the negative link; the row lists it", %{state: state} do
    state = state |> open_excludes() |> press(["Calls", :enter])
    {meetings, calls} = {cat(state, "Meetings"), cat(state, "Calls")}
    assert state.db.categories[meetings].excludes == [calls]
    assert state.db.categories[calls].excludes == [meetings]
    assert screen(state) =~ "Categories that may not share items with Meetings"

    # ESC clears the search, ESC closes the picker
    state = press(state, [:esc, :esc])
    assert screen(state) =~ ~r/Excludes:.*\n.*Calls/

    # ENTER keeps what was set (ESC would cancel it)
    state = press(state, :enter)
    assert screen(state) =~ "Meetings   not with Calls"
  end

  test "ENTER again removes it", %{state: state} do
    state = state |> open_excludes() |> press(["Calls", :enter, :enter])
    assert state.db.categories[cat(state, "Meetings")].excludes == []
  end

  test "items in both are reported, and nothing changes", %{state: state} do
    {meetings, calls} = {cat(state, "Meetings"), cat(state, "Calls")}
    item = hd(state.db.item_order)
    db = state.db |> Core.assign(item, meetings) |> Core.assign(item, calls)
    state = %{state | db: db} |> open_excludes() |> press(["Calls", :enter])
    assert state.db.categories[meetings].excludes == []
    assert screen(state) =~ "1 item is in both Meetings and Calls; move it first"
  end

  test "date categories cannot be excluded", %{state: state} do
    state = state |> open_excludes() |> press(["When", :enter])
    assert screen(state) =~ "Only standard categories can exclude each other"
  end
end
