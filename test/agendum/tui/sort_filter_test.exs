defmodule Agendum.TUI.SortFilterTest do
  @moduledoc "Filters (R28) and sorting (R36) from the menu, ALT-F5 and the Sort box."
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

  test "View > Filter: ENTER cycles a category's filter; the view shows it in brackets", %{
    state: state
  } do
    state = press(state, [{:f, 10}, "v", "f", "High", :enter])
    assert %{type: :picker} = State.mode(state)
    assert State.view(state).filter == [{cat(state, "High"), :assigned}]
    state = press(state, [:esc, :esc, :esc, :esc])
    assert state.modes == []
    assert screen(state) =~ "View: Activities [High]"
    assert length(texts(state)) == 1
  end

  test "a section filter shows after the section head", %{state: state} do
    state = press(state, [{:f, 10}, "v", "s", "f", "Abigail", :enter, :enter, :esc, :esc])
    assert screen(state) =~ "Calls [-Abigail Scheer]"
    assert length(texts(state)) == 3
  end

  test "typing into a filtered view assigns the new item to the filter", %{state: state} do
    state =
      press(state, [
        {:f, 10},
        "v",
        "f",
        "High",
        :enter,
        :esc,
        :esc,
        :esc,
        :esc,
        "Call the bank",
        :enter
      ])

    item = Enum.find(Database.items(state.db), &(&1.text == "Call the bank"))
    assert Database.member?(state.db, item.id, cat(state, "High"))
    assert "Call the bank" in texts(state)
  end

  test "View > Order: sort on item text, then reverse the order", %{state: state} do
    state = press(state, [{:f, 10}, "v", "o"])
    assert %{type: :sort} = State.mode(state)
    assert screen(state) =~ "Sort items in all sections"

    state = press(state, " ")
    assert State.view(state).sort == [%SortKey{on: :text}]

    assert hd(texts(state)) ==
             "Call Marketing to arrange a Rapidfire demo for Abigail Scheer this Tuesday."

    state = press(state, [:down, " "])

    assert hd(texts(state)) ==
             "Set up meeting at Terracotta Corp to discuss CopyCat before the end of the month."
  end

  test "Sort on cycles on to Category note, which sorts by a line of the notes",
       %{state: state} do
    db = state.db
    db = Core.set_category_note(db, cat(state, "Anna Lasky"), "Anna Lasky\nZurich")
    db = Core.set_category_note(db, cat(state, "Abigail Scheer"), "Abigail\nAmsterdam")
    db = Core.set_category_note(db, cat(state, "Daniel Fiske"), "Daniel\nMadrid")
    state = %{state | db: db}

    # None -> Item text -> Category (Contact) -> Category note (Contact)
    state = press(state, [{:f, 10}, "v", "o", " ", " ", "Contact", :enter, " "])
    assert screen(state) =~ "Choose the category whose notes to sort by"
    state = press(state, ["Contact", :enter])
    assert State.view(state).sort == [%SortKey{on: {:note, cat(state, "Contact")}}]
    assert screen(state) =~ "Category note: Contact"
    assert screen(state) =~ ~r/Line number\s+: 1/

    # Line number 2 (typed): the towns; Amsterdam (Abigail) first
    state = press(state, [:down, :down, :down, :down, "2"])
    assert hd(State.view(state).sort).line == 2
    assert hd(texts(state)) =~ "Abigail"

    # Category note -> None
    state = press(state, [:up, :up, :up, :up, " "])
    assert State.view(state).sort == []
  end

  describe "sorting section heads" do
    setup %{state: state} do
      view = state.view_id
      db = Core.add_section(state.db, view, cat(state, "Priority"), 1)
      db = Core.add_section(db, view, cat(state, "Contact"), 1)
      %{state: Agendum.TUI.Layout.settle(%{state | db: db})}
    end

    defp heads(state),
      do: for(%{kind: :section, category: c} <- Agendum.TUI.Layout.rows(state), do: c.name)

    test "the view's Sort box sorts the section heads", %{state: state} do
      assert heads(state) == ["Calls", "Contact", "Priority"]
      state = press(state, [{:f, 10}, "v", "o"] ++ List.duplicate(:down, 7))
      assert screen(state) =~ ~r/Section sorting\s+: None/

      # None -> Category order -> Alphabetic
      state = press(state, [" ", " "])
      assert screen(state) =~ ~r/Section sorting\s+: Alphabetic/
      state = press(state, [:down, " "])
      assert screen(state) =~ ~r/Section order\s+: Descending/
      assert heads(state) == ["Priority", "Contact", "Calls"]

      # Alphabetic -> Numeric -> None
      state = press(state, [:up, " ", " "])
      assert State.view(state).section_sort == :none
    end

    test "a section's Sort box has no section rows", %{state: state} do
      refute screen(press(state, [{:f, 10}, "v", "s", "s"])) =~ "Section sorting"
    end

    test "GO TO lists the sections in the order shown", %{state: state} do
      state = %{state | db: Core.set_section_sort(state.db, state.view_id, :alpha, :desc)}
      state = press(state, [{:alt_f, 5}, :enter])

      assert %{kind: :section, category: %{name: "Priority"}} =
               Agendum.TUI.Layout.current_row(state)
    end
  end

  test "sorting on a category uses the category box", %{state: state} do
    state = press(state, [{:f, 10}, "v", "o", " ", " ", "Prio", :enter])
    assert State.view(state).sort == [%SortKey{on: {:category, cat(state, "Priority")}}]
    assert screen(state) =~ "Category: Priority"
    # High first: the Anna Lasky item
    assert hd(texts(state)) =~ "Anna Lasky"
  end

  test "View ▸ Section ▸ Sort opens the section's Sort box, which can use the view's settings",
       %{state: state} do
    state = press(state, [{:f, 10}, "v", "s", "s"])
    assert screen(state) =~ "Sort items in Calls"
    assert screen(state) =~ "As the view (None)"

    state = press(state, [" ", " "])
    assert hd(State.view(state).sections).sort == [%SortKey{on: :text}]
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
