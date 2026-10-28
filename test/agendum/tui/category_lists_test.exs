defmodule Agendum.TUI.CategoryListsTest do
  @moduledoc """
  Category lists opened from a box, as Agenda's (checked in Agenda 2.0,
  2026-10-22 and 2026-10-24; ADR 0030, amended; the owner's choices,
  2026-10-24): the filters, conditions, actions, Excludes and the
  Schedule's filter, and the Assignment Profile. SPACE switches a category
  (in a filter: once included, twice not included, then off); ENTER and ESC
  both close the list keeping what was switched ("Press ENTER to accept").
  While a name is typed to find a category, SPACE goes on typing it and
  ENTER ends the typing, staying in the list.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Core.Database
  alias Agendum.TUI.{Layout, State}

  setup do
    %{state: start(Agendum.Sample.build(~D[2026-10-08]))}
  end

  defp cat(state, name), do: hd(Database.find_categories(state.db, name))
  defp filter(state), do: State.view(state).filter

  # UI guidelines rule 6.2: the keys under a list are made from its keys;
  # what the marks mean is a line of its own above them, never cut short
  # (the owner, 2026-10-28)
  describe "the lines under a list" do
    test "the marks' meaning, then the keys", %{state: state} do
      calls = cat(state, "Calls")
      lists = Agendum.TUI.CategoryScreens

      for {purpose, legend} <- [
            also_assign: "+ assign · - remove · none (dates, numbers: a box)",
            excludes: "x may not share items",
            condition: "+ assigned · - not assigned · none"
          ] do
        text = screen(lists.open_picker(state, {purpose, calls}, state.db.main_id))
        assert text =~ legend
        assert text =~ "SPACE switch · F4 clear · INS new category"
      end
    end

    test "a list to pick one category from names its keys", %{state: state} do
      text =
        screen(
          Agendum.TUI.CategoryScreens.open_picker(state, {:column_head, 1}, state.db.main_id)
        )

      assert text =~ "INS new category · type search by name"
      refute text =~ "SPACE switch"
    end
  end

  describe "a filter list" do
    test "says Press ENTER to accept", %{state: state} do
      assert screen(filter_picker(state, :view)) =~ "Press ENTER to accept"
    end

    test "SPACE switches: once included, twice not included, a third time off",
         %{state: state} do
      list = state |> filter_picker(:view) |> press(["High", :enter])
      high = cat(list, "High")
      once = press(list, " ")
      assert filter(once) == [{high, :assigned}]
      twice = press(once, " ")
      assert filter(twice) == [{high, :not_assigned}]
      assert filter(press(twice, " ")) == []
    end

    test "typing a name: SPACE goes on typing it, ENTER ends the typing and stays",
         %{state: state} do
      list = state |> filter_picker(:view) |> press(String.graphemes("Abigail Sch"))
      assert State.mode(list).search == "Abigail Sch"
      assert filter(list) == []

      found = press(list, :enter)
      assert %{type: :picker, search: ""} = State.mode(found)
      assert filter(press(found, " ")) == [{cat(state, "Abigail Scheer"), :assigned}]
    end

    test "ENTER and ESC both close it, keeping what was switched", %{state: state} do
      switched = state |> filter_picker(:view) |> press(["High", :enter, " "])

      for key <- [:enter, :esc] do
        closed = press(switched, key)
        assert %{type: :view_props} = State.mode(closed)
        assert filter(closed) == filter(switched)
      end
    end
  end

  describe "the Assignment Profile (F3 on an item)" do
    setup %{state: state} do
      on_item = press(state, :down)
      %{on_item: on_item, item: Layout.current_row(on_item).item.id}
    end

    test "says Press ENTER to accept; SPACE switches; ENTER closes keeping it",
         %{on_item: on_item} do
      profile = press(on_item, {:f, 3})
      assert screen(profile) =~ "Press ENTER to accept"
      # a standard category below MAIN, Entry, When and Done
      switched = press(profile, List.duplicate(:down, 4) ++ [" "])
      refute switched.db == profile.db

      closed = press(switched, :enter)
      assert State.mode(closed) == nil
      assert closed.db == switched.db
    end
  end
end
