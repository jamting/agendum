defmodule Agendum.TUI.PanelTypingTest do
  @moduledoc """
  Category names and column entries are typed in the control panel, as
  Agenda's (checked in Agenda 2.0, 2026-10-25; the owner's choice): line 1
  says what is typed ("Category name:", "Date:", or automatic completion's
  "1 of 2 matching categories. Current choice: High"), line 2 holds the
  line being typed; the list, the cell or the box keeps showing what is
  there until ENTER. While a standard column entry is typed, AUTOC shows
  and the key bar is Agenda's: Help, Choices, NewCat, PrevSel, NextSel.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Starters.Planner
  alias Agendum.TUI.{Layout, State}

  @today ~D[2026-10-12]

  setup do
    db = Planner.build() |> Planner.with_samples(@today)
    state = start(db, today: @today, height: 25, width: 80)
    people = Enum.find(Map.values(state.db.views), &(&1.name == "People"))
    %{state: state |> State.switch_view(people.id) |> Layout.settle()}
  end

  defp line(state, n), do: state |> screen() |> String.split("\n") |> Enum.at(n)

  defp bar(state) do
    state
    |> screen()
    |> String.split("\n")
    |> List.last()
    |> String.split("│")
    |> Enum.map(&String.trim/1)
  end

  describe "the category manager" do
    test "F2: the name is edited on line 2, the list keeps it", %{state: state} do
      catmgr = press(state, {:f, 9})
      mode = State.mode(catmgr)
      rows = Agendum.TUI.CategoryScreens.rows(catmgr, mode)
      # People: one Agenda lets rename (Entry, When and Done it does not)
      at = Enum.find_index(rows, fn {id, _} -> catmgr.db.categories[id].name == "People" end)
      catmgr = press(catmgr, List.duplicate(:down, at - mode.cursor))
      name = "People"
      typing = press(catmgr, {:f, 2})
      assert line(typing, 0) =~ ~r/^ Category name: +EDIT *$/
      assert String.trim(line(typing, 1)) == name
      # the list still shows it, highlighted, as it was
      assert typing |> screen() |> String.split("\n") |> Enum.drop(2) |> Enum.any?(&(&1 =~ name))
    end

    test "INS: a blank row in the list, the name typed on line 2", %{state: state} do
      typing = press(state, [{:f, 9}, :down, :insert, "Errands"])
      assert line(typing, 0) =~ ~r/^ Category name:/
      assert line(typing, 1) =~ ~r/^ Errands/
      after_enter = press(typing, :enter)
      assert Enum.any?(Map.values(after_enter.db.categories), &(&1.name == "Errands"))
    end
  end

  describe "a column entry" do
    setup %{state: state} do
      # the first item, in the Priority column (standard), then When (a date)
      %{priority: press(state, [:down, :right]), when: press(state, [:down, :right, :right])}
    end

    test "typing a category: Agenda's completion line, the text on line 2", %{priority: state} do
      typing = press(state, "Me")
      assert line(typing, 0) =~ ~r/^ 1 of 1 matching categories\. Current choice: Medium +AUTOC/
      assert line(typing, 1) =~ ~r/^ Medium/
    end

    test "no match: No matching categories.", %{priority: state} do
      assert line(press(state, "Zq"), 0) =~ ~r/^ No matching categories\. +AUTOC/
    end

    test "the cell keeps what it had until ENTER", %{priority: state} do
      before = Enum.drop(String.split(screen(state), "\n"), 2)
      typing = press(state, "Zq")

      assert Enum.drop(String.split(screen(typing), "\n"), 2) |> Enum.drop(-2) ==
               Enum.drop(before, -2)
    end

    test "the key bar: Help, Choices, NewCat, PrevSel, NextSel", %{priority: state} do
      assert bar(press(state, "Me")) ==
               ["Help", "", "Choices", "", "NewCat", "", "PrevSel", "NextSel", "", ""]
    end

    test "F3 lists the choices", %{priority: state} do
      listed = press(state, ["Me", {:f, 3}])
      assert listed.edit == nil
      refute State.mode(listed) == nil
    end

    test "a date: Date:, EDIT", %{when: state} do
      typing = press(state, "tomorrow")
      assert line(typing, 0) =~ ~r/^ Date: +EDIT *$/
      assert line(typing, 1) =~ ~r/^ tomorrow/
    end
  end

  test "renaming a section head (F2 on it): Category name:", %{state: state} do
    typing = press(state, {:f, 2})
    assert line(typing, 0) =~ ~r/^ Category name: +EDIT/
    assert line(typing, 1) =~ ~r/^ Anna Berg/
  end

  test "a box's category field (Section Properties' head): Category name:", %{state: state} do
    box = press(state, [{:f, 10}, "v", "s", "p"])
    typing = press(box, {:f, 2})
    assert line(typing, 0) =~ ~r/^ Category name: +EDIT/
    assert line(typing, 1) =~ ~r/^ Anna Berg/
  end
end
