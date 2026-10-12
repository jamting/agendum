defmodule Agenda.TUI.ViewManagerTest do
  @moduledoc """
  Typing in the view manager highlights a view (R53; User's Guide 9-5,
  Starter Applications 1-10): the next view starting with the letter, and
  further letters narrow it down.
  """
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.Core
  alias Agenda.TUI.State

  # views in order: Activities, Calls, Completed This Week, Contacts, Tasks
  setup do
    db = Agenda.Sample.build(~D[2026-10-08])
    section = db.main_id

    db =
      Enum.reduce(["Calls", "Completed This Week", "Contacts", "Tasks"], db, fn name, db ->
        {db, _} = Core.add_view(db, name, [section])
        db
      end)

    %{state: press(start(db), {:f, 8})}
  end

  defp highlighted(state) do
    %{type: :viewmgr, cursor: i} = State.mode(state)
    state.db.views[Enum.at(state.db.view_order, i)].name
  end

  test "a letter highlights the next view starting with it", %{state: state} do
    assert highlighted(press(state, "c")) == "Calls"
    assert highlighted(press(state, "t")) == "Tasks"
    assert highlighted(press(state, "T")) == "Tasks"
  end

  test "more letters narrow it down", %{state: state} do
    assert highlighted(press(state, "co")) == "Completed This Week"
    assert highlighted(press(state, "con")) == "Contacts"
    # BACKSPACE takes a letter back
    assert highlighted(press(state, ["con", :backspace, :backspace])) == "Calls"
  end

  test "the same letter again goes on to the next one, round the list", %{state: state} do
    assert highlighted(press(state, "cc")) == "Completed This Week"
    assert highlighted(press(state, "ccc")) == "Contacts"
    assert highlighted(press(state, "cccc")) == "Calls"
  end

  test "a letter no view starts with leaves the highlight; ENTER shows the view", %{state: state} do
    state = press(state, ["t", "x"])
    assert highlighted(state) == "Tasks"
    assert screen(state) =~ "Find: t"

    state = press(state, :enter)
    assert State.view(state).name == "Tasks"
  end

  test "moving forgets what was typed", %{state: state} do
    state = press(state, ["co", :up, "c"])
    assert highlighted(state) == "Completed This Week"
  end
end
