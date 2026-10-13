defmodule Agenda.TUI.SectionColumnsTest do
  @moduledoc """
  Columns per section in the view (R55): each section shows its own
  columns, its item text filling the width they leave; removing a column
  that is in several sections asks which.
  """
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  import Agenda.Fixtures, only: [cat: 2, with_categories: 2]

  alias Agenda.Core
  alias Agenda.Core.{Database, View}

  # Calls with People and When, Follow up with When only, as in Agenda's
  # Activities view (screenshot 42).
  setup do
    db = Core.new_file(view_name: "Activities", section_name: "Calls")
    db = with_categories(db, ["Follow up", "People"])
    [view] = Database.views(db)
    db = Core.add_section(db, view.id, cat(db, "Follow up"), 1)
    db = Core.add_column(db, view.id, cat(db, "People"), {0, 0}, 12, :section)
    {db, _} = Core.add_item(db, "Call the plumber", ~D[2026-10-08], section: cat(db, "Calls"))

    {db, _} =
      Core.add_item(db, "Chase the invoice", ~D[2026-10-08], section: cat(db, "Follow up"))

    %{state: start(db), view_id: view.id}
  end

  defp line_with(state, text),
    do: state |> screen() |> String.split("\n") |> Enum.find(&String.contains?(&1, text))

  defp heads(state, view_id) do
    view = state.db.views[view_id]

    Enum.map(0..1, fn s ->
      view |> View.columns(s) |> Enum.map(&state.db.categories[&1.category_id].name)
    end)
  end

  test "each section shows its own column heads", %{state: state} do
    assert line_with(state, "Calls") =~ "People"
    refute line_with(state, "Follow up") =~ "People"
    assert line_with(state, "Follow up") =~ "When"
  end

  test "a column in every section stays in the same place", %{state: state} do
    position = &(state |> line_with(&1) |> :binary.match("When") |> elem(0))
    assert position.("Calls") == position.("Follow up")
  end

  test "the column cursor moves over the section's own columns", %{state: state} do
    # the item in Follow up: → twice stays on When, its only column
    state = press(state, [:down, :down, :down, :right, :right])
    assert state.col == 1
  end

  test "removing a column in several sections asks which; current section only",
       %{state: state, view_id: v} do
    # When in Calls is the second column there
    state = press(state, [:down, :right, :right, {:f, 10}, "v", "c", "r"])
    assert screen(state) =~ "All sections in view"
    assert screen(state) =~ "Current section only"
    state = press(state, "c")
    assert heads(state, v) == [["People"], ["When"]]
  end

  test "removing a column from all sections, as one undo step", %{state: state, view_id: v} do
    state = press(state, [:down, :right, :right, {:f, 10}, "v", "c", "r", "a"])
    assert heads(state, v) == [["People"], []]
    assert state |> Agenda.TUI.History.undo() |> heads(v) == [["People", "When"], ["When"]]
  end

  test "a column in one section only goes without a question", %{state: state, view_id: v} do
    state = press(state, [:down, :right, {:f, 10}, "v", "c", "r"])
    assert heads(state, v) == [["When"], ["When"]]
  end

  test "MAIN can head a new section", %{state: state} do
    assert press(state, {:alt, "d"}) |> screen() =~ "MAIN"
  end

  test "a new section below gets the linked columns of the one the cursor is in",
       %{state: state, view_id: v} do
    {:ok, db, _} = Core.add_category(state.db, state.db.main_id, "Ideas")
    state = %{state | db: db}
    state = press(state, [{:alt, "d"}, "Ideas", :enter])
    assert state.db.views[v] |> View.columns(1) |> Enum.map(& &1.category_id) == [cat(db, "When")]
  end

  describe "a column head on the section head line (User's Guide 5-22, 5-25)" do
    # Ideas, a third section with no items: its column head is the only
    # place to highlight its column
    setup %{state: state, view_id: v} do
      db = with_categories(state.db, ["Ideas"])
      db = Core.add_section(db, v, cat(db, "Ideas"), 2)
      # rows: Calls, its item, Follow up, its item, Ideas
      %{state: press(%{state | db: db}, [:end])}
    end

    defp highlighted(state) do
      for line <- Agenda.TUI.Render.render(state),
          {:cursor_cell, text} <- line,
          do: String.trim(text)
    end

    test "→ highlights it in an empty section", %{state: state} do
      state = press(state, :right)
      assert state.col == 1
      assert highlighted(state) == ["When"]
    end

    test "DEL removes the column, asking which sections", %{state: state, view_id: v} do
      state = press(state, [:right, :delete])
      assert screen(state) =~ "Current section only"
      state = press(state, "c")
      assert state.db.views[v] |> View.columns(2) == []
      assert state.db.views[v] |> View.columns(1) |> length() == 1
    end

    test "F6 opens Column Properties", %{state: state} do
      state = press(state, [:right, {:f, 6}])
      assert screen(state) =~ "Link with other sections"
    end

    test "F3 replaces the column head", %{state: state, view_id: v} do
      state = press(state, [:right, {:f, 3}, "People", :enter])

      assert state.db.views[v] |> View.columns(2) |> Enum.map(& &1.category_id) ==
               [cat(state.db, "People")]
    end

    test "F2 renames the column head's category", %{state: state} do
      state = press(state, [:right, {:f, 2}])
      assert screen(state) =~ "When cannot be renamed"
      # People, a column head that may be renamed: the first in Calls (the
      # column cursor stays on the first column when the row changes)
      state = press(state, [:home, {:f, 2}, {:ctrl, "u"}, "Contacts", :enter])
      assert state.db.categories[cat(state.db, "Contacts")]
    end

    test "on the section name, DEL still removes the section", %{state: state, view_id: v} do
      state = press(state, :delete)
      assert length(state.db.views[v].sections) == 2
    end
  end
end
