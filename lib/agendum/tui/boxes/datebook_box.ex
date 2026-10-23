defmodule Agendum.TUI.Boxes.DatebookBox do
  @moduledoc """
  The Datebook settings box (View ▸ Properties of a datebook view, and
  after View ▸ Add with Type Datebook; SPEC R47; User's Guide 10-6 to
  10-10, Help "View Add box"): Date category, End category, Section,
  Period, Interval, Start at, End at, Base date on, then the view's Hide
  column heads (R57), Section separators (R58) and Number items (R79), as
  Agenda's View Properties of a datebook has them (screenshot 55).

  The box is drawn from `@layout` (`Agendum.TUI.Boxes.Template`): the rows and
  their order, for the cursor too, are the fields there.

    * SPACE on a category row picks the category; DEL clears the End
      category
    * SPACE cycles Period and Interval, and Start at / End at of a
      week (a day of the week)
    * SPACE on Start at / End at of a day, or Base date on, asks for it
      (a time; a date such as "today", "next week" or "2026-11-05")
    * SPACE switches Hide column heads, Section separators and Number
      items (R79)
    * ENTER closes the box; ESC closes it and cancels its changes
      (`Agendum.TUI.Boxes.BoxCancel`)

  Every change applies at once and is one undo step. Rows that do not
  apply to the period show "—". Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, indicator: "PROPS", cancels: true

  alias Agendum.TUI.Boxes.{Box}

  alias Agendum.Core
  alias Agendum.Core.{Datebook, DateFormat}
  alias Agendum.TUI.{CategoryScreens, State, Boxes.Template}
  alias Agendum.TUI.Update.Prompts

  @layout """
   Date category      : [date_category         ]
   End category       : [end_category          ]
   Section            : [section_category      ]
   Period             : [period                ]
   Interval           : [interval              ]
   Start at           : [start                 ]
   End at             : [end                   ]
   Base date on       : [base                                ]

   Hide column heads  : [hide_column_heads     ]
   Section separators : [section_separators    ]
   Number items       : [number_items          ]
  """
  @rows Template.fields(@layout)
  # the view's own settings, switched on or off (not the datebook's)
  @options [:hide_column_heads, :section_separators, :number_items]
  @days ~w(Mon Tue Wed Thu Fri Sat Sun)

  @help %{
    date_category: "The date category whose dates place items in the slots. SPACE picks one.",
    end_category:
      "A date category for the end of items that last a while. SPACE picks one, DEL clears it.",
    section_category: "The category at the head of every section. SPACE picks one.",
    period: "How long the datebook shows: a day, a week, a month or a quarter. SPACE changes it.",
    interval: "How long each section (slot) is. SPACE for the next choice.",
    start:
      "Where the datebook starts: an hour of the day or a day of the week. SPACE changes it.",
    end: "Where the datebook ends: an hour of the day or a day of the week. SPACE changes it.",
    base:
      "The date the period is taken from, such as \"today\" or \"next week\", " <>
        "read each time the view is shown. SPACE types it.",
    hide_column_heads: "Whether the column heads show above each section. SPACE switches.",
    section_separators: "Whether a line separates the sections. SPACE switches.",
    number_items: "Display a number next to the item tag in front of every item."
  }

  def open(state, view_id),
    do: State.push(state, %Agendum.TUI.Modes.DatebookProps{view_id: view_id, cursor: 0})

  defp datebook(state, mode), do: state.db.views[mode.view_id].datebook

  @impl Box
  # its keys are the settings box's, and DEL empties End category (R65)
  def handle(state, _mode, _key), do: state

  @impl Box
  def keymap(_mode), do: Box.settings_keymap(%{:delete => :clear, {:ctrl, "d"} => :clear})

  @impl Box
  def commands(_mode), do: Box.settings_commands([{:clear, "Clear", "Empty End category"}])

  # ENTER is done (ESC cancels: `Agendum.TUI.Boxes.BoxCancel`)
  @impl Box
  def run(state, mode, :change) do
    change(state, mode, datebook(state, mode), Enum.at(@rows, mode.cursor), 1, {:char, " "})
  end

  def run(state, mode, :clear) do
    if Enum.at(@rows, mode.cursor) == :end_category,
      do: set(state, mode, %{datebook(state, mode) | end_category: nil}),
      else: state
  end

  def run(state, mode, id), do: Box.run_settings(state, mode, Template.grid(@layout, @rows), id)

  # SPACE switches a Yes/No, so `_step` and `_key` are ignored
  defp change(state, mode, _d, row, _step, _key) when row in @options,
    do: State.run(state, {:toggle_view_option, mode.view_id, row})

  defp change(state, mode, _d, row, _step, key)
       when row in [:date_category, :end_category, :section_category] and
              key == {:char, " "},
       do: CategoryScreens.open_picker(state, {:datebook, mode.view_id, row}, nil)

  defp change(state, mode, d, :period, step, _key) do
    period = cycle(Datebook.periods(), d.period, step)
    set(state, mode, %{d | period: period, interval: nil})
  end

  defp change(state, mode, %{period: period} = d, :interval, step, _key) when period != :week do
    intervals = Datebook.intervals(period)
    set(state, mode, %{d | interval: cycle(intervals, Datebook.interval(d), step)})
  end

  defp change(state, mode, %{period: :week} = d, row, step, _key) when row in [:start, :end] do
    {first, last} = Datebook.days(d, state.db.date_settings)

    case row do
      :start -> set(state, mode, %{d | start_day: Integer.mod(first - 1 + step, 7) + 1})
      :end -> set(state, mode, %{d | end_day: Integer.mod(last - 1 + step, 7) + 1})
    end
  end

  defp change(state, mode, %{period: :day} = d, row, _step, key)
       when row in [:start, :end] and key == {:char, " "} do
    {first, last} = Datebook.hours(d, state.db.date_settings)
    time = if row == :start, do: first, else: last
    label = if row == :start, do: "Start at (a time):", else: "End at (a time):"
    Prompts.prompt(state, label, {:datebook_time, mode.view_id, row}, time_text(time))
  end

  defp change(state, mode, d, :base, _step, {:char, " "}),
    do:
      Prompts.prompt(
        state,
        "Base date on (e.g. today, next week, 2026-11-05):",
        {:datebook_base, mode.view_id},
        d.base
      )

  defp change(state, _mode, _d, _row, _step, _key), do: state

  defp cycle(list, value, step) do
    index = Enum.find_index(list, &(&1 == value)) || 0
    Enum.at(list, Integer.mod(index + step, length(list)))
  end

  defp set(state, mode, d), do: set_datebook(state, mode.view_id, d)

  defp set_datebook(state, view_id, d) do
    case State.command(state, {:set_datebook, view_id, d}) do
      {:ok, state, _} -> state
      {:error, :not_a_date_category} -> State.error(state, "Pick a date category")
    end
  end

  @doc "A category picked for one of the category rows."
  def set_category(state, view_id, row, cat_id) do
    d = state.db.views[view_id].datebook

    d =
      case row do
        # a new date category takes the Section along when it followed it
        :date_category when d.section_category == d.date_category ->
          %{d | date_category: cat_id, section_category: cat_id}

        row ->
          Map.put(d, row, cat_id)
      end

    set_datebook(state, view_id, d)
  end

  @doc "A time typed for Start at or End at of a day."
  def set_time(state, view_id, row, text) do
    d = state.db.views[view_id].datebook

    case Core.read_when(state.db, text, State.context(state)) do
      {:ok, _date, %Time{} = time} ->
        field = if row == :start, do: :start_time, else: :end_time
        set_datebook(state, view_id, Map.put(d, field, time))

      _ ->
        State.error(state, "Not a time: #{text}")
    end
  end

  @doc "The text typed for Base date on; unreadable text is refused."
  def set_base(state, view_id, text) do
    d = state.db.views[view_id].datebook

    case Core.read_when(state.db, text, State.context(state)) do
      {:ok, _date, _time} -> set_datebook(state, view_id, %{d | base: text})
      :error -> State.error(state, "Not a date: #{text}")
    end
  end

  defp time_text(time), do: time |> Time.to_string() |> String.slice(0, 5)

  @impl Box
  def title(state, mode), do: "Datebook settings: #{state.db.views[mode.view_id].name}"

  @impl Box
  def content(state, mode, inner, _max_rows) do
    d = datebook(state, mode)
    db = state.db
    view = db.views[mode.view_id]
    name = fn id -> if id, do: db.categories[id].name, else: "(none)" end
    yes_no = fn on -> if on, do: "Yes", else: "No" end
    {start, stop} = range_text(state, d)
    base = Datebook.base_date(d, db.date_settings, State.context(state))

    values = %{
      date_category: name.(d.date_category),
      end_category: name.(d.end_category),
      section_category: name.(d.section_category),
      period: d.period |> Atom.to_string() |> String.capitalize(),
      interval: interval_text(d),
      start: start,
      end: stop,
      base: "#{d.base} (#{DateFormat.date(base, db.date_format)})",
      hide_column_heads: yes_no.(view.hide_column_heads),
      section_separators: yes_no.(view.section_separators),
      number_items: yes_no.(view.number_items)
    }

    Template.render(@layout, values, selected: field(state, mode)) ++
      [[], Box.hint(keys(state, mode), inner)]
  end

  @impl Box
  def keys(_state, _mode),
    do: [
      {"↑↓←→", "Setting", "Move between settings"},
      {"SPACE", "Change", "Pick, type or next choice"},
      {"DEL", "Clear", "Clear the End category"},
      {"ENTER", "Done"},
      {"ESC", "Cancel"}
    ]

  @impl Box
  def help, do: @help

  defp range_text(state, %{period: :day} = d) do
    {first, last} = Datebook.hours(d, state.db.date_settings)
    {DateFormat.time(first, state.db.date_format), DateFormat.time(last, state.db.date_format)}
  end

  defp range_text(state, %{period: :week} = d) do
    {first, last} = Datebook.days(d, state.db.date_settings)
    {Enum.at(@days, first - 1), Enum.at(@days, last - 1)}
  end

  defp range_text(_state, _d), do: {"—", "—"}

  defp interval_text(%{period: :week}), do: "— (a day each)"
  defp interval_text(d), do: interval_name(Datebook.interval(d))

  defp interval_name(15), do: "15 min"
  defp interval_name(30), do: "30 min"
  defp interval_name(60), do: "Hourly"
  defp interval_name(:day), do: "Daily"
  defp interval_name(:week), do: "Weekly"
  defp interval_name(:month), do: "Monthly"

  @impl Box
  def field(_state, mode), do: Enum.at(@rows, mode.cursor)
end
