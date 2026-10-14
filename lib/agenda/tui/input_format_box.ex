defmodule Agenda.TUI.InputFormatBox do
  @moduledoc """
  The Input Format box (Global date settings ▸ Input format; User's Guide 7-17,
  SPEC R41b): how this person types dates and times: Number order, Input
  date separator and Input clock, each "Language (…)" until set. These
  are the person's, not the file's (ADR 0008): a change applies at once,
  is saved to their preferences file (`{:save_preferences, path, prefs}`)
  and is not part of undo.

  ↑↓ choose a setting; SPACE or → shows the next choice, ← the previous
  one. ESC or ENTER closes the box. Pure.
  """

  alias Agenda.Core.InputFormat
  alias Agenda.TUI.State

  @rows [:number_order, :separator, :clock]

  def open(state), do: State.push(state, %{type: :input_format, cursor: 0})

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
    input = InputFormat.cycle(state.input, row, step)
    value = Map.fetch!(input, row)

    State.change_preference(
      state,
      &%{&1 | input: input},
      &%{&1 | input: Map.put(&1.input, row, value)}
    )
  end

  @doc "`{label, value}` for each row."
  def lines(state) do
    label = &InputFormat.label(state.input, &1, state.languages)

    [
      {"Number order", label.(:number_order)},
      {"Input date separator", label.(:separator)},
      {"Input clock", label.(:clock)}
    ]
  end

  @doc "The highlighted field, for its help in the control panel (`Agenda.TUI.FieldHelp`)."
  def field(_state, mode), do: Enum.at(@rows, mode.cursor)
end
