defmodule Agenda.TUI.NoteSearchTest do
  @moduledoc "Searching and replacing text in a note: ALT-F6 and ALT-S in a note (R39)."
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.Core
  alias Agenda.TUI.{History, Layout, State}

  @note "Ask the Personnel Division\nthen personnel division again\nPERSONNEL DIVISION"

  setup do
    Process.delete(:effects_seen)
    state = start(Agenda.Sample.build(~D[2026-10-08])) |> press(:down)
    item = Layout.current_row(state).item
    state = %{state | db: Core.set_note(state.db, item.id, @note, state.today)}
    state = %{state | saved_db: state.db}
    %{state: press(state, {:f, 5}), id: item.id}
  end

  defp note(state), do: State.mode(state)
  defp cursor(state), do: {note(state).edit.row, note(state).edit.col}

  test "ALT-F6 in a note opens the Search/Replace box", %{state: state} do
    state = press(state, {:alt_f, 6})
    text = screen(state)
    assert text =~ "Search/Replace in note"
    assert text =~ "Search for"
    assert text =~ "Replace text"
    assert text =~ "Direction"
    assert text =~ "Ignore case"
    refute text =~ "Replace with"
    assert text =~ "SEARCH"
  end

  test "searching moves the cursor to the match; ALT-S finds the next, then beeps",
       %{state: state} do
    # The cursor starts at the end of the note, so the search continues from the top.
    state = press(state, [{:alt_f, 6}, "personnel division", :enter])
    assert %{type: :note} = note(state)
    assert cursor(state) == {0, 8}
    assert screen(state) =~ "continued from the top"

    state = press(state, {:alt, "s"})
    assert cursor(state) == {1, 5}
    state = press(state, {:alt, "s"})
    assert cursor(state) == {2, 0}

    state = press(state, {:alt, "s"})
    assert cursor(state) == {2, 0}
    assert :bell in effects()
    assert screen(state) =~ ~s(No more occurrences of "personnel division")
  end

  test "searching backward, matching case", %{state: state} do
    # Rows: text, replace, direction, ignore case
    state = press(state, [{:alt_f, 6}, "Personnel", :down, :down, " ", :down, " ", :enter])
    assert cursor(state) == {0, 8}
    state = press(state, {:alt, "s"})
    assert cursor(state) == {0, 8}
    assert :bell in effects()
  end

  test "the match is highlighted until the cursor moves", %{state: state} do
    state = press(state, [{:alt_f, 6}, "then", :enter])
    assert note(state).match == {1, 0, 4}
    state = press(state, :right)
    assert note(state).match == nil
  end

  test "no occurrence is reported", %{state: state} do
    state = press(state, [{:alt_f, 6}, "zebra", :enter])
    assert screen(state) =~ ~s(No occurrence of "zebra")
    assert cursor(state) == {2, 18}
  end

  test "Replace text: Yes shows the replacement settings", %{state: state} do
    state = press(state, [{:alt_f, 6}, :down, " "])
    text = screen(state)
    assert text =~ "Replace with"
    assert text =~ "Global replacement"
    assert text =~ "Confirm replacement"
  end

  # Rows with Replace text = Yes: text, replace, replace with, direction,
  # ignore case, global, confirm.
  defp replace_box(state, search, replacement, opts) do
    global = if opts[:global], do: [" "], else: []
    confirm = if opts[:confirm], do: [], else: [" "]

    press(
      state,
      [{:alt_f, 6}, search, :down, " ", :down, replacement, :down, :down, :down] ++
        global ++ [:down] ++ confirm ++ [:enter]
    )
  end

  test "global replacement without confirming replaces every occurrence; one undo reverses it",
       %{state: state, id: id} do
    state = replace_box(state, "personnel division", "Human Resources", global: true)
    assert screen(state) =~ "Replaced 3 occurrences"

    state = press(state, :esc)

    assert state.db.items[id].note ==
             "Ask the Human Resources\nthen Human Resources again\nHuman Resources"

    state = History.undo(state)
    assert state.db.items[id].note == @note
  end

  test "a single replacement replaces the next occurrence only", %{state: state, id: id} do
    state = press(state, [:up, :up, :home])
    state = replace_box(state, "personnel division", "HR", [])
    assert screen(state) =~ "Replaced 1 occurrence"
    state = press(state, :esc)

    assert state.db.items[id].note ==
             "Ask the HR\nthen personnel division again\nPERSONNEL DIVISION"
  end

  test "confirming asks at each occurrence: Y replaces, N skips, ESC stops",
       %{state: state, id: id} do
    state = replace_box(state, "personnel division", "HR", global: true, confirm: true)
    assert note(state).match == {0, 8, 18}
    assert screen(state) =~ "Replace this occurrence? (Y/N, ESC stops)"

    state = press(state, "y")
    assert note(state).match == {1, 5, 18}
    state = press(state, "n")
    assert note(state).match == {2, 0, 18}
    state = press(state, :esc)
    assert note(state).match == nil
    assert screen(state) =~ "Replaced 1 occurrence"

    state = press(state, :esc)

    assert state.db.items[id].note ==
             "Ask the HR\nthen personnel division again\nPERSONNEL DIVISION"
  end

  test "confirming the last occurrence ends the replacement", %{state: state} do
    state = replace_box(state, "personnel division", "HR", global: true, confirm: true)
    state = press(state, ["y", "y", "y"])
    assert note(state).match == nil
    assert note(state).replacing == nil
    assert screen(state) =~ "Replaced 3 occurrences"
  end

  test "the box remembers the last search", %{state: state} do
    state = press(state, [{:alt_f, 6}, "then", :enter, {:alt_f, 6}])
    assert screen(state) =~ ~r"Search for +: then"
  end

  test "an empty search is refused", %{state: state} do
    state = press(state, [{:alt_f, 6}, :enter])
    assert screen(state) =~ "Type what to search for"
  end
end
