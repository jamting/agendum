defmodule Agenda.TUI.DatebookBox do
  @moduledoc """
  The Datebook settings box (View ▸ Properties of a datebook view, and
  after View ▸ Add with Type Datebook; SPEC R47; User's Guide 10-6 to
  10-10, Help "View Add box"): Date category, End category, Section,
  Period, Interval, Start at, End at, Base date on.

    * ENTER (or SPACE) on a category row picks the category; DEL clears
      the End category
    * SPACE or → / ← cycle Period and Interval, and Start at / End at of a
      week (a day of the week)
    * ENTER on Start at / End at of a day, or Base date on, asks for it
      (a time; a date such as "today", "next week" or "2026-11-05")
    * ESC closes the box

  Every change applies at once and is one undo step. Rows that do not
  apply to the period show "—". Pure.
  """

  alias Agenda.Core
  alias Agenda.Core.{Datebook, DateFormat}
  alias Agenda.TUI.{CategoryScreens, State, Update}

  @rows [
    :date_category,
    :end_category,
    :section_category,
    :period,
    :interval,
    :start,
    :end,
    :base
  ]
  @days ~w(Mon Tue Wed Thu Fri Sat Sun)

  def open(state, view_id),
    do: State.push(state, %{type: :datebook_props, view_id: view_id, cursor: 0})

  defp datebook(state, mode), do: state.db.views[mode.view_id].datebook

  def handle(state, mode, key) do
    row = Enum.at(@rows, mode.cursor)
    d = datebook(state, mode)

    case key do
      :esc ->
        State.pop(state)

      :up ->
        State.put_mode(state, %{mode | cursor: max(mode.cursor - 1, 0)})

      :down ->
        State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, length(@rows) - 1)})

      k when k in [:enter, {:char, " "}, :right] ->
        change(state, mode, d, row, 1, k)

      :left ->
        change(state, mode, d, row, -1, :left)

      k when k in [:delete, {:ctrl, "d"}] and row == :end_category ->
        set(state, mode, %{d | end_category: nil})

      _ ->
        state
    end
  end

  defp change(state, mode, _d, row, _step, key)
       when row in [:date_category, :end_category, :section_category] and
              key in [:enter, {:char, " "}],
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
       when row in [:start, :end] and key in [:enter, {:char, " "}] do
    {first, last} = Datebook.hours(d, state.db.date_settings)
    time = if row == :start, do: first, else: last
    label = if row == :start, do: "Start at (a time):", else: "End at (a time):"
    Update.prompt(state, label, {:datebook_time, mode.view_id, row}, time_text(time))
  end

  defp change(state, mode, d, :base, _step, key) when key in [:enter, {:char, " "}],
    do:
      Update.prompt(
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

  @doc "`{label, value}` for each row."
  def lines(state, mode) do
    d = datebook(state, mode)
    db = state.db
    name = fn id -> if id, do: db.categories[id].name, else: "(none)" end
    {start, stop} = range_text(state, d)
    base = Datebook.base_date(d, db.date_settings, State.context(state))

    [
      {"Date category", name.(d.date_category)},
      {"End category", name.(d.end_category)},
      {"Section", name.(d.section_category)},
      {"Period", d.period |> Atom.to_string() |> String.capitalize()},
      {"Interval", interval_text(d)},
      {"Start at", start},
      {"End at", stop},
      {"Base date on", "#{d.base} (#{DateFormat.date(base, db.date_format)})"}
    ]
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
end
