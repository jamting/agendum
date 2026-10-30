# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Boxes.BoxNav do
  @moduledoc """
  Moving between the settings of a box, as Agenda (User's Guide 2-16,
  "Moving Between Settings"):

    * → or TAB: right one setting, or to the next one when there is none
      to the right; ← or SHIFT-TAB: left, or to the previous one
    * ↓ ↑: to the next or previous row with settings, onto the setting
      nearest the same place: from a right-hand setting to the right-hand
      one below, or to the left one when the row has only that
    * HOME / END: the first / last setting

  A box's settings are a grid: rows of `{field, column}` in reading order,
  from its layout (`Agendum.TUI.Boxes.Template.grid/2`), or `column/1` for a box
  that lists one setting a row, where → and ← go down and up. The top and
  bottom rows do not wrap. Pure.
  """

  @typedoc "Rows of settings, each with the column it starts at."
  @type grid :: [[{term, non_neg_integer}]]

  alias Agendum.TUI.State

  @moves [:up, :down, :left, :right, :tab, :shift_tab, :home, :end]

  @doc "Whether the key moves between settings."
  @spec move?(term) :: boolean
  def move?(key), do: key in @moves

  @doc """
  The same, usable in a guard: a box's `case` takes its moves with
  `k when is_move(k) -> BoxNav.move(state, mode, grid, k)`.
  """
  defguard is_move(key)
           when key in [:up, :down, :left, :right, :tab, :shift_tab, :home, :end]

  @doc "Moves the cursor of the box on top (`mode`) through its grid."
  @spec move(State.t(), map, grid, term) :: State.t()
  def move(state, mode, grid, key),
    do: State.put_mode(state, %{mode | cursor: cursor(grid, mode.cursor, key) || mode.cursor})

  @doc "The grid of a box listing one setting a row (any terms: Item Properties' rows are tuples)."
  @spec column([term]) :: grid
  def column(fields), do: Enum.map(fields, &[{&1, 0}])

  @doc "The setting a move goes to from `field`."
  @spec field(grid, term, term) :: term
  def field(grid, field, key) do
    flat = List.flatten(grid)
    index = Enum.find_index(flat, &(elem(&1, 0) == field)) || 0
    flat |> Enum.at(cursor(grid, index, key) || index) |> elem(0)
  end

  @doc """
  The same move with the box's cursor, an index into the settings in
  reading order; nil when the key is not a move.
  """
  @spec cursor(grid, non_neg_integer, term) :: non_neg_integer | nil
  def cursor(grid, index, key) do
    if move?(key) and grid != [] do
      last = length(List.flatten(grid)) - 1
      index = min(index, last)

      case key do
        k when k in [:right, :tab] -> min(index + 1, last)
        k when k in [:left, :shift_tab] -> max(index - 1, 0)
        :home -> 0
        :end -> last
        :down -> vertical(grid, index, 1)
        :up -> vertical(grid, index, -1)
      end
    end
  end

  # the row above or below, onto the setting starting nearest the same column
  defp vertical(grid, index, step) do
    # each setting as {row, column, index}, in reading order
    placed =
      for {row, r} <- Enum.with_index(grid), {_field, x} <- row, do: {r, x}

    placed = Enum.with_index(placed, fn {r, x}, i -> {r, x, i} end)
    {row, x, _} = Enum.at(placed, index)

    case Enum.filter(placed, fn {r, _, _} -> r == row + step end) do
      [] -> index
      # the nearest; on a tie the left one, which comes first
      target -> target |> Enum.min_by(fn {_, tx, _} -> abs(tx - x) end) |> elem(2)
    end
  end
end
