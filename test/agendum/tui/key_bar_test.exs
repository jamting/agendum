defmodule Agendum.TUI.KeyBarTest do
  @moduledoc """
  The key bar on a narrow screen (R65): entries that do not fit are left
  out whole, never cut mid-word. A box drops ENTER and ESC first, as its
  bottom edge names them; elsewhere the last entries go.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Starters.Planner
  alias Agendum.TUI.{Render.KeyBar, State}

  @today ~D[2026-10-12]

  defp planner(width) do
    Planner.build()
    |> Planner.with_samples(@today)
    |> start(today: @today, width: width, height: 25)
  end

  defp bar(state), do: state |> KeyBar.line() |> Enum.map_join(&elem(&1, 1)) |> String.trim()

  # the box's keys as the short bar writes them, "F2 Edit"
  defp entries(state) do
    mode = State.mode(state)

    Agendum.TUI.Boxes.Box.registry()[mode.type].keys(state, mode)
    |> Enum.map(&(elem(&1, 0) <> " " <> elem(&1, 1)))
  end

  # the bar is some of the entries, whole, in their order
  defp whole_entries!(state) do
    bar = bar(state)
    shown = Enum.filter(entries(state), &String.contains?(bar, &1))
    assert bar == Enum.join(shown, " ")
    shown
  end

  for width <- [80, 64] do
    test "View Properties at #{width} columns: whole entries, ENTER and ESC dropped first" do
      state = unquote(width) |> planner() |> press([{:f, 10}, "v", "p"])
      shown = whole_entries!(state)
      assert "SPACE Change" in shown
      refute Enum.any?(shown, &String.starts_with?(&1, ["ENTER", "ESC"]))
    end

    test "Section Properties at #{width} columns: whole entries" do
      state = unquote(width) |> planner() |> press({:f, 6})
      assert %{type: :section_props} = State.mode(state)
      whole_entries!(state)
    end
  end

  test "a box whose keys all fit keeps ENTER and ESC" do
    state = 120 |> planner() |> press([{:f, 10}, "v", "p"])
    shown = whole_entries!(state)
    assert "ENTER Done" in shown
    assert "ESC Cancel" in shown
  end

  test "outside a box, the last entries go first: ENTER and ESC stay" do
    state = 33 |> planner() |> press({:f, 2})
    assert state.edit != nil
    # "^A/^E Start/End" and "^U Clear" do not fit 33 columns
    assert bar(state) == "ENTER Done ESC Cancel ←→ Move"
  end
end
