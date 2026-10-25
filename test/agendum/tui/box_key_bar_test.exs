defmodule Agendum.TUI.BoxKeyBarTest do
  @moduledoc """
  The key bar while a box or the menu is on top, as Agenda's (checked in
  Agenda 2.0, 2026-10-25; `docs/reference/agenda_boxes.json`): the ten
  F-key slots, as in a view, each with the label of what its key does on
  the highlighted field; no hints naming ENTER, ESC, SPACE or INS (the
  box's edge and the help on top say those).
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Starters.Planner

  @today ~D[2026-10-12]

  setup do
    db = Planner.build() |> Planner.with_samples(@today)
    %{state: start(db, today: @today, height: 25, width: 80)}
  end

  # the labels of the ten slots, "" for an empty one
  defp bar(state) do
    state
    |> screen()
    |> String.split("\n")
    |> List.last()
    |> String.split("│")
    |> Enum.map(&String.trim/1)
  end

  defp keys_line(state), do: state |> screen() |> String.split("\n") |> Enum.at(-2)

  test "View Properties: Help, Edit, Choices, Props and Default in their slots", %{state: state} do
    box = props(state, :view)
    assert keys_line(box) =~ ~r/^ +F1 +│ +F2 +│ +F3/
    assert bar(box) == ["Help", "Edit", "Choices", "", "", "Props", "", "Default", "", ""]
    refute screen(box) =~ "SPACE Change"

    # the Sections list has no default, as in Agenda
    sections = press(box, :right)
    assert Enum.at(bar(sections), 7) == ""
  end

  test "Item Properties' Assigned to: F4 Values there alone", %{state: state} do
    box = press(state, [:down, {:f, 6}])
    assert Enum.slice(bar(box), 0..5) == ["Help", "Edit", "Choices", "", "", "Props"]

    assigned = to_setting(box, "Assigned to")
    assert Enum.at(bar(assigned), 3) == "Values"
  end

  test "a statistics box and the menu: Help alone", %{state: state} do
    stats = state |> props(:view) |> to_setting("View statistics") |> press(" ")
    assert bar(stats) == ["Help", "", "", "", "", "", "", "", "", ""]

    menu = press(state, {:f, 10})
    assert bar(menu) == ["Help", "", "", "", "", "", "", "", "", ""]
  end

  test "typing in a field: Agenda's editing bar", %{state: state} do
    typing = state |> props(:view) |> press({:f, 2})
    assert keys_line(typing) =~ ~r/^ +F1 +│/
    assert Enum.at(bar(typing), 1) == "Paste"
  end
end
