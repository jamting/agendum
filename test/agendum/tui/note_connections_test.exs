defmodule Agendum.TUI.NoteConnectionsTest do
  @moduledoc """
  A note's connections to the rest of the file (R64f, NOTE_EDITOR.md step
  6), as Agenda's: ALT-F9 APPEND moves text to the end of the item's text
  (or the category's name), ALT-F8 GETITMS copies the marked items into
  the note, ALT-C types a date chosen in the calendar.
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
    # the cursor at the end; the item "Draft the plan for the website redesign"
    note = press(state, [:down, {:f, 5}])
    %{state: state, note: note, item: State.mode(note).target |> elem(1)}
  end

  defp edit(state), do: State.mode(state).edit
  defp types(state), do: Enum.map(state.modes, & &1.type)

  describe "ALT-F9 APPEND" do
    test "with nothing marked it asks Word, Line or All text", %{note: note} do
      asked = press(note, {:alt_f, 9})
      assert screen(asked) =~ "Append (ALT-F9)"
      assert screen(asked) =~ ~r/Word.*\n.*Line.*\n.*All text/s
    end

    test "the word moves from the note to the end of the item's text, one undo step",
         %{note: note, item: item, state: state} do
      done = press(note, [:ctrl_left, {:alt_f, 9}, :enter])
      assert done.db.items[item].text == "Draft the plan for the website redesign costs."
      assert List.last(edit(done).lines) == "Ask Anna about the hosting"
      assert types(done) == [:note]
      # the message covers the header until the next key; the title has
      # grown (cut with "…" on 80 columns)
      assert screen(press(done, :right)) =~
               "Note for:   Draft the plan for the website redesign cost"

      back = press(done, [{:f, 5}, {:ctrl, "z"}])
      assert back.db.items[item] == state.db.items[item]
    end

    test "marked text is taken as it is", %{note: note, item: item} do
      done = press(note, [:home, :home, {:f, 7}, :ctrl_right, {:alt_f, 9}])
      assert done.db.items[item].text == "Draft the plan for the website redesign Ask"
      assert List.last(edit(done).lines) == " Anna about the hosting costs."
    end

    test "what does not fit in 350 characters stays in the note", %{state: state} do
      # the item's text: 39 characters, a space and 300 more, so 9 fit
      long = String.duplicate("x", 300)
      note = press(state, [:down, {:f, 2}, :end, " " <> long, :enter, {:f, 5}])
      item = State.mode(note).target |> elem(1)
      assert String.length(note.db.items[item].text) == 340
      typed = press(note, [:ctrl_end, :enter, "abcdefghijklmnop", {:alt_f, 9}, :enter])
      assert String.length(typed.db.items[item].text) == 350
      assert String.ends_with?(typed.db.items[item].text, " abcdefghi")
      assert List.last(edit(typed).lines) == "jklmnop"
    end

    test "in a category's note, to the category's name", %{state: state} do
      # the highlight starts on the section head: its category's note
      note = press(state, [{:f, 5}, "Web", {:alt_f, 9}, :enter])
      cat = State.mode(note).target |> elem(1)
      assert note.db.categories[cat].name =~ ~r/ Web$/
    end
  end

  describe "ALT-F8 GETITMS" do
    test "copies the marked items, each with its note, in at the cursor", %{state: state} do
      marked = press(state, [:down, :down, {:f, 7}])
      [id] = Agendum.Core.marked_items(marked.db)
      text = marked.db.items[id].text

      note = press(marked, [:up, {:f, 5}, :ctrl_end, {:alt_f, 8}])
      joined = Enum.join(edit(note).lines, "\n")
      assert joined =~ "costs.\n" <> text
      # the items stay, marked
      assert Agendum.Core.marked_items(note.db) == [id]
    end

    test "with nothing marked it says so", %{note: note} do
      said = press(note, {:alt_f, 8})
      assert {:error, "There are no marked items in the file."} = said.message
      assert edit(said) == edit(note)
    end
  end

  describe "ALT-C" do
    test "the calendar's date is typed at the cursor on ENTER", %{note: note} do
      calendar = press(note, {:alt, "c"})
      assert State.mode(calendar).type == :calendar
      typed = press(calendar, [:right, :enter])
      assert types(typed) == [:note]
      assert List.last(edit(typed).lines) == "Ask Anna about the hosting costs.10/13/26"
    end

    test "ESC types nothing", %{note: note} do
      assert edit(press(note, [{:alt, "c"}, :esc])) == edit(note)
    end
  end
end
