defmodule Agenda.TUI.CollapseTest do
  @moduledoc """
  Collapsing and expanding families of categories and sections of a view
  (User's Guide 16-8 to 16-9 and 5-5 to 5-6).
  """
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.Core.Database
  alias Agenda.TUI.{CategoryScreens, State}

  setup do
    %{state: start(Agenda.Sample.build(~D[2026-10-08]))}
  end

  defp cat(state, name), do: hd(Database.find_categories(state.db, name))

  defp visible(state),
    do:
      state
      |> CategoryScreens.rows(State.mode(state))
      |> Enum.map(fn {id, _} -> state.db.categories[id].name end)

  defp highlighted(state),
    do:
      state.db.categories[
        elem(Enum.at(CategoryScreens.rows(state, State.mode(state)), State.mode(state).cursor), 0)
      ].name

  # category manager rows: MAIN Entry When Done Calls Priority High Medium Low Contact ...
  defp on_high(state), do: press(state, [{:f, 9}] ++ List.duplicate(:down, 6))

  test "ALT-- anywhere in a family collapses it and shows an ellipsis", %{state: state} do
    state = state |> on_high() |> press({:alt, "-"})
    refute "High" in visible(state)
    assert highlighted(state) == "Priority"
    assert screen(state) =~ ~r/Priority\.\.\./
  end

  test "ALT-- on a parent collapses its own children", %{state: state} do
    state = press(state, [{:f, 9}] ++ List.duplicate(:down, 5) ++ [{:alt, "-"}])
    refute "High" in visible(state)
    assert highlighted(state) == "Priority"
  end

  test "ALT-- twice collapses every family", %{state: state} do
    state = state |> on_high() |> press([{:alt, "-"}, {:alt, "-"}])
    assert visible(state) == ["MAIN"]
  end

  test "ALT-= expands the highlighted family; twice expands everything", %{state: state} do
    state = state |> on_high() |> press([{:alt, "-"}, {:alt, "="}])
    assert "High" in visible(state)

    state = press(state, [{:alt, "-"}, {:alt, "-"}, {:alt, "="}, {:alt, "="}])
    assert "Anna Lasky" in visible(state)
  end

  test "a collapsed family stays collapsed in the category box", %{state: state} do
    state = state |> on_high() |> press([{:alt, "-"}, :esc, {:alt, "d"}])
    assert %{type: :picker} = State.mode(state)
    refute "High" in visible(state)
  end

  test "the assignment profile still shows assigned categories in collapsed families", %{
    state: state
  } do
    # the first item is assigned to Medium; collapse Priority, then open its profile
    state = state |> on_high() |> press([{:alt, "-"}, :esc, :down, {:f, 6}])
    assert "Medium" in visible(state)
    refute "High" in visible(state)
  end

  test "moving a category into a collapsed family expands it", %{state: state} do
    # rows: ... Contact(9) Anna(10) Abigail(11) Daniel(12) Meetings(13)
    # collapse Contact from Anna, then demote Meetings (its previous sibling is Contact)
    state = press(state, [{:f, 9}] ++ List.duplicate(:down, 10) ++ [{:alt, "-"}, :down, {:f, 8}])
    assert state.db.categories[cat(state, "Meetings")].parent_id == cat(state, "Contact")
    assert highlighted(state) == "Meetings"
    assert "Anna Lasky" in visible(state)
  end

  describe "sections in a view" do
    setup %{state: state} do
      db = state.db
      [view] = Database.views(db)
      db = Agenda.Core.add_section(db, view.id, hd(Database.find_categories(db, "Meetings")), 1)
      %{state: start(db)}
    end

    defp collapsed(state), do: Enum.map(State.view(state).sections, & &1.collapsed)

    test "ALT-- collapses the current section, twice collapses all", %{state: state} do
      state = press(state, {:alt, "-"})
      assert collapsed(state) == [true, false]
      assert screen(state) =~ "§"

      state = press(state, {:alt, "-"})
      assert collapsed(state) == [true, true]
    end

    test "ALT-= expands the current section, twice expands all", %{state: state} do
      state = press(state, [{:alt, "-"}, {:alt, "-"}, :esc, {:alt, "="}])
      assert collapsed(state) == [false, true]
      state = press(state, {:alt, "="})
      assert collapsed(state) == [false, false]
    end
  end
end
