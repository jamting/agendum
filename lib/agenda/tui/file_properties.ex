defmodule Agenda.TUI.FileProperties do
  @moduledoc """
  The File Properties box (File ▸ Properties; User's Guide 7-13 to 7-15):
  how the file displays dates and times (SPEC R41).

  Rows: Date format, Date separator, Clock and Show day of week, with a
  formatted sample below, as in Agenda's Display Format box. SPACE or →
  shows the next choice, ← the previous one; every change applies at once
  and is one undo step. ESC or ENTER closes the box. Pure.
  """

  alias Agenda.Core
  alias Agenda.Core.DateFormat
  alias Agenda.TUI.State

  @rows [:order, :separator, :clock, :day_of_week]

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

  defp change(state, row, step) do
    format = DateFormat.cycle(state.db.date_format, row, step)
    State.change_db(state, Core.set_date_format(state.db, format))
  end

  @doc "`{label, value}` for each row."
  def lines(state) do
    f = state.db.date_format

    [
      {"Date format", DateFormat.label(f.order)},
      {"Date separator", separator(f.separator)},
      {"Clock", "#{f.clock} hr"},
      {"Show day of week", if(f.day_of_week, do: "Yes", else: "No")}
    ]
  end

  defp separator(" "), do: "(space)"
  defp separator(s), do: s
end
