defmodule Agendum.TUI.CategoryStatsTest do
  @moduledoc """
  Category Properties' "..." settings, as Agenda (screenshot 74): Note,
  Statistics and Advanced settings each open a box of their own.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.TUI.CategoryScreens.Properties
  alias Agendum.TUI.State

  setup do
    state = start(Agendum.Sample.build(~D[2026-10-08]), width: 80, height: 30)
    # Calls, in the category manager
    %{state: press(state, [{:f, 9}, :down, :down, :down, :down, {:f, 6}])}
  end

  defp tabs_to(field) do
    index = Enum.find_index(Properties.props_fields(), &(&1 == field))
    List.duplicate(:tab, index)
  end

  test "Note, Statistics and Advanced settings show \"...\"", %{state: state} do
    text = screen(state)
    assert text =~ ~r/Note: +\.\.\./
    assert text =~ ~r/Statistics: +\.\.\./
    assert text =~ ~r/Advanced settings: +\.\.\./
  end

  test "Statistics opens a box of how much of the file uses the category", %{state: state} do
    state = press(state, tabs_to(:statistics) ++ [" "])
    assert %{type: :category_stats} = State.mode(state)
    text = screen(state)
    assert text =~ "Category statistics: Calls"
    assert text =~ ~r/Items in category: +5/
    assert text =~ ~r/Child categories: +0/
    assert text =~ ~r/Used as section heads: +1/
    assert text =~ ~r/Included in view filters: +0/

    # nothing to change: ENTER or ESC go back to Category Properties
    assert %{type: :props} = State.mode(press(state, :enter))
    assert %{type: :props} = State.mode(press(state, :esc))
  end

  test "Advanced settings and Note open theirs with SPACE", %{state: state} do
    assert %{type: :category_match} = State.mode(press(state, tabs_to(:advanced) ++ [" "]))
    assert %{type: :note} = State.mode(press(state, tabs_to(:note) ++ [" "]))
  end
end
