defmodule Agendum.TUI.Layout do
  @moduledoc """
  Flattens a view into cursor rows and screen lines.

  A *row* is something the cursor can rest on: a section head or an item.
  Each row occupies one or more screen *lines* (item text wraps, and
  sections after the first are preceded by a blank line, unless the view
  has Section separators, R58). The last row of a section also carries the
  section's calculation lines (`calcs`, R29), drawn below it. Every row carries its section's `columns` (R55): the item
  text fills the width they leave, so it differs from section to section.
  """

  alias Agendum.Core.View.ItemColumn
  alias Agendum.Core.ViewModel
  alias Agendum.TUI.{Terminal.Draw, State}

  @type row :: %{
          required(:kind) => :section | :item,
          required(:sidx) => non_neg_integer,
          required(:key) => State.cursor_key(),
          required(:columns) => [Agendum.Core.View.Column.t()],
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
        alarms: section.alarms,
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
                percents: r.percents,
                inherited: r.inherited,
                number: r.number,
                category: section.category,
                alarms: section.alarms,
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
  as wide as its columns leave (R55, `Agendum.Core.View.ItemColumn`).
  """
  @spec text_width(State.t(), row) :: pos_integer
  def text_width(%State{width: w}, row),
    do: max(ItemColumn.text_width(row.item_column, row.columns, w) - number_width(row), 1)

  @doc """
  An item's number as it is drawn before its text (Number items, R79):
  left-aligned in four columns, as Agenda's ("1   ", "10  "), wider only
  past 999; "" for a row without a number.
  """
  @spec number_label(row) :: String.t()
  def number_label(%{number: n}) when is_integer(n),
    do: String.pad_trailing(Integer.to_string(n), 3) <> " "

  def number_label(_row), do: ""

  # the item text gives up the number's columns (Agenda's item column
  # stays as wide, its text starting further right)
  defp number_width(row), do: String.length(number_label(row))

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
    separators = rows != [] and State.view(state).section_separators

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

          # so is a section head with Section separators (R58); otherwise
          # a blank line comes before it
          %{kind: :section} ->
            if separators, do: 1, else: 2

          %{kind: :item, item: item} ->
            line_count(item.text, text_width(state, row))
        end

      own + length(Map.get(row, :calcs, []))
    end)
  end

  # The lines `Draw.wrap/2` makes of a text, without wrapping one that fits:
  # wrapping only joins words with single spaces, so a text no longer than
  # the width stays one line. `byte_size/1` is instant and never less than
  # the length in characters, so most texts need no counting at all.
  defp line_count(text, width) do
    if byte_size(text) <= width or String.length(text) <= width,
      do: 1,
      else: length(Draw.wrap(text, width))
  end

  @doc """
  Re-anchors the cursor after the rows changed: keeps it on the same
  section/item if it still exists, otherwise clamps the index. Then scrolls
  so the cursor is visible.
  """
  @spec settle(State.t(), [row] | nil) :: State.t()
  def settle(%State{} = state, rows \\ nil) do
    # the caller's rows when it has them (`move_to/2`), as a view of many
    # rows takes a while to make
    rows = rows || rows(state)
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
    # only the rows down to the cursor matter: wrapping every row's text
    # was the slow part of a key in a long view (the News view)
    heights = rows |> Enum.take(state.cursor + 1) |> heights(state)
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
    settle(%{state | cursor: index, cursor_key: Enum.at(rows, index)[:key]}, rows)
  end

  @spec current_row(State.t()) :: row | nil
  def current_row(state), do: state |> rows() |> Enum.at(state.cursor)

  @doc """
  The highlighted column and where it is (`{section, column}`, R55): a
  column entry, or a column head on a section head line. Nil when the
  highlight is on the item text or the section name.
  """
  @spec current_column(State.t()) :: {Agendum.Core.View.Column.t(), Agendum.Core.View.at()} | nil
  def current_column(%State{col: col} = state) when col > 0 do
    # `with` runs its clauses in order; the first that does not match
    # (no row, or no column there) is returned as it is, here nil
    with %{sidx: sidx, columns: columns} <- current_row(state),
         %Agendum.Core.View.Column{} = column <- Enum.at(columns, col - 1) do
      {column, {sidx, col - 1}}
    end
  end

  def current_column(_state), do: nil

  @doc """
  What the highlight is on, for its note (User's Guide 12-2): the item,
  the section head's category, a column head's category, or the category
  a column entry stands for (`Agendum.Core.ViewModel.entry_category/3`).
  Nil for an entry that is no category: a date, a number, or nothing.
  """
  @spec note_target(State.t()) :: {:item, Agendum.Core.Item.id()} | {:category, integer} | nil
  def note_target(state) do
    row = current_row(state)
    column = if row && state.col > 0, do: Enum.at(row.columns, state.col - 1)

    case {row, column} do
      {nil, _} ->
        nil

      {%{kind: :section, category: cat}, nil} ->
        {:category, cat.id}

      {%{kind: :section}, column} ->
        {:category, column.category_id}

      {%{kind: :item, item: item}, nil} ->
        {:item, item.id}

      {%{kind: :item, item: item}, column} ->
        case ViewModel.entry_category(state.db, item.id, column) do
          nil -> nil
          id -> {:category, id}
        end
    end
  end

  @doc "Whether what the highlight is on has a note (the ♪ in the control panel)."
  @spec note_here?(State.t()) :: boolean
  def note_here?(state) do
    case note_target(state) do
      {:item, id} -> state.db.items[id].note != ""
      {:category, id} -> state.db.categories[id].note != ""
      nil -> false
    end
  end
end
