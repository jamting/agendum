defmodule Agendum.TUI.LineEditingTest do
  @moduledoc """
  Typing a line (an item's text, a box's field, a prompt) as Agenda's
  (User's Guide 3-4; checked in Agenda 2.0, 2026-10-25): F7 MARK starts
  marking at the cursor, F3 COPY and F4 CUT take the marked text (with
  nothing marked, "What to copy": a word or all the text), ALT-F4 DELETE
  takes it without keeping it, F2 PASTE puts in what was copied or cut
  last (the note editor's too); F5 NOTE on an item's text keeps the text
  and opens its note; F1 the help. The key bar names them in their slots.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Starters.Planner
  alias Agendum.TUI.{Layout, State}

  @today ~D[2026-10-12]

  setup do
    db = Planner.build() |> Planner.with_samples(@today)
    %{state: start(db, today: @today, height: 25, width: 80)}
  end

  defp item_named(state, text),
    do: state.db.items |> Map.values() |> Enum.find(&(&1.text == text))

  defp bar(state) do
    state
    |> screen()
    |> String.split("\n")
    |> List.last()
    |> String.split("│")
    |> Enum.map(&String.trim/1)
  end

  test "F7 marks, F3 copies, F2 pastes", %{state: state} do
    state = press(state, [:down, "Hello", {:f, 7}, :left, :left, {:f, 3}, :end, {:f, 2}, :enter])
    assert item_named(state, "Hellolo")
  end

  test "F4 cuts the marked text, F2 puts it back elsewhere", %{state: state} do
    state = press(state, [:down, "Hello world", :home, {:f, 7}])
    state = press(state, List.duplicate(:right, 6) ++ [{:f, 4}, :end, " ", {:f, 2}, :enter])
    assert item_named(state, "world Hello")
  end

  test "ALT-F4 deletes the marked text without keeping it", %{state: state} do
    state = press(state, [:down, "abc", {:f, 7}, :left, {:f, 3}, :end])
    state = press(state, [{:f, 7}, :left, :left, {:alt_f, 4}, {:f, 2}, :enter])
    # "bc" deleted, then the copied "c" pasted
    assert item_named(state, "ac")
  end

  test "with nothing marked, F3 asks what to copy: the word", %{state: state} do
    state = press(state, [:down, "one two", {:f, 3}])
    assert %{type: :choice} = State.mode(state)
    state = press(state, [:enter, " ", {:f, 2}, :enter])
    assert item_named(state, "one two two")
  end

  test "the note editor's copied text pastes into a line", %{state: state} do
    copied = %{state | last: %{state.last | copied: "from a note"}}
    state = press(copied, [:down, "Text ", {:f, 2}, :enter])
    assert item_named(state, "Text from a note")
  end

  test "F5 on an item's text keeps it and opens its note", %{state: state} do
    state = press(state, [:down, "Write the report", {:f, 5}])
    assert %{type: :note} = State.mode(state)
    assert item_named(state, "Write the report")
  end

  test "F1 opens the help, and ESC comes back to the typing", %{state: state} do
    typing = press(state, [:down, "Half typed"])
    help = press(typing, {:f, 1})
    assert %{type: :help} = State.mode(help)
    back = press(help, :esc)
    assert back.edit.line.text == "Half typed"
  end

  test "the key bar while typing an item: Agenda's slots", %{state: state} do
    typing = press(state, [:down, "Hi"])
    assert bar(typing) == ["Help", "Paste", "Copy", "Cut", "Note", "", "Mark", "", "", ""]
  end

  test "the key bar while typing in a box's field: no Note", %{state: state} do
    typing = state |> props(:view) |> press({:f, 2})
    assert bar(typing) == ["Help", "Paste", "Copy", "Cut", "", "", "Mark", "", "", ""]
  end

  test "the marked text shows highlighted while typing", %{state: state} do
    typing = press(state, [:down, "Hello", {:f, 7}, :left, :left])
    row = Layout.current_row(typing)
    assert row
    styles = typing |> Agendum.TUI.Render.render() |> List.flatten()
    assert Enum.any?(styles, &match?({:edit_cursor, "lo"}, &1))
  end
end
