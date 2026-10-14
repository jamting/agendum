defmodule Agenda.TUI.SortBox do
  @moduledoc """
  The Sort box (SPEC R36; User's Guide 15-13 to 15-16): how the items of a
  view (`:view`) or of one section (`{:section, index}`) are ordered.

  Rows: the primary key (Sort on), its Order, where items without a value
  go (Sort n/a's), the Sequence of a category's children, the Line number
  of a category note, then a secondary key (Then by) and its order. SPACE
  changes the highlighted row (the line number is typed, 1 to 9);
  Sort on cycles None, Item text, Category… and Category note…, the last
  two through the category box. A section can also use the view's
  settings ("As the view"). The view's box also sorts the section heads
  (Section sorting: None, Category order, Alphabetic, Numeric; Section
  order). ENTER closes the box; ESC closes it and cancels its changes
  (`Agenda.TUI.BoxCancel`). Pure.
  """

  import Agenda.TUI.BoxNav, only: [is_move: 1]
  alias Agenda.TUI.BoxNav

  alias Agenda.Core
  alias Agenda.Core.Database
  alias Agenda.Core.View.SortKey
  alias Agenda.TUI.{CategoryScreens, State}

  @rows [:on, :order, :na, :sequence, :line, :then_on, :then_order]
  @section_rows [:sections, :section_order]

  @doc "The rows of the box: the view's box also sorts its section heads."
  def rows(%{scope: :view}), do: @rows ++ @section_rows
  def rows(_mode), do: @rows

  def open(state, scope), do: State.push(state, %{type: :sort, scope: scope, cursor: 0})

  @doc "The keys in effect for the scope: the section's own, or `nil` when it uses the view's."
  @spec keys(State.t(), map) :: [SortKey.t()] | nil
  def keys(state, %{scope: :view}), do: State.view(state).sort
  def keys(state, %{scope: {:section, i}}), do: Enum.at(State.view(state).sections, i).sort

  # What the rows show when a section uses the view's keys.
  defp effective(state, mode), do: keys(state, mode) || State.view(state).sort

  def handle(state, mode, key) do
    case key do
      # ENTER is done (ESC cancels: `Agenda.TUI.BoxCancel`)
      k when k in [:esc, :enter, {:alt_f, 5}] ->
        State.pop(state)

      k when is_move(k) ->
        BoxNav.move(state, mode, BoxNav.column(rows(mode)), k)

      {:char, " "} ->
        change(state, mode, Enum.at(rows(mode), mode.cursor))

      # Line number: typed, a digit (Agenda's "type your own choice")
      {:char, c} ->
        if Enum.at(rows(mode), mode.cursor) == :line and c in ~w(1 2 3 4 5 6 7 8 9),
          do: line(state, mode, :line, String.to_integer(c), :set),
          else: state

      _ ->
        state
    end
  end

  # Sort on / Then by cycle: (As the view →) None → Item text → Category… →
  # Category note… → …
  defp change(state, mode, row) when row in [:on, :then_on] do
    index = if row == :on, do: 0, else: 1
    keys = keys(state, mode)
    current = keys && Enum.at(keys, index)

    no_primary = index == 1 and effective(state, mode) == []

    case {keys, current} do
      _ when no_primary ->
        State.error(state, "Choose what to sort on first")

      {nil, _} when index == 0 ->
        put(state, mode, [])

      {_, nil} ->
        put(state, mode, set_key(effective(state, mode), index, %SortKey{on: :text}))

      {_, %SortKey{on: :text}} ->
        CategoryScreens.open_picker(state, {:sort_category, mode.scope, index}, nil)

      {_, %SortKey{on: {:category, _}}} ->
        CategoryScreens.open_picker(state, {:sort_note, mode.scope, index}, nil)

      {_, %SortKey{on: {:note, _}}} when index == 0 and mode.scope != :view ->
        put(state, mode, nil)

      {_, %SortKey{on: {:note, _}}} ->
        put(state, mode, Enum.take(effective(state, mode), index))
    end
  end

  defp change(state, mode, :line), do: line(state, mode, :line, 1)

  # Section sorting (User's Guide 15-20): None → Category order →
  # Alphabetic → Numeric → None; the order flips Ascending / Descending.
  defp change(state, _mode, row) when row in @section_rows do
    view = State.view(state)

    {sort, order} =
      case row do
        :sections -> {next_section_sort(view.section_sort), view.section_order}
        :section_order -> {view.section_sort, toggle(:order, view.section_order)}
      end

    State.change_db(state, Core.set_section_sort(state.db, state.view_id, sort, order))
  end

  defp change(state, mode, row) do
    {index, field} =
      case row do
        :order -> {0, :order}
        :na -> {0, :na}
        :sequence -> {0, :sequence}
        :then_order -> {1, :order}
      end

    keys = effective(state, mode)

    case Enum.at(keys, index) do
      nil ->
        State.error(state, "Choose what to sort on first")

      key ->
        put(
          state,
          mode,
          List.replace_at(keys, index, Map.update!(key, field, &toggle(field, &1)))
        )
    end
  end

  # The line of the category note to sort on (1 or more).
  # a step from the line number now, or (`:set`) a line typed
  defp line(state, mode, :line, n, how \\ :step) do
    keys = effective(state, mode)

    case List.first(keys) do
      %SortKey{on: {:note, _}} = key ->
        line = if how == :set, do: n, else: max(key.line + n, 1)
        put(state, mode, List.replace_at(keys, 0, %{key | line: line}))

      _ ->
        State.error(state, "The line number is for sorting on a category note")
    end
  end

  defp next_section_sort(:none), do: :category
  defp next_section_sort(:category), do: :alpha
  defp next_section_sort(:alpha), do: :numeric
  defp next_section_sort(:numeric), do: :none

  defp toggle(:order, :asc), do: :desc
  defp toggle(:order, :desc), do: :asc
  defp toggle(:na, :bottom), do: :top
  defp toggle(:na, :top), do: :bottom
  defp toggle(:sequence, :hierarchy), do: :alpha
  defp toggle(:sequence, :alpha), do: :hierarchy

  @doc "Sets key `index` to sort on a category's notes (from the category box)."
  def set_note(state, scope, index, cat_id) do
    mode = %{scope: scope}
    keys = effective(state, mode)
    old = Enum.at(keys, index) || %SortKey{}
    put(state, mode, set_key(keys, index, %{old | on: {:note, cat_id}}))
  end

  @doc "Sets key `index` to sort on a category (from the category box)."
  def set_category(state, scope, index, cat_id) do
    mode = %{scope: scope}
    keys = effective(state, mode)
    old = Enum.at(keys, index) || %SortKey{}
    put(state, mode, set_key(keys, index, %{old | on: {:category, cat_id}}))
  end

  defp set_key(keys, index, key) when index < length(keys), do: List.replace_at(keys, index, key)
  defp set_key(keys, _index, key), do: keys ++ [key]

  defp put(state, mode, keys),
    do: State.change_db(state, Core.set_sort(state.db, state.view_id, mode.scope, keys))

  # --- what the rows say ---------------------------------------------------------

  @doc "`{label, value}` for each row."
  def lines(state, mode) do
    own = keys(state, mode)
    keys = effective(state, mode)
    first = Enum.at(keys, 0)
    second = Enum.at(keys, 1)

    [
      {"Sort on",
       if(own == nil,
         do: "As the view (#{describe(state.db, first)})",
         else: describe(state.db, first)
       )},
      {"Order", first && order_text(first.order)},
      {"Sort n/a's",
       first && if(first.na == :bottom, do: "Bottom of section", else: "Top of section")},
      {"Sequence",
       first && category_key?(first) &&
         if(first.sequence == :hierarchy, do: "Category hierarchy", else: "Alphabetic")},
      {"Line number", first && note_key?(first) && Integer.to_string(first.line)},
      {"Then by", describe(state.db, second)},
      {"Then order", second && order_text(second.order)}
    ]
    |> Enum.concat(section_lines(state, mode))
    |> Enum.map(fn {label, value} -> {label, value || "-"} end)
  end

  defp section_lines(state, %{scope: :view}) do
    view = State.view(state)

    sort =
      %{none: "None", category: "Category order", alpha: "Alphabetic", numeric: "Numeric"}[
        view.section_sort
      ]

    [
      {"Section sorting", sort},
      {"Section order", view.section_sort != :none && order_text(view.section_order)}
    ]
  end

  defp section_lines(_state, _mode), do: []

  defp describe(_db, nil), do: "None"
  defp describe(_db, %SortKey{on: :text}), do: "Item text"

  defp describe(db, %SortKey{on: {:category, id}}),
    do: "Category: " <> Database.category(db, id).name

  defp describe(db, %SortKey{on: {:note, id}}),
    do: "Category note: " <> Database.category(db, id).name

  defp note_key?(%SortKey{on: {:note, _}}), do: true
  defp note_key?(_), do: false

  defp category_key?(%SortKey{on: {:category, _}}), do: true
  defp category_key?(_), do: false

  defp order_text(:asc), do: "Ascending"
  defp order_text(:desc), do: "Descending"

  @doc "The highlighted field, for its help in the control panel (`Agenda.TUI.FieldHelp`)."
  def field(_state, mode), do: Enum.at(rows(mode), mode.cursor)
end
