defmodule Agendum.TUI.ColumnAddTest do
  @moduledoc """
  The Column Add box (View ▸ Column ▸ Add; User's Guide 3-15 to 3-18):
  the column head, its width, Position (right or left of the current
  column) and Insert in, which overrides File Properties ▸ Insert new
  columns in for this one column (R55).
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  import Agendum.Fixtures, only: [cat: 2, with_categories: 2]

  alias Agendum.Core
  alias Agendum.Core.{Database, View}
  alias Agendum.TUI.{History, State}

  # Calls and Follow up, each with People and the new file's When (both
  # linked); the cursor on People in Calls, the box open. The box's fields:
  # Column head, Category type, Width, Format (standard), Position, Insert in.
  setup do
    db = Core.new_file(view_name: "Activities", section_name: "Calls")
    db = with_categories(db, ["Follow up", "People", "Priority"])
    [view] = Database.views(db)
    db = Core.add_section(db, view.id, cat(db, "Follow up"), 1)
    db = Core.add_column(db, view.id, cat(db, "People"), {0, 0}, 12)
    {db, _} = Core.add_item(db, "Call the plumber", ~D[2026-10-08], section: cat(db, "Calls"))
    state = db |> start() |> press([:down, :right, {:f, 10}, "v", "c", "a"])
    %{state: state, view_id: view.id}
  end

  defp heads(state, view_id, sidx) do
    state.db.views[view_id]
    |> View.columns(sidx)
    |> Enum.map(&state.db.categories[&1.category_id].name)
  end

  # F3 on Column head, then "pr" finds Priority in the picker
  defp pick_priority(state), do: press(state, [{:f, 3}, "p", "r", :enter])

  test "shows the new column's settings, the file's Insert in first", %{state: state} do
    assert %{type: :column_add} = State.mode(state)
    text = screen(state)
    assert text =~ "Column Add"
    assert text =~ ~r/Column head: +\(F3 to pick\)/
    assert text =~ ~r/Width: +12/
    assert text =~ ~r/Position: +Right of current column/
    assert text =~ ~r/Insert in: +All sections/
  end

  test "F3 picks the head; ENTER adds it right of the current column, in all sections",
       %{state: state, view_id: v} do
    state = pick_priority(state)
    assert %{type: :column_add} = State.mode(state)
    assert screen(state) =~ ~r/Column head: +Priority/
    state = press(state, :enter)
    assert heads(state, v, 0) == ["People", "Priority", "When"]
    assert heads(state, v, 1) == ["People", "Priority", "When"]
    # the highlight is on the new column
    assert state.col == 2
  end

  test "Insert in: Current section adds it to this section only, one undo step",
       %{state: state, view_id: v} do
    state = state |> pick_priority() |> press([:down, :down, :down, :down, " ", :enter])
    assert heads(state, v, 0) == ["People", "Priority", "When"]
    assert heads(state, v, 1) == ["People", "When"]
    assert heads(History.undo(state), v, 0) == ["People", "When"]
  end

  test "Position: Left of current column puts it before", %{state: state, view_id: v} do
    state = state |> pick_priority() |> press([:down, :down, :down, " ", :enter])
    assert heads(state, v, 0) == ["Priority", "People", "When"]
    assert state.col == 1
  end

  test "Width: typed; a date category starts at 16", %{state: state, view_id: v} do
    state = state |> pick_priority() |> press([:down, "1", "3", :enter, :enter])
    assert (state.db.views[v] |> View.columns(0) |> Enum.at(1)).width == 13

    state = press(state, [{:f, 10}, "v", "c", "a", {:f, 3}, "w", "h", "e", "n", :enter])
    assert screen(state) =~ ~r/Width: +16/
  end

  describe "typing the column head (User's Guide 3-17)" do
    test "the name of an existing category makes it the head", %{state: state, view_id: v} do
      state = press(state, ["p", "r", "i"])
      # typed in the control panel, as Agenda's (2026-10-25)
      assert screen(state) =~ ~r/^ Category name: .*\n pri/m
      state = press(state, ["o", "r", "i", "t", "y", :enter])
      assert screen(state) =~ ~r/Column head: +Priority/
      state = press(state, :enter)
      assert heads(state, v, 0) == ["People", "Priority", "When"]
    end

    test "a new name makes a new category", %{state: state, view_id: v} do
      state = press(state, ["P", "h", "o", "n", "e", :enter, :enter])
      assert heads(state, v, 0) == ["People", "Phone", "When"]
    end

    test "ESC leaves the name, not the box", %{state: state} do
      state = press(state, ["x", :esc])
      assert %{type: :column_add} = State.mode(state)
      assert screen(state) =~ ~r/Column head: +\(F3 to pick\)/
    end

    test "a name several categories have asks for the picker", %{state: state} do
      {:ok, db, _} = Core.add_category(state.db, cat(state.db, "Follow up"), "People")
      state = press(%{state | db: db}, ["p", "e", "o", "p", "l", "e", :enter])
      assert panel(state) =~ "Several categories are called people"
    end
  end

  describe "Format (R56)" do
    test "Star: 2 wide, added as a star column", %{state: state, view_id: v} do
      state = state |> pick_priority() |> press([:down, :down, " ", " ", " "])
      assert screen(state) =~ ~r/Format: +Star \(\*\)/
      assert screen(state) =~ ~r/Width: +2 /
      state = press(state, :enter)
      column = state.db.views[v] |> View.columns(0) |> Enum.at(1)
      assert {column.format, column.width} == {:star, 2}
    end

    test "Category note: Line number and a typed Column title", %{state: state, view_id: v} do
      state = state |> pick_priority() |> press([:down, :down] ++ List.duplicate(" ", 5))
      assert screen(state) =~ ~r/Format: +Category note/
      state = press(state, [:down, "2", :enter, :down, "C", "o", "s", "t", :enter])
      assert screen(state) =~ ~r/Column title: +Cost/
      state = press(state, :enter)
      column = state.db.views[v] |> View.columns(0) |> Enum.at(1)
      assert {column.format, column.note_line, column.title} == {:note, 2, "Cost"}
    end

    test "a date column has no Format", %{state: state} do
      state = press(state, [{:f, 3}, "w", "h", "e", "n", :enter])
      refute screen(state) =~ "Format:"
    end
  end

  describe "Category type (User's Guide 3-17)" do
    defp kind(state, name), do: state.db.categories[cat(state.db, name)].kind

    # SPACE goes Standard → Numeric → Date, Agenda's order (checked in
    # Agenda 2.0, 2026-10-25)
    test "a standard head can be made Numeric or Date; ENTER does both, one undo step",
         %{state: state, view_id: v} do
      state = state |> pick_priority() |> press([:right, " ", " "])
      assert screen(state) =~ ~r/Category type: +Date/
      # the width follows the type until it is changed
      assert screen(state) =~ ~r/Width: +16/
      state = press(state, [" ", " "])
      assert screen(state) =~ ~r/Category type: +Numeric/
      assert screen(state) =~ ~r/Width: +12/
      state = press(state, :enter)
      assert kind(state, "Priority") == :numeric
      assert heads(state, v, 0) == ["People", "Priority", "When"]
      state = History.undo(state)
      assert {kind(state, "Priority"), heads(state, v, 0)} == {:standard, ["People", "When"]}
    end

    test "chosen before the head, it stays for a standard head", %{state: state} do
      state = state |> press([:right, " ", :left]) |> pick_priority()
      assert screen(state) =~ ~r/Category type: +Numeric/
    end

    test "when children or items would change, it asks first, as Category Properties does",
         %{state: state} do
      {:ok, db, _} = Core.add_category(state.db, cat(state.db, "Priority"), "High")
      state = %{state | db: db} |> pick_priority() |> press([:right, " ", :enter])
      assert screen(state) =~ "Convert Priority to numeric?"
      state = press(state, "n")
      # nothing changed, and the box is still open
      assert {kind(state, "Priority"), State.mode(state).type} == {:standard, :column_add}
      state = press(state, [:enter, "y"])
      assert kind(state, "Priority") == :numeric
      assert State.mode(state) == nil
    end

    test "a date head stays a date category", %{state: state} do
      state = press(state, [{:f, 3}, "w", "h", "e", "n", :enter, :right, " "])
      assert panel(state) =~ "stays a date category"
      assert screen(state) =~ ~r/Category type: +Date/
    end
  end

  # Zettel ids are an extra (R73a): their format shows only with Extras on
  test "Format's choices are Agenda's while Extras is off", %{state: state} do
    text = state |> to_setting("Format") |> press({:f, 3}) |> screen()
    assert text =~ "Category note"
    refute text =~ "Zettel id"
  end

  test "the box starts with the file's Insert new columns in", %{state: state} do
    db = Core.set_insert_columns(state.db, :section)
    state = %{state | db: db, modes: []} |> press([{:f, 10}, "v", "c", "a"])
    assert screen(state) =~ ~r/Insert in: +Current section/
  end

  test "ENTER without a head opens the picker; ESC adds nothing", %{state: state, view_id: v} do
    picking = press(state, :enter)
    assert %{type: :picker} = State.mode(picking)
    assert screen(picking) =~ "Column Head: select a category"
    # back to the View ▸ Column menu it came from
    state = press(state, :esc)
    assert %{type: :menu} = State.mode(state)
    assert heads(state, v, 0) == ["People", "When"]
  end
end
