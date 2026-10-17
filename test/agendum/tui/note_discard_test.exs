defmodule Agendum.TUI.NoteDiscardTest do
  @moduledoc """
  ESC in a note asks "Discard changes?" as Agenda (R64d, NOTE_EDITOR.md
  step 4; the owner's choice, 2026-10-17): No (the answer shown first)
  saves and goes back, Yes puts the note back as it was opened.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Starters.Planner
  alias Agendum.TUI.State

  @today ~D[2026-10-12]

  setup do
    db = Planner.build() |> Planner.with_samples(@today)
    state = start(db, today: @today, height: 25, width: 80)
    note = press(state, [:down, {:f, 5}])
    item = State.mode(note).target |> elem(1)
    %{state: state, note: note, item: item, text: state.db.items[item].note}
  end

  defp types(state), do: Enum.map(state.modes, & &1.type)

  test "ESC with nothing changed goes back without asking", %{state: state, note: note} do
    back = press(note, :esc)
    assert back.modes == [] and back.db == state.db
  end

  test "ESC after a change asks, No shown first", %{note: note} do
    asked = press(note, ["!", :esc])
    assert screen(asked) =~ ~r/Discard changes\? +No/
    assert types(asked) == [:confirm, :note]
  end

  test "ENTER on No saves and goes back", %{note: note, item: item, text: text} do
    back = press(note, ["!", :esc, :enter])
    assert back.modes == []
    assert back.db.items[item].note == text <> "!"
  end

  test "Yes puts the note back as it was opened", %{state: state, note: note} do
    back = press(note, ["!", :esc, "y"])
    assert back.modes == [] and back.db == state.db
  end

  test "Yes also takes back what was already saved: a replacement, a Clear",
       %{state: state, note: note, item: item, text: text} do
    cleared = press(note, [{:f, 10}, "c", :enter])
    assert cleared.db.items[item].note == ""
    back = press(cleared, [:esc, "y"])
    assert back.modes == []
    assert back.db.items[item].note == text
    assert back.db.items == state.db.items
  end

  test "ESC on the question goes back to the note, as it was", %{note: note} do
    typed = press(note, "!")
    back = press(typed, [:esc, :esc])
    assert types(back) == [:note]
    assert State.mode(back).edit == State.mode(typed).edit
  end

  test "F5 still saves without asking", %{note: note, item: item, text: text} do
    back = press(note, ["!", {:f, 5}])
    assert back.modes == [] and back.db.items[item].note == text <> "!"
  end

  test "in the macro editor too" do
    state = start(Agendum.Sample.build(@today))

    state =
      press(state, [
        {:alt_f, 3},
        :insert,
        "Water",
        :enter,
        {:f, 2},
        "abc",
        :esc
      ])

    assert screen(state) =~ "Discard changes?"
    back = press(state, "y")
    assert Agendum.Core.Database.find_macro(back.db, "Water").keys == ""
  end
end
