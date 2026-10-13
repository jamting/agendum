defmodule Agenda.TUI.ColumnBox do
  @moduledoc """
  The Column Properties box (View ▸ Column ▸ Properties; User's Guide 3-18
  to 3-19, 6-19 to 6-22, 8-6 to 8-7; screenshots 127, 133, 142): one box
  for every column, as Agenda's.

    * The top part is every column's: Column head (F3, SPACE or → picks
      another category, R55), Category type (shown; a category's type is
      changed in its Category Properties), Width (→ ← by one) and Link
      with other sections (R55).
    * Below a rule, a numeric column has its Numeric Column Properties
      (R29): currency symbol, decimal places, thousands separator, negative
      indicator and the calculations, with formatted samples.
    * A date column has its Date Column Properties (R41a): Settings says
      "Global defaults" while it uses the file's format and "Local
      settings" once it has its own (any change makes them its own; SPACE
      on Settings goes back), then `Agenda.TUI.DateFormatRows`, with a
      formatted sample.

  Each part is a layout (`Agenda.TUI.Template`); the cursor goes through
  the fields in reading order. Every change applies at once to the column
  and the columns linked to it, and is one undo step. ESC or ENTER closes
  the box. Pure.
  """

  alias Agenda.Core
  alias Agenda.Core.{Database, DateFormat, NumberFormat, View}
  alias Agenda.TUI.{CategoryScreens, DateFormatRows, Draw, State, Template}

  @top """
   Column head: [head          ]  Category type:            [type    ]
   Width:       [width ]          Link with other sections: [linked  ]
  """

  @numeric """
                         Numeric Column Properties

   Label or currency symbol: [symbol    ]  Count:   [count]
   Decimal places:           [decimals  ]  Total:   [total]
   Use thousands separator:  [thousands ]  Average: [average]
   Negative indicator:       [negative  ]  Minimum: [minimum]
                                           Maximum: [maximum]
  """

  @date """
                          Date Column Properties

   Settings:                 [settings       ]
   Display date and/or time: [show       ]  Clock:          [clock   ]
   Show day of week:         [day_of_week]  Show am/pm:     [am_pm   ]
   Date format:              [order      ]
   Date separator:           [separator  ]  Time separator: [time_sep]
  """

  @hint " SPACE/→ next choice · ← previous · F3 picks the head · ESC closes"
  @max_decimals 6
  @date_rows DateFormatRows.rows()

  @doc "Opens the box for the column at `at` (`{section, column}`, R55)."
  def open(state, at), do: State.push(state, %{type: :column_props, column: at, cursor: 0})

  @doc "The column the box is for."
  def column(state, %{column: {sidx, index}}),
    do: state |> State.view() |> View.columns(sidx) |> Enum.at(index)

  @doc "The box's fields for a column of this kind, in the cursor's order."
  @spec fields(:standard | :numeric | :date) :: [atom]
  def fields(kind), do: kind |> layout() |> Template.fields()

  defp layout(:standard), do: @top
  defp layout(:numeric), do: @top <> rule() <> @numeric
  defp layout(:date), do: @top <> rule() <> @date

  # a line across the box, as Agenda draws between the two parts
  defp rule, do: " " <> String.duplicate("─", 70) <> "\n"

  defp kind(state, mode) do
    cat_id = column(state, mode).category_id

    cond do
      state.db.categories[cat_id].kind == :numeric -> :numeric
      Database.date_category?(state.db, cat_id) -> :date
      true -> :standard
    end
  end

  # The highlighted field. After the head changes the column may be of
  # another kind, with fewer fields, so the cursor is kept within them.
  defp field(state, mode) do
    fields = fields(kind(state, mode))
    Enum.at(fields, min(mode.cursor, length(fields) - 1))
  end

  def handle(state, mode, key) do
    last = length(fields(kind(state, mode))) - 1
    row = field(state, mode)

    case key do
      k when k in [:esc, :enter] -> State.pop(state)
      :up -> State.put_mode(state, %{mode | cursor: max(min(mode.cursor, last) - 1, 0)})
      :down -> State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, last)})
      {:f, 3} when row == :head -> pick_head(state, mode)
      k when k in [{:char, " "}, :right] -> change(state, mode, row, 1)
      :left -> change(state, mode, row, -1)
      _ -> state
    end
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

  @doc "The box's lines, the highlighted setting selected."
  def content(state, mode) do
    kind = kind(state, mode)
    column = column(state, mode)

    top = %{
      head: state.db.categories[column.category_id].name,
      type: kind |> Atom.to_string() |> String.capitalize(),
      width: Integer.to_string(column.width),
      linked: yes_no(column.link != nil)
    }

    values = Map.merge(top, values(state, mode, kind))
    lines = Template.render(layout(kind), values, selected: field(state, mode))
    lines ++ samples(state, mode, kind) ++ [[], [{:box, @hint}]]
  end

  defp values(_state, _mode, :standard), do: %{}

  defp values(state, mode, :numeric) do
    f = column(state, mode).number

    calcs =
      Map.new(NumberFormat.calcs(), fn calc -> {calc, yes_no(calc in f.calcs)} end)

    Map.merge(calcs, %{
      symbol: f.symbol || "None",
      decimals: Integer.to_string(f.decimals),
      thousands: yes_no(f.thousands),
      negative: if(f.negative == :minus, do: "-", else: "()")
    })
  end

  defp values(state, mode, :date) do
    # `DateFormatRows.lines/1` gives `{label, value}` in its rows' order;
    # `Enum.zip/2` pairs each row's name with its value
    dates =
      DateFormatRows.rows()
      |> Enum.zip(DateFormatRows.lines(date_format(state, mode)))
      |> Map.new(fn {row, {_label, value}} -> {row, value} end)

    dates
    |> Map.put(:time_sep, dates.time_separator)
    |> Map.put(
      :settings,
      if(column(state, mode).date, do: "Local settings", else: "Global defaults")
    )
  end

  defp samples(_state, _mode, :standard), do: []

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

  defp yes_no(true), do: "Yes"
  defp yes_no(false), do: "No"
end
