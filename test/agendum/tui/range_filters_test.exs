# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.RangeFiltersTest do
  @moduledoc "The Date Filter and Numeric Filter boxes (R28a; User's Guide 11-5 to 11-12)."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.TUI.{Layout, State}

  setup do
    %{state: start(Agendum.Sample.build(~D[2026-10-08]))}
  end

  defp texts(state),
    do: for(%{kind: :item, item: item} <- Layout.rows(state), do: item.text)

  test "choosing a date category in the filter box asks for a date range", %{state: state} do
    state = state |> filter_picker(:view) |> press(["When", :enter, " "])
    assert %{type: :range_filter} = State.mode(state)
    text = screen(state)
    assert text =~ "Date filter: When"
    assert text =~ ~r/Show items\s+: Assigned/
    assert text =~ "Start date"
    assert text =~ "End date"
    assert text =~ ~r/Items should be\s+: Inside range/
  end

  test "a date range filters the view and shows in the title", %{state: state} do
    state =
      state
      |> filter_picker(:view)
      |> press(["When", :enter, " ", :down, "2026-10-01", :down, "2026-10-07", :enter])
      |> close_props()

    assert state.modes == []
    assert screen(state) =~ "[When 10/01/26..10/07/26]"
    assert [only] = texts(state)
    assert only =~ "Call Marketing"
  end

  test "an item typed into a date-filtered view gets the start date", %{state: state} do
    state =
      state
      |> filter_picker(:view)
      |> press(["When", :enter, " ", :down, "2026-10-01", :enter])
      |> close_props()
      |> press(["Plan the offsite", :enter])

    item = Enum.find(Database.items(state.db), &(&1.text == "Plan the offsite"))
    assert item.when == ~D[2026-10-01]
    assert "Plan the offsite" in texts(state)
  end

  test "Outside range and Not assigned", %{state: state} do
    state =
      state
      |> filter_picker(:view)
      |> press([
        "When",
        :enter,
        " ",
        :down,
        "2026-10-01",
        :down,
        "2026-10-07",
        :down,
        " ",
        :enter
      ])
      |> close_props()

    assert screen(state) =~ "[When not 10/01/26..10/07/26]"
    assert [only] = texts(state)
    assert only =~ "Terracotta"

    state =
      state |> filter_picker(:view) |> press(["When", :enter, " ", " ", :enter]) |> close_props()

    assert screen(state) =~ "[-When]"
    assert length(texts(state)) == 3
  end

  test "a date that cannot be read is refused and the box stays open", %{state: state} do
    state =
      state |> filter_picker(:view) |> press(["When", :enter, " ", :down, "someday", :enter])

    assert %{type: :range_filter} = State.mode(state)
    assert panel(state) =~ message(:bad_date)
  end

  test "DEL in the box removes the filter", %{state: state} do
    state =
      state
      |> filter_picker(:view)
      |> press(["When", :enter, " ", :down, "2026-10-01", :enter, "When", :enter, " ", :delete])

    assert State.view(state).filter == []
  end

  test "a section can have a date filter", %{state: state} do
    state =
      state
      |> filter_picker(:section)
      |> press(["When", :enter, " ", :down, "2026-10-20", :enter])
      |> close_props()

    assert screen(state) =~ "Calls [When 10/20/26..]"
    assert [only] = texts(state)
    assert only =~ "Terracotta"
  end

  test "a numeric category gets a Numeric Filter box", %{state: state} do
    db = state.db
    {:ok, db, cost} = Core.add_category(db, db.main_id, "Cost")
    {:ok, db} = Core.make_numeric(db, cost)
    {:ok, db} = Core.set_number(db, hd(db.item_order), cost, 1500)
    state = %{state | db: db}

    state = state |> filter_picker(:view) |> press(["Cost", :enter, " "])
    text = screen(state)
    assert text =~ "Numeric filter: Cost"
    assert text =~ "Minimum value"
    assert text =~ "Maximum value"

    state = state |> press([:down, "1000", :enter]) |> close_props()
    assert screen(state) =~ "[Cost 1,000..]"
    assert length(texts(state)) == 1

    state =
      state
      |> filter_picker(:view)
      |> press(["Cost", :enter, " ", :down, {:ctrl, "u"}, "lots", :enter])

    assert panel(state) =~ message(:bad_number)
  end

  # The review of group f (2026-10-31): ENTER crashed if the box's category
  # was no longer a date or numeric one (Agenda never turns one back, so
  # only a change from outside the box could do it)
  test "ENTER on a category no longer date or numeric says so instead of crashing",
       %{state: state} do
    state = state |> filter_picker(:view) |> press(["When", :enter, " "])
    plain = Enum.find(Map.values(state.db.categories), &(&1.name == "Calls"))
    state = State.put_mode(state, %{State.mode(state) | cat_id: plain.id})
    state = press(state, :enter)
    assert %{type: :range_filter} = State.mode(state)
    assert screen(state) =~ "must be a date or numeric category"
  end
end
