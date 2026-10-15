defmodule Agendum.TUI.Boxes.FileProperties do
  @moduledoc """
  The File Properties box (File ▸ Properties; User's Guide 7-13 to 7-17)
  and the boxes it opens, nested as in Agenda 2.0, each row with "..."
  opening the next box:

    * File Properties (`:file_props`): Insert new columns in (R55), Global
      date settings ..., Auto-assign settings ...
      (`Agendum.TUI.Boxes.AutoAssignBox`, R16a) and File statistics ...
      (`Agendum.TUI.Boxes.FileStatsBox`). Drawn from `@layout`
      (`Agendum.TUI.Boxes.Template`), Agenda's box (screenshot 130) with only the
      settings Agendum has
    * Global Date Settings (`Agendum.TUI.Boxes.DateSettingsBox`, R14e)
    * Display Format (`Agendum.TUI.Boxes.DisplayFormatBox`, R41), from Global
      Date Settings

  SPACE shows the next choice (or opens a "..." box), the arrows move
  between settings (`Agendum.TUI.Boxes.BoxNav`); every change applies at once
  and is one undo step. ENTER closes
  the box, ESC closes it and cancels its changes (`Agendum.TUI.Boxes.BoxCancel`);
  either goes back to the box beneath. Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, indicator: "PROPS", cancels: true

  alias Agendum.Core
  alias Agendum.TUI.Boxes.{AutoAssignBox, Box, DateSettingsBox, FileStatsBox, Template}
  alias Agendum.TUI.State

  # Agenda's File Properties (screenshot 130), its other settings left out
  # until Agendum has them
  @layout """
   Insert new columns in:  [insert_columns ]

   Global date settings:   [dates]   Auto-assign settings:  [auto ]
                                     File statistics:       [stats]
  """

  @rows Template.fields(@layout)
  # two settings side by side, as Agenda's
  @grid Template.grid(@layout, @rows)

  @help %{
    insert_columns:
      "Choose to insert new columns in one or all sections in the view. " <>
        "You can override when you add individual columns.",
    dates:
      "Press SPACE BAR to choose date and time formats to use as defaults throughout the file.",
    auto: "Press SPACE BAR to choose how items are assigned to categories by their text.",
    stats: "Press SPACE BAR to display current statistics for the file."
  }

  def open(state), do: State.push(state, %{type: :file_props, cursor: 0})

  @impl Box
  # its keys are the settings box's (R65): SPACE changes the setting
  def handle(state, _mode, _key), do: state

  @impl Box
  def keymap, do: Box.settings_keymap()

  @impl Box
  def commands, do: Box.settings_commands()

  @impl Box
  def run(state, mode, :change), do: change(state, field(state, mode))
  def run(state, mode, id), do: Box.run_settings(state, mode, @grid, id)

  defp change(state, :dates), do: DateSettingsBox.open(state)
  defp change(state, :auto), do: AutoAssignBox.open(state)
  defp change(state, :stats), do: FileStatsBox.open(state)

  # two choices, so SPACE flips it
  defp change(state, :insert_columns) do
    where = if state.db.insert_columns == :all, do: :section, else: :all
    State.change_db(state, Core.set_insert_columns(state.db, where))
  end

  @impl Box
  def title(_state, _mode), do: "File properties"

  # two columns of settings, as Agenda's (screenshot 130)
  @impl Box
  def width(state, _mode), do: min(state.width - 8, 72)

  @impl Box
  def content(state, mode, inner, _max_rows) do
    values = %{
      insert_columns:
        if(state.db.insert_columns == :all, do: "All sections", else: "Current section"),
      dates: "...",
      auto: "...",
      stats: "..."
    }

    Template.render(@layout, values, selected: field(state, mode)) ++
      [[], Box.hint(keys(state, mode), inner)]
  end

  @impl Box
  def keys(_state, _mode),
    do: [
      {"↑↓←→", "Setting", "Move between settings"},
      {"SPACE", "Next", "Next choice or open ..."},
      {"ENTER", "Done"},
      {"ESC", "Cancel"}
    ]

  @impl Box
  def help, do: @help

  @impl Box
  def field(_state, mode), do: Enum.at(@rows, mode.cursor)
end
