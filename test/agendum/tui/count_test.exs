defmodule Agendum.TUI.CountTest do
  @moduledoc """
  A count typed with ALT-digits before a command in a view (R65, ADR 0033;
  Emacs's numeric prefix): commands that take a count run that many
  times, others once; a repeat that changes nothing stops.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Starters.Planner
  alias Agendum.TUI.{Layout, State}

  @today ~D[2026-10-12]

  setup do
    db = Planner.build() |> Planner.with_samples(@today)
    %{state: start(db, today: @today, height: 60)}
  end

  defp count(digits), do: for(d <- String.graphemes(digits), do: {:alt, d})

  test "ALT-3 ↓ moves three rows down, as ↓ three times", %{state: state} do
    assert press(state, count("3") ++ [:down]).cursor ==
             press(state, [:down, :down, :down]).cursor

    assert press(state, count("3") ++ [:down]).cursor == state.cursor + 3
  end

  test "two digits make a two-digit count, shown in the control panel", %{state: state} do
    shown = press(state, count("12"))
    assert screen(shown) =~ "Count: 12"
    assert press(shown, :down).cursor == min(state.cursor + 12, length(Layout.rows(state)) - 1)
  end

  test "the count goes after one command", %{state: state} do
    moved = press(state, count("3") ++ [:down, :down])
    assert moved.cursor == state.cursor + 4
    refute screen(moved) =~ "Count:"
  end

  test "a count past the end stops at the last row", %{state: state} do
    last = length(Layout.rows(state)) - 1
    assert press(state, count("999") ++ [:down]).cursor == last
  end

  test "counts stop at 999", %{state: state} do
    assert screen(press(state, count("12345"))) =~ "Count: 999"
  end

  test "ALT-0 alone starts no count", %{state: state} do
    zero = press(state, count("0"))
    refute screen(zero) =~ "Count:"
    assert press(zero, :down).cursor == state.cursor + 1
  end

  test "ESC drops the count", %{state: state} do
    assert press(state, count("3") ++ [:esc, :down]).cursor == state.cursor + 1
  end

  test "a command that takes no count runs once", %{state: state} do
    on_item = press(state, :down)
    marked = press(on_item, count("3") ++ [{:f, 7}])
    assert length(Agendum.Core.marked_items(marked.db)) == 1
  end

  test "typing after a count types the character once", %{state: state} do
    typing = press(state, [:down] ++ count("3") ++ ["x"])
    assert typing.edit.line.text == "x"
  end

  test "ALT-2 ALT-N shows the view two further on, as ALT-N twice", %{state: state} do
    twice = press(state, [{:alt, "n"}, {:alt, "n"}])
    assert press(state, count("2") ++ [{:alt, "n"}]).view_id == twice.view_id
  end

  test "a repeat that reports an error stops: no marked items", %{state: state} do
    jumped = press(state, count("5") ++ [{:alt, "j"}])
    assert jumped.cursor == state.cursor
    assert screen(jumped) =~ "No marked items"
  end

  test "the count is not undone and is not a change to the file", %{state: state} do
    assert press(state, count("3")).db == state.db
    assert %State{count: nil} = press(state, count("3") ++ [:down])
  end
end
