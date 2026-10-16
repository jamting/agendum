defmodule Agendum.TUI.Boxes.ColumnBox do
  @moduledoc """
  The Column Properties box (View ▸ Column ▸ Properties; User's Guide 3-18
  to 3-19, 6-19 to 6-22, 8-6 to 8-7; screenshots 127, 133, 142): one box
  for every column, as Agenda's.

    * The top part is every column's: Column head (typing a name gives
      the category of that name, or a new one, `Agendum.TUI.Boxes.FieldTyping`;
      F3 or SPACE picks another category, R55), Category type (shown; a category's type is
      changed in its Category Properties), Width (typed) and Link
      with other sections (R55).
    * Below a rule, a numeric column has its Numeric Column Properties
      (R29): currency symbol, decimal places, thousands separator, negative
      indicator, Display % of total (a "% tot" column beside it) and the
      calculations, with formatted samples.
    * A date column has its Date Column Properties (R41a): Settings says
      "Global defaults" while it uses the file's format and "Local
      settings" once it has its own (any change makes them its own; SPACE
      on Settings goes back), then `Agendum.TUI.Boxes.DateFormatRows`, with a
      formatted sample.

  Each part is a layout (`Agendum.TUI.Boxes.Template`); the cursor goes through the
  fields in reading order. Every change applies at once to the column and
  the columns linked to it, and is one undo step. ENTER closes the box; ESC
  closes it and cancels its changes (`Agendum.TUI.Boxes.BoxCancel`). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, indicator: "PROPS", cancels: true

  alias Agendum.TUI.Boxes.{Box}

  alias Agendum.Core
  alias Agendum.Core.{Database, DateFormat, NumberFormat, View}

  alias Agendum.TUI.{
    CategoryScreens,
    Boxes.DateFormatRows,
    Terminal.Draw,
    Boxes.FieldTyping,
    State,
    Boxes.Template
  }

  @top """
   Column head:  [head         ]  Category type:            [type    ]
   Width:        [width ]         Link with other sections: [linked  ]
  """

  # a standard column's Format (R56); Category note has a line and a title
  @standard """
   Format:       [format              ]
  """

  @note """
   Format:       [format              ]
   Line number:  [note_line ]
   Column title: [title                        ]
  """

  @numeric """
                         Numeric Column Properties

   Label or currency symbol: [symbol    ]  Count:   [count]
   Decimal places:           [decimals  ]  Total:   [total]
   Use thousands separator:  [thousands ]  Average: [average]
   Negative indicator:       [negative  ]  Minimum: [minimum]
   Display % of total:       [percent   ]  Maximum: [maximum]
  """

  @date """
                          Date Column Properties

   Settings:                 [settings       ]
   Display date and/or time: [show       ]  Clock:          [clock   ]
   Show day of week:         [day_of_week]  Show am/pm:     [am_pm   ]
   Date format:              [order      ]
   Date separator:           [separator  ]  Time separator: [time_sep]
  """

  @max_decimals 6
  @date_rows DateFormatRows.rows()

  @doc "Opens the box for the column at `at` (`{section, column}`, R55)."
  def open(state, at), do: State.push(state, %{type: :column_props, column: at, cursor: 0})

  @doc "The column the box is for."
  def column(state, %{column: {sidx, index}}),
    do: state |> State.view() |> View.columns(sidx) |> Enum.at(index)

  @doc "The box's fields for a column of this kind, in the cursor's order."
  @spec fields(:standard | :note | :numeric | :date) :: [atom]
  def fields(kind), do: kind |> layout() |> Template.fields()

  defp layout(:standard), do: @top <> @standard
  defp layout(:note), do: @top <> @note
  defp layout(:numeric), do: @top <> rule() <> @numeric
  defp layout(:date), do: @top <> rule() <> @date

  # a line across the box, as Agenda draws between the two parts
  defp rule, do: " " <> String.duplicate("─", 70) <> "\n"

  defp kind(state, mode) do
    cat_id = column(state, mode).category_id

    cond do
      state.db.categories[cat_id].kind == :numeric -> :numeric
      Database.date_category?(state.db, cat_id) -> :date
      column(state, mode).format == :note -> :note
      true -> :standard
    end
  end

  # The highlighted field. After the head changes the column may be of
  # another kind, with fewer fields, so the cursor is kept within them.
  @impl Box
  def field(state, mode) do
    fields = fields(kind(state, mode))
    Enum.at(fields, min(mode.cursor, length(fields) - 1))
  end

  @impl Box
  def handle(state, mode, key) do
    if FieldTyping.typing?(mode),
      do: FieldTyping.key(state, mode, key, &typed(&1, &2, &3, mode.column)),
      else: typing_key(state, mode, key)
  end

  # a typed head: the column (and those linked to it) shows it, with a new
  # category made for it if need be, as one change
  defp typed(state, :head, name, at) do
    FieldTyping.head_named(state, name, fn state, id ->
      State.run(state, {:set_column_head, state.view_id, at, id})
    end)
  end

  # a Category note column's title (R56)
  defp typed(state, :title, text, at),
    do: State.change_db(state, Core.set_column_display(state.db, state.view_id, at, title: text))

  # a typed number (Agenda's "type your own choice"): the width, the line
  # of the category note, or the decimal places
  defp typed(state, :width, text, at) do
    case FieldTyping.number(text, 1, 200) do
      {:ok, n} -> State.change_db(state, Core.set_column_width(state.db, state.view_id, at, n))
      :error -> State.error(state, "Type a width, a number")
    end
  end

  defp typed(state, :note_line, text, at) do
    case FieldTyping.number(text, 1, 99) do
      {:ok, n} ->
        State.change_db(state, Core.set_column_display(state.db, state.view_id, at, note_line: n))

      :error ->
        State.error(state, "Type a line number")
    end
  end

  defp typed(state, :decimals, text, at) do
    case FieldTyping.number(text, 0, @max_decimals) do
      {:ok, n} ->
        format = %{column(state, State.mode(state)).number | decimals: n}
        State.change_db(state, Core.set_column_format(state.db, state.view_id, at, format))

      :error ->
        State.error(state, "Type 0 to #{@max_decimals} decimal places")
    end
  end

  # a letter in Head or Column title, a digit in a number, starts typing it
  defp typing_key(state, mode, {:char, c}) when c != " " do
    row = field(state, mode)

    cond do
      row in [:head, :title] ->
        FieldTyping.start(state, mode, row, c)

      row in [:width, :note_line, :decimals] and FieldTyping.digit?(c) ->
        FieldTyping.start(state, mode, row, c)

      true ->
        state
    end
  end

  defp typing_key(state, _mode, _key), do: state

  # the settings box's keys; F3 on Head picks it (R65)
  @impl Box
  def keymap(_mode), do: Box.settings_keymap(%{{:f, 3} => :pick_head})

  @impl Box
  def commands(_mode),
    do: Box.settings_commands([{:pick_head, "Pick head", "Choose the head's category"}])

  @impl Box
  def run(state, mode, :change), do: change(state, mode, field(state, mode), 1)

  def run(state, mode, :pick_head),
    do: if(field(state, mode) == :head, do: pick_head(state, mode), else: state)

  def run(state, mode, id) do
    kind = kind(state, mode)
    Box.run_settings(state, mode, Template.grid(layout(kind), fields(kind)), id)
  end

  # the whole hierarchy, as Agenda's Column Head box (screenshot 144)
  defp pick_head(state, mode),
    do: CategoryScreens.open_picker(state, {:column_head, mode.column}, nil)

  # --- the top part ---

  defp change(state, mode, :head, _step), do: pick_head(state, mode)

  defp change(state, _mode, :type, _step),
    do: State.error(state, "A category's type is changed in its Category Properties")

  defp change(state, mode, :width, step),
    do: State.change_db(state, Core.resize_column(state.db, state.view_id, mode.column, step))

  defp change(state, mode, :linked, _step) do
    linked = column(state, mode).link == nil
    State.change_db(state, Core.set_column_linked(state.db, state.view_id, mode.column, linked))
  end

  # --- a standard column's Format (R56) ---

  defp change(state, mode, :format, step) do
    formats = View.Column.formats()
    index = Enum.find_index(formats, &(&1 == column(state, mode).format))
    format = Enum.at(formats, Integer.mod(index + step, length(formats)))
    display(state, mode, format: format)
  end

  defp change(state, mode, :note_line, step),
    do: display(state, mode, note_line: column(state, mode).note_line + step)

  defp change(state, _mode, :title, _step), do: State.error(state, "Type the column's title")

  # --- a date column ---

  defp change(state, mode, :settings, _step) do
    own = if column(state, mode).date, do: nil, else: state.db.date_format
    set_date(state, mode, own)
  end

  # (the layout's field is `time_sep`: `time_separator` is too long for it)
  defp change(state, mode, :time_sep, step), do: change(state, mode, :time_separator, step)

  defp change(state, mode, row, step) when row in @date_rows,
    do: set_date(state, mode, DateFormat.cycle(date_format(state, mode), row, step))

  # --- a numeric column ---

  defp change(state, mode, row, step) do
    format = state |> column(mode) |> Map.fetch!(:number) |> step(row, step)
    State.change_db(state, Core.set_column_format(state.db, state.view_id, mode.column, format))
  end

  defp display(state, mode, changes),
    do:
      State.change_db(
        state,
        Core.set_column_display(state.db, state.view_id, mode.column, changes)
      )

  defp set_date(state, mode, format),
    do:
      State.change_db(
        state,
        Core.set_column_date_format(state.db, state.view_id, mode.column, format)
      )

  @doc "The date format the column shows: its own or the file's."
  def date_format(state, mode), do: column(state, mode).date || state.db.date_format

  defp step(f, :symbol, step), do: %{f | symbol: cycle(NumberFormat.symbols(), f.symbol, step)}

  defp step(f, :decimals, step),
    do: %{f | decimals: Integer.mod(f.decimals + step, @max_decimals + 1)}

  defp step(f, :thousands, _step), do: %{f | thousands: not f.thousands}

  defp step(f, :negative, _step),
    do: %{f | negative: if(f.negative == :minus, do: :parens, else: :minus)}

  defp step(f, :percent, _step), do: %{f | percent: not f.percent}

  # a calculation: on or off, kept in Agenda's order
  defp step(f, calc, _step) do
    calcs =
      if calc in f.calcs,
        do: List.delete(f.calcs, calc),
        else: Enum.filter(NumberFormat.calcs(), &(&1 == calc or &1 in f.calcs))

    %{f | calcs: calcs}
  end

  defp cycle(list, value, step) do
    index = Enum.find_index(list, &(&1 == value)) || 0
    Enum.at(list, Integer.mod(index + step, length(list)))
  end

  # --- drawing ---

  # the column's head is the box's first row, as in Agenda (screenshot 142)
  @impl Box
  def title(_state, _mode), do: "Column Properties"

  # two columns of settings, as Agenda's (screenshot 127)
  @impl Box
  def width(state, _mode), do: min(state.width - 8, 72)

  @impl Box
  def content(state, mode, inner, _max_rows) do
    kind = kind(state, mode)
    column = column(state, mode)

    top = %{
      head: state.db.categories[column.category_id].name,
      type:
        if(kind == :note, do: "Standard", else: kind |> Atom.to_string() |> String.capitalize()),
      width: Integer.to_string(column.width),
      linked: yes_no(column.link != nil)
    }

    values = Map.merge(top, values(state, mode, kind))
    opts = [selected: field(state, mode)] ++ FieldTyping.editing(mode)
    lines = Template.render(layout(kind), values, opts)
    lines ++ samples(state, mode, kind) ++ [[], Box.hint(keys(state, mode), inner)]
  end

  @impl Box
  def keys(_state, _mode),
    do: Box.settings_keys([{"type", "Number", "a number"}, {"F3", "Choices", "Pick the head"}])

  @impl Box
  def help do
    Map.merge(DateFormatRows.help(), %{
      head: "Press F3 to pick a category or type a new one.",
      type:
        "The type of the column's category: standard, date or numeric. " <>
          "Change it in the category's properties.",
      width: "The width of the column, in characters. Type it.",
      linked:
        "Whether the column changes with the same column in other sections. SPACE switches.",
      format:
        "How the column shows categories: name only, parent:category, ancestor, star, " <>
          "yes/no or a note line. SPACE changes it.",
      note_line: "Which line of the category note the column shows. Type it.",
      title: "Type the column's title.",
      symbol: "The label or currency symbol shown with numbers. SPACE for the next one.",
      decimals: "How many decimal places numbers show. Type it, or SPACE for one more.",
      thousands: "Whether numbers show a separator between thousands. SPACE switches.",
      negative: "How negative numbers show: with a minus sign or in parentheses. SPACE.",
      percent: "Whether a column with each number's percent of the total shows beside it. SPACE.",
      count: "Whether the section shows how many items have a number. SPACE switches.",
      total: "Whether the section shows the total of the column. SPACE switches.",
      average: "Whether the section shows the average of the column. SPACE switches.",
      minimum: "Whether the section shows the smallest number in the column. SPACE switches.",
      maximum: "Whether the section shows the largest number in the column. SPACE switches."
    })
  end

  defp values(state, mode, kind) when kind in [:standard, :note] do
    column = column(state, mode)

    %{
      format: format_name(column.format),
      note_line: Integer.to_string(column.note_line),
      title: column.title || ""
    }
  end

  defp values(state, mode, :numeric) do
    f = column(state, mode).number

    calcs =
      Map.new(NumberFormat.calcs(), fn calc -> {calc, yes_no(calc in f.calcs)} end)

    Map.merge(calcs, %{
      symbol: f.symbol || "None",
      decimals: Integer.to_string(f.decimals),
      thousands: yes_no(f.thousands),
      percent: yes_no(f.percent),
      negative: if(f.negative == :minus, do: "-", else: "()")
    })
  end

  defp values(state, mode, :date) do
    dates = DateFormatRows.values(date_format(state, mode))

    dates
    |> Map.put(:time_sep, dates.time_separator)
    |> Map.put(
      :settings,
      if(column(state, mode).date, do: "Local settings", else: "Global defaults")
    )
  end

  defp samples(_state, _mode, kind) when kind in [:standard, :note], do: []

  defp samples(state, mode, :numeric) do
    f = column(state, mode).number
    opts = State.number_opts(state)

    shown =
      NumberFormat.format(1234.5, f, opts) <> "     " <> NumberFormat.format(-1234.5, f, opts)

    [[], centred("Formatted Samples"), centred(shown)]
  end

  defp samples(state, mode, :date),
    do: [[], centred("Formatted Sample"), centred(DateFormat.sample(date_format(state, mode)))]

  # centred in the box, as Agenda's headings are
  defp centred(text),
    do: [{:box, Draw.pad(Draw.spaces(div(70 - String.length(text), 2)) <> text, 70)}]

  @doc "A Format's name as Agenda's box says it."
  def format_name(:name), do: "Name only"
  def format_name(:parent), do: "Parent:Category"
  def format_name(:ancestor), do: "Ancestor"
  def format_name(:star), do: "Star (*)"
  def format_name(:yes_no), do: "Yes/No"
  def format_name(:note), do: "Category note"

  defp yes_no(true), do: "Yes"
  defp yes_no(false), do: "No"
end
