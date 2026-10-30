# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.NoteKeysTest do
  @moduledoc "Agenda's accelerator keys in a note (R42; Help: \"Notes: Accelerator Keys\")."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.TUI.{Layout, State}

  setup do
    Process.delete(:effects_seen)
    state = start(Agendum.Sample.build(~D[2026-10-08]), now: ~N[2026-10-08 14:05:00])
    # the first item, below the Calls section head
    %{state: press(state, :down)}
  end

  defp note(state), do: State.mode(state)
  defp text(state), do: Agendum.TUI.Typing.TextEdit.text(note(state).edit)
  defp item_id(state), do: Layout.current_row(state).item.id

  test "ALT-D and ALT-T insert today's date and the time, in the file's format",
       %{state: state} do
    state = press(state, [{:f, 5}, "Called ", {:alt, "d"}, " at ", {:alt, "t"}])
    assert text(state) == "Called 10/08/26 at 2:05pm"

    format = %Agendum.Core.DateFormat{order: :ddmmmyy, clock: 12}
    state = %{state | db: Core.set_date_format(state.db, format)}
    state = press(state, [" ", {:alt, "d"}, " ", {:alt, "t"}])
    assert text(state) =~ "08 Oct 26 2:05pm"
  end

  test "ALT-N saves the note and shows the next item's note; ALT-P goes back",
       %{state: state} do
    first = item_id(state)
    state = press(state, [{:f, 5}, "first note", {:alt, "n"}])
    assert state.db.items[first].note == "first note"

    second = item_id(state)
    refute second == first
    assert %{type: :note, target: {:item, ^second}} = note(state)

    state = press(state, {:alt, "p"})
    assert %{type: :note, target: {:item, ^first}} = note(state)
    assert text(state) == "first note"
  end

  test "ALT-P on the first item beeps and stays in its note", %{state: state} do
    first = item_id(state)
    state = press(state, [{:f, 5}, {:alt, "p"}])
    assert %{type: :note, target: {:item, ^first}} = note(state)
    assert {:sound, :error} in effects()
  end

  test "in the category manager, ALT-N shows the next category's note", %{state: state} do
    # rows: MAIN Entry When Done Calls Priority
    state = press(state, [{:f, 9}, :down, :down, :down, :down, {:f, 5}, "calls", {:alt, "n"}])
    assert note(state).title == "Priority"
    state = press(state, :esc)
    assert %{type: :catmgr} = State.mode(state)
    assert Enum.find(Map.values(state.db.categories), &(&1.name == "Calls")).note == "calls"
  end

  test "ALT-S repeats a single replacement", %{state: state} do
    id = item_id(state)
    state = %{state | db: Core.set_note(state.db, id, "a b a b a", state.today)}

    # Search for a, Replace text Yes, Replace with x, Direction, Ignore case,
    # Global No, Confirm No
    state =
      press(
        state,
        [{:f, 5}, {:alt_f, 6}, "a", :down, " ", :down, "x"] ++
          [:down, :down, :down, :down, " ", :enter]
      )

    assert text(state) == "x b a b a"
    state = press(state, [{:alt, "s"}, {:alt, "s"}])
    assert text(state) == "x b x b x"
    press(state, {:alt, "s"})
    assert {:sound, :error} in effects()
  end

  test "ALT-Q saves the note and quits (asking to save the file)", %{state: state} do
    id = item_id(state)
    state = press(state, [{:f, 5}, "keep this", {:alt, "q"}])
    assert state.db.items[id].note == "keep this"
    assert screen(state) =~ "Save changes before quitting?"
  end

  test "ALT-K shows the ALT keys in a note too, and in turn hides the key map", %{state: state} do
    state = press(state, [{:f, 5}, {:alt, "k"}])
    assert state.key_map == :alt
    state = press(state, List.duplicate({:alt, "k"}, 3))
    refute state.key_map
  end
end
