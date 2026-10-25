defmodule Agendum.TUI.Boxes.DateSettingsBox do
  @moduledoc """
  The Global Date Settings box (File ▸ Properties ▸ Global date settings;
  User's Guide 7-13 to 7-17, SPEC R14e): Display format ... (the file's,
  `Agendum.TUI.Boxes.DisplayFormatBox`), Input format ... (the person's own box,
  `Agendum.TUI.Boxes.InputFormatBox`, R41b), then beginning and end of week,
  first quarter, beginning of year, month alone means, morning, afternoon
  and evening.

  SPACE shows the next choice or opens a "..." box; Morning, Afternoon and
  Evening are typed (SPACE asks). Every change applies at once and is one
  undo step. ENTER closes the box, ESC closes it and cancels its changes
  (`Agendum.TUI.Boxes.BoxCancel`); either goes back to File Properties. Drawn
  from `@layout` (`Agendum.TUI.Boxes.Template`). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, cancels: true

  alias Agendum.Core
  alias Agendum.Core.{DateFormat, DateSettings}
  alias Agendum.TUI.Boxes.{Box, DisplayFormatBox, InputFormatBox, Template}
  alias Agendum.TUI.State
  alias Agendum.TUI.Update.Prompts

  @layout """
   Display format       : [display_format                    ]
   Input format         : [input_format                      ]
   Beginning of week    : [week_start                        ]
   End of week          : [week_end                          ]
   First quarter        : [quarter_start                     ]
   Beginning of year    : [year_start                        ]
   Month alone means    : [month_alone                       ]
   Morning              : [morning                           ]
   Afternoon            : [afternoon                         ]
   Evening              : [evening                           ]
  """

  @rows Template.fields(@layout)
  @grid Template.grid(@layout, @rows)
  @times [:morning, :afternoon, :evening]

  @days ~w(Mon Tue Wed Thu Fri Sat Sun)
  @months ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

  @help %{
    display_format:
      "Press SPACE BAR to choose how dates and times are displayed throughout the file. " <>
        "Date columns can override it.",
    input_format:
      "Press SPACE BAR to choose how you type dates. It is yours, " <>
        "for every file, not part of this one.",
    week_start: "The first day of a week, for \"this week\" and datebooks. SPACE for the next.",
    week_end: "The last day of a week, for \"end of week\" and datebooks. SPACE for the next.",
    quarter_start: "The month the first quarter begins in. SPACE for the next month.",
    year_start: "The month the year begins in, for \"this year\". SPACE for the next month.",
    month_alone:
      "Which day a month typed alone means (\"April\"): its first, its last, or another day. " <>
        "SPACE for the next.",
    morning: "The time \"morning\" means in a date. SPACE asks for it.",
    afternoon: "The time \"afternoon\" means in a date. SPACE asks for it.",
    evening: "The time \"evening\" means in a date. SPACE asks for it."
  }

  def open(state), do: State.push(state, %Agendum.TUI.Modes.DateSettings{cursor: 0})

  @impl Box
  # its keys are the settings box's (R65): SPACE changes the setting
  def handle(state, _mode, _key), do: state

  @impl Box
  def keymap(_mode), do: Box.settings_keymap()

  @impl Box
  def commands(_mode), do: Box.settings_commands()

  @impl Box
  def run(state, mode, :change), do: change(state, field(state, mode))
  def run(state, mode, id), do: Box.run_settings(state, mode, @grid, id)

  defp change(state, :display_format), do: DisplayFormatBox.open(state)
  defp change(state, :input_format), do: InputFormatBox.open(state)

  # a time is typed, as Agenda's (SPACE asks for it)
  defp change(state, row) when row in @times do
    time = Map.fetch!(state.db.date_settings, row) |> Time.to_string() |> String.slice(0, 5)
    label = "#{row |> Atom.to_string() |> String.capitalize()} (a time):"
    Prompts.prompt(state, label, {:date_setting_time, row}, time)
  end

  defp change(state, row) do
    settings = DateSettings.cycle(state.db.date_settings, row, 1)
    State.run(state, {:set_date_settings, settings})
  end

  @doc "The time typed for Morning, Afternoon or Evening; unreadable text is refused."
  def set_time(state, row, text) do
    case Core.read_when(state.db, text, State.context(state)) do
      {:ok, _date, %Time{} = time} ->
        settings = Map.put(state.db.date_settings, row, time)
        State.run(state, {:set_date_settings, settings})

      _ ->
        State.error(state, Agendum.TUI.Messages.text(:bad_time))
    end
  end

  @impl Box
  def title(_state, _mode), do: "Global Date Settings"

  @impl Box
  def content(state, mode, inner, _max_rows) do
    Template.render(@layout, values(state), selected: field(state, mode)) ++
      [[], Box.hint(keys(state, mode), inner)]
  end

  defp values(state) do
    f = state.db.date_format
    s = state.db.date_settings

    %{
      display_format: "...",
      input_format: "... (yours)",
      week_start: Enum.at(@days, s.week_start - 1),
      week_end: Enum.at(@days, s.week_end - 1),
      quarter_start: Enum.at(@months, s.quarter_start - 1) <> " 1",
      year_start: Enum.at(@months, s.year_start - 1) <> " 1",
      month_alone: month_alone(s.month_alone),
      morning: DateFormat.time(s.morning, f),
      afternoon: DateFormat.time(s.afternoon, f),
      evening: DateFormat.time(s.evening, f)
    }
  end

  defp month_alone(:first), do: "First day"
  defp month_alone(:last), do: "Last day"
  defp month_alone(day), do: "Day #{day}"

  @impl Box
  def keys(_state, _mode),
    do: Box.settings_keys([{"type", "Time", "a time"}])

  @impl Box
  def help, do: @help

  @impl Box
  def field(_state, mode), do: Enum.at(@rows, mode.cursor)

  # F8 and ALT-F8 (`Agendum.TUI.Boxes.BoxDefaults`): a new file's date
  # settings; Display and Input format are boxes of their own
  @impl Box
  def defaults(_state, _mode) do
    new = Core.new_file().date_settings

    Map.new(Template.fields(@layout) -- [:display_format, :input_format], fn row ->
      {row, &setting_back(&1, row, Map.fetch!(new, row))}
    end)
  end

  defp setting_back(state, row, default) do
    settings = state.db.date_settings

    if Map.fetch!(settings, row) == default,
      do: state,
      else: State.run(state, {:set_date_settings, Map.put(settings, row, default)})
  end
end
