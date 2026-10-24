defmodule Agendum.TUI.Boxes.NumericFunctionsBox do
  @moduledoc """
  The Select Numeric Functions box (Section Properties ▸ Select numeric
  functions; R61, R29; User's Guide 8-10, Help "Select Numeric Functions
  Box"): Count, Total, Average, Minimum and Maximum, each Yes or No, for
  every numeric column of the section at once (`Core.set_section_calcs/4`).
  A function shows Yes when every numeric column has it.

  SPACE (or ←, →) switches the highlighted one at once, one undo step, so
  the section's calculation lines change behind the box; ENTER closes the
  box; ESC closes it and cancels its changes (`Agendum.TUI.Boxes.BoxCancel`). Drawn
  from `@layout` (`Agendum.TUI.Boxes.Template`). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, indicator: "PROPS", cancels: true

  alias Agendum.Core
  alias Agendum.TUI.Boxes.{Box, Template}
  alias Agendum.TUI.State

  @layout """
   Count   : [count  ]
   Total   : [total  ]
   Average : [average]
   Minimum : [minimum]
   Maximum : [maximum]
  """
  @rows Template.fields(@layout)

  @help %{
    count: "Show how many items have a number, in every numeric column. SPACE switches.",
    total: "Show the total of every numeric column. SPACE switches.",
    average: "Show the average of every numeric column. SPACE switches.",
    minimum: "Show the smallest number of every numeric column. SPACE switches.",
    maximum: "Show the largest number of every numeric column. SPACE switches."
  }

  @doc "Opens the box for section `sidx` of the current view."
  def open(state, sidx),
    do: State.push(state, %Agendum.TUI.Modes.NumericFunctions{sidx: sidx, cursor: 0})

  defp calcs(state, mode), do: Core.section_calcs(state.db, state.view_id, mode.sidx) || []

  @impl Box
  # its keys are the settings box's (R65): SPACE changes the setting
  def handle(state, _mode, _key), do: state

  @impl Box
  def keymap(_mode), do: Box.settings_keymap()

  @impl Box
  def commands(_mode), do: Box.settings_commands()

  @impl Box
  def run(state, mode, :change), do: switch(state, mode, Enum.at(@rows, mode.cursor))
  def run(state, mode, id), do: Box.run_settings(state, mode, Template.grid(@layout, @rows), id)

  defp switch(state, mode, calc) do
    calcs = calcs(state, mode)
    # on: added to what every column has; off: taken away
    calcs = if calc in calcs, do: List.delete(calcs, calc), else: [calc | calcs]
    State.run(state, {:set_section_calcs, state.view_id, mode.sidx, calcs})
  end

  @impl Box
  def title(_state, _mode), do: "Select Numeric Functions"

  # a small box, as Agenda's
  @impl Box
  def width(state, _mode), do: min(state.width - 8, 32)

  @impl Box
  def content(state, mode, inner, _max_rows) do
    calcs = calcs(state, mode)
    values = Map.new(@rows, &{&1, if(&1 in calcs, do: "Yes", else: "No")})

    Template.render(@layout, values, selected: field(state, mode)) ++
      [[], Box.hint(keys(state, mode), inner)]
  end

  @impl Box
  def keys(_state, _mode),
    do: [
      {"↑↓←→", "Function", "Move between the calculations"},
      {"SPACE", "Yes/No", "Switch it for the section's numeric columns"},
      {"ENTER", "Done"},
      {"ESC", "Cancel"}
    ]

  @impl Box
  def help, do: @help

  @impl Box
  def field(_state, mode), do: Enum.at(@rows, mode.cursor)

  # F8 and ALT-F8 (`Agendum.TUI.Boxes.BoxDefaults`): what a new numeric
  # column calculates (Total)
  @impl Box
  def defaults(_state, mode) do
    new = %Agendum.Core.NumberFormat{}.calcs

    Map.new(@rows, fn calc ->
      {calc,
       fn state ->
         if calc in calcs(state, mode) == calc in new, do: state, else: switch(state, mode, calc)
       end}
    end)
  end
end
