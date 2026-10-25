defmodule Agendum.TUI.SortFilterTest do
  @moduledoc """
  Filters (R28) and sorting (R36) from View and Section Properties, ALT-F5
  and the Sort box.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.Core.View.SortKey
  alias Agendum.TUI.State

  setup do
    %{state: start(Agendum.Sample.build(~D[2026-10-08]))}
  end

  defp cat(state, name), do: hd(Database.find_categories(state.db, name))

  defp texts(state) do
    state.db
    |> Agendum.Core.ViewModel.build(State.view(state))
    |> hd()
    |> Map.get(:rows)
    |> Enum.map(& &1.item.text)
  end

  test "View Properties ▸ Filter: SPACE cycles a category's filter; the view shows it in brackets",
       %{
         state: state
       } do
    state = state |> filter_picker(:view) |> press(["High", :enter, " "])
    assert %{type: :picker} = State.mode(state)
    assert State.view(state).filter == [{cat(state, "High"), :assigned}]
    state = close_props(state)
    assert state.modes == []
    assert screen(state) =~ "View: Activities [High]"
    assert length(texts(state)) == 1
  end

  test "a section filter shows after the section head", %{state: state} do
    state =
      state |> filter_picker(:section) |> press(["Abigail", :enter, " ", " "]) |> close_props()

    assert screen(state) =~ "Calls [-Abigail Scheer]"
    assert length(texts(state)) == 3
  end

  test "typing into a filtered view assigns the new item to the filter", %{state: state} do
    state =
      state
      |> filter_picker(:view)
      |> press(["High", :enter, " "])
      |> close_props()
      |> press(["Call the bank", :enter])

    item = Enum.find(Database.items(state.db), &(&1.text == "Call the bank"))
    assert Database.member?(state.db, item.id, cat(state, "High"))
    assert "Call the bank" in texts(state)
  end

  # Agenda's Item Sorting box (checked in Agenda 2.0, 2026-10-25): Sort new
  # items, then a Primary and a Secondary sort key, each showing only the
  # settings that apply to what it sorts on
  test "View Properties ▸ Item sorting: Agenda's box; sort on item text, then reverse it",
       %{state: state} do
    state = sort_box(state, :view)
    assert %{type: :sort} = State.mode(state)
    text = screen(state)
    assert text =~ "Item Sorting in All Sections"
    assert text =~ ~r/Sort new items: +When item is entered/
    assert text =~ "Primary sort key"
    assert text =~ "Secondary sort key"
    assert length(Regex.scan(~r/Sort on: +None/, text)) == 2
    refute text =~ "Order:"
    refute text =~ "Section sorting"

    state = press(state, " ")
    assert State.view(state).sort == [%SortKey{on: :text}]
    assert screen(state) =~ ~r/Order: +Ascending +Sort n\/a's: +Bottom of section/
    refute screen(state) =~ "Category:"

    assert hd(texts(state)) ==
             "Call Marketing to arrange a Rapidfire demo for Abigail Scheer this Tuesday."

    state = state |> to_setting("Order") |> press(" ")

    assert hd(texts(state)) ==
             "Set up meeting at Terracotta Corp to discuss CopyCat before the end of the month."
  end

  test "Sort on goes on to Category (its own row) and Category note, keeping the category",
       %{state: state} do
    db = state.db
    db = Core.set_category_note(db, cat(state, "Anna Lasky"), "Anna Lasky\nZurich")
    db = Core.set_category_note(db, cat(state, "Abigail Scheer"), "Abigail\nAmsterdam")
    db = Core.set_category_note(db, cat(state, "Daniel Fiske"), "Daniel\nMadrid")
    state = %{state | db: db}

    # None -> Item text -> Category: no category yet, so the box opens
    state = state |> sort_box(:view) |> press([" ", " "])
    assert %{type: :picker} = State.mode(state)
    state = press(state, ["Contact", :enter])
    assert State.view(state).sort == [%SortKey{on: {:category, cat(state, "Contact")}}]
    text = screen(state)
    assert text =~ ~r/Sort on: +Category /
    assert text =~ ~r/Category: +Contact/
    assert text =~ ~r/Sequence: +Category hierarchy/

    # Category -> Category note, the same category; Line number beside it
    state = state |> to_setting("Sort on") |> press(" ")
    assert State.view(state).sort == [%SortKey{on: {:note, cat(state, "Contact")}}]
    assert screen(state) =~ ~r/Sort on: +Category note +Line number:1/

    # Line number 2 (typed): the towns; Amsterdam (Abigail) first
    state = state |> to_setting("Line number") |> press("2")
    assert hd(State.view(state).sort).line == 2
    assert hd(texts(state)) =~ "Abigail"

    # Category note -> None -> Item text -> Category: Contact again, no box
    state = state |> to_setting("Sort on") |> press(" ")
    assert State.view(state).sort == []
    state = press(state, [" ", " "])
    assert %{type: :sort} = State.mode(state)
    assert hd(State.view(state).sort).on == {:category, cat(state, "Contact")}
  end

  test "a date category has no Sequence; SPACE on Category picks another", %{state: state} do
    state = state |> sort_box(:view) |> press([" ", " ", "When", :enter])
    refute screen(state) =~ "Sequence:"

    # Category is two rows below Sort on (to_setting would take the Order
    # row, whose line above reads "Category")
    state = press(state, [:home, :down, :down, " "])
    assert %{type: :picker} = State.mode(state)
    state = press(state, ["Prio", :enter])
    assert State.view(state).sort == [%SortKey{on: {:category, cat(state, "Priority")}}]
    # High first: the Anna Lasky item
    assert hd(texts(state)) =~ "Anna Lasky"
  end

  test "the Secondary sort key has the same settings", %{state: state} do
    state = state |> sort_box(:view) |> press(" ")
    # the last setting is the secondary key's Sort on
    state = press(state, [:end, " "])
    assert [%SortKey{on: :text}, %SortKey{on: :text}] = State.view(state).sort
    state = press(state, [:end, " "])
    assert [_, %SortKey{na: :top}] = State.view(state).sort
  end

  test "the secondary key needs a primary one", %{state: state} do
    state = state |> sort_box(:view) |> press([:end, " "])
    assert State.view(state).sort == []
    assert screen(state) =~ "Choose what to sort on first"
  end

  test "Section Properties ▸ Item sorting: (View default) until changed; ALT-F8 goes back",
       %{state: state} do
    state = sort_box(state, :section)
    assert screen(state) =~ "Item Sorting in Current Section"
    assert screen(state) =~ ~r/Primary sort key +\(View default\)/
    assert screen(state) =~ ~r/Secondary sort key \(View default\)/

    state = press(state, " ")
    assert hd(State.view(state).sections).sort == [%SortKey{on: :text}]
    refute screen(state) =~ "(View default)"

    state = press(state, {:alt_f, 8})
    assert hd(State.view(state).sections).sort == nil
    assert screen(state) =~ "(View default)"
  end

  describe "sorting section heads" do
    setup %{state: state} do
      view = state.view_id
      db = Core.add_section(state.db, view, cat(state, "Priority"), 1)
      db = Core.add_section(db, view, cat(state, "Contact"), 1)
      %{state: Agendum.TUI.Layout.settle(%{state | db: db})}
    end

    test "the sort box has no section rows: View Properties sorts the heads",
         %{state: state} do
      refute state |> sort_box(:view) |> screen() =~ "Section sorting"
      refute state |> sort_box(:section) |> screen() =~ "Section sorting"
      assert state |> props(:view) |> screen() =~ "Section sorting"
    end

    test "GO TO lists the sections in the order shown", %{state: state} do
      state = %{state | db: Core.set_section_sort(state.db, state.view_id, :alpha, :desc)}
      state = press(state, [{:alt_f, 5}, :enter])

      assert %{kind: :section, category: %{name: "Priority"}} =
               Agendum.TUI.Layout.current_row(state)
    end
  end

  test "ALT-F5 in the category manager sorts a family alphabetically", %{state: state} do
    # rows: MAIN Entry When Done Calls Priority
    state = press(state, [{:f, 9}] ++ List.duplicate(:down, 5) ++ [{:alt_f, 5}, "y"])

    names =
      Enum.map(
        state.db.categories[cat(state, "Priority")].children,
        &state.db.categories[&1].name
      )

    assert names == ["High", "Low", "Medium"]
  end

  test "ALT-F5 in the view manager sorts the views", %{state: state} do
    state =
      press(state, [{:f, 8}, :insert, "Agenda", :enter, "Calls", :enter, {:f, 8}, {:alt_f, 5}])

    assert state.db |> Database.views() |> Enum.map(& &1.name) == ["Activities", "Agenda"]
  end
end
