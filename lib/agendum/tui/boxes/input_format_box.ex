defmodule Agendum.TUI.Boxes.InputFormatBox do
  @moduledoc """
  The Input Format box (Global date settings ▸ Input format; User's Guide 7-17,
  SPEC R41b): how this person types dates and times: Number order, Input
  date separator and Input clock, each "Language (…)" until set. These
  are the person's, not the file's (ADR 0008): a change applies at once,
  is saved to their preferences file (`{:save_preferences, path, prefs}`)
  and is not part of undo.

  The arrows choose a setting (`Agendum.TUI.Boxes.BoxNav`); SPACE shows the next choice.
  ENTER closes the box; ESC closes it and cancels its changes
  (`Agendum.TUI.Boxes.BoxCancel`). Drawn from `@layout`
  (`Agendum.TUI.Boxes.Template`). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, cancels: true

  alias Agendum.TUI.Boxes.{Box, Template}

  alias Agendum.Core.InputFormat
  alias Agendum.TUI.State

  @layout """
   Number order         : [number_order                    ]
   Input date separator : [separator                       ]
   Input clock          : [clock                           ]

   Saved in your preferences, not in this file.
  """

  @rows Template.fields(@layout)
  @grid Template.grid(@layout, @rows)

  @help %{
    number_order:
      "Choose the order in which you enter day, month, and year, so Agendum can read " <>
        "dates such as 3/2. SPACE for the next.",
    separator: "The character you type between the numbers of a date. SPACE for the next choice.",
    clock: "Choose whether you type times on a 12-hour or a 24-hour clock. SPACE switches."
  }

  def open(state), do: State.push(state, %Agendum.TUI.Modes.InputFormat{cursor: 0})

  @impl Box
  # its keys are the settings box's (R65): SPACE changes the setting
  def handle(state, _mode, _key), do: state

  @impl Box
  def keymap(_mode), do: Box.settings_keymap()

  @impl Box
  def commands(_mode), do: Box.settings_commands()

  @impl Box
  def run(state, mode, :change), do: change(state, Enum.at(@rows, mode.cursor), 1)
  def run(state, mode, id), do: Box.run_settings(state, mode, @grid, id)

  defp change(state, row, step) do
    input = InputFormat.cycle(State.input(state), row, step)
    value = Map.fetch!(input, row)

    State.change_preference(
      state,
      &State.put_reader(&1, input: input),
      &%{&1 | input: Map.put(&1.input, row, value)}
    )
  end

  @impl Box
  def title(_state, _mode), do: "Input Format"

  @impl Box
  def content(state, mode, inner, _max_rows) do
    values =
      Map.new(@rows, &{&1, InputFormat.label(State.input(state), &1, State.languages(state))})

    Template.render(@layout, values, selected: field(state, mode)) ++
      [Box.hint(keys(state, mode), inner)]
  end

  @impl Box
  def keys(_state, _mode), do: Box.settings_keys()

  @impl Box
  def help, do: @help

  @impl Box
  def field(_state, mode), do: Enum.at(@rows, mode.cursor)

  # F8 and ALT-F8 (`Agendum.TUI.Boxes.BoxDefaults`): a fresh start's input
  # format, read from the date languages
  @impl Box
  def defaults(_state, _mode) do
    new = %InputFormat{}

    Map.new(@rows, fn row ->
      {row,
       fn state ->
         default = Map.fetch!(new, row)

         if Map.fetch!(State.input(state), row) == default do
           state
         else
           State.change_preference(
             state,
             &State.put_reader(&1, input: Map.put(State.input(&1), row, default)),
             &%{&1 | input: Map.put(&1.input, row, default)}
           )
         end
       end}
    end)
  end
end
