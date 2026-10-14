defmodule Agendum.TUI.Boxes.CalendarsBox do
  @moduledoc """
  The Calendars box (File ▸ Transfer ▸ Calendars; SPEC R45): the file's
  calendar subscriptions, each with its address, how often it is read, how
  far ahead, and when it was last read (or why that failed).

    * INS (or CTRL-N) subscribes: the calendar's address, then a name for
      the category its events go in; it is read at once
    * ENTER (or R) reads the highlighted calendar now
    * F changes how often it is read, A how far ahead it imports
    * DEL unsubscribes, asking whether to discard its items too
    * ESC closes the box

  Reading happens in the shell (`{:fetch_calendar, id, url}`); the result
  comes back through `Agendum.TUI.Update.calendar_read/3`. Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :none

  alias Agendum.Core
  alias Agendum.Core.{Calendar, Database, DateFormat}
  alias Agendum.TUI.{Boxes.Box, Terminal.Draw, State, Update}
  alias Agendum.TUI.Update.Prompts

  def open(state), do: State.push(state, %{type: :calendars, cursor: 0})

  @doc "The calendar the highlight is on, if any."
  def current(state, mode), do: state.db |> Database.calendars() |> Enum.at(mode.cursor)

  @impl Box
  def handle(state, mode, key) do
    count = length(Database.calendars(state.db))
    mode = %{mode | cursor: mode.cursor |> min(count - 1) |> max(0)}
    state = State.put_mode(state, mode)
    cal = current(state, mode)

    case {key, cal} do
      {:esc, _} ->
        State.pop(state)

      {:up, _} ->
        State.put_mode(state, %{mode | cursor: max(mode.cursor - 1, 0)})

      {:down, _} ->
        State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, max(count - 1, 0))})

      {k, _} when k in [:insert, {:ctrl, "n"}] ->
        Prompts.prompt(state, "Calendar's web address (https:// or webcal://):", :calendar_url)

      {_, nil} ->
        state

      {k, cal} when k in [:enter, {:char, "r"}, {:char, "R"}] ->
        Update.fetch_calendar(state, cal.id, :manual)

      {{:char, c}, cal} when c in ["f", "F"] ->
        setting(state, cal, :refresh_minutes)

      {{:char, c}, cal} when c in ["a", "A"] ->
        setting(state, cal, :ahead_days)

      {k, cal} when k in [:delete, {:ctrl, "d"}] ->
        unsubscribe(state, cal)

      _ ->
        state
    end
  end

  defp setting(state, cal, setting),
    do: State.change_db(state, Core.cycle_calendar_setting(state.db, cal.id, setting, 1))

  defp unsubscribe(state, cal) do
    items = Enum.count(cal.events, fn {_, %{item: id}} -> Map.has_key?(state.db.items, id) end)

    Prompts.ask(
      state,
      "Unsubscribe from #{cal.name}. Discard its #{Draw.count(items, "item")} too?",
      {:unsubscribe_calendar, cal.id}
    )
  end

  @impl Box
  def title(_state, _mode), do: "Calendars"

  @impl Box
  def content(state, mode, _inner, _max_rows) do
    rows =
      state
      |> lines(mode)
      |> Enum.map(fn {style, text} ->
        [{if(style == :selected, do: :box_selected, else: :box), " " <> text}]
      end)

    rows ++
      [
        [],
        [{:box, " INS subscribe · ENTER read now · DEL unsubscribe"}],
        [{:box, " F how often · A how far ahead"}]
      ]
  end

  @impl Box
  def keys(_state, _mode),
    do: [
      {"INS", "Subscribe", "Subscribe to a calendar"},
      {"ENTER", "Read now"},
      {"F", "How often", "How often to read it"},
      {"A", "Ahead", "How far ahead"},
      {"DEL", "Unsubscribe"},
      {"ESC", "Close"}
    ]

  @impl Box
  def help,
    do:
      "Your calendar subscriptions. ENTER reads one now, F sets how often, " <>
        "A how far ahead; INS adds one, DEL removes it."

  # for each calendar its name and state, address, and settings
  defp lines(state, mode) do
    case Database.calendars(state.db) do
      [] ->
        [{:normal, "No calendars yet · INS subscribes to one"}]

      calendars ->
        calendars
        |> Enum.with_index()
        |> Enum.flat_map(fn {cal, i} ->
          head = Draw.pad(cal.name, 24) <> " " <> status(state, cal)
          style = if i == mode.cursor, do: :selected, else: :normal

          [
            {style, head},
            {:normal, "   " <> cal.url},
            {:normal, "   " <> refresh(cal.refresh_minutes) <> " · #{cal.ahead_days} days ahead"}
          ] ++ if(cal.error, do: [{:normal, "   failed: " <> cal.error}], else: [])
        end)
    end
  end

  defp status(state, cal) do
    cond do
      Map.has_key?(state.fetching, cal.id) -> "reading…"
      cal.refreshed_at == nil -> "not read yet"
      true -> "read " <> DateFormat.datetime(cal.refreshed_at, state.db.date_format)
    end
  end

  @doc "How often a calendar is read, in words."
  def refresh(nil), do: "only on request"
  def refresh(60), do: "every hour"
  def refresh(1440), do: "every day"
  def refresh(minutes), do: "every #{div(minutes, 60)} hours"

  @doc false
  def choices, do: Calendar.refresh_choices()
end
