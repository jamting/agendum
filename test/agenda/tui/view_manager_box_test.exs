defmodule Agenda.TUI.ViewManagerBoxTest do
  @moduledoc """
  The view manager as a box over the view, as Agenda's (screenshot 40): the
  views' names, * before a datebook view, "Press ENTER when done, ESC to
  cancel".
  """
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.Core
  alias Agenda.TUI.{Render, State}

  setup do
    db = Agenda.Sample.build(~D[2026-10-08])
    {db, _} = Core.add_view(db, "Calls", [db.main_id])
    {:ok, db, _} = Core.add_datebook_view(db, "This Week", %Agenda.Core.Datebook{})
    %{state: start(db, width: 80, height: 25)}
  end

  defp styles(state),
    do: for(line <- Render.render(state), {style, _} <- line, uniq: true, do: style)

  test "F8 opens a box over the view, with the views' names", %{state: state} do
    state = press(state, {:f, 8})
    text = screen(state)
    assert text =~ "View Manager"
    assert text =~ "Activities"
    assert text =~ "Calls"
    # a datebook view is starred
    assert text =~ ~r/\* This Week/
    assert text =~ "Press ENTER when done, ESC to cancel"
    # the view is behind it, faded, as behind any box
    assert :backdrop in styles(state)
  end

  test "the control panel says what to do, as Agenda's", %{state: state} do
    assert panel(press(state, {:f, 8})) =~ "To display a view, highlight the view name"
  end

  test "ENTER shows the highlighted view; ESC goes back to the one shown", %{state: state} do
    shown = state.view_id
    state = press(state, [{:f, 8}, :down])
    assert State.view(press(state, :enter)).name == "Calls"

    back = press(state, :esc)
    assert back.modes == []
    assert back.view_id == shown
  end

  test "F4 discards the highlighted view, as DEL does (after asking)", %{state: state} do
    state = press(state, [{:f, 8}, :down, {:f, 4}])
    assert screen(state) =~ "Discard view Calls?"
    state = press(state, "y")
    refute Enum.any?(Map.values(state.db.views), &(&1.name == "Calls"))
  end

  test "a long list scrolls, with an arrow where it goes on", %{state: state} do
    db =
      Enum.reduce(1..30, state.db, fn n, db ->
        {db, _} = Core.add_view(db, "View #{n}", [db.main_id])
        db
      end)

    state = press(%{state | db: db}, {:f, 8})
    assert screen(state) =~ "↓"
    state = press(state, :end)
    assert screen(state) =~ "View 30"
    assert screen(state) =~ "↑"
  end
end
