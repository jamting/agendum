defmodule Agendum.TUI.NoteEditingKeysTest do
  @moduledoc """
  The note editor's editing keys, as Agenda's (R64e, NOTE_EDITOR.md step
  5): words, the rest of a line, a new line, pages, the start and end of
  the note.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Starters.Planner
  alias Agendum.TUI.State

  @today ~D[2026-10-12]

  setup do
    db = Planner.build() |> Planner.with_samples(@today)
    state = start(db, today: @today, height: 25, width: 80)
    # "Scope, milestones and budget.\nAsk Anna about the hosting costs.",
    # the cursor at the end
    %{note: press(state, [:down, {:f, 5}])}
  end

  defp edit(state), do: State.mode(state).edit
  defp cursor(state), do: {edit(state).row, edit(state).col}
  defp line(state, n), do: Enum.at(edit(state).lines, n)

  test "CTRL-← and CTRL-→ (and ⌥← ⌥→) move by a word", %{note: note} do
    assert cursor(press(note, :ctrl_left)) == {1, 27}
    assert cursor(press(note, {:alt, :left})) == {1, 27}
    assert cursor(press(note, [:ctrl_left, :ctrl_left, :ctrl_right])) == {1, 26}
    assert cursor(press(note, [:home, {:alt, :right}])) == {1, 3}
  end

  test "a word move goes on to the line above or below", %{note: note} do
    assert cursor(press(note, [:home, :home, :ctrl_left])) == {0, 22}
    assert cursor(press(note, [:up, :end, :ctrl_right])) == {1, 3}
  end

  test "⌥⌫ and CTRL-W delete the word before the cursor", %{note: note} do
    assert line(press(note, {:alt, :backspace}), 1) == "Ask Anna about the hosting "
    assert line(press(note, {:ctrl, "w"}), 1) == "Ask Anna about the hosting "
  end

  test "ALT-W deletes the word after the cursor", %{note: note} do
    assert line(press(note, [:home, :home, {:alt, "w"}]), 1) == " Anna about the hosting costs."
  end

  test "CTRL-K deletes to the end of the line", %{note: note} do
    cut = press(note, [:home, :home, :right, :right, :right, :right, {:ctrl, "k"}])
    assert line(cut, 1) == "Ask "
    assert line(press(cut, {:ctrl, "k"}), 1) == "Ask "
  end

  test "ALT-M breaks the line, as ENTER", %{note: note} do
    broken = press(note, [:ctrl_left, {:alt, "m"}])
    assert edit(broken).lines |> Enum.drop(1) == ["Ask Anna about the hosting ", "costs."]
  end

  test "CTRL-HOME and CTRL-END (and ⌥< ⌥>) go to the start and the end of the note",
       %{note: note} do
    assert cursor(press(note, :ctrl_home)) == {0, 0}
    assert cursor(press(note, {:alt, "<"})) == {0, 0}
    assert cursor(press(note, [:ctrl_home, :ctrl_end])) == {1, 33}
    assert cursor(press(note, [:ctrl_home, {:alt, ">"}])) == {1, 33}
  end

  test "PGUP and PGDN move a page of rows" do
    db = Planner.build() |> Planner.with_samples(@today)
    state = start(db, today: @today, height: 12, width: 80)
    typed = Enum.flat_map(1..40, &["line #{&1}", :enter])
    long = press(state, [:down, {:f, 5}] ++ typed ++ [:ctrl_home])
    page = State.body_height(long)

    assert elem(cursor(press(long, :pgdn)), 0) == page
    assert elem(cursor(press(long, [:pgdn, :pgdn, :pgup])), 0) == page
    assert cursor(press(long, :pgup)) == {0, 0}
  end
end
