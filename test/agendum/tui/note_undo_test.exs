# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.NoteUndoTest do
  @moduledoc """
  Undo in the note editor (R64g, ours: Agenda had no undo): CTRL-Z and
  CTRL-Y while the note is open, a word at a time for typing, a run of
  deletions as one step, and a command that changed the file (ALT-F7,
  Clear, a replacement …) undone with the file. Once the note is closed,
  the whole note is one step again, as before (R30).
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.TUI.{Layout, State}

  # the first Call's note open, empty
  setup do
    state =
      Agendum.Sample.build(~D[2026-10-08])
      |> start(height: 30)
      |> press(:down)

    %{kind: :item, item: item} = Layout.current_row(state)
    state = press(state, {:f, 5})
    assert lines(state) == [""]
    %{state: state, id: item.id}
  end

  # the note's lines as typed (`TextEdit.text/1` would trim the spaces)
  defp lines(state), do: Enum.find(state.modes, &(&1.type == :note)).edit.lines
  defp undo(state), do: press(state, {:ctrl, "z"})
  defp redo(state), do: press(state, {:ctrl, "y"})
  defp calls(state), do: for(%{kind: :item, item: i} <- Layout.rows(state), do: i.text)

  test "typing is undone a word at a time, and redone", %{state: state} do
    state = press(state, "Buy milk today")
    state = undo(state)
    assert lines(state) == ["Buy milk "]
    state = undo(state)
    assert lines(state) == ["Buy "]
    state = undo(state)
    assert lines(state) == [""]
    assert panel(undo(state)) =~ "Nothing to undo in this note"

    state = redo(state)
    assert lines(state) == ["Buy "]
    state = state |> redo() |> redo()
    assert lines(state) == ["Buy milk today"]
    assert panel(redo(state)) =~ "Nothing to redo in this note"
  end

  test "a new line ends a word too", %{state: state} do
    state = press(state, ["Call Bob", :enter, "about it"])
    assert lines(undo(state)) == ["Call Bob", "about "]
    assert lines(state |> undo() |> undo()) == ["Call Bob", ""]
    assert lines(state |> undo() |> undo() |> undo()) == ["Call "]
  end

  test "a run of deletions is one step", %{state: state} do
    state = press(state, ["Buy milk", :backspace, :backspace, :backspace, :backspace])
    assert lines(state) == ["Buy "]
    state = undo(state)
    assert lines(state) == ["Buy milk"]
  end

  test "moving the cursor ends a step", %{state: state} do
    state = press(state, ["ab", :left, "c"])
    assert lines(state) == ["acb"]
    assert lines(undo(state)) == ["ab"]
  end

  test "a date typed with ALT-D is a step of its own", %{state: state} do
    state = press(state, ["Seen", {:alt, "d"}])
    assert lines(undo(state)) == ["Seen"]
  end

  test "typing after an undo drops what could be redone", %{state: state} do
    state = state |> press("a b") |> undo() |> press("c")
    assert lines(state) == ["a c"]
    assert panel(redo(state)) =~ "Nothing to redo in this note"
  end

  test "the cursor goes back with the text", %{state: state} do
    state = state |> press(["Hello", :home, "Oh "]) |> undo()
    note = Enum.find(state.modes, &(&1.type == :note))
    assert {note.edit.row, note.edit.col} == {0, 0}
  end

  test "undoing every step leaves the note unchanged: ESC asks nothing", %{state: state, id: id} do
    state = state |> press("Hi there") |> undo() |> undo() |> press(:esc)
    assert state.modes == []
    assert state.db.items[id].note == ""
  end

  test "ALT-F7's new item is undone with the text it took, and redone",
       %{state: state, id: id} do
    state = press(state, ["Call Bob", {:alt_f, 7}, "l"])
    assert lines(state) == [""]
    assert "Call Bob" in calls(state)

    state = undo(state)
    assert lines(state) == ["Call Bob"]
    refute "Call Bob" in calls(state)
    assert %{type: :note} = State.mode(state)

    state = redo(state)
    assert lines(state) == [""]
    assert "Call Bob" in calls(state)

    # the typing before it is still a step of its own
    state = state |> undo() |> undo()
    assert lines(state) == ["Call "]
    assert state.db.items[id].note == ""
  end

  test "Clear is undone in the note, the file too", %{state: state, id: id} do
    state = press(state, ["Keep this", {:f, 10}, "c", :enter])
    assert lines(state) == [""]
    state = undo(state)
    assert lines(state) == ["Keep this"]
    # what was typed is in the file again once the note is closed
    assert press(state, {:f, 5}).db.items[id].note == "Keep this"
  end

  test "a replacement is undone in the note, the file too", %{state: state, id: id} do
    state =
      press(state, [
        "the old one",
        {:alt_f, 6},
        "old",
        :down,
        " ",
        :down,
        "new",
        :down,
        :down,
        :down,
        " ",
        :down,
        " ",
        :enter
      ])

    assert lines(state) == ["the new one"]
    assert state.db.items[id].note == "the new one"

    state = undo(state)
    assert lines(state) == ["the old one"]
    assert press(state, {:f, 5}).db.items[id].note == "the old one"
  end

  test "once closed, one CTRL-Z puts back the whole note, as before", %{state: state, id: id} do
    state = press(state, ["Buy milk today", {:f, 5}])
    assert state.db.items[id].note == "Buy milk today"
    state = undo(state)
    assert state.db.items[id].note == ""
  end

  test "CTRL-Z and CTRL-Y are the note's Undo and Redo commands (F1 lists them)" do
    assert Agendum.TUI.Keymap.lookup(:note, {:ctrl, "z"}) == :undo
    assert Agendum.TUI.Keymap.lookup(:note, {:ctrl, "y"}) == :redo
    assert %{name: "Undo"} = Agendum.TUI.Commands.get(:note, :undo)
    assert %{name: "Redo"} = Agendum.TUI.Commands.get(:note, :redo)
  end
end
