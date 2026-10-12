defmodule Agenda.TUI.Layout do
  @moduledoc """
  Flattens a view into cursor rows and screen lines.

  A *row* is something the cursor can rest on: a section head or an item.
  Each row occupies one or more screen *lines* (item text wraps, and
  sections after the first are preceded by a blank line). The last row of
  a section also carries the section's calculation lines (`calcs`, R29),
  drawn below it.
  """

  alias Agenda.Core.ViewModel
  alias Agenda.TUI.{Draw, State}

  @type row :: %{
          required(:kind) => :section | :item,
          required(:sidx) => non_neg_integer,
          required(:key) => State.cursor_key(),
          optional(atom) => term
        }

  @doc "All cursor rows of the current view."
  @spec rows(State.t()) :: [row]
  def rows(%State{} = state) do
    view = State.view(state)

    state.db
    |> ViewModel.build(view, State.context(state))
    |> Enum.with_index()
    |> Enum.flat_map(fn {section, sidx} ->
      # with hide_empty some sections are skipped; recover the real index
      # (a datebook view's sections are its slots, R47: not stored)
      sidx =
        if section.slot,
          do: sidx,
          else: Enum.find_index(view.sections, &(&1.category_id == section.category.id)) || sidx

      head = %{
        kind: :section,
        sidx: sidx,
        key: {:section, sidx},
        category: section.category,
        collapsed: section.collapsed,
        count: length(section.rows),
        slot: section.slot
      }

      items =
        if section.collapsed,
          do: [],
          else:
            Enum.map(section.rows, fn r ->
              %{
                kind: :item,
                sidx: sidx,
                key: {:item, sidx, r.item.id},
                item: r.item,
                cells: r.cells,
                inherited: r.inherited,
                category: section.category,
                slot: section.slot
              }
            end)

      section.calcs
      |> attach_calcs([head | items], section.collapsed)
    end)
  end

  # The calculation lines go below the last row of an expanded section.
  defp attach_calcs([], rows, _collapsed), do: rows
  defp attach_calcs(_calcs, rows, true), do: rows

  defp attach_calcs(calcs, rows, false),
    do: List.update_at(rows, -1, &Map.put(&1, :calcs, calcs))

  @doc "Width available for item text, given the view's columns."
  @spec text_width(State.t()) :: pos_integer
  def text_width(%State{width: w} = state) do
    columns = State.view(state).columns |> Enum.map(&(&1.width + 1)) |> Enum.sum()
    max(w - 3 - columns, 10)
  end

  @doc "How many screen lines each row takes (in order)."
  @spec heights([row], pos_integer) :: [pos_integer]
  def heights(rows, text_width) do
    rows
    |> Enum.with_index()
    |> Enum.map(fn {row, index} ->
      own =
        case row do
          %{kind: :section} when index == 0 -> 1
          # a datebook slot is a line across, with no blank line above (R47)
          %{kind: :section, slot: %{}} -> 1
          %{kind: :section} -> 2
          %{kind: :item, item: item} -> length(Draw.wrap(item.text, text_width))
        end

      own + length(Map.get(row, :calcs, []))
    end)
  end

  @doc """
  Re-anchors the cursor after the rows changed: keeps it on the same
  section/item if it still exists, otherwise clamps the index. Then scrolls
  so the cursor is visible.
  """
  @spec settle(State.t()) :: State.t()
  def settle(%State{} = state) do
    rows = rows(state)
    count = length(rows)

    index =
      Enum.find_index(rows, &(&1.key == state.cursor_key)) ||
        state.cursor |> min(count - 1) |> max(0)

    row = Enum.at(rows, index)
    ncols = length(State.view(state).columns)
    col = if row && row.kind == :item, do: min(state.col, ncols), else: 0

    %{state | cursor: index, cursor_key: row && row.key, col: col}
    |> scroll_to_cursor(rows)
  end

  defp scroll_to_cursor(state, rows) do
    heights = heights(rows, text_width(state))
    start = heights |> Enum.take(state.cursor) |> Enum.sum()
    height = Enum.at(heights, state.cursor, 1)
    body = State.body_height(state)

    scroll =
      cond do
        start < state.scroll -> start
        start + height > state.scroll + body -> start + height - body
        true -> state.scroll
      end

    %{state | scroll: max(scroll, 0)}
  end

  @doc "Moves the cursor to row `index` (clamped)."
  @spec move_to(State.t(), integer) :: State.t()
  def move_to(state, index) do
    rows = rows(state)
    index = index |> min(length(rows) - 1) |> max(0)
    settle(%{state | cursor: index, cursor_key: Enum.at(rows, index)[:key]})
  end

  @spec current_row(State.t()) :: row | nil
  def current_row(state), do: state |> rows() |> Enum.at(state.cursor)
end
