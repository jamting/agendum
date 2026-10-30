# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.ColumnFormatsTest do
  @moduledoc """
  Typing in Star, Yes/No and Category note columns (R56; User's Guide
  5-31 to 5-37): SPACE stars or unstars, Y and N answer, and text typed in
  a Category note column goes into that line of the category's note.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  import Agendum.Fixtures, only: [cat: 2, with_categories: 2]

  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.TUI.History

  # Staff ─ Tom (note "Telephone: 555-1234"); the Tasks section with a
  # Staff column; "Call Tom" in Tom, "Order paper" in nothing. The cursor
  # is on Call Tom's Staff cell.
  setup do
    db = Core.new_file(view_name: "Tasks", section_name: "Tasks")
    db = with_categories(db, [{"Staff", [], ["Tom"]}])
    db = Core.set_category_note(db, cat(db, "Tom"), "Telephone: 555-1234")
    [view] = Database.views(db)
    tasks = cat(db, "Tasks")
    {db, tom_item} = Core.add_item(db, "Call Tom", ~D[2026-10-08], section: tasks)
    db = Core.assign(db, tom_item, cat(db, "Tom"))
    {db, other} = Core.add_item(db, "Order paper", ~D[2026-10-08], section: tasks)
    db = Core.add_column(db, view.id, cat(db, "Staff"), {0, 0}, 16)
    state = db |> start() |> press([:down, :right])
    %{state: state, view_id: view.id, tom_item: tom_item, other: other}
  end

  defp with_format(state, view_id, changes),
    do: %{state | db: Core.set_column_display(state.db, view_id, {0, 0}, changes)}

  defp staff(state), do: cat(state.db, "Staff")

  test "Star: SPACE takes Call Tom out of Staff, and on Order paper stars it",
       %{state: state, view_id: v, tom_item: tom, other: other} do
    state = state |> with_format(v, format: :star) |> press(" ")
    refute Database.member?(state.db, tom, staff(state))
    state = press(state, [:down, " "])
    assert Database.explicit?(state.db, other, staff(state))
    assert screen(state) =~ ~r/Order paper +·\*/
    # one undo step each
    assert History.undo(state).db |> Database.member?(other, staff(state)) == false
  end

  test "Yes/No: N and Y; other letters type a name as usual",
       %{state: state, view_id: v, tom_item: tom, other: other} do
    state = state |> with_format(v, format: :yes_no) |> press("n")
    refute Database.member?(state.db, tom, staff(state))
    assert screen(state) =~ ~r/Call Tom +·N/
    state = press(state, [:down, "Y"])
    assert Database.member?(state.db, other, staff(state))
    state = press(state, ["t", "o", "m", :enter])
    assert Database.explicit?(state.db, other, cat(state.db, "Tom"))
  end

  test "Category note: typing writes that line of Tom's note, after its label",
       %{state: state, view_id: v} do
    state = with_format(state, v, format: :note, title: "Phone")
    state = press(state, ["5", "5", "5", "-", "9", "9", "9", "9", :enter])
    assert state.db.categories[cat(state.db, "Tom")].note == "Telephone: 555-9999"
    assert screen(state) =~ ~r/Call Tom +·555-9999/
    # F2 edits what is there; DEL empties the line
    assert state |> press({:f, 2}) |> Map.fetch!(:edit) |> Map.fetch!(:line) |> Map.fetch!(:text) ==
             "555-9999"

    state = press(state, :delete)
    assert state.db.categories[cat(state.db, "Tom")].note == "Telephone:"
  end

  test "Category note: while typing, the control panel says what the line is",
       %{state: state, view_id: v} do
    state = state |> with_format(v, format: :note, note_line: 2) |> press("5")
    assert panel(state) =~ "Line 2 of the category's note:"
    # an empty line edited with F2 draws too
    assert state |> press(:esc) |> press({:f, 2}) |> panel() =~ "Line 2"
  end

  test "Category note: an item with no category there has no note to write",
       %{state: state, view_id: v} do
    state = state |> with_format(v, format: :note) |> press([:down, "x", :enter])
    assert panel(state) =~ "Order paper has no Staff category"
  end

  test "Star and Yes/No: DEL takes the item out", %{state: state, view_id: v, tom_item: tom} do
    state = state |> with_format(v, format: :yes_no) |> press(:delete)
    refute Database.member?(state.db, tom, staff(state))
  end

  # ours (R73a)
  test "Zettel id: shows the id; typing and DEL say how an id is given",
       %{state: state, view_id: v, tom_item: tom} do
    {:ok, db, _} = Core.attach_zettels(state.db, [tom])
    state = with_format(%{state | db: db}, v, format: :zettel)
    assert screen(state) =~ ~r/Call Tom +·bonalaku/
    assert screen(state) =~ "Zettel id"

    typed = press(state, "x")
    assert typed.db == state.db
    assert screen(typed) =~ "A Zettel id is given by Item ▸ Zettel ▸ Attach"
    assert press(state, :delete).db == state.db
  end
end
