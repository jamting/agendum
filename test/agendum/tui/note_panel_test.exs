defmodule Agendum.TUI.NotePanelTest do
  @moduledoc """
  The note editor's control panel and key bar, as Agenda's (R64a,
  NOTE_EDITOR.md step 1): "Note for:   <title>" on line 1 with the line
  the cursor is on, INS and EDIT on the right; a message over it until
  the next key; the key bar in Agenda's order.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Starters.Planner

  @today ~D[2026-10-12]

  setup do
    db = Planner.build() |> Planner.with_samples(@today)
    state = start(db, today: @today, height: 25, width: 80)
    # the first item, whose note has two lines
    %{note: press(state, [:down, {:f, 5}])}
  end

  defp line(state, n), do: state |> screen() |> String.split("\n") |> Enum.at(n)

  test "line 1 is the header: Note for, then the line, INS and EDIT on the right",
       %{note: note} do
    first = line(note, 0)
    assert first =~ ~r/^ Note for:   Draft the plan for the website redesign +Line +2 INS EDIT$/
    refute first =~ "2026-10-12"
    refute line(note, 1) =~ "Note for"
  end

  test "Line counts the lines of the text, not the rows shown", %{note: note} do
    assert line(press(note, :up), 0) =~ ~r/Line +1 INS EDIT/
  end

  test "a message shows over the header until the next key", %{note: note} do
    # nothing has been copied yet, so F2 says so
    copied = press(note, {:f, 2})
    {_kind, message} = copied.message
    assert line(copied, 0) =~ message
    refute line(copied, 0) =~ "Note for"
    assert line(press(copied, :left), 0) =~ "Note for:"
  end

  test "the key bar is Agenda's: F1 Help, F2 Paste, F3 Copy, F4 Cut, F5 Return, F7 Mark",
       %{note: note} do
    assert slots(note) == "F1 Help F2 Paste F3 Copy F4 Cut F5 Return F7 Mark F10 Menu"
  end

  test "a box over the note shows its own indicator, not the note's", %{note: note} do
    searching = press(note, {:alt_f, 6})
    refute line(searching, 0) =~ "INS EDIT"
  end
end
