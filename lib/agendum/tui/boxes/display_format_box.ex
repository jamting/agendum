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

  import Agendum.TUI.Boxes.BoxNav, only: [is_move: 1]

  alias Agendum.Core
  alias Agendum.Core.DateFormat
  alias Agendum.TUI.Boxes.{Box, BoxNav, DateFormatRows, Template}
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

  def open(state), do: State.push(state, %{type: :display_format, cursor: 0})

  @impl Box
  def handle(state, mode, key) do
    case key do
      k when k in [:esc, :enter] ->
        State.pop(state)

      k when is_move(k) ->
        BoxNav.move(state, mode, @grid, k)

      {:char, " "} ->
        format = DateFormat.cycle(state.db.date_format, field(state, mode), 1)
        State.change_db(state, Core.set_date_format(state.db, format))

      _ ->
        state
    end
  end

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
end
