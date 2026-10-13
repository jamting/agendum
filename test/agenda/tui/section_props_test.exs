defmodule Agenda.TUI.SectionPropsTest do
  @moduledoc """
  The Section Properties box (View ▸ Section ▸ Properties, or F6 on a
  section head; R61; Help "Section Properties/Add Box"): the section's
  head, Item sorting, Section statistics, Filter and Columns.
  """
  use ExUnit.Case, async: true

  import Agenda.Fixtures, only: [cat: 2]
  import Agenda.TUIHelpers

  alias Agenda.Core.{Database, View}
  alias Agenda.Starters.Planner
  alias Agenda.TUI.{History, State}

  @today ~D[2026-10-12]

  # the Planner's Activities view with the sample data; the cursor on the
  # Calls section head (People, Phone # and When columns)
  setup do
    db = Planner.build() |> Planner.with_samples(@today)
    view = Enum.find(Database.views(db), &(&1.name == "Activities"))
    state = db |> start(today: @today, width: 100, height: 40) |> State.switch_view(view.id)
    %{state: state, view: view.id}
  end

  defp props(state), do: press(state, [{:f, 10}, "v", "s", "p"])
  defp calls(state, view), do: hd(state.db.views[view].sections)

  defp heads(state, view),
    do:
      Enum.map(
        calls(state, view).columns,
        &(&1.title || state.db.categories[&1.category_id].name)
      )

  test "the box: head, sorting, statistics, filter and the columns with <Items>",
       %{state: state} do
    state = props(state)
    assert %{type: :section_props, sidx: 0} = State.mode(state)
    text = screen(state)
    assert text =~ "Section Properties"
    assert text =~ ~r/Section head +: Calls/
    assert text =~ ~r/Item sorting +: As the view \.\.\./
    assert text =~ ~r/Section statistics +: \.\.\./
    assert text =~ ~r/Filter +: \(none\)/
    # the item column first, then the columns in their order
    assert text =~ ~r/Columns[\s\S]*<Items>[\s\S]*People[\s\S]*Phone #[\s\S]*When/
  end

  test "F6 on a section head opens it, as Agenda's PROPS does; F6 on its head field the category's",
       %{state: state} do
    state = press(state, {:f, 6})
    assert %{type: :section_props} = State.mode(state)
    assert %{type: :props, cat_id: id} = State.mode(press(state, {:f, 6}))
    assert id == cat(state.db, "Calls")
  end

  test "typing a head puts another category at the head, one undo step", %{state: state, view: v} do
    state = props(state) |> press(["Mail", :enter])
    assert calls(state, v).category_id == cat(state.db, "Mail")
    assert screen(state) =~ ~r/Section head +: Mail/
    assert History.undo(state) |> calls(v) |> Map.get(:category_id) == cat(state.db, "Calls")
  end

  test "Item sorting opens the section's sort; Filter the section's filter", %{state: state} do
    state = props(state)
    assert %{type: :sort, scope: {:section, 0}} = state |> press([:down, " "]) |> State.mode()

    assert %{type: :picker, purpose: {:filter, {:section, 0}}} =
             state |> press([:down, :down, :down, :enter]) |> State.mode()
  end

  test "Section statistics: the items in the section", %{state: state} do
    assert state |> props() |> press([:down, :down, " "]) |> panel() =~ "5 items in Calls"
  end

  describe "Columns" do
    # the list's rows come after the four settings: <Items> is the fifth
    defp to_column(state, n),
      do: press(state, List.duplicate(:up, 12) ++ List.duplicate(:down, 4 + n))

    test "DEL removes a column from this section only; <Items> stays", %{state: state, view: v} do
      state = props(state) |> to_column(2) |> press(:delete)
      assert heads(state, v) == ["People", "When"]
      # When is still in the other sections
      assert Enum.at(state.db.views[v].sections, 1).columns |> length() == 1
      assert state |> to_column(0) |> press(:delete) |> panel() =~ "The item column stays"
    end

    test "ALT-↑ ↓ move the highlighted column, the highlight with it", %{state: state, view: v} do
      state = props(state) |> to_column(1) |> press({:alt, :down})
      assert heads(state, v) == ["Phone #", "People", "When"]
      state = press(state, {:alt, :down})
      assert heads(state, v) == ["Phone #", "When", "People"]
      # the item column moves too, as View ▸ Column ▸ Move moves it
      state = state |> to_column(0) |> press({:alt, :down})
      assert View.columns(state.db.views[v], 0) |> length() == 3
      assert hd(state.db.views[v].sections).item_column.position == 1
    end

    test "INS adds a column right of the highlighted one", %{state: state} do
      state = props(state) |> to_column(1) |> press(:insert)
      assert %{type: :column_add, sidx: 0, col: 1} = State.mode(state)
    end
  end

  describe "Select numeric functions (User's Guide 8-10)" do
    # Expense Entry: one section, Expenses, with an Amount column (TOTAL)
    defp expenses(state) do
      view = Enum.find(Database.views(state.db), &(&1.name == "Expense Entry"))
      state |> State.switch_view(view.id) |> press({:f, 6})
    end

    test "only in a section with a numeric column", %{state: state} do
      refute screen(props(state)) =~ "Select numeric functions"
      assert screen(expenses(state)) =~ ~r/Select numeric functions +: \.\.\./
    end

    test "its box switches each calculation for the section, one undo step", %{state: state} do
      # head, sorting, statistics, then Select numeric functions
      state = expenses(state) |> press([:down, :down, :down, " "])
      assert %{type: :numeric_functions, sidx: 0} = State.mode(state)
      assert screen(state) =~ ~r/Count +: No/
      assert screen(state) =~ ~r/Total +: Yes/

      state = press(state, " ")
      assert screen(state) =~ ~r/Count +: Yes/
      assert Agenda.Core.section_calcs(state.db, state.view_id, 0) == [:count, :total]
      # the section shows it at once, behind the boxes
      assert state |> press([:esc, :esc]) |> screen() =~ "COUNT"

      assert History.undo(state) |> then(&Agenda.Core.section_calcs(&1.db, &1.view_id, 0)) == [
               :total
             ]
    end
  end

  test "a datebook view has no sections to set", %{state: state} do
    view = Enum.find(Database.views(state.db), &(&1.name == "Today"))
    state = state |> State.switch_view(view.id) |> props()
    assert panel(state) =~ "A datebook view's sections are its dates"
  end
end
