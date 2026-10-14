defmodule Agendum.TUI.Boxes.CalendarBox do
  @moduledoc """
  The pop-up calendar (SPEC R46; User's Guide 6-14 to 6-17): a month with
  the highlight on a day.

    * F3 in a date column opens it on the entry's date (or today), to pick
      a date for the entry; ENTER sets it as if typed, keeping its time
    * ALT-C opens it anywhere on today, for reference; ENTER closes it
    * ← → a day, ↑ ↓ a week, HOME / END the first / last day of the month,
      PGUP / PGDN a month, CTRL-← / CTRL-→ (or < / >) a year
    * F6 sets a time to go with the date (empty: none); typing a date
      ("next friday", "2027-03-15") jumps there
    * ESC closes it and changes nothing

  The month and the moves are `Agendum.Core.MonthCalendar`. Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :accept, indicator: "CHOICES"

  alias Agendum.Core
  alias Agendum.Core.{Database, MonthCalendar}
  alias Agendum.TUI.{Boxes.Box, State}
  alias Agendum.TUI.Update.{Editing, Prompts}

  @moves %{
    :left => {:day, -1},
    :right => {:day, 1},
    :up => {:week, -1},
    :down => {:week, 1},
    :home => {:first, 0},
    :end => {:last, 0},
    :pgup => {:month, -1},
    :pgdn => {:month, 1},
    :ctrl_left => {:year, -1},
    :ctrl_right => {:year, 1},
    {:char, "<"} => {:year, -1},
    {:char, ">"} => {:year, 1}
  }

  @months ~w(January February March April May June July August September October November December)
  @days ~w(Mon Tue Wed Thu Fri Sat Sun)

  @doc """
  Opens the calendar: for the date column entry `{item_id, category_id}`, on
  its date and time, or with `nil` for reference, on today.
  """
  def open(state, nil),
    do: State.push(state, %{type: :calendar, date: state.today, time: nil, target: nil})

  # the date of the Show Schedule box beneath (R49)
  def open(state, {:schedule, date}),
    do: State.push(state, %{type: :calendar, date: date, time: nil, target: :schedule})

  def open(state, {item_id, cat_id} = target) do
    date = Database.item_date(state.db, item_id, cat_id) || state.today
    time = Database.item_time(state.db, item_id, cat_id)
    State.push(state, %{type: :calendar, date: date, time: time, target: target})
  end

  @impl Box
  def handle(state, mode, key) do
    case {key, @moves[key]} do
      {_, {move, n}} ->
        State.put_mode(state, %{mode | date: MonthCalendar.move(mode.date, move, n)})

      {:esc, _} ->
        State.pop(state)

      {:enter, _} ->
        choose(State.pop(state), mode)

      {{:f, 6}, _} ->
        Prompts.prompt(
          state,
          "Time (e.g. 3pm, 15:30; empty for none):",
          :calendar_time,
          time_text(mode.time)
        )

      {{:char, c}, _} when c != " " ->
        Prompts.prompt(state, "Go to date:", :calendar_jump, c)

      _ ->
        state
    end
  end

  defp choose(state, %{target: nil}), do: state

  defp choose(state, %{target: :schedule, date: date}),
    do: Agendum.TUI.Boxes.ScheduleBox.set_date(state, date)

  defp choose(state, %{target: {item_id, cat_id}, date: date, time: time}) do
    text = Enum.join([Date.to_iso8601(date), time_text(time)], " ") |> String.trim()
    Editing.set_column_entry(state, item_id, cat_id, text)
  end

  @doc "F6's answer: the time to go with the date; empty for none."
  def set_time(state, ""), do: update(state, &%{&1 | time: nil})

  def set_time(state, text) do
    case Core.read_when(state.db, text, State.context(state)) do
      {:ok, _date, %Time{} = time} -> update(state, &%{&1 | time: time})
      _ -> State.error(state, "Not a time: #{text}")
    end
  end

  @doc "A typed date: the highlight jumps there."
  def jump(state, text) do
    case Core.read_when(state.db, text, State.context(state)) do
      {:ok, date, _time} -> update(state, &%{&1 | date: date})
      :error -> State.error(state, "Not a date: #{text}")
    end
  end

  defp update(state, fun) do
    case State.mode(state) do
      %{type: :calendar} = mode -> State.put_mode(state, fun.(mode))
      _ -> state
    end
  end

  defp time_text(nil), do: ""
  defp time_text(time), do: time |> Time.to_string() |> String.slice(0, 5)

  # the month and year
  @impl Box
  def title(_state, mode), do: "#{Enum.at(@months, mode.date.month - 1)} #{mode.date.year}"

  # the weekday names from the file's beginning of week, the six weeks
  # with the highlighted day, and the time
  @impl Box
  def content(state, mode, _inner, _max_rows) do
    week_start = state.db.date_settings.week_start
    names = Enum.map_join(0..6, " ", &Enum.at(@days, Integer.mod(week_start - 1 + &1, 7)))

    weeks =
      mode.date
      |> MonthCalendar.weeks(week_start)
      |> Enum.map(fn week ->
        cells = Enum.map(week, &cell(&1, mode.date))
        [{:box, " "} | Enum.intersperse(cells, {:box, " "})]
      end)

    time = if mode.time, do: time_text(mode.time), else: "(none; F6 sets one)"
    [[{:box, " " <> names}], []] ++ weeks ++ [[], [{:box, " Time: " <> time}]]
  end

  # a small box, as in Agenda
  @impl Box
  def width(state, _mode), do: min(state.width - 8, 30)

  @impl Box
  def keys(_state, %{target: target}),
    do: [
      {"←→↑↓", "Day/week", "←→ ↑↓", "Day, week"},
      {"PGUP/DN", "Month", "PGUP/PGDN", "Month"},
      {"^←→", "Year", "CTRL-←→ or < >", "Year"},
      {"ENTER", if(target, do: "Select", else: "Close"),
       if(target, do: "Set the date", else: "Close")},
      {"F6", "Time", "Set a time"},
      {"type", "Go to", "Type a date to go there"},
      {"ESC", "Cancel"}
    ]

  @impl Box
  def help,
    do:
      "Move the highlight to a date and press ENTER. PGUP/PGDN for another month; " <>
        "type a date to go there; F6 adds a time."

  defp cell(nil, _highlight), do: {:box, "   "}
  defp cell(date, date), do: {:box_selected, String.pad_leading("#{date.day}", 3)}
  defp cell(date, _highlight), do: {:box, String.pad_leading("#{date.day}", 3)}
end
