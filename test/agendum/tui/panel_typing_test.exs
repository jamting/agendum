# SPDX-License-Identifier: AGPL-3.0-only
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

  describe "F2 in the assignment profile (Agenda's EDIT)" do
    setup %{state: state} do
      profile = press(state, [:down, {:f, 3}])
      mode = State.mode(profile)
      rows = Agendum.TUI.CategoryScreens.rows(profile, mode)
      at = Enum.find_index(rows, fn {id, _} -> profile.db.categories[id].name == "People" end)
      %{profile: press(profile, List.duplicate(:down, at - mode.cursor))}
    end

    test "renames the highlighted category, typed in the control panel", %{profile: profile} do
      typing = press(profile, {:f, 2})
      assert line(typing, 0) =~ ~r/^ Category name: +EDIT/
      assert String.trim(line(typing, 1)) == "People"
      renamed = press(typing, [" and pets", :enter])
      assert Enum.any?(Map.values(renamed.db.categories), &(&1.name == "People and pets"))
      assert %{type: :profile} = State.mode(renamed)
    end

    test "a category Agenda keeps (Entry) cannot be renamed", %{profile: profile} do
      mode = State.mode(profile)
      rows = Agendum.TUI.CategoryScreens.rows(profile, mode)
      at = Enum.find_index(rows, fn {id, _} -> profile.db.categories[id].name == "Entry" end)
      entry = press(profile, List.duplicate(:up, mode.cursor - at))
      assert {:error, _} = press(entry, {:f, 2}).message
    end
  end

  describe "automatic completion in a box's category field (checked in Agenda 2.0, 2026-10-25)" do
    setup %{state: state} do
      %{column: press(state, [:down, :right, {:f, 10}, "v", "c", "p"])}
    end

    test "typing a head: Agenda's completion line and AUTOC", %{column: box} do
      typing = press(box, "pri")
      assert line(typing, 0) =~ ~r/^ 1 of 1 matching categories\. Current choice: Priority +AUTOC/
      # what is typed, then the rest of the match in grey
      assert line(typing, 1) =~ ~r/^ priority/
    end

    test "ENTER takes the shown match", %{column: box} do
      done = press(box, ["pri", :enter])
      assert screen(done) =~ ~r/Column head: +Priority/
    end

    test "F5 (NEWCAT) takes exactly what was typed", %{column: box} do
      done = press(box, ["Pri", {:f, 5}])
      assert screen(done) =~ ~r/Column head: +Pri /
    end

    test "F8 and F7 go through the matches", %{state: state} do
      box = press(state, [{:f, 10}, "v", "s", "p"])
      typing = press(box, "M")
      first = line(typing, 0)
      assert first =~ ~r/^ 1 of \d+ matching categories/
      assert line(press(typing, {:f, 8}), 0) =~ ~r/^ 2 of /
      assert line(press(typing, [{:f, 8}, {:f, 7}]), 0) == first
    end

    test "the key bar: Help, Choices, NewCat, PrevSel, NextSel", %{column: box} do
      assert bar(press(box, "pri")) ==
               ["Help", "", "Choices", "", "NewCat", "", "PrevSel", "NextSel", "", ""]
    end
  end

  test "a box's category field (Section Properties' head): Category name:", %{state: state} do
    box = press(state, [{:f, 10}, "v", "s", "p"])
    typing = press(box, {:f, 2})
    assert line(typing, 0) =~ ~r/^ Category name: +EDIT/
    assert line(typing, 1) =~ ~r/^ Anna Berg/
  end
end
