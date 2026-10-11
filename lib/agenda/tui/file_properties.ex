defmodule Agenda.TUI.FileProperties do
  @moduledoc """
  The File Properties box (File ▸ Properties; User's Guide 7-13 to 7-17)
  and the boxes it opens, nested as in Agenda 2.0, each row with "..."
  opening the next box:

    * File Properties (`:file_props`): Global date settings ..., and
      Auto-assign settings ... (`Agenda.TUI.AutoAssignBox`, R16a)
    * Global Date Settings (`:date_settings`, R14e): Display format ...,
      Input format ... (the person's own box, `Agenda.TUI.InputFormatBox`,
      R41b), then beginning and end of week, first quarter, beginning of
      year, month alone means, morning, afternoon, evening
    * Display Format (`:display_format`, R41): the Date Column Properties
      rows (`Agenda.TUI.DateFormatRows`), with a formatted sample below

  SPACE or → shows the next choice (or opens a "..." box), ← the previous
  one; every change applies at once and is one undo step. ESC goes back to
  the box beneath; ENTER closes the box too. Pure.
  """

  alias Agenda.Core
  alias Agenda.Core.{DateFormat, DateSettings}
  alias Agenda.TUI.{DateFormatRows, State}

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
    file_props: [:date_settings, :auto_assign],
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

  defp change(state, :date_settings, _step), do: open(state, :date_settings)
  defp change(state, :display_format, _step), do: open(state, :display_format)
  defp change(state, :auto_assign, _step), do: Agenda.TUI.AutoAssignBox.open(state)
  defp change(state, :input_format, _step), do: Agenda.TUI.InputFormatBox.open(state)

  defp change(state, row, step) when row in @settings_rows do
    settings = DateSettings.cycle(state.db.date_settings, row, step)
    State.change_db(state, Core.set_date_settings(state.db, settings))
  end

  defp change(state, row, step) do
    format = DateFormat.cycle(state.db.date_format, row, step)
    State.change_db(state, Core.set_date_format(state.db, format))
  end

  @doc "`{label, value}` for each row of a box."
  def lines(state, type \\ :file_props)

  def lines(_state, :file_props),
    do: [{"Global date settings", "..."}, {"Auto-assign settings", "..."}]

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
end
