defmodule Agendum.TUI.ViewManagerBoxTest do
  @moduledoc """
  The view manager as a box over the view, as Agenda's (screenshot 40): the
  views' names, * before a datebook view, "Press ENTER when done, ESC to
  cancel".
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.TUI.{Render, State}

  setup do
    db = Agendum.Sample.build(~D[2026-10-08])
    {db, _} = Core.add_view(db, "Calls", [db.main_id])
    {:ok, db, _} = Core.add_datebook_view(db, "This Week", %Agendum.Core.Datebook{})
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

  # R68: the current view keeps a marker of its own, wherever the highlight is
  test "► marks the current view, apart from the datebook *", %{state: state} do
    # the marker is an extra (R77)
    refute state |> press({:f, 8}) |> screen() =~ "►"
    state = put_in(state.prefs.extras, true) |> press({:f, 8})
    assert screen(state) =~ ~r/► +Activities/
    state = press(state, [:down, :down])
    # the highlight moved; the marker stayed on the view shown
    assert screen(state) =~ ~r/► +Activities/
    refute screen(state) =~ ~r/► *\*? *Calls/
    assert screen(state) =~ ~r/ \* This Week/

    # another view shown, the marker goes with it
    state = press(state, [:enter, {:f, 8}])
    assert screen(state) =~ ~r/►\* This Week/
  end

  describe "listed by recently used (F5, R68)" do
    # an extra (R77)
    setup %{state: state}, do: %{state: put_in(state.prefs.extras, true)}

    # the views by name, in the order the list shows them
    defp listed(state) do
      for line <- String.split(screen(state), "\n"),
          [_, name] <- [Regex.run(~r/│ [ ↑↓] [ ►][ *] (\S[^│]*?)\s*│/u, line)],
          do: name
    end

    test "F5 lists the views shown last first, and back; the file's order stays", %{
      state: state
    } do
      order = state.db.view_order
      # show This Week, then Calls
      state = press(state, [{:f, 8}, :end, :enter, {:f, 8}, :up, :enter])
      assert State.view(state).name == "Calls"

      state = press(state, {:f, 8})
      assert listed(state) == ["Activities", "Calls", "This Week"]
      state = press(state, {:f, 5})
      assert screen(state) =~ "View Manager: recently used"
      assert listed(state) == ["Calls", "This Week", "Activities"]
      # the highlight stayed on the view shown
      assert State.view(press(state, :enter)).name == "Calls"
      assert state.db.view_order == order

      state = press(state, {:f, 5})
      assert listed(state) == ["Activities", "Calls", "This Week"]
    end

    test "ALT-N keeps the file's order", %{state: state} do
      state = press(state, [{:f, 8}, :end, :enter, {:f, 8}, {:f, 5}, :esc])
      assert State.view(state).name == "This Week"
      assert State.view(press(state, {:alt, "n"})).name == "Activities"
    end

    test "moving and sorting views wait for your own order", %{state: state} do
      state = press(state, [{:f, 8}, {:f, 5}, :down])
      order = state.db.view_order

      for key <- [{:alt, :down}, {:alt, :up}, {:alt_f, 5}] do
        moved = press(state, key)
        assert moved.db.view_order == order
        assert screen(moved) =~ "Listed by recently used: F5 shows your order"
      end
    end

    test "the order is kept with where you left the file, and saved at once", %{state: state} do
      prefs = %Agendum.Preferences{path: "/p/preferences", extras: true}
      state = %{state | path: "/p/x.agendum", prefs: prefs}
      {state, effects} = Agendum.TUI.Update.handle(press(state, {:f, 8}), {:f, 5})
      assert [{:save_preferences, "/p/preferences", saved}] = effects
      assert Agendum.Preferences.place(saved, "/p/x.agendum").by_recent

      again = start(state.db, path: "/p/x.agendum", prefs: saved)
      assert again.views.by_recent
    end

    test "starts off", %{state: state} do
      refute state.views.by_recent
      assert screen(press(state, {:f, 8})) =~ "F5 Recent"
    end
  end
end
