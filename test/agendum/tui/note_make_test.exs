# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.NoteMakeTest do
  @moduledoc """
  In a note (R42; User's Guide 12-8 to 12-9): ALT-F7 MAKEITM makes the
  word, line or all the text at the cursor into a new item, taking it out
  of the note; ALT-F2 MAKECAT makes the word at the cursor into a new
  category under a parent the person picks, leaving the note as it is.
  """
  use ExUnit.Case, async: true

  import Agendum.Fixtures, only: [cat: 2, item_id: 2]
  import Agendum.TUIHelpers

  alias Agendum.Core.Database
  alias Agendum.TUI.{Layout, State, Typing.TextEdit}

  @first "Set up meeting at Terracotta Corp to discuss CopyCat before the end of the month."

  # the patent's Calls; the note of the first item open, holding two
  # lines, the cursor at the end of the second
  setup do
    db = Agendum.Sample.build(~D[2026-10-08])

    state =
      db
      |> start(height: 30)
      |> press([:down, {:f, 5}, "Ask Lisa Jones,", :enter, "about the budget"])

    %{state: state}
  end

  defp note(state), do: TextEdit.text(State.mode(state).edit)
  defp calls(state), do: for(%{kind: :item, item: i} <- Layout.rows(state), do: i.text)

  describe "TextEdit" do
    test "the word at the cursor, or the one just before it" do
      e = TextEdit.new("Ask Lisa Jones, now")
      assert TextEdit.word(%{e | col: 6}) == "Lisa"
      assert TextEdit.word(%{e | col: 3}) == "Ask"
      assert TextEdit.word(%{e | col: 0}) == "Ask"
      assert TextEdit.word(TextEdit.new("")) == nil
    end

    test "taking a word, a line or everything out" do
      e = %{TextEdit.new("Ask Lisa Jones\nabout it") | row: 0, col: 5}
      assert {"Lisa", e2} = TextEdit.take(e, :word)
      assert TextEdit.text(e2) == "Ask Jones\nabout it"
      assert {"Ask Lisa Jones", e3} = TextEdit.take(e, :line)
      assert TextEdit.text(e3) == "about it"
      assert {"Ask Lisa Jones\nabout it", e4} = TextEdit.take(e, :all)
      assert TextEdit.text(e4) == ""
    end
  end

  describe "ALT-F7 MAKEITM" do
    test "asks Word, Line or All text; the line becomes an item below the note's", %{state: state} do
      state = press(state, {:alt_f, 7})
      assert %{type: :choice, kind: :make_item} = State.mode(state)
      assert screen(state) =~ "Make into an item:"

      state = press(state, "l")
      assert %{type: :note} = State.mode(state)
      assert note(state) == "Ask Lisa Jones,"
      assert panel(state) =~ "New item in Calls: about the budget"

      # below the item whose note it is, in Calls
      state = press(state, :esc)
      assert Enum.take(calls(state), 2) == [@first, "about the budget"]

      assert Database.member?(
               state.db,
               item_id(state.db, "about the budget"),
               cat(state.db, "Calls")
             )
    end

    test "ENTER takes the word; the item and the shorter note are one change", %{state: state} do
      undo = length(state.history.undo)
      state = press(state, [{:alt_f, 7}, :enter])
      assert note(state) == "Ask Lisa Jones,\nabout the"
      assert item_id(state.db, "budget")
      assert state.db.items[item_id(state.db, @first)].note == "Ask Lisa Jones,\nabout the"
      assert length(state.history.undo) == undo + 1
    end

    test "text longer than an item can be goes into its note", %{state: state} do
      long = String.duplicate("word ", 80)
      state = press(state, [long, {:alt_f, 7}, "a"])
      item = Enum.find(Database.items(state.db), &String.starts_with?(&1.text, "Ask Lisa"))
      assert String.length(item.text) == 350
      assert item.note != ""
    end

    test "only in a note opened from a view", %{state: state} do
      state = state |> press({:f, 5}) |> press([{:f, 9}, :down, {:f, 5}, "Ideas", {:alt_f, 7}])
      assert panel(state) =~ "ALT-F7 makes items from a note opened in a view"
    end
  end

  describe "ALT-F2 MAKECAT" do
    test "the word becomes a category under the parent picked; the note keeps it",
         %{state: state} do
      state = press(state, [:up, :end, :left, {:alt_f, 2}])
      assert %{type: :picker, purpose: {:make_category, "Jones"}} = State.mode(state)

      state = press(state, ["Contact", :enter])
      assert %{type: :note} = State.mode(state)
      assert note(state) == "Ask Lisa Jones,\nabout the budget"
      jones = cat(state.db, "Jones")
      assert state.db.categories[jones].parent_id == cat(state.db, "Contact")
      assert panel(state) =~ "New category Jones under Contact"
    end

    test "on an empty line there is no word", %{state: state} do
      assert state |> press([:enter, {:alt_f, 2}]) |> panel() =~ "No word at the cursor"
    end
  end
end
