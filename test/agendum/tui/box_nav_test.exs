defmodule Agendum.TUI.BoxNavTest do
  @moduledoc "Moving between the settings of a box, as Agenda (User's Guide 2-16)."
  use ExUnit.Case, async: true

  alias Agendum.TUI.Boxes.BoxNav

  # Two columns, then a row with only a left setting, then two again:
  #   head    type
  #   width   linked
  #   format
  #   count   total
  @grid [[head: 1, type: 20], [width: 1, linked: 20], [format: 1], [count: 1, total: 20]]

  defp move(field, key), do: BoxNav.field(@grid, field, key)

  test "→ and TAB go right, or on to the next row's first setting" do
    assert move(:head, :right) == :type
    assert move(:type, :right) == :width
    assert move(:type, :tab) == :width
    # the last stays
    assert move(:total, :right) == :total
  end

  test "← and SHIFT-TAB go left, or back to the previous row's last setting" do
    assert move(:type, :left) == :head
    assert move(:width, :left) == :type
    assert move(:width, :shift_tab) == :type
    assert move(:head, :left) == :head
  end

  test "↓ and ↑ keep to the same side when the next row has a setting there" do
    assert move(:type, :down) == :linked
    assert move(:linked, :up) == :type
    assert move(:head, :down) == :width
  end

  test "from a right-hand setting to a row with only a left one, and on" do
    assert move(:linked, :down) == :format
    assert move(:format, :down) == :count
    assert move(:total, :up) == :format
    # the top and bottom rows stay
    assert move(:type, :up) == :type
    assert move(:total, :down) == :total
  end

  test "HOME and END go to the first and last setting" do
    assert move(:linked, :home) == :head
    assert move(:width, :end) == :total
  end

  test "a box listing one setting a row: → and ← go down and up" do
    grid = BoxNav.column([:a, :b, :c])
    assert BoxNav.field(grid, :a, :right) == :b
    assert BoxNav.field(grid, :b, :down) == :c
    assert BoxNav.field(grid, :c, :left) == :b
  end

  test "the cursor as an index into the settings, in reading order" do
    assert BoxNav.cursor(@grid, 1, :down) == 3
    assert BoxNav.cursor(@grid, 3, :down) == 4
    assert BoxNav.cursor(@grid, 0, :page_down) == nil
  end

  test "keys that are not moves are left to the box" do
    assert BoxNav.move?(:down)
    assert BoxNav.move?(:shift_tab)
    refute BoxNav.move?({:char, " "})
  end
end
