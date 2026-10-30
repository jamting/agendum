# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Boxes.DisplayFormatBox do
  @moduledoc """
  The Display Format box (File ▸ Properties ▸ Global date settings ▸
  Display format; User's Guide 7-13 to 7-17, SPEC R41): how the file shows
  dates and times. Agenda draws it as the Column Properties box with its
  top part blank: a rule, "Date Column Properties", the settings for what
  the dates display (`Agendum.TUI.Boxes.DateFormatRows.layout/1`: no clock
  for Date only, no date format for Time only) and a formatted sample
  (checked in Agenda 2.0, 2026-10-25).

  SPACE shows the next choice; every change applies at once and is one
  undo step. ENTER closes the box, ESC closes it and cancels its changes
  (`Agendum.TUI.Boxes.BoxCancel`); either goes back to Global Date Settings.
  Drawn from a layout (`Agendum.TUI.Boxes.Template`). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, cancels: true

  alias Agendum.Core.DateFormat
  alias Agendum.TUI.Boxes.{Box, DateFormatRows, Template}
  alias Agendum.TUI.State

  # the blank rows stand where Column Properties has its column's settings
  @head " \n \n" <>
          DateFormatRows.rule() <> "                          Date Column Properties\n \n \n"

  defp layout(state), do: @head <> DateFormatRows.layout(state.db.date_format.show)

  # the settings in the cursor's order, for the dates as they are shown now
  defp rows(state), do: Template.fields(layout(state))

  # `time_sep` is the format's `time_separator`
  defp attribute(:time_sep), do: :time_separator
  defp attribute(row), do: row

  def open(state), do: State.push(state, %Agendum.TUI.Modes.DisplayFormat{cursor: 0})

  @impl Box
  # its keys are the settings box's (R65): SPACE changes the setting
  def handle(state, _mode, _key), do: state

  @impl Box
  # F6 is in Agenda's bar here but does nothing (checked 2026-10-25)
  def keymap(_mode), do: Box.settings_keymap(%{{:f, 6} => :category_props})

  @impl Box
  def commands(_mode),
    do: Box.settings_commands([{:category_props, "Props", "Nothing here: no category"}])

  @impl Box
  def run(state, _mode, :category_props), do: state

  def run(state, mode, :change),
    do:
      State.run(
        state,
        {:set_date_format,
         DateFormat.cycle(state.db.date_format, attribute(field(state, mode)), 1)}
      )

  def run(state, mode, id),
    do: Box.run_settings(state, mode, Template.grid(layout(state), rows(state)), id)

  # as wide as Column Properties, whose box Agenda draws it in
  @impl Box
  def width(state, _mode), do: min(state.width - 8, 72)

  @impl Box
  def title(_state, _mode), do: "Display Format"

  # F1 (R65): the settings box's usual text, and how new files get this
  # format too (R82a; meeting 2026-10-26-1358, § 6)
  @impl Box
  def about(state, mode) do
    Box.default_about(__MODULE__, state, mode) <>
      "\n\nNew files start with Agenda's format (MMDDYY). To start them with this " <>
      "one, go back to File Properties and use Update defaults."
  end

  @impl Box
  def content(state, mode, inner, _max_rows) do
    format = state.db.date_format

    Template.render(layout(state), DateFormatRows.values(format), selected: field(state, mode)) ++
      DateFormatRows.sample(format) ++ [[], Box.hint(keys(state, mode), inner)]
  end

  @impl Box
  def keys(_state, _mode), do: Box.settings_keys()

  @impl Box
  def help, do: DateFormatRows.help()

  @impl Box
  def field(state, mode) do
    rows = rows(state)
    Enum.at(rows, min(mode.cursor, length(rows) - 1))
  end

  # F8 and ALT-F8 (`Agendum.TUI.Boxes.BoxDefaults`): a new file's display
  # format
  @impl Box
  def defaults(state, _mode) do
    new = State.new_file(state).date_format

    Map.new(DateFormatRows.rows() ++ [:time_sep], fn row ->
      {row,
       fn state ->
         format = state.db.date_format
         default = Map.fetch!(new, attribute(row))

         if Map.fetch!(format, attribute(row)) == default,
           do: state,
           else: State.run(state, {:set_date_format, Map.put(format, attribute(row), default)})
       end}
    end)
  end
end
