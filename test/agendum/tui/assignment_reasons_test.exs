defmodule Agendum.TUI.AssignmentReasonsTest do
  @moduledoc """
  The assignment profile (F3 on an item) says why the item is in the
  highlighted category, in the control panel (R67).
  """
  use ExUnit.Case, async: true

  import Agendum.Fixtures
  import Agendum.TUIHelpers

  alias Agendum.Core
  alias Agendum.TUI.{CategoryScreens, State}

  setup do
    db = with_categories(Core.new_file(), [{"People", [], ["Kanga", "Roo"]}, "Calls", "Urgent"])
    {calls, urgent} = {cat(db, "Calls"), cat(db, "Urgent")}
    {:ok, db} = Core.add_condition(db, urgent, calls, :assigned)
    {db, id} = Core.add_item(db, "Ask Kanga about lunch", today())
    db = Core.assign(db, id, calls, today())
    state = db |> start() |> CategoryScreens.open_profile(id)
    %{state: state}
  end

  # the profile with the highlight on a category, by name
  defp on(state, name) do
    mode = State.mode(state)
    rows = CategoryScreens.rows(state, mode)
    index = Enum.find_index(rows, fn {id, _} -> state.db.categories[id].name == name end)
    State.put_mode(state, %{mode | cursor: index})
  end

  test "a text match", %{state: state} do
    assert panel(on(state, "Kanga")) =~ "In Kanga: its text matches"
  end

  test "through a child", %{state: state} do
    assert panel(on(state, "People")) =~ "In People: through Kanga"
  end

  test "a condition, and by hand", %{state: state} do
    assert panel(on(state, "Urgent")) =~ "In Urgent: its condition holds (Calls)"
    assert panel(on(state, "Calls")) =~ "In Calls: assigned by hand, or kept from before"
  end

  test "a date category: the date it holds", %{state: state} do
    assert panel(on(state, "Entry")) =~ "In Entry: dated 2026-10-08"
  end

  test "a category the item is not in says nothing more", %{state: state} do
    refute panel(on(state, "Roo")) =~ "In Roo"
  end

  test "a message comes first", %{state: state} do
    state = state |> on("Kanga") |> State.info("Hello")
    assert panel(state) =~ "Hello"
    refute panel(state) =~ "In Kanga"
  end
end
