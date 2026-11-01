# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.MoveBoxTest do
  @moduledoc """
  ALT-F10 on an item: Agenda's Move box (R26; checked in Agenda 2.0,
  2026-11-01). It lists the view's sections; the item goes last in the one
  chosen, the highlight staying behind; into its own section it stays put;
  a view with one section refuses, pointing to Item ▸ Reposition.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.TUI.{Layout, State}

  # the sample's Activities view with a second section, Meetings, holding
  # two items of its own; the highlight on the first item in Calls
  setup do
    db = Agendum.Sample.build(~D[2026-10-08])
    [view] = Database.views(db)
    meetings = hd(Database.find_categories(db, "Meetings"))
    db = Core.add_section(db, view.id, meetings, 1)

    db =
      Enum.reduce(["Meet Pooh", "Meet Piglet"], db, fn text, db ->
        {db, _} = Core.add_item(db, text, ~D[2026-10-08], section: meetings)
        db
      end)

    %{state: db |> start() |> press(:down), meetings: meetings}
  end

  defp texts(state, sidx) do
    for row <- Layout.rows(state), row.kind == :item, row.sidx == sidx, do: row.item.text
  end

  test "the box lists the sections, the current one first chosen", %{state: state} do
    state = press(state, {:alt_f, 10})
    assert %{type: :move_items, cursor: 0} = State.mode(state)
    text = screen(state)
    assert text =~ "Move"
    assert text =~ "Calls"
    assert text =~ "Meetings"
    assert panel(state) =~ "Highlight the section where you want to move the item"
  end

  test "ENTER on another section moves the item there, last", %{state: state, meetings: m} do
    item = Layout.current_row(state).item
    next = state |> texts(0) |> Enum.at(1)
    there = texts(state, 1)
    state = press(state, [{:alt_f, 10}, :down, :enter])

    assert State.mode(state) == nil
    assert Database.member?(state.db, item.id, m)
    # an item the section already showed (the sample files some under
    # two categories) goes last too
    assert texts(state, 1) == (there -- [item.text]) ++ [item.text]
    refute item.text in texts(state, 0)
    # the highlight stays behind, on the item that followed it
    assert Layout.current_row(state).item.text == next
  end

  test "into its own section the item stays where it is", %{state: state} do
    before = texts(state, 0)
    state = press(state, [{:alt_f, 10}, :enter])
    assert texts(state, 0) == before
    assert state.history.undo == []
  end

  test "ESC moves nothing", %{state: state} do
    moved = press(state, [{:alt_f, 10}, :down, :esc])
    assert moved.db == state.db
    assert State.mode(moved) == nil
  end

  test "marked items go last in the section chosen, in their order", %{state: state} do
    calls = texts(state, 0)
    there = texts(state, 1)
    state = press(state, [{:f, 7}, :down, {:f, 7}, {:alt_f, 10}, "m", :down, :enter])
    moved = Enum.take(calls, 2)
    assert texts(state, 1) == (there -- moved) ++ moved
  end

  test "the key bar: F1 Help alone, as Agenda's", %{state: state} do
    labels = state |> press({:alt_f, 10}) |> screen() |> String.split("\n") |> List.last()
    assert String.trim(String.replace(labels, "│", " ")) == "Help"
  end

  # Agenda's F1: "Agenda arranges marked items in the same order in which
  # you mark them" (checked in Agenda 2.0, 2026-11-01); the order lives in
  # the session, as Agenda kept no marks in the file
  test "marked items go in the order they were marked", %{state: state} do
    [first, second | _] = texts(state, 0)
    there = texts(state, 1)
    # the second item marked first, then the first
    state = press(state, [:down, {:f, 7}, :up, {:f, 7}, {:alt_f, 10}, "m", :down, :enter])
    assert texts(state, 1) == (there -- [first, second]) ++ [second, first]
  end

  test "items marked when the file was opened come first, in the view's order", c do
    [first, second, third | _] = texts(c.state, 0)
    ids = for row <- Layout.rows(c.state), row.kind == :item, row.sidx == 0, do: row.item.id
    state = c.state.db |> Core.set_marked(Enum.take(ids, 2), true) |> start() |> press(:down)
    there = texts(state, 1)
    # the third marked now, after the two the file had
    state = press(state, [:down, :down, {:f, 7}, {:alt_f, 10}, "m", :down, :enter])
    assert texts(state, 1) == (there -- [first, second, third]) ++ [first, second, third]
  end

  test "a view with one section refuses, in Agenda's words" do
    state = Agendum.Sample.build(~D[2026-10-08]) |> start() |> press([:down, {:alt_f, 10}])
    assert State.mode(state) == nil
    assert panel(state) =~ "You can copy or move items only to another section"
  end
end
