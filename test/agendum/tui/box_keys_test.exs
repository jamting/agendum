defmodule Agendum.TUI.BoxKeysTest do
  @moduledoc """
  The function keys Agenda's boxes name in their key bar, as Agenda's
  (checked in Agenda 2.0, 2026-10-25): F2 EDIT edits the highlighted
  field's text (a "..." field opens, a list of choices does nothing), F6
  PROPS opens the properties of the category in the highlighted field, F8
  DEFAULT says nothing on a setting without a default; in a category list
  F7 INCLCAT is SPACE, F4 CLRCATS clears every choice, F6 PROPS the
  highlighted category's properties.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Starters.Planner
  alias Agendum.TUI.State

  @today ~D[2026-10-12]

  setup do
    db = Planner.build() |> Planner.with_samples(@today)
    state = start(db, today: @today, height: 25, width: 80)
    people = Enum.find(Map.values(state.db.views), &(&1.name == "People"))
    %{state: state |> State.switch_view(people.id) |> Agendum.TUI.Layout.settle()}
  end

  defp menu(state, letters), do: press(state, [{:f, 10} | String.graphemes(letters)])
  defp type(state), do: State.mode(state).type

  describe "F2 EDIT" do
    test "on a list of choices does nothing", %{state: state} do
      box = state |> props(:view) |> to_setting("Hide done items")
      after_f2 = press(box, {:f, 2})
      assert State.mode(after_f2) == State.mode(box)
      assert after_f2.edit == nil
    end

    test "on a ... field opens it, as SPACE", %{state: state} do
      box = state |> props(:view) |> to_setting("View statistics") |> press({:f, 2})
      assert type(box) == :view_stats
    end

    test "on a number edits the number it has", %{state: state} do
      # People's first column is Priority, 12 wide: F2 keeps the 12
      box = state |> press([:down, :right]) |> menu("vvcp") |> to_setting("Width")
      typing = press(box, {:f, 2})
      assert {:width, %{text: "12"}} = State.mode(typing).typing
      state = press(typing, [:backspace, "9", :enter, :enter])
      column = Agendum.TUI.Layout.current_column(state) |> elem(0)
      assert column.width == 19
    end

    test "on a category field edits its name", %{state: state} do
      typing = state |> menu("vvsp") |> press({:f, 2})
      # the first section of People is Anna Berg
      assert {:head, %{text: "Anna Berg"}} = State.mode(typing).typing
    end
  end

  test "F8 on a setting without a default says nothing", %{state: state} do
    box = state |> props(:view) |> press({:f, 8})
    assert box.message == nil
  end

  describe "F6 PROPS" do
    test "in Column Properties opens the column head's Category Properties", %{state: state} do
      box = state |> press([:down, :right]) |> menu("vvcp") |> press({:f, 6})
      assert type(box) == :props
      assert screen(box) =~ ~r/Category name: +Priority/
    end

    test "in Show Schedule opens the date category's", %{state: state} do
      box = state |> menu("uss") |> press({:f, 6})
      assert type(box) == :props
      assert screen(box) =~ ~r/Category name: +When/
    end

    test "in the assignment profile opens the highlighted category's", %{state: state} do
      profile = press(state, [:down, {:f, 3}])
      assert type(press(profile, {:f, 6})) == :props
    end
  end

  test "F7 INCLCAT in the assignment profile is SPACE", %{state: state} do
    profile = press(state, [:down, {:f, 3}])
    # the first row SPACE changes the item's assignments on
    profile =
      Enum.find_value(0..20, fn n ->
        moved = press(profile, List.duplicate(:down, n))
        if press(moved, " ").db != moved.db, do: moved
      end)

    assert press(profile, {:f, 7}).db == press(profile, " ").db
  end

  describe "a list of several categories (a view's filter)" do
    setup %{state: state} do
      %{list: filter_picker(state, :view)}
    end

    test "F7 INCLCAT is SPACE", %{list: list} do
      list = press(list, :down)
      assert press(list, {:f, 7}).db == press(list, " ").db
    end

    test "F4 CLRCATS clears every choice", %{list: list} do
      # People's filter is -Contact List
      refute State.view(list).filter == []
      assert State.view(press(list, {:f, 4})).filter == []
    end
  end
end
