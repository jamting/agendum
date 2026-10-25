defmodule Agendum.TUI.Boxes.SortBox do
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
  (`Agendum.TUI.Boxes.BoxCancel`). Drawn from `@layout`
  (`Agendum.TUI.Boxes.Template`). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, indicator: "SORT", cancels: true

  alias Agendum.Core.Database
  alias Agendum.Core.View.SortKey
  alias Agendum.TUI.Boxes.{Box, Template}
  alias Agendum.TUI.{CategoryScreens, State}

  # the last two rows only in the view's box (a section has no sections)
  @layout """
   Sort on         : [on                                     ]
   Order           : [order                                  ]
   Sort n/a's      : [na                                     ]
   Sequence        : [sequence                               ]
   Line number     : [line                                   ]
   Then by         : [then_on                                ]
   Then order      : [then_order                             ]
   Section sorting : [sections                               ]
   Section order   : [section_order                          ]
  """

  @section_rows [:sections, :section_order]
  @rows Template.fields(@layout) -- @section_rows

  @help %{
    on: "What to sort the items on: item text, a category, or a category note. SPACE.",
    order: "Sort in ascending or descending order. SPACE switches.",
    na: "Where items with nothing to sort on go: the top or the bottom. SPACE switches.",
    sequence:
      "Sort on the children of the category in their hierarchy order or alphabetically. " <>
        "SPACE switches.",
    line: "Which line of the category note to sort on. Type it (1 to 9).",
    then_on: "What to sort items on when they are equal so far. SPACE changes it.",
    then_order: "Sort the second key in ascending or descending order. SPACE switches.",
    sections: "How to order the sections: none, by category order, alphabetic or numeric. SPACE.",
    section_order: "Sort the sections in ascending or descending order. SPACE switches."
  }

  @doc "The rows of the box: the view's box also sorts its section heads."
  def rows(%{scope: :view}), do: @rows ++ @section_rows
  def rows(_mode), do: @rows

  def open(state, scope), do: State.push(state, %Agendum.TUI.Modes.Sort{scope: scope, cursor: 0})

  @doc "The keys in effect for the scope: the section's own, or `nil` when it uses the view's."
  @spec sort_keys(State.t(), map) :: [SortKey.t()] | nil
  def sort_keys(state, %{scope: :view}), do: State.view(state).sort
  def sort_keys(state, %{scope: {:section, i}}), do: Enum.at(State.view(state).sections, i).sort

  # What the rows show when a section uses the view's keys.
  defp effective(state, mode), do: sort_keys(state, mode) || State.view(state).sort

  @impl Box
  # Line number: typed, a digit (Agenda's "type your own choice")
  def handle(state, mode, {:char, c}) do
    if Enum.at(rows(mode), mode.cursor) == :line and c in ~w(1 2 3 4 5 6 7 8 9),
      do: line(state, mode, :line, String.to_integer(c), :set),
      else: state
  end

  def handle(state, _mode, _key), do: state

  # the settings box's keys; ALT-F5, which opened it, is done too (R65)
  @impl Box
  def keymap(_mode), do: Box.settings_keymap(%{{:alt_f, 5} => :done})

  @impl Box
  def commands(_mode), do: Box.settings_commands()

  # ENTER is done (ESC cancels: `Agendum.TUI.Boxes.BoxCancel`)
  @impl Box
  def run(state, mode, :change), do: change(state, mode, Enum.at(rows(mode), mode.cursor))

  def run(state, mode, id),
    do: Box.run_settings(state, mode, Template.grid(@layout, rows(mode)), id)

  # Sort on / Then by cycle: (As the view →) None → Item text → Category… →
  # Category note… → …
  defp change(state, mode, row) when row in [:on, :then_on] do
    index = if row == :on, do: 0, else: 1
    keys = sort_keys(state, mode)
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

    State.run(state, {:set_section_sort, state.view_id, sort, order})
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

  # F8 and ALT-F8 (`Agendum.TUI.Boxes.BoxDefaults`): Sort on back to no sort
  # of the box's own (a section's: the view's, Agenda's "View default",
  # User's Guide 15-20), Then by gone, a key's settings a new key's
  # (`SortKey`), the view's sections unsorted. Each reads the sort as it
  # is when it runs, and touches only a sort the box has of its own
  @impl Box
  def defaults(_state, mode) do
    blank = %SortKey{}
    none = if mode.scope == :view, do: [], else: nil

    keys =
      Map.new(
        [
          order: {0, :order},
          na: {0, :na},
          sequence: {0, :sequence},
          line: {0, :line},
          then_order: {1, :order}
        ],
        fn {row, {index, field}} ->
          {row, &key_back(&1, mode, index, field, Map.fetch!(blank, field))}
        end
      )

    sections = %{
      sections:
        &State.run(&1, {:set_section_sort, &1.view_id, :none, State.view(&1).section_order}),
      section_order:
        &State.run(&1, {:set_section_sort, &1.view_id, State.view(&1).section_sort, :asc})
    }

    keys
    |> Map.merge(%{
      on: &if(sort_keys(&1, mode) in [nil, []], do: &1, else: put(&1, mode, none)),
      then_on: &then_back(&1, mode)
    })
    |> Map.merge(if mode.scope == :view, do: sections, else: %{})
  end

  defp then_back(state, mode) do
    case sort_keys(state, mode) do
      [first, _ | _] -> put(state, mode, [first])
      _ -> state
    end
  end

  defp key_back(state, mode, index, field, default) do
    keys = sort_keys(state, mode) || []

    key = Enum.at(keys, index)

    if key == nil or Map.fetch!(key, field) == default,
      do: state,
      else: put(state, mode, List.replace_at(keys, index, Map.put(key, field, default)))
  end

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
    do: State.run(state, {:set_sort, state.view_id, mode.scope, keys})

  # --- what the rows say ---------------------------------------------------------

  @impl Box
  def title(_state, %{scope: :view}), do: "Item Sorting in All Sections"

  def title(_state, %{scope: {:section, _}}), do: "Item Sorting in Current Section"

  @impl Box
  def content(state, mode, inner, _max_rows) do
    Template.render(@layout, values(state, mode), selected: field(state, mode)) ++
      [[], Box.hint(keys(state, mode), inner)]
  end

  # a setting that does not apply shows "-"
  defp values(state, mode) do
    own = sort_keys(state, mode)
    keys = effective(state, mode)
    first = Enum.at(keys, 0)
    second = Enum.at(keys, 1)

    %{
      on:
        if(own == nil,
          do: "As the view (#{describe(state.db, first)})",
          else: describe(state.db, first)
        ),
      order: first && order_text(first.order),
      na: first && if(first.na == :bottom, do: "Bottom of section", else: "Top of section"),
      sequence:
        first && category_key?(first) &&
          if(first.sequence == :hierarchy, do: "Category hierarchy", else: "Alphabetic"),
      line: first && note_key?(first) && Integer.to_string(first.line),
      then_on: describe(state.db, second),
      then_order: second && order_text(second.order)
    }
    |> Map.new(fn {field, value} -> {field, value || "-"} end)
    |> Map.merge(section_values(state, mode))
  end

  # nil leaves the rows out (`Agendum.TUI.Boxes.Template`)
  defp section_values(state, %{scope: :view}) do
    view = State.view(state)

    sort =
      %{none: "None", category: "Category order", alpha: "Alphabetic", numeric: "Numeric"}[
        view.section_sort
      ]

    %{
      sections: sort,
      section_order: if(view.section_sort == :none, do: "-", else: order_text(view.section_order))
    }
  end

  defp section_values(_state, _mode), do: %{sections: nil, section_order: nil}

  @impl Box
  def keys(_state, _mode),
    do: [
      {"↑↓←→", "Setting", "Move between settings"},
      {"SPACE", "Change", "Change the setting"},
      {"ENTER", "Done"},
      {"ESC", "Cancel"}
    ]

  @impl Box
  def help, do: @help

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

  @impl Box
  def field(_state, mode), do: Enum.at(rows(mode), mode.cursor)
end
