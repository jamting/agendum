defmodule Agendum.TUI.Boxes.DisplayFormatBox do
  @moduledoc """
  The Display Format box (File ▸ Properties ▸ Global date settings ▸
  Display format; User's Guide 7-13 to 7-17, SPEC R41): how the file shows
  dates and times, the rows of Agenda's Date Column Properties
  (`Agendum.TUI.Boxes.DateFormatRows`), with a formatted sample below.

  SPACE shows the next choice; every change applies at once and is one
  undo step. ENTER closes the box, ESC closes it and cancels its changes
  (`Agendum.TUI.Boxes.BoxCancel`); either goes back to Global Date Settings.
  Drawn from `@layout` (`Agendum.TUI.Boxes.Template`). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, indicator: "PROPS", cancels: true

  alias Agendum.Core.DateFormat
  alias Agendum.TUI.Boxes.{Box, DateFormatRows, Template}
  alias Agendum.TUI.State

  @layout """
   Display date/time    : [show                              ]
   Show day of week     : [day_of_week                       ]
   Date format          : [order                             ]
   Date separator       : [separator                         ]
   Clock                : [clock                             ]
   Show am/pm           : [am_pm                             ]
   Time separator       : [time_separator                    ]

   Sample               : [sample                            ]
  """

  # the sample is shown, not a setting
  @rows Template.fields(@layout) -- [:sample]
  @grid Template.grid(@layout, @rows)

  def open(state), do: State.push(state, %Agendum.TUI.Modes.DisplayFormat{cursor: 0})

  @impl Box
  # its keys are the settings box's (R65): SPACE changes the setting
  def handle(state, _mode, _key), do: state

  @impl Box
  def keymap(_mode), do: Box.settings_keymap()

  @impl Box
  def commands(_mode), do: Box.settings_commands()

  @impl Box
  def run(state, mode, :change),
    do:
      State.run(
        state,
        {:set_date_format, DateFormat.cycle(state.db.date_format, field(state, mode), 1)}
      )

  def run(state, mode, id), do: Box.run_settings(state, mode, @grid, id)

  @impl Box
  def title(_state, _mode), do: "Display format"

  @impl Box
  def content(state, mode, inner, _max_rows) do
    values =
      state.db.date_format
      |> DateFormatRows.values()
      |> Map.put(:sample, DateFormat.sample(state.db.date_format))

    Template.render(@layout, values, selected: field(state, mode)) ++
      [[], Box.hint(keys(state, mode), inner)]
  end

  @impl Box
  def keys(_state, _mode), do: Box.settings_keys()

  @impl Box
  def help, do: Map.take(DateFormatRows.help(), @rows)

  @impl Box
  def field(_state, mode), do: Enum.at(@rows, mode.cursor)

  # F8 and ALT-F8 (`Agendum.TUI.Boxes.BoxDefaults`): a new file's display
  # format
  @impl Box
  def defaults(_state, _mode) do
    new = Agendum.Core.new_file().date_format

    Map.new(@rows, fn row ->
      {row,
       fn state ->
         format = state.db.date_format
         default = Map.fetch!(new, row)

         if Map.fetch!(format, row) == default,
           do: state,
           else: State.run(state, {:set_date_format, Map.put(format, row, default)})
       end}
    end)
  end
end
