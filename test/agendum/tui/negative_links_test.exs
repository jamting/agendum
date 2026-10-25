defmodule Agendum.TUI.NegativeLinksTest do
  @moduledoc "Excludes in Category Properties: negative links (R9, not in Agenda 2.0)."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.Core.Database

  # Meetings is the last category in the manager.
  setup do
    %{state: start(quiet_meetings(Agendum.Sample.build(~D[2026-10-08])))}
  end

  defp cat(state, name), do: hd(Database.find_categories(state.db, name))

  defp open_excludes(state) do
    state |> press([{:f, 9}, :ctrl_end, {:f, 6}]) |> to_setting("Excludes") |> press(" ")
  end

  test "SPACE on a category toggles the negative link; the row lists it", %{state: state} do
    state = state |> open_excludes() |> press(["Calls", :enter, " "])
    {meetings, calls} = {cat(state, "Meetings"), cat(state, "Calls")}
    assert state.db.categories[meetings].excludes == [calls]
    assert state.db.categories[calls].excludes == [meetings]
    assert screen(state) =~ "Categories that may not share items with Meetings"

    # ENTER ended the search; ESC closes the picker, keeping it
    state = press(state, :esc)
    assert screen(state) =~ ~r/Excludes:.*\n.*Calls/

    # ENTER keeps what was set (ESC would cancel it); the category manager
    # shows names only, as Agenda's
    state = press(state, :enter)
    assert state.db.categories[meetings].excludes == [calls]
    refute screen(state) =~ "not with Calls"
  end

  test "ENTER again removes it", %{state: state} do
    state = state |> open_excludes() |> press(["Calls", :enter, " ", " "])
    assert state.db.categories[cat(state, "Meetings")].excludes == []
  end

  test "items in both are reported, and nothing changes", %{state: state} do
    {meetings, calls} = {cat(state, "Meetings"), cat(state, "Calls")}
    item = hd(state.db.item_order)
    db = state.db |> Core.assign(item, meetings) |> Core.assign(item, calls)
    state = %{state | db: db} |> open_excludes() |> press(["Calls", :enter, " "])
    assert state.db.categories[meetings].excludes == []
    assert screen(state) =~ "1 item is in both Meetings and Calls; move it first"
  end

  test "date categories cannot be excluded", %{state: state} do
    state = state |> open_excludes() |> press(["When", :enter, " "])
    assert screen(state) =~ "Only standard categories can exclude each other"
  end
end
