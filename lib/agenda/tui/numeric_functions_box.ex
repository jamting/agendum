defmodule Agenda.TUI.NumericFunctionsBox do
  @moduledoc """
  The Select Numeric Functions box (Section Properties ▸ Select numeric
  functions; R61, R29; User's Guide 8-10, Help "Select Numeric Functions
  Box"): Count, Total, Average, Minimum and Maximum, each Yes or No, for
  every numeric column of the section at once (`Core.set_section_calcs/4`).
  A function shows Yes when every numeric column has it.

  SPACE (or ←, →) switches the highlighted one at once, one undo step, so
  the section's calculation lines change behind the box; ESC or ENTER
  closes it. Drawn from `@layout` (`Agenda.TUI.Template`). Pure.
  """

  alias Agenda.Core
  alias Agenda.TUI.{State, Template}

  @layout """
   Count   : [count  ]
   Total   : [total  ]
   Average : [average]
   Minimum : [minimum]
   Maximum : [maximum]

   SPACE switches · ESC closes
  """
  @rows Template.fields(@layout)

  @doc "Opens the box for section `sidx` of the current view."
  def open(state, sidx), do: State.push(state, %{type: :numeric_functions, sidx: sidx, cursor: 0})

  defp calcs(state, mode), do: Core.section_calcs(state.db, state.view_id, mode.sidx) || []

  def handle(state, mode, key) do
    case key do
      k when k in [:esc, :enter] ->
        State.pop(state)

      :up ->
        State.put_mode(state, %{mode | cursor: max(mode.cursor - 1, 0)})

      :down ->
        State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, length(@rows) - 1)})

      k when k in [{:char, " "}, :right, :left] ->
        switch(state, mode, Enum.at(@rows, mode.cursor))

      _ ->
        state
    end
  end

  defp switch(state, mode, calc) do
    calcs = calcs(state, mode)
    # on: added to what every column has; off: taken away
    calcs = if calc in calcs, do: List.delete(calcs, calc), else: [calc | calcs]
    State.change_db(state, Core.set_section_calcs(state.db, state.view_id, mode.sidx, calcs))
  end

  @doc "The box's lines, the highlighted function selected."
  def content(state, mode) do
    calcs = calcs(state, mode)
    values = Map.new(@rows, &{&1, if(&1 in calcs, do: "Yes", else: "No")})
    Template.render(@layout, values, selected: Enum.at(@rows, mode.cursor))
  end

  @doc "The highlighted field, for its help in the control panel (`Agenda.TUI.FieldHelp`)."
  def field(_state, mode), do: Enum.at(@rows, mode.cursor)
end
