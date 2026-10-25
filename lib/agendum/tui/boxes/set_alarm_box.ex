defmodule Agendum.TUI.Boxes.SetAlarmBox do
  @moduledoc """
  The Set Alarm box (Item ▸ Alarm, ALT-A; SPEC R38; User's Guide 10-17,
  10-18), laid out as Agenda 2.0's (checked 2026-10-25):

    * Date category (When): the date category whose date and time the
      alarm rings before; SPACE goes to the next date category, F3 lists
      them (Agenda's Select Date Category: Entry, When, Done and the
      user's own)
    * Minutes before (5): typed, 0 through 60

  ENTER sets the alarm, saying nothing, as Agenda; ESC closes the box. The
  settings live in the box until then. An item without a date in the
  category takes the alarm too, which waits until it has one. Drawn from
  `@layout` (`Agendum.TUI.Boxes.Template`). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, choices: true

  alias Agendum.Core.Database
  alias Agendum.TUI.Boxes.{Box, FieldTyping, Template}
  alias Agendum.TUI.State

  @layout """

     Date category:    [date_category            ]
     Minutes before:   [minutes                  ]

  """

  @rows Template.fields(@layout)
  @grid Template.grid(@layout, @rows)

  # Agenda's own help lines for the two fields
  @help %{
    date_category:
      "Press F3 to pick the date category whose value is compared to " <>
        "the system date and time for the alarm.",
    minutes: "Type the number of minutes before the designated time you want the alarm to ring."
  }

  @doc "Opens the box for an item, with Agenda's defaults: When, 5 minutes."
  def open(state, item_id) do
    State.push(state, %Agendum.TUI.Modes.SetAlarm{
      item_id: item_id,
      date_category: state.db.special.when,
      minutes: 5,
      cursor: 0
    })
  end

  @impl Box
  # a digit on Minutes before starts typing it; while typing, the keys are
  # the line's (ENTER takes the number and stays in the box)
  def handle(state, %{typing: {_, _}} = mode, key),
    do: FieldTyping.key(state, mode, key, &typed/3)

  def handle(state, mode, {:char, c}) do
    if field(state, mode) == :minutes and FieldTyping.digit?(c),
      do: FieldTyping.start(state, mode, :minutes, c),
      else: state
  end

  def handle(state, _mode, _key), do: state

  defp typed(state, :minutes, text) do
    case FieldTyping.number(text, 0, 60) do
      {:ok, minutes} -> State.put_mode(state, %{State.mode(state) | minutes: minutes})
      :error -> State.error(state, Agendum.TUI.Messages.text(:bad_number))
    end
  end

  @impl Box
  def keymap(_mode), do: Box.settings_keymap()

  @impl Box
  def commands(_mode),
    do: Box.settings_commands([{:done, "Set", "Set the alarm"}])

  @impl Box
  def run(state, mode, :done) do
    command = {:set_alarm, mode.item_id, mode.minutes, category(state, mode)}

    case State.command(State.pop(state), command) do
      {:ok, state, _} -> state
      {:error, :minutes} -> State.error(state, Agendum.TUI.Messages.text(:bad_number))
    end
  end

  def run(state, mode, :change), do: change(state, mode, field(state, mode))
  def run(state, mode, id), do: Box.run_settings(state, mode, @grid, id)

  # When is stored as nil, as in files from before alarms had a category
  defp category(state, mode),
    do: if(mode.date_category == state.db.special.when, do: nil, else: mode.date_category)

  # SPACE on Date category: the next date category, in the hierarchy's
  # order, round to the first (so F3 can list them, `BoxChoices`)
  defp change(state, mode, :date_category) do
    dates = date_categories(state.db)
    at = Enum.find_index(dates, &(&1 == mode.date_category)) || -1
    next = Enum.at(dates, rem(at + 1, length(dates)))
    State.put_mode(state, %{mode | date_category: next})
  end

  defp change(state, _mode, :minutes), do: state

  # `for` with a filter: the pairs of the hierarchy whose category is a
  # date category, the depth dropped
  defp date_categories(db),
    do: for({id, _depth} <- Database.hierarchy(db), Database.date_category?(db, id), do: id)

  @impl Box
  def title(_state, _mode), do: "Set Alarm"

  # F3's list on Date category is titled as Agenda's (`BoxChoices`)
  @impl Box
  def choices_frame(state, mode),
    do: if(field(state, mode) == :date_category, do: "Select Date Category")

  # as narrow as Agenda's
  @impl Box
  def width(state, _mode), do: min(state.width - 8, 44)

  @impl Box
  def content(state, mode, inner, _max_rows) do
    values = %{
      date_category: state.db.categories[mode.date_category].name,
      minutes: Integer.to_string(mode.minutes)
    }

    Template.render(@layout, values, [selected: field(state, mode)] ++ FieldTyping.editing(mode)) ++
      [Box.hint(keys(state, mode), inner)]
  end

  @impl Box
  def keys(_state, _mode),
    do: [
      {"↑↓", "Setting", "Move between settings"},
      {"SPACE", "Next", "Next date category"},
      {"ENTER", "Set"},
      {"ESC", "Cancel"}
    ]

  @impl Box
  def help, do: @help

  @impl Box
  def field(_state, mode), do: Enum.at(@rows, mode.cursor)
end
