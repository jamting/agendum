# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.MoveKeyBarTest do
  @moduledoc """
  The key bar in moves, as Agenda's (meeting 2026-10-26-1108, § 6; checked in
  Agenda 2.0, 2026-10-26): its ten slots stay, empty while an item or a
  section moves, F1 Help alone while a column moves or its width changes;
  no line of hints.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  setup do
    %{state: start(Agendum.Sample.build(~D[2026-10-26]))}
  end

  defp bar(state), do: state |> screen() |> String.split("\n") |> Enum.take(-2)

  test "moving an item: the ten slots, empty", %{state: state} do
    moving = press(state, [:down, {:alt_f, 10}])
    assert %{type: :move_item} = Agendum.TUI.State.mode(moving)
    [keys, labels] = bar(moving)
    assert keys =~ "F10"
    assert String.trim(String.replace(labels, "│", "")) == ""
  end

  test "moving a section: the ten slots, empty", %{state: state} do
    moving = press(state, {:alt_f, 10})
    assert %{type: :section_move} = Agendum.TUI.State.mode(moving)
    assert slots(moving) == ""
  end

  test "a column's width and moving a column: F1 Help alone", %{state: state} do
    width = press(state, [:down, :right, {:f, 10}, "v", "c", "w"])
    assert %{type: :column_width} = Agendum.TUI.State.mode(width)
    assert slots(width) == "F1 Help"

    move = press(state, [:down, :right, {:f, 10}, "v", "c", "m"])
    assert %{type: :column_move} = Agendum.TUI.State.mode(move)
    assert slots(move) == "F1 Help"
  end
end
