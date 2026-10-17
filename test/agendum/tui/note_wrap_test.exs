defmodule Agendum.TUI.NoteWrapTest do
  @moduledoc """
  Word wrap in the note editor: a long line is shown on as many rows as it
  needs, wrapping at the rightmost space that fits, without line breaks
  in the text; the cursor moves through the rows on the screen.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.TUI.{Layout, State}

  # 30 wide: the text wraps at 28 characters (a margin and the cursor's column)
  @long "The quick brown fox jumps over the lazy dog and then runs far away"
  @note @long <> "\nshort"

  setup do
    state = start(Agendum.Sample.build(~D[2026-10-08]), width: 30) |> press(:down)
    item = Layout.current_row(state).item
    state = %{state | db: Core.set_note(state.db, item.id, @note, state.today)}
    %{state: press(state, {:f, 5}), id: item.id}
  end

  defp edit(state), do: State.mode(state).edit
  defp cursor(state), do: {edit(state).row, edit(state).col}
  defp rows(state), do: state |> screen() |> String.split("\n")

  test "a long line is shown whole, on several rows, broken after spaces", %{state: state} do
    rows = rows(state)
    assert " The quick brown fox jumps" in Enum.map(rows, &String.trim_trailing/1)
    assert " over the lazy dog and then" in Enum.map(rows, &String.trim_trailing/1)
    assert Enum.any?(rows, &String.starts_with?(&1, " runs far away"))
    assert Enum.any?(rows, &String.starts_with?(&1, " short"))
  end

  test "no line break goes into the text", %{state: state, id: id} do
    state = press(state, [:up, :end, "!", {:f, 5}])
    assert state.db.items[id].note == @long <> "!\nshort"
  end

  test "↑ and ↓ move through the rows on the screen, keeping the column", %{state: state} do
    # the note opens at its end: line 1 ("short"), column 5
    assert cursor(state) == {1, 5}
    # up: the last row of the long line ("runs far away" starts at 53)
    state = press(state, :up)
    assert cursor(state) == {0, 58}
    # up again: the middle row ("over the lazy dog and then " starts at 26)
    state = press(state, :up)
    assert cursor(state) == {0, 31}
    state = press(state, :up)
    assert cursor(state) == {0, 5}
    # and down again, row by row
    state = press(state, :down)
    assert cursor(state) == {0, 31}
    state = press(state, [:down, :down])
    assert cursor(state) == {1, 5}
  end

  test "a shorter row: the cursor goes to its end", %{state: state} do
    # from the end of the middle row (its space, column 26 of it) to the
    # last row, 13 long
    state = press(state, [:up, :up, :end])
    assert cursor(state) == {0, 52}
    state = press(state, :down)
    assert cursor(state) == {0, 66}
  end

  test "↑ and ↓ keep the column through a shorter row", %{state: state} do
    # column 20 of the middle row, then down to the last row (13 long) and
    # on to "short": back up, the column is 20 again
    state = press(state, [:up, :up, :home] ++ List.duplicate(:right, 20))
    assert cursor(state) == {0, 46}
    state = press(state, :down)
    assert cursor(state) == {0, 66}
    state = press(state, :up)
    assert cursor(state) == {0, 46}

    # through the five-character line "short" too
    state = press(state, [:down, :down])
    assert cursor(state) == {1, 5}
    state = press(state, [:up, :up])
    assert cursor(state) == {0, 46}
  end

  test "any other key forgets the column kept", %{state: state} do
    state = press(state, [:up, :up, :home] ++ List.duplicate(:right, 20) ++ [:down])
    assert cursor(state) == {0, 66}
    # a move left: the column is now that of the cursor
    state = press(state, [:left, :up])
    assert cursor(state) == {0, 38}
  end

  test "HOME and END go to the row's ends; pressed again, the line's", %{state: state} do
    state = press(state, [:up, :up])
    assert cursor(state) == {0, 31}
    state = press(state, :home)
    assert cursor(state) == {0, 26}
    state = press(state, :home)
    assert cursor(state) == {0, 0}

    state = press(state, [:down, :end])
    # the row's last character, the space it wraps at
    assert cursor(state) == {0, 52}
    state = press(state, :end)
    assert cursor(state) == {0, String.length(@long)}
    # CTRL-A and CTRL-E as HOME and END
    assert state |> press({:ctrl, "a"}) |> cursor() == {0, 53}
  end

  test "a word wider than the screen is broken at the edge", %{state: state, id: id} do
    word = String.duplicate("x", 40)
    state = press(state, [:enter, word])
    rows = rows(state)
    assert Enum.any?(rows, &(&1 == " " <> String.duplicate("x", 28)))
    assert Enum.any?(rows, &String.starts_with?(&1, " " <> String.duplicate("x", 12)))
    state = press(state, {:f, 5})
    assert state.db.items[id].note == @note <> "\n" <> word
  end

  test "the note scrolls by rows so that the cursor's row shows", %{state: state} do
    state = %{state | height: 6}
    lines = String.duplicate(@long <> "\n", 4) <> "last"

    state = %{
      state
      | modes: [%{State.mode(state) | edit: Agendum.TUI.Typing.TextEdit.new(lines)}]
    }

    assert screen(state) =~ " last"
    state = press(state, List.duplicate(:up, 6))
    assert cursor(state) == {2, 4}
    assert screen(state) =~ "over the lazy dog"
  end
end
