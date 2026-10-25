defmodule Agendum.TUI.Boxes.ViewProps do
  @moduledoc """
  The View Properties box (View ▸ Properties, or F6 on a view in the view
  manager; R78; User's Guide 9-9 to 9-11, Help "View Properties/Add/Copy
  Box"), laid out as Agenda 2.0's (checked headless, 2026-10-23). A
  datebook view's box has no Section sorting, and its right column holds
  the datebook's settings instead of Sections, as Agenda's (checked
  2026-10-25; `Agendum.TUI.Boxes.DatebookSettings`).

  On the left, one under the other:

    * View name: typing replaces the name, F2 (or SPACE) edits it
    * Item sorting ...: the view's sort (`Agendum.TUI.Boxes.SortBox`)
    * Section sorting: None, Category order, Alphabetic or Numeric, and
      under it Order (Ascending, Descending) while it is not None
    * Hide empty sections, Hide done items, Hide dependent items, Hide
      inherited items, Hide column heads, Section separators, Number
      items (R79): Yes or No
    * View statistics ...: the marked items, sections and items, in a box
      of their own (`Agendum.TUI.Boxes.ViewStatsBox`)

  On the right, Sections: the view's sections in their order. ↓ and ↑ walk
  them (↓ from the last goes on to Filter, ↑ from Filter comes back to the
  first, as in Agenda); typing a name, or INS, adds a section below the
  highlighted one (a new category if no category has the name), F3 picks
  its category instead; DEL removes the highlighted one (not the last);
  F6 opens its Section Properties; ALT-F10 picks it up, ↑ ↓ carry it and
  ENTER or ESC put it down, as Agenda's; ALT-↑ ↓ move it a place at once
  (ours). Below them, Filter: the view's filter (the filter picker).

  Every change applies at once and is one undo step; ENTER closes the box,
  ESC closes it and puts back what changed (`Agendum.TUI.Boxes.BoxCancel`).
  Named print set and View protection are not in Agendum (SPEC § 6).

  Opened from the view manager on another view, the box shows that view
  beneath it while it is open (its settings boxes work on the view shown),
  and closing it shows again the view that was shown. Pure.
  """

  # the box stays open on ENTER of a typed field; ENTER on a setting is done
  use Agendum.TUI.Boxes.Box, finish: :done, cancels: true

  alias Agendum.TUI.Boxes.{
    Box,
    DatebookSettings,
    FieldTyping,
    SectionBox,
    SortBox,
    Template,
    ViewStatsBox
  }

  alias Agendum.TUI.{CategoryScreens, State}
  alias Agendum.TUI.Render.Text
  alias Agendum.TUI.Typing.LineEdit

  # Agenda's layout: the settings on the left, the Sections list on the
  # right beside them, `s1` to `s8` the rows it shows (it scrolls when the
  # view has more), Filter under it. Order's row is blank while Section
  # sorting is None, as in Agenda; the row is kept so the list stays put.
  @layout """
   View name:  [name                                               ]
   Item sorting:    [sorting       ] Sections:
   Section sorting: [section_sort  ]   [s1                         ]
   [order                          ]   [s2                         ]
   Hide empty sections:   [empty    ]  [s3                         ]
   Hide done items:       [done     ]  [s4                         ]
   Hide dependent items:  [dependent]  [s5                         ]
   Hide inherited items:  [inherited]  [s6                         ]
   Hide column heads:     [col_heads]  [s7                         ]
   Section separators:    [lines    ]  [s8                         ]
   Number items:          [number   ]  Filter: [filter               ]

   View statistics:       [statistics]
  """

  # A datebook view's box (R47): the datebook's settings on the right, the
  # rows below Period as its period has them (`datebook_layout/1`)
  @datebook_top """
   View name:  [name                                               ]
   Item sorting:    [sorting       ] Date category: [dcat          ]
                                     End category:  [ecat          ]
                                     Section:       [scat          ]
   Hide empty sections:   [empty    ]Period:        [period        ]
  """

  @datebook_bottom """
   Hide column heads:     [col_heads]Base date on:  [base          ]
   Section separators:    [lines    ]
   Number items:          [number   ]  Filter: [filter               ]

   View statistics:       [statistics]
  """

  @datebook_middle [
    " Hide done items:       [done     ]",
    " Hide dependent items:  [dependent]",
    " Hide inherited items:  [inherited]"
  ]

  @period_labels %{
    ival: "Interval:      [ival          ]",
    start: "Start at:      [start         ]",
    end: "End at:        [end           ]"
  }

  # the layout's short names for the datebook's settings, which must fit
  # their fields' width
  @aliases %{
    dcat: :date_category,
    ecat: :end_category,
    scat: :section_category,
    period: :period,
    ival: :interval,
    start: :start,
    end: :end,
    base: :base
  }
  @short Map.new(@aliases, fn {short, row} -> {row, short} end)

  # the rows of the Sections list, and the screen row (in the layout) of
  # the first; the left column's settings with their rows
  @slots [:s1, :s2, :s3, :s4, :s5, :s6, :s7, :s8]
  @first_slot 2
  @filter_row 10
  @left [
    name: 0,
    sorting: 1,
    section_sort: 2,
    order: 3,
    empty: 4,
    done: 5,
    dependent: 6,
    inherited: 7,
    col_heads: 8,
    lines: 9,
    number: 10,
    statistics: 12
  ]

  # the view's Yes/No settings, by the box's field (`toggle_view_option`)
  @options %{
    empty: :hide_empty,
    done: :hide_done,
    dependent: :hide_dependent,
    inherited: :hide_inherited,
    col_heads: :hide_column_heads,
    lines: :section_separators,
    number: :number_items
  }

  # Agenda's choices for Section sorting, in its order (Help)
  @section_sorts [
    none: "None",
    category: "Category order",
    alpha: "Alphabetic",
    numeric: "Numeric"
  ]

  @help %{
    name: "Type a name for the view. F2 edits the name it has.",
    sorting: "Press SPACE BAR to set criteria for sorting items in all sections in the view.",
    section_sort: "Press F3 to pick the type of sorting (if any) for section heads.",
    order: "Sort the sections from the top (A to Z, 0 to 9) or from the bottom. SPACE switches.",
    empty: "Choose whether to display section heads when no items are assigned to the section.",
    done: "Choose whether to continue to display items after you designate them as done.",
    dependent:
      "Choose whether to display items you can't do until a prerequisite item is completed.",
    inherited:
      "Choose whether to display items assigned to a descendant of the section head only.",
    col_heads: "Choose whether to display column heads for all sections or just the first one.",
    lines: "Display a line between each section.",
    number: "Display a number next to the item tag in front of every item.",
    statistics: "Press SPACE BAR to display current statistics for the view.",
    sections: "Type category(s) for section head(s) or press F3 to pick existing category(s).",
    moving: "Use Up and Down arrow keys to reposition the section. Press ENTER to accept.",
    filter: "Display items only if they are assigned to the filter category(s)."
  }

  @doc """
  Opens the box for view `view_id`. Another view than the one shown is
  shown beneath the box until it closes (`back` keeps where the person was).
  """
  @spec open(State.t(), Agendum.Core.Database.id()) :: State.t()
  def open(%State{view_id: view_id} = state, view_id), do: push(state, view_id, nil)

  def open(state, view_id) do
    back = Map.take(state, [:view_id, :cursor, :cursor_key, :col, :scroll])
    state = %{state | view_id: view_id, cursor: 0, cursor_key: nil, col: 0, scroll: 0}
    push(state, view_id, back)
  end

  defp push(state, view_id, back),
    do:
      State.push(state, %Agendum.TUI.Modes.ViewProps{
        view_id: view_id,
        cursor: :name,
        back: back
      })

  defp view(state, mode), do: state.db.views[mode.view_id]
  defp sections(state, mode), do: view(state, mode).sections
  defp sorted?(state, mode), do: view(state, mode).section_sort != :none
  defp datebook(state, mode), do: view(state, mode).datebook

  # the datebook's settings shown, by their short names, top to bottom
  defp datebook_fields(d),
    do: Enum.map(DatebookSettings.rows(d.period), &Map.fetch!(@short, &1))

  defp datebook_layout(d) do
    middle =
      d.period
      |> DatebookSettings.period_rows()
      |> Enum.map(&Map.fetch!(@period_labels, Map.fetch!(@short, &1)))

    # Hide done … Hide inherited, with the period's rows beside them
    rows =
      @datebook_middle
      |> Enum.with_index()
      |> Enum.map_join("\n", fn {left, i} -> left <> (Enum.at(middle, i) || "") end)

    @datebook_top <> rows <> "\n" <> @datebook_bottom
  end

  defp layout(state, mode) do
    case datebook(state, mode) do
      nil -> @layout
      d -> datebook_layout(d)
    end
  end

  # --- moving between the settings ---------------------------------------------

  # The settings in reading order (TAB's): the left column, then the
  # sections and Filter. Order is there only while Section sorting is on.
  defp left(state, mode) do
    fields = Keyword.keys(@left)

    cond do
      datebook(state, mode) -> fields -- [:section_sort, :order]
      sorted?(state, mode) -> fields
      true -> List.delete(fields, :order)
    end
  end

  defp right(state, mode) do
    case datebook(state, mode) do
      nil ->
        count = length(sections(state, mode))
        Enum.map(0..(count - 1)//1, &{:section, &1}) ++ [:filter]

      d ->
        datebook_fields(d) ++ [:filter]
    end
  end

  defp all(state, mode), do: left(state, mode) ++ right(state, mode)

  # the highlighted setting, kept to one that exists: a section removed
  # (or put back by undo) moves it to the nearest one left
  defp current(state, mode) do
    case mode.cursor do
      {:section, n} -> {:section, min(n, length(sections(state, mode)) - 1)}
      :order -> if sorted?(state, mode), do: :order, else: :section_sort
      # a datebook's setting its period no longer has: Period, above it
      field when is_map_key(@aliases, field) -> datebook_field(state, mode, field)
      field -> field
    end
  end

  defp datebook_field(state, mode, field) do
    if field in datebook_fields(datebook(state, mode)), do: field, else: :period
  end

  defp move_to(state, mode, field), do: State.put_mode(state, %{mode | cursor: field})

  # ↓ ↑ in the same column, without wrapping; ← → to the other column, onto
  # the setting on the nearest row. Into the Sections list from Filter
  # comes the first section, as Agenda's ↑ does.
  defp step(state, mode, key) do
    here = current(state, mode)
    {column, other} = columns(state, mode, here)
    index = Enum.find_index(column, &(&1 == here))

    case key do
      :down -> Enum.at(column, min(index + 1, length(column) - 1))
      :up when here == :filter -> {:section, 0}
      :up -> Enum.at(column, max(index - 1, 0))
      side when side in [:left, :right] -> nearest(state, mode, other, row(state, mode, here))
      :tab -> next(all(state, mode), here, 1)
      :shift_tab -> next(all(state, mode), here, -1)
      # the first and the last setting on the screen
      :home -> :name
      :end -> :statistics
    end
  end

  defp columns(state, mode, here) do
    left = left(state, mode)
    right = right(state, mode)
    if here in left, do: {left, right}, else: {right, left}
  end

  defp next(list, here, step) do
    index = Enum.find_index(list, &(&1 == here))
    Enum.at(list, min(max(index + step, 0), length(list) - 1))
  end

  # the setting of `fields` on the screen row nearest `row` (on a tie the
  # upper one, which comes first)
  defp nearest(state, mode, fields, row),
    do: Enum.min_by(fields, &abs(row(state, mode, &1) - row))

  # the layout row a setting is on; a section's is its row in the list as
  # it is scrolled now
  defp row(_state, _mode, :filter), do: @filter_row
  defp row(state, mode, {:section, n}), do: @first_slot + n - top(state, mode)
  defp row(_state, _mode, :base), do: 8

  # Date category on the Item sorting row, the others one under the other
  defp row(state, mode, field) when is_map_key(@aliases, field),
    do: Enum.find_index(datebook_fields(datebook(state, mode)), &(&1 == field)) + 1

  defp row(_state, _mode, field), do: Keyword.fetch!(@left, field)

  # the first section the list shows: it scrolls to keep the highlighted
  # (or the carried) one in sight
  defp top(state, mode) do
    case current(state, mode) do
      {:section, n} -> max(n - length(@slots) + 1, 0)
      _ -> 0
    end
  end

  # --- keys ----------------------------------------------------------------------

  @impl Box
  def typing?(state, mode), do: state.edit != nil or mode.typing != nil

  @impl Box
  def handle(state, mode, key) do
    if FieldTyping.typing?(mode),
      do: FieldTyping.key(state, mode, key, &typed/3),
      else: typing_key(state, mode, key)
  end

  # a character on View name replaces the name; on a section it starts the
  # name of a new section below it, as in Agenda
  defp typing_key(state, %{moving: nil} = mode, {:char, c}) when c != " " do
    case current(state, mode) do
      :name -> FieldTyping.start(state, mode, :name, c)
      {:section, n} -> FieldTyping.start(state, mode, {:new_section, n}, c)
      _ -> state
    end
  end

  defp typing_key(state, _mode, _key), do: state

  # the settings box's keys, and those of the Sections list (R65); while a
  # section is carried, only the arrows and putting it down
  @impl Box
  def keymap(%{moving: moving}) when moving != nil,
    do: %{:up => :carry_up, :down => :carry_down, :enter => :put_down, :esc => :put_down}

  def keymap(_mode) do
    Box.settings_keymap(%{
      {:f, 2} => :edit,
      {:f, 3} => :pick,
      {:f, 6} => :properties,
      :insert => :add,
      :delete => :remove,
      {:ctrl, "d"} => :remove,
      {:alt_f, 10} => :move,
      {:alt, :up} => :move_up,
      {:alt, :down} => :move_down
    })
  end

  @impl Box
  def commands(%{moving: moving}) when moving != nil,
    do: [
      {:carry_up, "Up", "Carry the section up"},
      {:carry_down, "Down", "Carry the section down"},
      {:put_down, "Put down", "Leave the section where it is"}
    ]

  def commands(_mode) do
    Box.settings_commands([
      {:edit, "Edit", "Edit the view's name"},
      {:pick, "Pick section", "Pick the category of a new section"},
      {:properties, "Section props", "The highlighted section's properties"},
      {:add, "Add section", "Add a section below this one"},
      {:remove, "Remove section", "Remove the section from the view"},
      {:move, "Move section", "Pick the section up to move it"},
      {:move_up, "Move up", "Move the section up"},
      {:move_down, "Move down", "Move the section down"}
    ])
  end

  @impl Box
  def run(state, mode, id), do: command(state, mode, id, current(state, mode))

  @moves %{
    up: :up,
    down: :down,
    left: :left,
    right: :right,
    next: :tab,
    previous: :shift_tab,
    first: :home,
    last: :end
  }

  defp command(state, mode, id, here) when is_map_key(@moves, id),
    do: move_to(state, mode, step(state, %{mode | cursor: here}, @moves[id]))

  # ENTER: closed, and the view that was shown shown again; refused with no
  # section left (Section Select's F4), as Agenda's
  defp command(state, mode, id, _here) when id in [:done, :close] do
    view = state.db.views[mode.view_id]

    if id == :done and view.datebook == nil and view.sections == [],
      do: State.error(state, Agendum.TUI.Messages.text(:no_sections)),
      else: state |> State.pop() |> Map.merge(mode.back || %{})
  end

  defp command(state, mode, :change, here), do: change(state, mode, here)

  defp command(state, mode, :edit, :name), do: edit_name(state, mode)

  # F2 on a "..." setting opens it, as SPACE, as Agenda's (2026-10-25)
  defp command(state, mode, :edit, here) do
    if String.trim(Agendum.TUI.Render.Boxes.selected_value(state)) == "...",
      do: change(state, mode, here),
      else: state
  end

  # F3 on Sections: Agenda's Section Select, every section head starred
  # (checked in Agenda 2.0, 2026-10-25; the owner's choice)
  defp command(state, mode, :pick, {:section, _n}),
    do: CategoryScreens.open_picker(state, {:sections, mode.view_id}, nil)

  defp command(state, mode, :add, {:section, n}),
    do: State.put_mode(state, %{mode | typing: {{:new_section, n}, LineEdit.new("")}})

  defp command(state, _mode, :properties, {:section, n}), do: SectionBox.open(state, n)
  defp command(state, mode, :remove, {:section, n}), do: remove(state, mode, n)

  # DEL on a datebook's End category empties it
  defp command(state, mode, :remove, field) when is_map_key(@aliases, field),
    do: DatebookSettings.clear(state, mode.view_id, @aliases[field])

  defp command(state, mode, :move, {:section, n}), do: pick_up(state, mode, n)
  defp command(state, mode, :move_up, {:section, n}), do: move(state, mode, n, n - 1)
  defp command(state, mode, :move_down, {:section, n}), do: move(state, mode, n, n + 1)

  defp command(state, mode, :carry_up, _here), do: carry(state, mode, -1)
  defp command(state, mode, :carry_down, _here), do: carry(state, mode, 1)
  defp command(state, mode, :put_down, _here), do: put_down(state, mode)

  defp command(state, _mode, _id, _here), do: state

  defp change(state, mode, field) when is_map_key(@options, field),
    do: State.run(state, {:toggle_view_option, mode.view_id, @options[field]})

  defp change(state, mode, :name), do: edit_name(state, mode)

  defp change(state, mode, field) when is_map_key(@aliases, field),
    do: DatebookSettings.change(state, mode.view_id, @aliases[field])

  defp change(state, _mode, :sorting), do: SortBox.open(state, :view)

  defp change(state, mode, :section_sort) do
    view = view(state, mode)
    sorts = Keyword.keys(@section_sorts)
    index = Enum.find_index(sorts, &(&1 == view.section_sort))
    sort = Enum.at(sorts, rem(index + 1, length(sorts)))
    State.run(state, {:set_section_sort, mode.view_id, sort, view.section_order})
  end

  defp change(state, mode, :order) do
    view = view(state, mode)
    order = if view.section_order == :asc, do: :desc, else: :asc
    State.run(state, {:set_section_sort, mode.view_id, view.section_sort, order})
  end

  defp change(state, mode, :statistics), do: ViewStatsBox.open(state, mode.view_id)

  defp change(state, _mode, :filter),
    do: CategoryScreens.open_picker(state, {:filter, :view}, nil)

  # SPACE on a section does nothing, as in Agenda (so it is not a list of
  # choices for `BoxChoices` either)
  defp change(state, _mode, _field), do: state

  defp edit_name(state, mode),
    do:
      State.put_mode(state, %{
        mode
        | typing: {:name, LineEdit.new(view(state, mode).name)}
      })

  # ENTER on a typed field: the view's new name, or a new section below the
  # highlighted one, which the highlight goes to (one change each)
  defp typed(state, :name, text) do
    if String.trim(text) == "",
      do: state,
      else: State.run(state, {:rename_view, State.mode(state).view_id, text})
  end

  defp typed(state, {:new_section, n}, name) do
    FieldTyping.head_named(state, name, fn state, id ->
      mode = State.mode(state)

      state
      |> State.run({:add_section, mode.view_id, id, n + 1, n})
      |> State.put_mode(%{mode | cursor: {:section, n + 1}})
    end)
  end

  defp remove(state, mode, n) do
    if length(sections(state, mode)) == 1,
      do: State.error(state, Agendum.TUI.Messages.text(:view_needs_section)),
      else: State.run(state, {:remove_section, mode.view_id, n})
  end

  # --- moving a section ------------------------------------------------------------

  # a view that sorts its sections shows them in that order whatever their
  # place, as View ▸ Section ▸ Move says too (R62)
  defp pick_up(state, mode, n) do
    if sorted?(state, mode),
      do: sorted_error(state),
      else: State.put_mode(state, %{mode | moving: %{from: n, to: n}})
  end

  defp sorted_error(state),
    do: State.error(state, "This view sorts its sections; set Section sorting to None first")

  # ↑ ↓ while carried: only the box's list changes; the file changes once,
  # when it is put down (ADR 0026)
  defp carry(state, %{moving: moving} = mode, step) do
    to = min(max(moving.to + step, 0), length(sections(state, mode)) - 1)
    State.put_mode(state, %{mode | moving: %{moving | to: to}, cursor: {:section, to}})
  end

  defp put_down(state, %{moving: %{from: from, to: to}} = mode) do
    mode = %{mode | moving: nil, cursor: {:section, to}}
    state = State.put_mode(state, mode)
    if from == to, do: state, else: State.run(state, {:move_section, mode.view_id, from, to})
  end

  # ALT-↑ ↓ (ours): a place at once, the highlight with it
  defp move(state, mode, n, to) do
    cond do
      sorted?(state, mode) ->
        sorted_error(state)

      to < 0 or to >= length(sections(state, mode)) ->
        state

      true ->
        state
        |> State.run({:move_section, mode.view_id, n, to})
        |> State.put_mode(%{mode | cursor: {:section, to}})
    end
  end

  # --- drawing ---------------------------------------------------------------------

  @impl Box
  def width(state, _mode), do: min(state.width - 8, 68)

  @impl Box
  def title(_state, _mode), do: "View Properties"

  @impl Box
  def content(state, mode, inner, _max_rows) do
    here = current(state, mode)
    view = view(state, mode)
    selected = if is_atom(here), do: here

    values =
      Map.merge(
        %{
          name: view.name,
          sorting: "...",
          section_sort: Keyword.fetch!(@section_sorts, view.section_sort),
          order: order(view, here),
          statistics: "...",
          filter: filter(state, view.filter)
        },
        Map.new(@options, fn {field, option} -> {field, yes_no(Map.fetch!(view, option))} end)
      )
      |> Map.merge(slots(state, mode, here))
      |> Map.merge(datebook_values(state, view))

    Template.render(layout(state, mode), values, [selected: selected] ++ editing(state, mode)) ++
      [[], Box.hint(keys(state, mode), inner)]
  end

  defp datebook_values(_state, %{datebook: nil}), do: %{}

  defp datebook_values(state, %{datebook: d}) do
    values = DatebookSettings.values(state, d)
    Map.new(@aliases, fn {short, row} -> {short, Map.fetch!(values, row)} end)
  end

  # Order's row: its label and value while Section sorting is on, else blank
  defp order(%{section_sort: :none}, _here), do: ""

  defp order(view, here) do
    style = if here == :order, do: :box_selected, else: :box
    value = if view.section_order == :asc, do: "Ascending", else: "Descending"
    [{:box, "  Order:         "}, {style, value}]
  end

  defp filter(_state, []), do: "(none)"
  defp filter(state, filter), do: Text.filter_text(state, filter)

  # the rows of the Sections list: the section names as they are now (the
  # carried one at its new place), a new name being typed below its
  # section, scrolled to the highlight
  defp slots(state, mode, here) do
    names =
      state
      |> section_names(mode)
      |> Enum.with_index(fn name, n -> {name, {:section, n}} end)
      |> with_new_line(mode)

    shown = Enum.drop(names, top(state, mode))

    @slots
    |> Enum.with_index()
    |> Map.new(fn {slot, i} ->
      case Enum.at(shown, i) do
        nil -> {slot, ""}
        {name, ^here} when here != nil -> {slot, [{:box_selected, name}]}
        {name, _} -> {slot, name}
      end
    end)
  end

  defp section_names(state, mode) do
    names = Enum.map(sections(state, mode), &state.db.categories[&1.category_id].name)

    case mode.moving do
      nil ->
        names

      %{from: from, to: to} ->
        names |> List.delete_at(from) |> List.insert_at(to, Enum.at(names, from))
    end
  end

  # while a new section's name is typed, an empty row for it below its
  # section, which `editing/2` draws as the input line
  defp with_new_line(names, %{typing: {{:new_section, n}, _line}}),
    do: List.insert_at(names, n + 1, {"", :typing})

  defp with_new_line(names, _mode), do: names

  defp editing(state, %{typing: {:name, line}}), do: editing_at(state, :name, line)

  # a new section's name is typed in the control panel, as Agenda's: its
  # row stays blank below section n
  defp editing(_state, %{typing: {{:new_section, _n}, _line}}), do: []

  defp editing(_state, _mode), do: []

  defp editing_at(_state, field, line), do: [editing: {field, line}]

  defp yes_no(true), do: "Yes"
  defp yes_no(false), do: "No"

  @impl Box
  def keys(_state, %{moving: moving}) when moving != nil,
    do: [{"↑↓", "Move", "Carry the section"}, {"ENTER", "Accept"}]

  def keys(_state, _mode),
    # at 80 columns the bar leaves out ENTER and ESC (the box's bottom edge
    # names them too, `Agendum.TUI.Render.KeyBar`); Agenda's key bar had no
    # arrows either
    do: [
      {"SPACE", "Change", "Change the setting"},
      {"F2", "Edit", "Edit the view's name"},
      {"F3", "Choices", "Pick a choice or a section's category"},
      {"F6", "Props", "The section's properties"},
      {"INS", "Add", "Add a section"},
      {"DEL", "Remove", "Remove the section"},
      {"A-F10", "Move", "ALT-F10", "Move the section"},
      {"ENTER", "Done"},
      {"ESC", "Cancel"}
    ]

  @impl Box
  def help do
    datebook = DatebookSettings.help()
    Map.merge(@help, Map.new(@aliases, fn {short, row} -> {short, Map.fetch!(datebook, row)} end))
  end

  @impl Box
  def about(_state, _mode) do
    """
    View Properties holds the view's own settings: its name, how its items
    and sections are sorted, what it hides, whether it numbers its items,
    and its filter. SPACE changes
    the highlighted setting; a letter or F3 picks a choice.

    Sections, on the right, lists the view's sections: ↓ and ↑ walk them.
    Type a name (or press INS) to add a section below the highlighted one,
    F3 to pick its category. DEL removes a section from the view, F6 shows
    its properties. ALT-F10 picks a section up: ↑ ↓ carry it, ENTER puts
    it down. ALT-↑ and ALT-↓ move it a place at once.

    Every change shows at once. ENTER keeps them; ESC puts them all back.
    """
  end

  # F8 and ALT-F8 (`Agendum.TUI.Boxes.BoxDefaults`): a new view's settings;
  # the name, the sections and the statistics have no default. Each reads
  # the view as it is when it runs, so ALT-F8 can run them one after another
  @impl Box
  def defaults(state, mode) do
    id = mode.view_id
    new = %Agendum.Core.View{}

    options =
      Map.new(@options, fn {field, option} ->
        {field, &option_back(&1, id, option, Map.fetch!(new, option))}
      end)

    # a datebook view's settings go back to a new datebook's
    datebook =
      if state.db.views[id].datebook,
        do: Map.new(DatebookSettings.defaults(id), fn {row, back} -> {@short[row], back} end),
        else: %{}

    options
    |> Map.merge(datebook)
    |> Map.merge(%{
      sorting: &State.run(&1, {:set_sort, id, :view, new.sort}),
      section_sort:
        &State.run(&1, {:set_section_sort, id, new.section_sort, &1.db.views[id].section_order}),
      order:
        &State.run(&1, {:set_section_sort, id, &1.db.views[id].section_sort, new.section_order}),
      filter: &State.run(&1, {:set_filters, id, :view, new.filter})
    })
  end

  # a Yes/No setting is switched only when it is not its default already
  defp option_back(state, id, option, default) do
    if Map.fetch!(state.db.views[id], option) == default,
      do: state,
      else: State.run(state, {:toggle_view_option, id, option})
  end

  # on the Sections list Agenda's bar has no F8 DEFAULT (checked in Agenda
  # 2.0, 2026-10-25): a list has no default
  @impl Box
  def idle_keys(state, mode),
    do: if(field(state, mode) == :sections, do: [{:f, 8}, {:alt_f, 8}], else: [])

  @impl Box
  def field(_state, %{moving: moving}) when moving != nil, do: :moving

  def field(state, mode) do
    case current(state, mode) do
      {:section, _} -> :sections
      field -> field
    end
  end
end
