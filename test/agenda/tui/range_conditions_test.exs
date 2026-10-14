defmodule Agenda.TUI.RangeConditionsTest do
  @moduledoc "The Date Condition and Numeric Condition boxes (R15a; User's Guide 20-5 to 20-7)."
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.Core
  alias Agenda.Core.Database
  alias Agenda.TUI.{State, Update}

  # Meetings is the last category in the manager.
  setup do
    state = start(Agenda.Sample.build(~D[2026-10-08]), now: ~N[2026-10-08 10:00:00])
    %{state: state, meetings: hd(Database.find_categories(state.db, "Meetings"))}
  end

  defp open_conditions(state, keys \\ [{:f, 9}, :ctrl_end]),
    do: press(state, keys ++ [{:f, 6}] ++ downs_to(:conditions) ++ [" "])

  defp downs_to(field) do
    index = Enum.find_index(Agenda.TUI.CategoryScreens.Properties.props_fields(), &(&1 == field))
    List.duplicate(:tab, index)
  end

  test "choosing a date category in the conditions box asks for a date range",
       %{state: state, meetings: meetings} do
    state = open_conditions(state) |> press(["When", :enter])
    assert %{type: :range_filter} = State.mode(state)
    assert screen(state) =~ "Date condition: When"

    state = press(state, [:down, "beginning of this week", :down, "end of this week", :enter])

    assert [{_, {:range, "beginning of this week", "end of this week", :inside}}] =
             state.db.categories[meetings].conditions

    # ESC clears the picker's search, then closes it
    state = press(state, [:esc, :esc])
    assert screen(state) =~ ~r/Assignment conditions:.*\n.*When 2026-10-05\.\.2026-10-09/
  end

  test "items are pulled in by the date condition when their date changes",
       %{state: state, meetings: meetings} do
    {:ok, db} =
      Core.set_range_condition(
        state.db,
        meetings,
        state.db.special.when,
        {"beginning of this week", "end of this week", :inside},
        ~D[2026-10-08]
      )

    state = %{state | db: db} |> press(["Lunch with Ann tomorrow", :enter])
    item = Enum.find(Database.items(state.db), &(&1.text == "Lunch with Ann tomorrow"))
    assert Database.member?(state.db, item.id, meetings)

    # a week later, the item's date is last week: the clock tick lets it go
    {state, _} = Update.tick(state, ~N[2026-10-15 09:00:00])
    refute Database.member?(state.db, item.id, meetings)
  end

  test "a numeric condition, and removing it with DEL", %{state: state, meetings: meetings} do
    {:ok, db, cost} = Core.add_category(state.db, state.db.main_id, "Cost")
    {:ok, db} = Core.make_numeric(db, cost)
    state = %{state | db: db}

    # Cost is now the last category; Meetings is the one above it
    state = open_conditions(state, [{:f, 9}, :ctrl_end, :up])

    state = press(state, ["Cost", :enter])
    assert screen(state) =~ "Numeric condition: Cost"
    state = press(state, [:down, "1000", :enter])
    assert [{^cost, {:range, 1000.0, nil, :inside}}] = state.db.categories[meetings].conditions

    state = press(state, ["Cost", :enter, :delete])
    assert state.db.categories[meetings].conditions == []
  end

  test "a bad date keeps the box open", %{state: state} do
    state = open_conditions(state) |> press(["When", :enter, :down, "someday", :enter])
    assert %{type: :range_filter} = State.mode(state)
    assert screen(state) =~ "Not a date: someday"
  end
end
