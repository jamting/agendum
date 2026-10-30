# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.UserDateCategoriesTest do
  @moduledoc "Date categories the user makes, in the TUI (R6a; User's Guide 7-2 to 7-4)."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.TUI.CategoryScreens

  @today ~D[2026-10-08]

  defp choose_type(state) do
    state |> to_setting("Type") |> press(" ")
  end

  # A Bills section with a Due column, and the items heat and rent; the
  # cursor starts on heat's Due cell.
  setup do
    db = Core.new_file()
    {:ok, db, bills} = Core.add_category(db, db.main_id, "Bills")
    {:ok, db, due} = Core.add_category(db, db.main_id, "Due")
    view = hd(db.view_order)
    db = Core.set_section_category(db, view, 0, bills)

    db =
      Enum.reduce(["heat", "rent"], db, fn text, db ->
        {db, _} = Core.add_item(db, text, @today, section: bills)
        db
      end)

    %{state: start(db), due: due, view: view}
  end

  test "Type offers Numeric and Date; Date converts at once when nothing is affected",
       %{state: state, due: due} do
    state = state |> CategoryScreens.open_props(due) |> choose_type()
    text = screen(state)
    assert text =~ "Category type: Due"
    assert text =~ "Numeric"
    assert text =~ "Date"

    state = press(state, "d")
    assert state.db.categories[due].kind == :date
    assert screen(state) =~ ~r/Type: +Date/
  end

  # the settings TAB reaches from the first, in order
  defp settings(state) do
    box = CategoryScreens.Properties
    state = press(state, :home)

    # TAB stays on the last setting, so 20 presses reach every one
    Stream.iterate(state, &press(&1, :tab))
    |> Enum.take(20)
    |> Enum.map(&box.field(&1, Agendum.TUI.State.mode(&1)))
    |> Enum.uniq()
  end

  # Checked in Agenda 2.0 (2026-10-25, PLANNER's When and Amount, and Calls
  # converted): a date or numeric category's box keeps its size, with blank
  # rows where the other settings were, and the hidden values stay stored
  test "a date or numeric category's box shows only Agenda's settings",
       %{state: state, due: due} do
    db = Core.set_short_name(state.db, due, "D")
    {:ok, db} = Core.set_also_match(db, due, "deadline")
    {:ok, db, amount} = Core.add_category(db, db.main_id, "Amount")
    state = %{state | db: db}

    standard = CategoryScreens.open_props(state, due)
    assert screen(standard) =~ "Short name:"
    assert :excludes in settings(standard)

    for {cat, key, type} <- [{due, "d", "Date"}, {amount, "n", "Numeric"}] do
      state = state |> CategoryScreens.open_props(cat) |> choose_type() |> press(key)
      text = screen(state)
      assert text =~ ~r/Type: +#{type}/

      gone = ["Short name", "Also match", "Match category", "Exclusive", "conditions", "Excludes"]
      for label <- gone, do: refute(text =~ label, "#{type}: #{label} still shown")

      assert text =~ "Assignment actions:"
      assert text =~ "Advanced settings:"

      assert settings(state) ==
               [:name, :type, :note, :special, :statistics, :also_assign, :advanced]

      # the box keeps its height: blank rows where the settings were
      assert length(String.split(text, "\n")) == length(String.split(screen(standard), "\n"))
    end

    # the short name and Also match stay stored, hidden, as Agenda keeps them
    state = state |> CategoryScreens.open_props(due) |> choose_type() |> press("d")
    assert state.db.categories[due].short_name == "D"
    assert state.db.categories[due].also_match == "deadline"
  end

  test "with children, it asks first and says what is dropped", %{state: state, due: due} do
    {:ok, db, _} = Core.add_category(state.db, due, "after the meeting")
    state = %{state | db: db} |> CategoryScreens.open_props(due) |> choose_type() |> press("d")

    # the question box (it wraps the text over its lines)
    assert Agendum.TUI.State.mode(state).question ==
             "Make Due a date category? children become dates; dropped: after the meeting"

    state = press(state, "y")
    assert state.db.categories[due].kind == :date
  end

  test "a date column of it takes a date and a time", %{state: state, due: due, view: view} do
    {:ok, db} = Core.make_date(state.db, due, @today)
    db = Core.add_column(db, view, due, {0, 1}, 16)
    state = %{state | db: db} |> press([:down, :right, :right, "next friday 3pm", :enter])

    heat = Enum.find(Map.values(state.db.items), &(&1.text == "heat")).id
    assert Database.item_date(state.db, heat, due) == ~D[2026-10-16]
    assert screen(state) =~ ~r/heat\s+·10\/16\/26 3:00pm/
  end
end
