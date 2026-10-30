# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.NoteClipboardTest do
  @moduledoc """
  Marking, copying, cutting, deleting and pasting text in a note (R63;
  User's Guide 14-4 to 14-8): F7 MARK, F3 COPY, F4 CUT, ALT-F4 DELETE,
  F2 PASTE. Without a mark, copy, cut and delete ask Word, Line or All
  text. One piece of text is kept for the session; pasting keeps it.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.TUI.{Render, State, Typing.TextEdit}

  describe "TextEdit" do
    # "Ask Lisa Jones" / "about the budget", the cursor on the L of Lisa
    defp buffer, do: %{TextEdit.new("Ask Lisa Jones\nabout the budget") | row: 0, col: 4}

    test "F7 anchors a mark; the cursor stretches it, either way, over lines" do
      e = TextEdit.toggle_mark(buffer())
      assert TextEdit.marked(e) == ""
      e = Enum.reduce(1..4, e, fn _, e -> elem(TextEdit.handle(e, :right), 1) end)
      assert TextEdit.marked(e) == "Lisa"
      {:ok, e} = TextEdit.handle(e, :down)
      assert TextEdit.marked(e) == "Lisa Jones\nabout th"
      # backwards from the anchor too
      e = %{e | row: 0, col: 0}
      assert TextEdit.marked(e) == "Ask "
      assert TextEdit.toggle_mark(e).mark == nil
    end

    test "taking the marked text out; typing drops the mark first" do
      e = TextEdit.toggle_mark(buffer()) |> Map.put(:col, 9)
      assert {"Lisa ", e2} = TextEdit.take(e, :mark)
      assert TextEdit.text(e2) == "Ask Jones\nabout the budget"
      assert e2.mark == nil
      assert TextEdit.take(TextEdit.toggle_mark(buffer()), :mark) == nil

      {:ok, typed} = TextEdit.handle(e, {:char, "x"})
      assert typed.mark == nil
    end

    test "pasting text of several lines" do
      e = TextEdit.insert(buffer(), "one\ntwo ")
      assert TextEdit.text(e) == "Ask one\ntwo Lisa Jones\nabout the budget"
      assert {e.row, e.col} == {1, 4}
    end
  end

  # the patent's Calls; the first item's note open with two lines, the
  # cursor at the end of the second
  setup do
    db = Agendum.Sample.build(~D[2026-10-08])

    state =
      db
      |> start(height: 30)
      |> press([:down, {:f, 5}, "Ask Lisa Jones", :enter, "about the budget"])

    %{state: state}
  end

  defp note(state), do: TextEdit.text(State.mode(state).edit)

  test "F7 and ← mark text; F3 copies it, F2 pastes it, and again", %{state: state} do
    state = press(state, [{:f, 7}] ++ List.duplicate(:left, 6) ++ [{:f, 3}])
    assert state.last.copied == "budget"
    assert panel(state) =~ "Copied"
    assert State.mode(state).edit.mark == nil

    state = press(state, [:home, {:f, 2}, " ", {:f, 2}])
    assert note(state) == "Ask Lisa Jones\nbudget budgetabout the budget"
  end

  test "F4 cuts the marked text; the note stays open (ESC and F5 close it)", %{state: state} do
    state = press(state, [:up, :home, {:f, 7}, :right, :right, :right, :right, {:f, 4}])
    assert %{type: :note} = State.mode(state)
    assert note(state) == "Lisa Jones\nabout the budget"
    assert state.last.copied == "Ask "
  end

  test "ALT-F4 deletes the marked text, keeping nothing", %{state: state} do
    state = press(state, [{:f, 7}, :left, :left, :left, :left, :left, :left, {:alt_f, 4}])
    # (a note's text loses trailing spaces)
    assert note(state) == "Ask Lisa Jones\nabout the"
    assert state.last.copied == nil
  end

  test "without a mark, copy, cut and delete ask Word, Line or All text", %{state: state} do
    state = press(state, {:f, 4})
    # Agenda's box (checked in Agenda 2.0, 2026-10-25)
    assert %{type: :what_to_copy, action: :cut} = State.mode(state)
    assert screen(state) =~ ~r/What to cut: +Word/
    state = press(state, ["l", :enter])
    assert note(state) == "Ask Lisa Jones"
    assert state.last.copied == "about the budget"
  end

  test "F2 with nothing kept says so", %{state: state} do
    assert state |> press({:f, 2}) |> panel() =~ "Nothing to paste"
  end

  test "the marked text is shown marked", %{state: state} do
    state = press(state, [{:f, 7}, :left, :left, :left])
    line = state |> Render.render() |> Enum.find(&Enum.any?(&1, fn {_, t} -> t =~ "about" end))
    assert {:edit, "get"} in line
  end

  test "MAKEITM and MAKECAT take the marked text", %{state: state} do
    state = press(state, [:up, :end, {:f, 7}] ++ List.duplicate(:left, 10) ++ [{:alt_f, 7}])
    # no Word / Line / All question with a mark
    assert %{type: :note} = State.mode(state)
    assert note(state) == "Ask \nabout the budget"
    assert panel(state) =~ "New item in Calls: Lisa Jones"

    state =
      press(state, [:down, :home, {:f, 7}, :right, :right, :right, :right, :right, {:alt_f, 2}])

    assert %{type: :picker, purpose: {:make_category, "about"}} = State.mode(state)
  end

  describe "in the macro edit screen" do
    setup do
      db = Agendum.Sample.build(~D[2026-10-08])
      {:ok, db, id} = Agendum.Core.add_macro(db, "Water")
      %{state: start(Agendum.Core.set_macro_keys(db, id, "Water the lettuces"))}
    end

    # found by the fuzz test: the macro screen's mode has no search match
    test "copying, cutting and pasting work there too", %{state: state} do
      state = press(state, [{:alt_f, 3}, {:f, 2}])
      assert %{type: :note, target: {:macro, _}} = State.mode(state)

      # Agenda's What to copy box: a letter picks the choice, ENTER takes it
      state = press(state, [{:f, 3}, "a", :enter])
      assert state.last.copied =~ "Water the lettuces"
      state = press(state, {:f, 2})
      assert %{type: :note} = State.mode(state)
    end
  end
end
