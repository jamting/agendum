defmodule Agenda.TUI.ColumnProperties do
  @moduledoc """
  The Numeric Column Properties box (View ▸ Column ▸ Properties; User's
  Guide 8-6 to 8-7, SPEC R29): how a numeric column shows its numbers and
  which calculations appear at the bottom of each section, with formatted
  samples of a positive and a negative number.

  ↑↓ choose a setting; SPACE or → shows the next choice (decimal places go
  up), ← the previous one; every change applies at once and is one undo
  step. ESC or ENTER closes the box. Pure.
  """

  alias Agenda.Core
  alias Agenda.Core.NumberFormat
  alias Agenda.TUI.State

  @rows [:symbol, :decimals, :thousands, :negative] ++ NumberFormat.calcs()
  @max_decimals 6

  def rows, do: @rows

  def open(state, index), do: State.push(state, %{type: :column_props, column: index, cursor: 0})

  @doc "The column the box is for."
  def column(state, mode), do: Enum.at(State.view(state).columns, mode.column)

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

  defp change(state, mode, row, step) do
    format = state |> column(mode) |> Map.fetch!(:number) |> step(row, step)
    State.change_db(state, Core.set_column_format(state.db, state.view_id, mode.column, format))
  end

  defp step(f, :symbol, step), do: %{f | symbol: cycle(NumberFormat.symbols(), f.symbol, step)}

  defp step(f, :decimals, step),
    do: %{f | decimals: Integer.mod(f.decimals + step, @max_decimals + 1)}

  defp step(f, :thousands, _step), do: %{f | thousands: not f.thousands}

  defp step(f, :negative, _step),
    do: %{f | negative: if(f.negative == :minus, do: :parens, else: :minus)}

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

  @doc "`{label, value}` for each row."
  def lines(state, mode) do
    f = column(state, mode).number
    yes_no = &if(&1, do: "Yes", else: "No")

    Enum.map(@rows, fn
      :symbol -> {"Label or currency", f.symbol || "None"}
      :decimals -> {"Decimal places", Integer.to_string(f.decimals)}
      :thousands -> {"Thousands separator", yes_no.(f.thousands)}
      :negative -> {"Negative numbers", if(f.negative == :minus, do: "-1", else: "(1)")}
      calc -> {String.capitalize(Atom.to_string(calc)), yes_no.(calc in f.calcs)}
    end)
  end

  @doc "The formatted samples shown at the bottom of the box."
  def sample(state, mode) do
    f = column(state, mode).number
    NumberFormat.format(1234.5, f) <> " " <> NumberFormat.format(-1234.5, f)
  end
end
