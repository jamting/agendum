defmodule Agendum.TUI.Boxes.DatebookSettings do
  @moduledoc """
  A datebook view's own settings (SPEC R47; User's Guide 10-6 to 10-10,
  Help "View Add box"), shown in the right column of its View Properties
  (`Agendum.TUI.Boxes.ViewProps`) as Agenda 2.0 shows them (checked
  2026-10-25, PLANNER's Today, This Week and This Month): Date category,
  End category, Section, Period, then what the period has (a day: Interval,
  Start at, End at; a week: Start at, End at; a month or a quarter:
  Interval), and Base date on.

    * SPACE on a category row picks the category; DEL clears the End
      category
    * SPACE cycles Period and Interval, and Start at / End at of a
      week (a day of the week)
    * SPACE on Start at / End at of a day, or Base date on, asks for it
      (a time; a date such as "today", "next week" or "2026-11-05")

  Every change applies at once and is one undo step. Pure.
  """

  alias Agendum.Core
  alias Agendum.Core.{Datebook, DateFormat}
  alias Agendum.TUI.{CategoryScreens, State}
  alias Agendum.TUI.Update.Prompts

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
        "read each time the view is shown. SPACE types it."
  }

  @doc "The help for each setting, in the control panel."
  def help, do: @help

  @doc """
  The rows below Period for `period`, top to bottom, as Agenda shows them:
  a week's slots are its days, so it has no Interval; a month's and a
  quarter's have no hours or days to start and end at.
  """
  @spec period_rows(Datebook.period()) :: [atom]
  def period_rows(:day), do: [:interval, :start, :end]
  def period_rows(:week), do: [:start, :end]
  def period_rows(_month_or_quarter), do: [:interval]

  @doc "Every setting of a datebook with `period`, top to bottom."
  def rows(period),
    do:
      [:date_category, :end_category, :section_category, :period] ++
        period_rows(period) ++ [:base]

  @doc "A setting changed with SPACE (or F3) in view `view_id`."
  def change(state, view_id, row, key \\ {:char, " "}) do
    change(state, view_id, state.db.views[view_id].datebook, row, 1, key)
  end

  @doc "DEL: empties the End category."
  def clear(state, view_id, :end_category),
    do: set(state, view_id, %{state.db.views[view_id].datebook | end_category: nil})

  def clear(state, _view_id, _row), do: state

  defp change(state, view_id, _d, row, _step, key)
       when row in [:date_category, :end_category, :section_category] and
              key == {:char, " "},
       do: CategoryScreens.open_picker(state, {:datebook, view_id, row}, nil)

  defp change(state, view_id, d, :period, step, _key) do
    period = cycle(Datebook.periods(), d.period, step)
    set(state, view_id, %{d | period: period, interval: nil})
  end

  defp change(state, view_id, %{period: period} = d, :interval, step, _key)
       when period != :week do
    intervals = Datebook.intervals(period)
    set(state, view_id, %{d | interval: cycle(intervals, Datebook.interval(d), step)})
  end

  defp change(state, view_id, %{period: :week} = d, row, step, _key) when row in [:start, :end] do
    {first, last} = Datebook.days(d, state.db.date_settings)

    case row do
      :start -> set(state, view_id, %{d | start_day: Integer.mod(first - 1 + step, 7) + 1})
      :end -> set(state, view_id, %{d | end_day: Integer.mod(last - 1 + step, 7) + 1})
    end
  end

  defp change(state, view_id, %{period: :day} = d, row, _step, key)
       when row in [:start, :end] and key == {:char, " "} do
    {first, last} = Datebook.hours(d, state.db.date_settings)
    time = if row == :start, do: first, else: last
    label = if row == :start, do: "Start at (a time):", else: "End at (a time):"
    Prompts.prompt(state, label, {:datebook_time, view_id, row}, time_text(time))
  end

  defp change(state, view_id, d, :base, _step, {:char, " "}),
    do:
      Prompts.prompt(
        state,
        "Base date on (e.g. today, next week, 2026-11-05):",
        {:datebook_base, view_id},
        d.base
      )

  defp change(state, _view_id, _d, _row, _step, _key), do: state

  defp cycle(list, value, step) do
    index = Enum.find_index(list, &(&1 == value)) || 0
    Enum.at(list, Integer.mod(index + step, length(list)))
  end

  defp set(state, view_id, d) do
    case State.command(state, {:set_datebook, view_id, d}) do
      {:ok, state, _} ->
        state

      {:error, :not_a_date_category} ->
        State.error(state, Agendum.TUI.Messages.text(:select_date_category))
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

    set(state, view_id, d)
  end

  @doc "A time typed for Start at or End at of a day."
  def set_time(state, view_id, row, text) do
    d = state.db.views[view_id].datebook

    case Core.read_when(state.db, text, State.context(state)) do
      {:ok, _date, %Time{} = time} ->
        field = if row == :start, do: :start_time, else: :end_time
        set(state, view_id, Map.put(d, field, time))

      _ ->
        State.error(state, Agendum.TUI.Messages.text(:bad_time))
    end
  end

  @doc "The text typed for Base date on; unreadable text is refused."
  def set_base(state, view_id, text) do
    d = state.db.views[view_id].datebook

    case Core.read_when(state.db, text, State.context(state)) do
      {:ok, _date, _time} -> set(state, view_id, %{d | base: text})
      :error -> State.error(state, Agendum.TUI.Messages.text(:bad_date))
    end
  end

  defp time_text(time), do: time |> Time.to_string() |> String.slice(0, 5)

  @doc "What each setting shows, by its row."
  def values(state, %Datebook{} = d) do
    db = state.db
    name = fn id -> if id, do: db.categories[id].name, else: "" end
    {start, stop} = range_text(state, d)

    %{
      date_category: name.(d.date_category),
      end_category: name.(d.end_category),
      section_category: name.(d.section_category),
      period: d.period |> Atom.to_string() |> String.capitalize(),
      interval: interval_name(Datebook.interval(d)),
      start: start,
      end: stop,
      base: d.base
    }
  end

  defp range_text(state, %{period: :day} = d) do
    {first, last} = Datebook.hours(d, state.db.date_settings)
    {DateFormat.time(first, state.db.date_format), DateFormat.time(last, state.db.date_format)}
  end

  defp range_text(state, %{period: :week} = d) do
    {first, last} = Datebook.days(d, state.db.date_settings)
    {Enum.at(@days, first - 1), Enum.at(@days, last - 1)}
  end

  defp range_text(_state, _d), do: {"", ""}

  defp interval_name(15), do: "15 min"
  defp interval_name(30), do: "30 min"
  defp interval_name(60), do: "Hourly"
  defp interval_name(:day), do: "Daily"
  defp interval_name(:week), do: "Weekly"
  defp interval_name(:month), do: "Monthly"

  @doc """
  F8 and ALT-F8 (`Agendum.TUI.Boxes.BoxDefaults`): a new datebook view's
  settings (View ▸ Add ▸ Datebook, `Datebook`): a week from today, its days
  as the date settings say; the date, end and section categories as it
  makes them. Each reads the datebook as it is when it runs.
  """
  def defaults(view_id) do
    new = %Datebook{}

    fields = %{
      date_category: [:date_category],
      end_category: [:end_category],
      section_category: [:section_category],
      period: [:period, :interval],
      interval: [:interval],
      start: [:start_day, :start_time],
      end: [:end_day, :end_time],
      base: [:base]
    }

    Map.new(fields, fn {row, keys} ->
      {row,
       fn state ->
         d = state.db.views[view_id].datebook
         back = Map.merge(d, Map.take(new, keys))
         if back == d, do: state, else: set(state, view_id, back)
       end}
    end)
  end
end
