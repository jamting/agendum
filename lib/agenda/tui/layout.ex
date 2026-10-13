defmodule Agenda.TUI.Layout do
  @moduledoc """
  Flattens a view into cursor rows and screen lines.

  A *row* is something the cursor can rest on: a section head or an item.
  Each row occupies one or more screen *lines* (item text wraps, and
  sections after the first are preceded by a blank line). The last row of
  a section also carries the section's calculation lines (`calcs`, R29),
  drawn below it. Every row carries its section's `columns` (R55): the item
  text fills the width they leave, so it differs from section to section.
  """

  alias Agenda.Core.View.ItemColumn
  alias Agenda.Core.ViewModel
  alias Agenda.TUI.{Draw, State}

  @type row :: %{
          required(:kind) => :section | :item,
          required(:sidx) => non_neg_integer,
          required(:key) => State.cursor_key(),
          required(:columns) => [Agenda.Core.View.Column.t()],
          required(:item_column) => ItemColumn.t(),
          optional(atom) => term
        }

  @doc "All cursor rows of the current view."
  @spec rows(State.t()) :: [row]
  def rows(%State{} = state) do
    state.db
    |> ViewModel.build(State.view(state), State.context(state))
    |> Enum.with_index()
    |> Enum.flat_map(fn {section, shown} ->
      # the stored section's index (sorting and hide_empty may show it
      # elsewhere); a datebook view's sections are its slots (R47), not
      # stored, so they go by where they are shown
      sidx = section.index || shown

      head = %{
        kind: :section,
        sidx: sidx,
        key: {:section, sidx},
        category: section.category,
        collapsed: section.collapsed,
        count: length(section.rows),
        slot: section.slot,
        columns: section.columns,
        item_column: section.item_column
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
                slot: section.slot,
                columns: section.columns,
                item_column: section.item_column
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

  @doc """
  Width of a row's item text: its section's item column, set by hand or
  as wide as its columns leave (R55, `Agenda.Core.View.ItemColumn`).
  """
  @spec text_width(State.t(), row) :: pos_integer
  def text_width(%State{width: w}, row),
    do: ItemColumn.text_width(row.item_column, row.columns, w)

  @doc """
  The row's columns in the order they are shown, as `state.col` counts
  them (0 the item text, `i` the `i`th column): the item column is after
  as many columns as its `position` says (R55).
  """
  @spec shown_cols(row) :: [non_neg_integer]
  def shown_cols(row) do
    n = length(row.columns)
    List.insert_at(Enum.to_list(1..n//1), items_at(row), 0)
  end

  @doc "How many of the row's columns are shown left of its item text."
  @spec items_at(row) :: non_neg_integer
  def items_at(row), do: min(row.item_column.position, length(row.columns))

  @doc "The highlight `n` columns right (or left) as they are shown, within the row."
  @spec step_col(State.t(), row | nil, integer) :: State.t()
  def step_col(state, nil, _n), do: state

  def step_col(state, row, n) do
    cols = shown_cols(row)
    at = Enum.find_index(cols, &(&1 == state.col)) || 0
    %{state | col: Enum.at(cols, (at + n) |> max(0) |> min(length(cols) - 1))}
  end

  @doc "How many screen lines each row takes (in order)."
  @spec heights([row], State.t()) :: [pos_integer]
  def heights(rows, %State{} = state) do
    rows
    |> Enum.with_index()
    |> Enum.map(fn {row, index} ->
      own =
        case row do
          %{kind: :section} when index == 0 ->
            1

          # a datebook slot is a line across, with no blank line above (R47)
          %{kind: :section, slot: %{}} ->
            1

          %{kind: :section} ->
            2

          %{kind: :item, item: item} ->
            length(Draw.wrap(item.text, text_width(state, row)))
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
    # the column cursor stays within the section's own columns (R55); on a
    # section head line it rests on a column head (User's Guide 5-22)
    col = if row, do: min(state.col, length(row.columns)), else: 0

    %{state | cursor: index, cursor_key: row && row.key, col: col}
    |> scroll_to_cursor(rows)
  end

  defp scroll_to_cursor(state, rows) do
    heights = heights(rows, state)
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

  @doc """
  The highlighted column and where it is (`{section, column}`, R55): a
  column entry, or a column head on a section head line. Nil when the
  highlight is on the item text or the section name.
  """
  @spec current_column(State.t()) :: {Agenda.Core.View.Column.t(), Agenda.Core.View.at()} | nil
  def current_column(%State{col: col} = state) when col > 0 do
    # `with` runs its clauses in order; the first that does not match
    # (no row, or no column there) is returned as it is, here nil
    with %{sidx: sidx, columns: columns} <- current_row(state),
         %Agenda.Core.View.Column{} = column <- Enum.at(columns, col - 1) do
      {column, {sidx, col - 1}}
    end
  end

  def current_column(_state), do: nil
end
