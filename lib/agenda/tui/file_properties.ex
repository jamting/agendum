defmodule Agenda.TUI.FileProperties do
  @moduledoc """
  The File Properties box (File ▸ Properties; User's Guide 7-13 to 7-17)
  and the boxes it opens, nested as in Agenda 2.0, each row with "..."
  opening the next box:

    * File Properties (`:file_props`): Insert new columns in (R55), Global
      date settings ..., and Auto-assign settings ...
      (`Agenda.TUI.AutoAssignBox`, R16a). Drawn from `@layout`
      (`Agenda.TUI.Template`), Agenda's box (screenshot 130) with only the
      settings Agendum has
    * Global Date Settings (`:date_settings`, R14e): Display format ...,
      Input format ... (the person's own box, `Agenda.TUI.InputFormatBox`,
      R41b), then beginning and end of week, first quarter, beginning of
      year, month alone means, morning, afternoon, evening
    * Display Format (`:display_format`, R41): the Date Column Properties
      rows (`Agenda.TUI.DateFormatRows`), with a formatted sample below

  SPACE or → shows the next choice (or opens a "..." box), ← the previous
  one; every change applies at once and is one undo step. ENTER closes
  the box, ESC closes it and cancels its changes (`Agenda.TUI.BoxCancel`);
  either goes back to the box beneath. Pure.
  """

  alias Agenda.Core
  alias Agenda.Core.{DateFormat, DateSettings}
  alias Agenda.TUI.{DateFormatRows, State, Template}

  # Agenda's File Properties (screenshot 130), its other settings left out
  # until Agendum has them
  @layout """
   Insert new columns in:  [insert_columns ]

   Global date settings:   [dates]   Auto-assign settings:  [auto ]

   SPACE/→ next choice or open ... · ← previous
  """

  @format_rows DateFormatRows.rows()
  @settings_rows [
    :week_start,
    :week_end,
    :quarter_start,
    :year_start,
    :month_alone,
    :morning,
    :afternoon,
    :evening
  ]
  @rows %{
    file_props: Template.fields(@layout),
    date_settings: [:display_format, :input_format | @settings_rows],
    display_format: @format_rows
  }
  @days ~w(Mon Tue Wed Thu Fri Sat Sun)
  @months ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

  @doc "The box types, outermost first."
  def types, do: [:file_props, :date_settings, :display_format]

  def open(state, type \\ :file_props), do: State.push(state, %{type: type, cursor: 0})

  def handle(state, mode, key) do
    rows = @rows[mode.type]
    row = Enum.at(rows, mode.cursor)

    case key do
      k when k in [:esc, :enter] -> State.pop(state)
      :up -> State.put_mode(state, %{mode | cursor: max(mode.cursor - 1, 0)})
      :down -> State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, length(rows) - 1)})
      k when k in [{:char, " "}, :right] -> change(state, row, 1)
      :left -> change(state, row, -1)
      _ -> state
    end
  end

  defp change(state, :dates, _step), do: open(state, :date_settings)
  defp change(state, :display_format, _step), do: open(state, :display_format)
  defp change(state, :auto, _step), do: Agenda.TUI.AutoAssignBox.open(state)

  # two choices, so SPACE, → and ← all flip it
  defp change(state, :insert_columns, _step) do
    where = if state.db.insert_columns == :all, do: :section, else: :all
    State.change_db(state, Core.set_insert_columns(state.db, where))
  end

  defp change(state, :input_format, _step), do: Agenda.TUI.InputFormatBox.open(state)

  defp change(state, row, step) when row in @settings_rows do
    settings = DateSettings.cycle(state.db.date_settings, row, step)
    State.change_db(state, Core.set_date_settings(state.db, settings))
  end

  defp change(state, row, step) do
    format = DateFormat.cycle(state.db.date_format, row, step)
    State.change_db(state, Core.set_date_format(state.db, format))
  end

  @doc "The File Properties box's lines, the highlighted setting selected."
  def content(state, mode) do
    values = %{
      insert_columns:
        if(state.db.insert_columns == :all, do: "All sections", else: "Current section"),
      dates: "...",
      auto: "..."
    }

    Template.render(@layout, values, selected: Enum.at(@rows.file_props, mode.cursor))
  end

  @doc "`{label, value}` for each row of the boxes inside File Properties."
  def lines(state, type)

  def lines(state, :display_format), do: DateFormatRows.lines(state.db.date_format)

  def lines(state, :date_settings) do
    f = state.db.date_format
    s = state.db.date_settings

    [
      {"Display format", "..."},
      {"Input format", "... (yours)"},
      {"Beginning of week", Enum.at(@days, s.week_start - 1)},
      {"End of week", Enum.at(@days, s.week_end - 1)},
      {"First quarter", Enum.at(@months, s.quarter_start - 1) <> " 1"},
      {"Beginning of year", Enum.at(@months, s.year_start - 1) <> " 1"},
      {"Month alone means", month_alone(s.month_alone)},
      {"Morning", DateFormat.time(s.morning, f)},
      {"Afternoon", DateFormat.time(s.afternoon, f)},
      {"Evening", DateFormat.time(s.evening, f)}
    ]
  end

  defp month_alone(:first), do: "First day"
  defp month_alone(:last), do: "Last day"
  defp month_alone(day), do: "Day #{day}"

  @doc "The highlighted field, for its help in the control panel (`Agenda.TUI.FieldHelp`)."
  def field(_state, mode), do: Enum.at(@rows[mode.type], mode.cursor)
end
