defmodule Agenda.TUI.FileProperties do
  @moduledoc """
  The File Properties box (File ▸ Properties; User's Guide 7-13 to 7-17):
  how the file displays dates and times (SPEC R41), how it reads them
  (R14e), and whether text matches are confirmed first (Confirm
  assignments, R16).

  Rows: Date format, Date separator, Clock and Show day of week, with a
  formatted sample below, as in Agenda's Display Format box; then
  Agenda's Global Date Settings (beginning and end of week, first
  quarter, beginning of year, month alone means, morning, afternoon,
  evening); then Confirm assignments. SPACE or →
  shows the next choice, ← the previous one; every change applies at once
  and is one undo step. ESC or ENTER closes the box. Pure.
  """

  alias Agenda.Core
  alias Agenda.Core.{DateFormat, DateSettings}
  alias Agenda.TUI.State

  @format_rows [:order, :separator, :clock, :day_of_week]
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
  @rows @format_rows ++ @settings_rows ++ [:confirm]
  @days ~w(Mon Tue Wed Thu Fri Sat Sun)
  @months ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

  def open(state), do: State.push(state, %{type: :file_props, cursor: 0})

  def handle(state, mode, key) do
    row = Enum.at(@rows, mode.cursor)

    case key do
      k when k in [:esc, :enter] -> State.pop(state)
      :up -> State.put_mode(state, %{mode | cursor: max(mode.cursor - 1, 0)})
      :down -> State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, length(@rows) - 1)})
      k when k in [{:char, " "}, :right] -> change(state, row, 1)
      :left -> change(state, row, -1)
      _ -> state
    end
  end

  defp change(state, :confirm, _step) do
    mode = if state.db.confirm_assignments == :never, do: :always, else: :never
    State.change_db(state, Core.set_confirm_assignments(state.db, mode))
  end

  defp change(state, row, step) when row in @settings_rows do
    settings = DateSettings.cycle(state.db.date_settings, row, step)
    State.change_db(state, Core.set_date_settings(state.db, settings))
  end

  defp change(state, row, step) do
    format = DateFormat.cycle(state.db.date_format, row, step)
    State.change_db(state, Core.set_date_format(state.db, format))
  end

  @doc "`{label, value}` for each row."
  def lines(state) do
    f = state.db.date_format
    s = state.db.date_settings

    [
      {"Date format", DateFormat.label(f.order)},
      {"Date separator", separator(f.separator)},
      {"Clock", "#{f.clock} hr"},
      {"Show day of week", if(f.day_of_week, do: "Yes", else: "No")},
      {"Beginning of week", Enum.at(@days, s.week_start - 1)},
      {"End of week", Enum.at(@days, s.week_end - 1)},
      {"First quarter", Enum.at(@months, s.quarter_start - 1) <> " 1"},
      {"Beginning of year", Enum.at(@months, s.year_start - 1) <> " 1"},
      {"Month alone means", month_alone(s.month_alone)},
      {"Morning", DateFormat.time(s.morning, f)},
      {"Afternoon", DateFormat.time(s.afternoon, f)},
      {"Evening", DateFormat.time(s.evening, f)},
      {"Confirm assignments",
       if(state.db.confirm_assignments == :always, do: "Always", else: "Never")}
    ]
  end

  defp month_alone(:first), do: "First day"
  defp month_alone(:last), do: "Last day"
  defp month_alone(day), do: "Day #{day}"

  defp separator(" "), do: "(space)"
  defp separator(s), do: s
end
