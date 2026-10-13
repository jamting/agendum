defmodule Agenda.TUI.DateColumnBox do
  @moduledoc """
  The Date Column Properties box (View ▸ Column ▸ Properties on a date
  column; User's Guide 6-19 to 6-22, SPEC R41a): how this column shows its
  dates. Settings says "Global defaults" while the column uses the file's
  format (File Properties) and "Local settings" once it has its own;
  changing any setting makes them its own, and SPACE on Settings goes back
  to the global defaults. The rows are `Agenda.TUI.DateFormatRows`, with a
  formatted sample below.

  ↑↓ choose a setting; SPACE or → shows the next choice, ← the previous
  one; every change applies at once and is one undo step. ESC or ENTER
  closes the box. Pure.
  """

  alias Agenda.Core
  alias Agenda.Core.DateFormat
  alias Agenda.TUI.{DateFormatRows, State}

  @rows [:settings | DateFormatRows.rows()]

  @doc "Opens the box for the column at `at` (`{section, column}`, R55)."
  def open(state, at),
    do: State.push(state, %{type: :date_column_props, column: at, cursor: 0})

  @doc "The column the box is for."
  def column(state, %{column: {sidx, index}}),
    do: state |> State.view() |> Agenda.Core.View.columns(sidx) |> Enum.at(index)

  @doc "The format the column shows: its own or the file's."
  def format(state, mode), do: column(state, mode).date || state.db.date_format

  def handle(state, mode, key) do
    row = Enum.at(@rows, mode.cursor)

    case key do
      k when k in [:esc, :enter] -> State.pop(state)
      :up -> State.put_mode(state, %{mode | cursor: max(mode.cursor - 1, 0)})
      :down -> State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, length(@rows) - 1)})
      k when k in [{:char, " "}, :right] -> change(state, mode, row, 1)
      :left -> change(state, mode, row, -1)
      _ -> state
    end
  end

  defp change(state, mode, :settings, _step) do
    own = if column(state, mode).date, do: nil, else: state.db.date_format
    set(state, mode, own)
  end

  defp change(state, mode, row, step),
    do: set(state, mode, DateFormat.cycle(format(state, mode), row, step))

  defp set(state, mode, format),
    do:
      State.change_db(
        state,
        Core.set_column_date_format(state.db, state.view_id, mode.column, format)
      )

  @doc "`{label, value}` for each row."
  def lines(state, mode) do
    settings = if column(state, mode).date, do: "Local settings", else: "Global defaults"
    [{"Settings", settings} | DateFormatRows.lines(format(state, mode))]
  end

  @doc "The formatted sample shown at the bottom of the box."
  def sample(state, mode), do: DateFormat.sample(format(state, mode))
end
