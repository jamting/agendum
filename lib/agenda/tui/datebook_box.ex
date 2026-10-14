defmodule Agenda.TUI.DatebookBox do
  @moduledoc """
  The Datebook settings box (View ▸ Properties of a datebook view, and
  after View ▸ Add with Type Datebook; SPEC R47; User's Guide 10-6 to
  10-10, Help "View Add box"): Date category, End category, Section,
  Period, Interval, Start at, End at, Base date on, then the view's Hide
  column heads (R57) and Section separators (R58), as Agenda's View
  Properties of a datebook has them (screenshot 55).

  The box is drawn from `@layout` (`Agenda.TUI.Template`): the rows and
  their order, for the cursor too, are the fields there.

    * SPACE on a category row picks the category; DEL clears the End
      category
    * SPACE cycles Period and Interval, and Start at / End at of a
      week (a day of the week)
    * SPACE on Start at / End at of a day, or Base date on, asks for it
      (a time; a date such as "today", "next week" or "2026-11-05")
    * SPACE switches Hide column heads and Section separators
    * ENTER closes the box; ESC closes it and cancels its changes
      (`Agenda.TUI.BoxCancel`)

  Every change applies at once and is one undo step. Rows that do not
  apply to the period show "—". Pure.
  """

  import Agenda.TUI.BoxNav, only: [is_move: 1]
  alias Agenda.TUI.BoxNav

  alias Agenda.Core
  alias Agenda.Core.{Datebook, DateFormat}
  alias Agenda.TUI.{CategoryScreens, State, Template}
  alias Agenda.TUI.Update.Prompts

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

   SPACE picks, types or cycles · DEL clears
  """
  @rows Template.fields(@layout)
  # the view's own settings, switched on or off (not the datebook's)
  @options [:hide_column_heads, :section_separators]
  @days ~w(Mon Tue Wed Thu Fri Sat Sun)

  def open(state, view_id),
    do: State.push(state, %{type: :datebook_props, view_id: view_id, cursor: 0})

  defp datebook(state, mode), do: state.db.views[mode.view_id].datebook

  def handle(state, mode, key) do
    row = Enum.at(@rows, mode.cursor)
    d = datebook(state, mode)

    case key do
      # ENTER is done (ESC cancels: `Agenda.TUI.BoxCancel`)
      k when k in [:esc, :enter] ->
        State.pop(state)

      k when is_move(k) ->
        BoxNav.move(state, mode, Template.grid(@layout, @rows), k)

      {:char, " "} ->
        change(state, mode, d, row, 1, {:char, " "})

      k when k in [:delete, {:ctrl, "d"}] and row == :end_category ->
        set(state, mode, %{d | end_category: nil})

      _ ->
        state
    end
  end

  # SPACE switches a Yes/No, so `_step` and `_key` are ignored
  defp change(state, mode, _d, row, _step, _key) when row in @options,
    do: State.change_db(state, Core.toggle_view_option(state.db, mode.view_id, row))

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
    case Core.set_datebook(state.db, view_id, d) do
      {:ok, db} -> State.change_db(state, db)
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

  @doc "The box's title."
  def title(state, mode), do: "Datebook settings: #{state.db.views[mode.view_id].name}"

  @doc "The box's lines, the highlighted setting selected."
  def content(state, mode) do
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
      section_separators: yes_no.(view.section_separators)
    }

    Template.render(@layout, values, selected: Enum.at(@rows, mode.cursor))
  end

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

  @doc "The highlighted field, for its help in the control panel (`Agenda.TUI.FieldHelp`)."
  def field(_state, mode), do: Enum.at(@rows, mode.cursor)
end
