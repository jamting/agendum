defmodule Agendum.TUI.ViewPropsTest do
  @moduledoc """
  The View Properties box of a standard view (View ▸ Properties, or F6 in
  the view manager; R78; User's Guide 9-9 to 9-11, Help "View
  Properties/Add/Copy Box"): View name, Item sorting, Section sorting and
  Order, the Hide settings, Section separators, the Sections list, Filter
  and View statistics, laid out as Agenda's (checked in Agenda 2.0,
  2026-10-23).
  """
  use ExUnit.Case, async: true

  import Agendum.Fixtures, only: [cat: 2]
  import Agendum.TUIHelpers

  alias Agendum.Core.Database
  alias Agendum.Starters.Planner
  alias Agendum.TUI.{History, State}
  alias Agendum.TUI.Render.Boxes

  @today ~D[2026-10-12]

  # the Planner's Priorities view: High, Medium, Low and No Priority
  # Assigned, its sections sorted in category order
  setup do
    db = Planner.build() |> Planner.with_samples(@today)
    view = Enum.find(Database.views(db), &(&1.name == "Priorities"))
    state = db |> start(today: @today, width: 100, height: 40) |> State.switch_view(view.id)
    %{state: state, view: view.id}
  end

  defp props(state), do: press(state, [{:f, 10}, "v", "p"])
  defp view(state, id), do: state.db.views[id]

  defp heads(state, id),
    do: Enum.map(view(state, id).sections, &state.db.categories[&1.category_id].name)

  defp highlighted(state), do: Boxes.selected_value(state)

  # the Sections list's entries come after the left column's settings;
  # → from View name goes to the first
  defp to_section(state, n), do: press(state, [:home, :right] ++ List.duplicate(:down, n))

  # sections can be moved only in a view that does not sort them
  defp unsorted(state, id), do: State.run(state, {:set_section_sort, id, :none, :asc})

  test "View ▸ Properties: the view's settings, its sections and filter", %{state: state} do
    state = props(state)
    assert %{type: :view_props} = State.mode(state)
    text = screen(state)
    assert text =~ "View Properties"
    assert text =~ ~r/View name: +Priorities/
    assert text =~ ~r/Item sorting: +\.\.\./
    assert text =~ ~r/Section sorting: +Category order/
    assert text =~ ~r/Order: +Ascending/

    for label <- ~w(empty done dependent inherited),
        do: assert(text =~ ~r/Hide #{label} \w+: +No/)

    assert text =~ ~r/Hide column heads: +No/
    assert text =~ ~r/Section separators: +No/
    assert text =~ ~r/Sections:[\s\S]*High[\s\S]*Medium[\s\S]*Low[\s\S]*No Priority Assigned/
    assert text =~ ~r/Filter: +\(none\)/
    assert text =~ ~r/View statistics: +\.\.\./
    # printing and protection are not in Agendum (SPEC § 6)
    refute text =~ "Named print set"
    refute text =~ "View protection"
  end

  test "Order shows only while Section sorting is not None", %{state: state, view: v} do
    refute state |> unsorted(v) |> props() |> screen() =~ "Order:"
  end

  test "SPACE switches a Hide setting at once, one undo step", %{state: state, view: v} do
    state = state |> props() |> to_setting("Hide done items") |> press(" ")
    assert view(state, v).hide_done
    assert screen(state) =~ ~r/Hide done items: +Yes/
    refute History.undo(state) |> view(v) |> Map.get(:hide_done)
  end

  test "Section sorting goes through Agenda's choices; Order switches", %{state: state, view: v} do
    state = state |> props() |> to_setting("Section sorting")
    state = press(state, " ")
    assert view(state, v).section_sort == :alpha
    assert screen(state) =~ ~r/Section sorting: +Alphabetic/
    # then Numeric, None, and round to Category order
    assert state |> press([" ", " "]) |> view(v) |> Map.get(:section_sort) == :none
    assert state |> press([" ", " ", " "]) |> view(v) |> Map.get(:section_sort) == :category
    state = state |> to_setting("Order") |> press(" ")
    assert view(state, v).section_order == :desc
  end

  test "typing on View name renames the view; F2 edits the name", %{state: state, view: v} do
    state = state |> props() |> press(["Urgent", :enter])
    assert view(state, v).name == "Urgent"
    assert screen(state) =~ ~r/View name: +Urgent/
    state = press(state, [{:f, 2}, :end, " now", :enter])
    assert view(state, v).name == "Urgent now"
    assert History.undo(state) |> view(v) |> Map.get(:name) == "Urgent"
  end

  test "Item sorting opens the view's sort; Filter the view's filter", %{state: state} do
    state = props(state)

    assert %{type: :sort, scope: :view} =
             state |> to_setting("Item sorting") |> press(" ") |> State.mode()

    assert %{type: :picker, purpose: {:filter, :view}} =
             state |> to_setting("Filter") |> press(" ") |> State.mode()
  end

  test "View statistics: a box of the marked items, sections and items, as Agenda's",
       %{state: state} do
    state = state |> props() |> to_setting("View statistics") |> press(" ")
    assert %{type: :view_stats} = State.mode(state)
    text = screen(state)
    assert text =~ "View Statistics"
    assert text =~ ~r/Marked items: +0/
    assert text =~ ~r/Sections in view: +4/
    assert text =~ ~r/Items in view: +\d+/
    # any key goes back to View Properties, as Agenda's "Press any key"
    assert %{type: :view_props} = state |> press("x") |> State.mode()
  end

  test "HOME and END go to the first and the last setting on the screen", %{state: state} do
    state = state |> props() |> press(:end)
    assert Boxes.selected_name(state) == "View statistics"
    assert state |> press(:home) |> Boxes.selected_name() == "View name"
  end

  test "ESC puts back every change made in the box", %{state: state, view: v} do
    before = view(state, v)
    state = state |> props() |> to_setting("Hide done items") |> press(" ")
    state = state |> to_section(1) |> press(:delete) |> press(:esc)
    assert view(state, v) == before
  end

  describe "Sections" do
    test "↓ walks the sections, the last one on to Filter; ↑ from Filter to the first, as Agenda's",
         %{state: state} do
      state = props(state) |> to_section(0)
      assert highlighted(state) == "High"
      state = press(state, :down)
      assert highlighted(state) == "Medium"
      state = press(state, [:down, :down, :down])
      assert Boxes.selected_name(state) == "Filter"
      assert state |> press(:up) |> highlighted() == "High"
    end

    test "typing a name adds a section below the highlighted one, one undo step",
         %{state: state, view: v} do
      state = props(state) |> to_section(0) |> press(["Calls", :enter])
      assert heads(state, v) == ["High", "Calls", "Medium", "Low", "No Priority Assigned"]
      # the new section is highlighted, as in Agenda
      assert highlighted(state) == "Calls"
      assert History.undo(state) |> heads(v) |> length() == 4
    end

    test "INS starts the name of a new section; a new name makes a category",
         %{state: state, view: v} do
      state = props(state) |> to_section(3) |> press([:insert, "Someday", :enter])
      assert List.last(heads(state, v)) == "Someday"
      assert cat(state.db, "Someday")
    end

    test "DEL removes the highlighted section from the view, not the last one",
         %{state: state, view: v} do
      state = props(state) |> to_section(1) |> press(:delete)
      assert heads(state, v) == ["High", "Low", "No Priority Assigned"]
      assert highlighted(state) == "Low"
      state = press(state, [:delete, :delete, :delete])
      assert heads(state, v) == ["High"]
      assert panel(state) =~ "A view needs at least one section"
    end

    test "F6 opens the highlighted section's Section Properties", %{state: state} do
      state = props(state) |> to_section(2) |> press({:f, 6})
      assert %{type: :section_props, sidx: 2} = State.mode(state)
      assert %{type: :view_props} = state |> press(:esc) |> State.mode()
    end

    test "ALT-F10 picks the section up: ↑ ↓ carry it, ENTER puts it down, one undo step",
         %{state: state, view: v} do
      state = state |> unsorted(v) |> props() |> to_section(0) |> press({:alt_f, 10})
      assert panel(state) =~ "Use Up and Down arrow keys to reposition the section"
      state = press(state, [:down, :down])
      # the file changes when it is put down (ADR 0026)
      assert heads(state, v) == ["High", "Medium", "Low", "No Priority Assigned"]
      state = press(state, :enter)
      assert %{type: :view_props} = State.mode(state)
      assert heads(state, v) == ["Medium", "Low", "High", "No Priority Assigned"]
      assert highlighted(state) == "High"
      assert History.undo(state) |> heads(v) |> hd() == "High"
    end

    test "ESC puts the section down where it is, as Agenda's", %{state: state, view: v} do
      state = state |> unsorted(v) |> props() |> to_section(3)
      state = press(state, [{:alt_f, 10}, :up, :esc])
      assert %{type: :view_props} = State.mode(state)
      assert heads(state, v) == ["High", "Medium", "No Priority Assigned", "Low"]
    end

    test "ALT-↑ ↓ move it one place at once (ours)", %{state: state, view: v} do
      state = state |> unsorted(v) |> props() |> to_section(1) |> press({:alt, :up})
      assert heads(state, v) == ["Medium", "High", "Low", "No Priority Assigned"]
      assert highlighted(state) == "Medium"
    end

    test "a view that sorts its sections says so instead of moving one", %{state: state, view: v} do
      state = props(state) |> to_section(0) |> press({:alt_f, 10})
      assert panel(state) =~ "This view sorts its sections"
      assert heads(state, v) == ["High", "Medium", "Low", "No Priority Assigned"]
    end
  end

  describe "F6 in the view manager (User's Guide 9-9)" do
    test "opens the highlighted view's properties; ENTER goes back to the manager",
         %{state: state} do
      shown = state.view_id
      state = press(state, [{:f, 8}, "Projects", {:f, 6}])
      assert %{type: :view_props} = State.mode(state)
      assert screen(state) =~ ~r/View name: +Projects/
      state = state |> to_setting("Hide done items") |> press([" ", :enter])
      assert %{type: :viewmgr} = State.mode(state)
      assert state.view_id == shown
      projects = Enum.find(Database.views(state.db), &(&1.name == "Projects"))
      assert projects.hide_done
    end

    test "on a datebook view, its View Properties with the datebook's settings",
         %{state: state} do
      state = press(state, [{:f, 8}, "Today", {:f, 6}])
      assert %{type: :view_props} = State.mode(state)
      assert screen(state) =~ ~r/Date category: +When/
    end
  end

  # Agenda's (checked in Agenda 2.0, 2026-10-25): a day has Interval, Start
  # at and End at below Period, and no Section sorting
  test "a datebook view's View ▸ Properties holds its datebook settings", %{state: state} do
    today = Enum.find(Database.views(state.db), &(&1.name == "Today"))
    state = state |> State.switch_view(today.id) |> props()
    assert %{type: :view_props} = State.mode(state)
    text = screen(state)
    assert text =~ ~r/Period: +Day/
    assert text =~ ~r/Interval: +Hourly/
    assert text =~ "Start at:"
    assert text =~ "End at:"
    refute text =~ "Section sorting"
    refute text =~ "Sections:"
  end
end
