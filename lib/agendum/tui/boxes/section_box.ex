defmodule Agendum.TUI.Boxes.SectionBox do
  @moduledoc """
  The Section Properties box (View ▸ Section ▸ Properties, or F6 on a
  section head, as Agenda's PROPS; R61; Help "Section Properties/Add
  Box"): one section's settings in one place.

    * Section head: type a name (a new category if need be) or F3 to pick
      one; F6 opens the head category's properties
    * Item sorting ...: the section's sort (`Agendum.TUI.Boxes.SortBox`)
    * Section statistics ...: how many items the section shows
    * Select numeric functions ...: the calculations of all the section's
      numeric columns (`Agendum.TUI.Boxes.NumericFunctionsBox`), shown only when
      it has one
    * Filter: the section's filter (the filter picker)
    * Columns: the section's columns in their order, the item column as
      `<Items>`; DEL removes one from this section, ALT-↑ ↓ move one
      (the item column too), INS adds one right of the highlighted one
      (Column Add). Agenda's ALT-F10 moved them; ours are the macro
      manager's keys.

  Opened by View ▸ Section ▸ Add (`open_add/2`) it is Agenda's Section
  Add box: blank, with Insert (Below or Above the current section) under
  the head. The section is added once its head is typed or picked, and the
  box goes on as that section's settings; switching Insert then moves it to
  the other side. ESC takes it all back, the new section included.

  SPACE on a setting opens it; ENTER closes the box, ESC closes it and
  cancels its changes (`Agendum.TUI.Boxes.BoxCancel`). Each change is one undo
  step. The settings are drawn from
  `@layout` (`Agendum.TUI.Boxes.Template`), the columns listed below it. Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, indicator: "PROPS", cancels: true

  alias Agendum.TUI.Boxes.{Box, BoxNav}

  alias Agendum.Core
  alias Agendum.Core.{View, ViewColumns, ViewModel}

  alias Agendum.TUI.{
    CategoryScreens,
    Boxes.ColumnAddBox,
    Boxes.FieldTyping,
    Boxes.NumericFunctionsBox,
    Boxes.SortBox,
    State,
    Boxes.Template
  }

  alias Agendum.TUI.Render.Text

  # Select numeric functions shows only for a section with a numeric
  # column, Insert only in Section Add (a value nil leaves the row out)
  @layout """
   Section head             : [head                        ]
   Insert                   : [insert                      ]
   Item sorting             : [sorting                     ]
   Section statistics       : [statistics                  ]
   Select numeric functions : [numeric                     ]
   Filter                   : [filter                      ]

   Columns:
  """

  @help %{
    head:
      "Type a new or existing category name, or press F3 to pick one. " <>
        "F6 shows the category's properties.",
    insert:
      "Choose where the new section goes: below the current section or above it. " <>
        "SPACE switches.",
    sorting: "Press SPACE BAR to choose how the items in this section are sorted.",
    statistics: "Press SPACE BAR to see how many items the section shows.",
    numeric:
      "Press SPACE BAR to choose the calculations (total, average…) " <>
        "of the section's numeric columns.",
    filter: "Show only items in (or not in) some categories. Press SPACE BAR to choose them.",
    columns:
      "The section's columns. INS adds one, DEL removes it from this section, " <>
        "ALT-↑ ↓ moves it."
  }

  @doc "Opens the box for section `sidx` of the current view."
  def open(state, sidx),
    do: State.push(state, %Agendum.TUI.Modes.SectionProps{sidx: sidx, cursor: 0})

  @doc """
  Opens it as Agenda's Section Add box (View ▸ Section ▸ Add), blank, for a
  section below (or, with Insert, above) section `from` of the current view.
  """
  def open_add(state, from) do
    State.push(state, %Agendum.TUI.Modes.SectionProps{
      sidx: nil,
      cursor: 0,
      adding: %{from: from, insert: :below}
    })
  end

  # Domain: `sidx` is nil in Section Add until the head is chosen, when the
  # section exists
  defp section(_state, %{sidx: nil}), do: nil
  defp section(state, mode), do: Enum.at(State.view(state).sections, mode.sidx)
  defp slots(_state, %{sidx: nil}), do: []
  defp slots(state, mode), do: ViewColumns.slots(State.view(state), mode.sidx)

  # the settings shown, in the cursor's order: before Section Add has its
  # head, only the head and Insert
  defp fields(_state, %{sidx: nil}), do: [:head, :insert]

  defp fields(state, mode) do
    fields = Template.fields(@layout)
    fields = if numeric?(state, mode), do: fields, else: List.delete(fields, :numeric)
    if mode.adding, do: fields, else: List.delete(fields, :insert)
  end

  defp numeric?(state, mode), do: Core.section_calcs(state.db, state.view_id, mode.sidx) != nil

  # where the new section goes: right below the current one, or in its
  # place, the current one moving down
  defp insert_at(%{from: from, insert: :below}), do: from + 1
  defp insert_at(%{from: from, insert: :above}), do: max(from, 0)

  @doc "Section Add's head, typed or picked: the section is added, or its head changed."
  @spec set_new_head(State.t(), Agendum.Core.Database.id()) :: State.t()
  def set_new_head(state, id) do
    case State.mode(state) do
      %{sidx: nil, adding: adding} = mode ->
        at = min(insert_at(adding), length(State.view(state).sections))
        # `from` (the current section, or 0) gives it its linked columns (R55)
        state = State.run(state, {:add_section, state.view_id, id, at, max(adding.from, 0)})
        State.put_mode(state, %{mode | sidx: at})

      mode ->
        State.run(state, {:set_section_category, state.view_id, mode.sidx, id})
    end
  end

  # Insert switched: before the head only the setting; after it, the new
  # section moves to the other side of the current one
  defp switch_insert(state, %{adding: adding} = mode) do
    adding = %{adding | insert: if(adding.insert == :below, do: :above, else: :below)}

    case mode.sidx do
      nil ->
        State.put_mode(state, %{mode | adding: adding})

      sidx ->
        to = min(insert_at(adding), length(State.view(state).sections) - 1)

        state
        |> State.run({:move_section, state.view_id, sidx, to})
        |> State.put_mode(%{mode | adding: adding, sidx: to})
    end
  end

  # the rows: the settings, then `{:slot, n}` for the nth column listed
  defp rows(state, mode),
    do: fields(state, mode) ++ Enum.map(0..(length(slots(state, mode)) - 1)//1, &{:slot, &1})

  # the highlighted row
  defp row(state, mode) do
    rows = rows(state, mode)
    Enum.at(rows, min(mode.cursor, length(rows) - 1))
  end

  defp last(state, mode), do: length(fields(state, mode)) + length(slots(state, mode)) - 1

  @impl Box
  def handle(state, mode, key) do
    if FieldTyping.typing?(mode),
      do: FieldTyping.key(state, mode, key, &typed/3),
      else: typing_key(state, mode, key)
  end

  # a letter on Head starts typing the head's name
  defp typing_key(state, mode, {:char, c}) when c != " " do
    if row(state, mode) == :head, do: FieldTyping.start(state, mode, :head, c), else: state
  end

  defp typing_key(state, _mode, _key), do: state

  # the settings box's keys, and those of its columns list (R65)
  @impl Box
  def keymap(_mode) do
    Box.settings_keymap(%{
      {:f, 3} => :pick,
      {:f, 6} => :properties,
      :insert => :add,
      :delete => :remove,
      {:ctrl, "d"} => :remove,
      {:alt, :up} => :move_up,
      {:alt, :down} => :move_down
    })
  end

  @impl Box
  def commands(_mode) do
    Box.settings_commands([
      {:pick, "Pick head", "Choose the head's category"},
      {:properties, "Head properties", "The head category's properties"},
      {:add, "Add column", "Add a column to the section"},
      {:remove, "Remove column", "Remove the column from the section"},
      {:move_up, "Move up", "Move the column up"},
      {:move_down, "Move down", "Move the column down"}
    ])
  end

  # ENTER is done (ESC cancels: `Agendum.TUI.Boxes.BoxCancel`)
  @impl Box
  def run(state, mode, id), do: command(state, mode, id, row(state, mode))

  # ENTER in Section Add before a head: Agenda's box does not close
  defp command(state, %{sidx: nil}, :done, _row),
    do: State.error(state, "Type the section head's name, or press F3 to pick it")

  defp command(state, mode, :pick, :head), do: open_setting(state, mode, :head)

  defp command(state, %{sidx: nil}, :properties, :head), do: state

  defp command(state, mode, :properties, :head),
    do: CategoryScreens.open_props(state, section(state, mode).category_id)

  defp command(state, mode, :change, :insert), do: switch_insert(state, mode)

  defp command(state, mode, :change, row) when is_atom(row), do: open_setting(state, mode, row)
  defp command(state, mode, :add, row), do: add(state, mode, row)
  defp command(state, mode, :remove, row), do: remove(state, mode, row)
  defp command(state, mode, :move_up, row), do: move(state, mode, row, -1)
  defp command(state, mode, :move_down, row), do: move(state, mode, row, 1)

  defp command(state, _mode, id, _row) when id in [:pick, :properties, :change], do: state

  defp command(state, mode, id, _row),
    do: Box.run_settings(state, mode, BoxNav.column(rows(state, mode)), id)

  # a typed head: that category heads the section (a new one is made under
  # MAIN when no category has the name), one change
  defp typed(state, :head, name) do
    mode = State.mode(state)

    FieldTyping.head_named(state, name, fn state, id ->
      case mode.sidx do
        nil -> set_new_head(state, id)
        sidx -> State.run(state, {:set_section_category, state.view_id, sidx, id})
      end
    end)
  end

  defp open_setting(state, %{sidx: nil}, :head),
    do: CategoryScreens.open_picker(state, :section_add_head, nil)

  defp open_setting(state, mode, :head),
    do: CategoryScreens.open_picker(state, {:change_section, mode.sidx}, nil)

  defp open_setting(state, mode, :sorting), do: SortBox.open(state, {:section, mode.sidx})

  defp open_setting(state, mode, :statistics) do
    name = state.db.categories[section(state, mode).category_id].name

    State.info(
      state,
      "#{Agendum.TUI.Terminal.Draw.count(item_count(state, mode), "item")} in #{name}"
    )
  end

  defp open_setting(state, mode, :numeric), do: NumericFunctionsBox.open(state, mode.sidx)

  defp open_setting(state, mode, :filter),
    do: CategoryScreens.open_picker(state, {:filter, {:section, mode.sidx}}, nil)

  # the items the section shows now, as the view draws it
  defp item_count(state, mode) do
    state.db
    |> ViewModel.build(State.view(state), State.context(state))
    |> Enum.at(mode.sidx)
    |> Map.fetch!(:rows)
    |> length()
  end

  defp remove(state, mode, {:slot, n}) do
    case Enum.at(slots(state, mode), n) do
      :items ->
        State.error(state, "The item column stays; remove the other columns")

      index ->
        # the highlight stays on the row, which is now the next column
        state = State.run(state, {:remove_column, state.view_id, {mode.sidx, index}, :section})
        State.put_mode(state, %{mode | cursor: min(mode.cursor, last(state, mode))})
    end
  end

  defp remove(state, _mode, _row), do: state

  defp move(state, mode, {:slot, n}, step) do
    to = n + step

    if to < 0 or to >= length(slots(state, mode)) do
      state
    else
      state
      |> State.run({:move_column, state.view_id, mode.sidx, n, to})
      |> State.put_mode(%{mode | cursor: mode.cursor + step})
    end
  end

  defp move(state, _mode, _row, _step), do: state

  # Column Add counts the view's columns from 1, 0 being the item text
  defp add(state, mode, {:slot, n}) do
    col =
      case Enum.at(slots(state, mode), n) do
        :items -> 0
        index -> index + 1
      end

    ColumnAddBox.open(state, mode.sidx, col)
  end

  defp add(state, mode, _row), do: ColumnAddBox.open(state, mode.sidx, 0)

  # --- drawing ---

  @impl Box
  def title(_state, %{adding: %{}}), do: "Section Add"

  def title(_state, _mode), do: "Section Properties"

  @impl Box
  def content(state, mode, inner, _max_rows) do
    view = State.view(state)
    row = row(state, mode)
    values = Map.put(values(state, mode, section(state, mode)), :insert, insert_text(mode))

    opts = [selected: row] ++ FieldTyping.editing(mode)

    Template.render(@layout, values, opts) ++
      columns(state, view, mode, row) ++ [[], Box.hint(keys(state, mode), inner)]
  end

  # Section Add before its head: the head empty, the other settings left out
  defp values(_state, _mode, nil),
    do: %{head: "", sorting: nil, statistics: nil, numeric: nil, filter: nil}

  defp values(state, mode, section) do
    %{
      head: state.db.categories[section.category_id].name,
      sorting: if(section.sort == nil, do: "As the view ...", else: "Its own ..."),
      statistics: "...",
      numeric: if(numeric?(state, mode), do: "..."),
      filter: filter(state, section.filter)
    }
  end

  defp insert_text(%{adding: %{insert: :below}}), do: "Below current section"
  defp insert_text(%{adding: %{insert: :above}}), do: "Above current section"
  defp insert_text(_mode), do: nil

  defp filter(_state, []), do: "(none)"
  defp filter(state, filter), do: Text.filter_text(state, filter)

  defp columns(_state, _view, %{sidx: nil}, _row), do: []

  defp columns(state, view, mode, row) do
    columns = View.columns(view, mode.sidx)

    state
    |> slots(mode)
    |> Enum.with_index()
    |> Enum.map(fn {slot, n} ->
      name =
        case slot do
          :items -> "<Items>"
          index -> column_name(state, Enum.at(columns, index))
        end

      [{:box, "   "}, {if(row == {:slot, n}, do: :box_selected, else: :box), name}]
    end)
  end

  defp column_name(_state, %View.Column{title: title}) when is_binary(title), do: title
  defp column_name(state, column), do: state.db.categories[column.category_id].name

  @impl Box
  def keys(_state, _mode),
    do: [
      {"↑↓←→", "Setting", "Move between settings and columns"},
      {"SPACE", "Open", "Open the setting"},
      {"DEL", "Remove", "Remove the column from this section"},
      {"ALT-↑↓", "Move", "Move the column"},
      {"INS", "Add", "Add a column"},
      {"F3", "Choices", "Pick the section head"},
      {"F6", "Props", "The head category's properties"},
      {"ENTER", "Done"},
      {"ESC", "Cancel"}
    ]

  # F8 and ALT-F8 (`Agendum.TUI.Boxes.BoxDefaults`): the section's sort back
  # to the view's ("View default", User's Guide 15-20) and no filter; the
  # head, the statistics and the columns have none. Section Add before its
  # head has nothing to put back
  @impl Box
  def defaults(_state, %{sidx: nil}), do: %{}

  def defaults(_state, mode) do
    scope = {:section, mode.sidx}

    %{
      sorting: &State.run(&1, {:set_sort, &1.view_id, scope, nil}),
      filter: &State.run(&1, {:set_filters, &1.view_id, scope, []})
    }
  end

  @impl Box
  def help, do: @help

  @impl Box
  def field(state, mode) do
    case row(state, mode) do
      {:slot, _} -> :columns
      field -> field
    end
  end
end
