defmodule Agendum.TUI.BoxCancelTest do
  @moduledoc """
  A settings box as in Agenda (SPEC §5): its frame says "Press ENTER when
  done, ESC to cancel"; ENTER keeps what was changed in it, ESC puts back
  how things were when it opened.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Preferences
  alias Agendum.TUI.{History, State, Update}

  setup do
    %{state: start(Agendum.Sample.build(~D[2026-10-08]), width: 80, height: 25)}
  end

  defp file_props(state), do: press(state, [{:f, 10}, "f", "p"])

  test "the frame says how to finish", %{state: state} do
    assert screen(file_props(state)) =~ "Press ENTER when done, ESC to cancel"
    assert screen(press(state, {:alt_f, 5})) =~ "Press ENTER to accept, ESC to cancel"
  end

  test "ESC puts back what was changed in the box", %{state: state} do
    changed = press(file_props(state), " ")
    assert changed.db.insert_columns == :section

    cancelled = press(changed, :esc)
    assert cancelled.db.insert_columns == :all
    # back to the menu it came from (and not dirty: the file is as it was)
    assert %{type: :menu} = State.mode(cancelled)
    refute cancelled.dirty
  end

  test "ENTER keeps the changes", %{state: state} do
    done = press(file_props(state), [" ", :enter])
    assert done.db.insert_columns == :section
    assert done.modes == []
  end

  test "cancelling is one undo step, so undo brings the changes back", %{state: state} do
    cancelled = press(file_props(state), [" ", :esc, :esc, :esc])
    assert cancelled.db.insert_columns == :all
    assert History.undo(cancelled).db.insert_columns == :section
  end

  test "a box opened from a box cancels only its own changes", %{state: state} do
    state = press(file_props(state), [" ", :down, " "])
    assert %{type: :date_settings} = State.mode(state)
    week_start = state.db.date_settings.week_start

    state = press(state, [:down, :down, " "])
    refute state.db.date_settings.week_start == week_start

    state = press(state, :esc)
    assert %{type: :file_props} = State.mode(state)
    assert state.db.date_settings.week_start == week_start
    # the File Properties change stays until that box is cancelled too
    assert state.db.insert_columns == :section
    assert press(state, :esc).db.insert_columns == :all
  end

  test "ESC while typing in a field drops the typing and stays in the box", %{state: state} do
    state = press(state, [:down, :right, {:f, 10}, "v", "c", "p", "x"])
    assert %{type: :column_props, typing: {:head, _}} = State.mode(state)
    state = press(state, :esc)
    assert %{type: :column_props, typing: nil} = State.mode(state)
  end

  test "your preferences go back too, and are saved as they were", %{state: state} do
    state = %{state | prefs: %Preferences{path: "/prefs"}}
    state = press(state, [{:f, 10}, "f", "c", " "])
    assert state.theme == :mono

    {state, effects} = Update.handle(state, :esc)
    assert state.theme == :classic
    # saved as they were: no theme chosen
    assert [{:save_preferences, "/prefs", %Preferences{path: "/prefs"}}] == effects
  end

  test "ENTER is done in Category Properties; SPACE or F2 edits a field", %{state: state} do
    props = press(state, [{:f, 9}, :down, :down, :down, :down, {:f, 6}])
    assert %{type: :props} = State.mode(props)
    assert press(props, " ").edit != nil
    assert press(props, {:f, 2}).edit != nil
    assert %{type: :catmgr} = State.mode(press(props, :enter))
  end

  test "ENTER is done in Item Properties; F2 edits the text", %{state: state} do
    props = press(state, [:down, {:f, 6}])
    assert %{type: :item_props} = State.mode(props)
    assert press(props, {:f, 2}).edit != nil
    assert State.mode(press(props, :enter)) == nil
  end

  # found by tools/screenshots: View ▸ Add makes the view and opens its
  # settings with one key, so ESC there takes the new view away again
  test "ESC on a new datebook view's settings cancels the view, and shows the one before",
       %{state: state} do
    shown = state.view_id
    views = map_size(state.db.views)
    state = press(state, [{:f, 10}, "v", "a", "This Week", :enter, "d"])
    assert %{type: :datebook_props} = State.mode(state)

    state = press(state, :esc)
    assert map_size(state.db.views) == views
    assert state.view_id == shown
    # back at the View menu (ESC steps back), the view drawn behind it (it crashed here)
    assert %{type: :menu} = State.mode(state)
    assert screen(state) =~ "Set up meeting"
  end
end
