# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Extras.CalendarsBox do
  @moduledoc """
  The Calendars box (Extras ▸ Calendars; SPEC R45): the file's
  calendar subscriptions, each with its address, how often it is read, how
  far ahead, and when it was last read (or why that failed).

  A manager, as the Feeds box and the Macros manager are:

    * INS (or CTRL-N) subscribes: the calendar's address, then a name for
      the category its events go in; it is read at once
    * ENTER reads the highlighted calendar now, ALT-ENTER every calendar
    * F6 its properties: how often it is read, how far ahead
      (`Agendum.TUI.Extras.SubscriptionPropsBox`)
    * F2 renames it; DEL (F4, CTRL-D) unsubscribes, asking whether to
      discard its items too
    * ESC closes the box

  Reading happens in the shell (`{:fetch_calendar, id, url}`); the result
  comes back through `Agendum.TUI.Extras.Calendars.Results.calendar_read/4`. Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :none

  alias Agendum.Core.{Database, DateFormat}
  alias Agendum.Core.Extras.Calendar
  alias Agendum.TUI.{Boxes.Box, Boxes.Scroll, Terminal.Draw, State, Update}
  alias Agendum.TUI.Update.Prompts
  alias Agendum.TUI.Extras.Calendars.Messages

  def open(state), do: State.push(state, %Agendum.TUI.Modes.Calendars{cursor: 0})

  @doc "The calendar the highlight is on, if any."
  def current(state, mode), do: state.db |> Database.calendars() |> Enum.at(mode.cursor)

  @impl Box
  def handle(state, _mode, _key), do: state

  @impl Box
  def about(_state, _mode) do
    """
    Calendars on the web (iCal) that the file subscribes to: their events
    become items.

    INS subscribes to one, by its address. ENTER reads the highlighted
    one now, ALT-ENTER every calendar. F6 shows its properties: how often
    it is read, how far ahead. F2 renames it, and its category
    (only here: the category manager leaves a calendar's category alone).
    DEL unsubscribes. ESC goes back.
    """
  end

  # R65
  @impl Box
  def keymap(_mode) do
    %{
      :up => :up,
      :down => :down,
      :insert => :subscribe,
      {:ctrl, "n"} => :subscribe,
      :enter => :read,
      {:alt, :enter} => :read_all,
      {:f, 2} => :rename,
      {:f, 6} => :properties,
      {:f, 4} => :unsubscribe,
      :delete => :unsubscribe,
      {:ctrl, "d"} => :unsubscribe,
      :esc => :close
    }
  end

  @impl Box
  def commands(_mode) do
    [
      {:read, "Read now", "Read the calendar now"},
      {:read_all, "Read all", "Read every calendar now"},
      {:subscribe, "Subscribe", "Add a calendar by its address"},
      {:rename, "Rename", "Rename the calendar and its category"},
      {:properties, "Properties", "How often it is read, and more"},
      {:unsubscribe, "Unsubscribe", "Unsubscribe from the calendar"}
    ] ++ Enum.take(Box.list_moves(), 2) ++ [{:close, "Return", "Back to the view"}]
  end

  @impl Box
  def run(state, _mode, :close), do: State.pop(state)

  def run(state, _mode, :subscribe),
    do: Prompts.prompt(state, Messages.text(:address), :calendar_url)

  def run(state, _mode, :read_all), do: read_all(state)

  def run(state, mode, id) do
    count = length(Database.calendars(state.db))
    mode = %{mode | cursor: mode.cursor |> min(count - 1) |> max(0)}
    state = State.put_mode(state, mode)
    calendar(state, mode, id, current(state, mode), count)
  end

  defp calendar(state, mode, id, _cal, count) when id in [:up, :down],
    do: Box.list_move(state, mode, max(count, 1), id)

  defp calendar(state, _mode, _id, nil, _count), do: state
  defp calendar(state, _mode, :read, cal, _), do: Update.fetch_calendar(state, cal.id, :manual)

  # the one place to rename a calendar's category (R75a)
  defp calendar(state, _mode, :rename, cal, _),
    do: Prompts.prompt(state, Messages.text(:rename), {:rename_calendar, cal.id}, cal.name)

  defp calendar(state, _mode, :unsubscribe, cal, _), do: unsubscribe(state, cal)

  defp calendar(state, _mode, :properties, cal, _),
    do: Agendum.TUI.Extras.SubscriptionPropsBox.open(state, :calendar, cal.id)

  # ALT-ENTER: every calendar read, quietly unless it brings something
  # (only those not being read already count)
  defp read_all(state) do
    next =
      Enum.reduce(Database.calendars(state.db), state, &Update.fetch_calendar(&2, &1.id, :auto))

    case map_size(next.fetching) - map_size(state.fetching) do
      0 -> State.info(next, Messages.text(:nothing_to_read))
      started -> State.info(next, Messages.text(:reading_all, started))
    end
  end

  defp unsubscribe(state, cal) do
    items = Enum.count(cal.events, fn {_, %{item: id}} -> Map.has_key?(state.db.items, id) end)

    Prompts.ask(
      state,
      Messages.text(:unsubscribe, cal.name, items),
      {:unsubscribe_calendar, cal.id}
    )
  end

  # --- subscribing (INS): the address, a read, then the name -------------

  @doc """
  The address typed after INS: the calendar is read once before it is
  subscribed to (`{:probe_calendar, url}`), so its name can be offered (its own
  title) and one that cannot be read is refused (the owner, 2026-10-27).
  The box remembers the address it waits for (`probing`).
  """
  @spec address_typed(State.t(), String.t()) :: State.t()
  def address_typed(state, text) do
    case Agendum.Core.calendar_url(String.trim(text)) do
      {:ok, url} -> probe(state, url)
      {:error, :bad_url} -> State.error(state, Messages.text(:bad_url))
    end
  end

  defp probe(state, url) do
    case Enum.find_index(state.modes, &(&1.type == :calendars)) do
      nil ->
        state

      i ->
        %{state | modes: List.update_at(state.modes, i, &%{&1 | probing: url})}
        |> State.info(Messages.text(:probing, url))
        |> State.effect({:probe_calendar, url})
    end
  end

  @doc """
  The calendar read before subscribing: the name asked, its own title filled
  in (`Agendum.Core.subscription_name/2`), or why it was not subscribed.
  Dropped unless the box is still open and waiting for that address: the
  person may have closed it, or typed another (a key in between, another
  file opened meanwhile).
  """
  @spec probed(State.t(), String.t(), {:ok, map} | {:error, String.t()}) :: State.t()
  def probed(state, url, result) do
    case Enum.find_index(state.modes, &match?(%{type: :calendars, probing: ^url}, &1)) do
      nil ->
        state

      i ->
        state = %{state | modes: List.update_at(state.modes, i, &%{&1 | probing: nil})}
        asked(state, url, result)
    end
  end

  # Domain: the read runs in the background, so it can answer while
  # another prompt is typed in (INS again): there is one line to type in,
  # and asking for the name would take it over (nightly fuzz, 2026-11-01)
  defp asked(%State{edit: edit} = state, _url, {:ok, _read}) when edit != nil,
    do: State.error(state, Messages.text(:read_while_typing))

  defp asked(state, url, {:ok, read}) do
    name = Agendum.Core.subscription_name(read.title, url)
    Prompts.prompt(state, Messages.text(:name), {:calendar_name, url, read.events}, name)
  end

  defp asked(state, _url, {:error, reason}),
    do: State.error(state, Messages.text(:unreadable, reason))

  @doc """
  The name given: the calendar subscribed to and what was read filed at once,
  one change (one undo step), not read a second time.
  """
  @spec name_typed(State.t(), String.t(), list, String.t()) :: State.t()
  def name_typed(state, url, events, name) do
    case State.command(state, {:subscribe_calendar, name, url}) do
      {:ok, state, %{new: id}} ->
        {:ok, state, _} = State.command(state, {:sync_calendar, id, events})
        State.info(state, Messages.text(:subscribed, String.trim(name)))

      {:error, :bad_url} ->
        State.error(state, Messages.text(:bad_url))

      {:error, :no_name} ->
        State.error(state, Messages.text(:no_name))

      {:error, :duplicate} ->
        State.error(state, Messages.text(:duplicate, String.trim(name)))
    end
  end

  @impl Box
  def title(_state, _mode), do: "Calendars"

  @impl Box
  # the list scrolls by whole calendars, as the Feeds box's
  # (`Agendum.TUI.Boxes.Scroll`)
  def content(state, mode, inner, max_rows) do
    rows =
      state
      |> groups(mode)
      |> Enum.map(fn group -> Enum.map(group, &row/1) end)
      |> Scroll.window(mode.cursor, max(max_rows - 2, 4), &row({:normal, &1}))

    # the hint is made from the keys, as the key bar is (rule 6.2)
    rows ++ [[], Box.hint(keys(state, mode), inner)]
  end

  @impl Box
  def keys(_state, _mode),
    do: [
      {"ENTER", "Read now", "read now"},
      {"A-ENTER", "Read all", "ALT-ENTER", "read all"},
      {"INS", "Subscribe", "subscribe"},
      {"F2", "Rename", "rename"},
      {"F6", "Props", "properties"},
      {"DEL", "Unsubscribe", "unsubscribe"},
      {"ESC", "Close"}
    ]

  # the key bar's words (R65b): F2 renames, F4 unsubscribes
  @impl Box
  def labels(_mode),
    do: %{rename: "Rename", unsubscribe: "Unsubs", properties: "Props"}

  @impl Box
  def help,
    do:
      "Your calendar subscriptions. ENTER reads one now, ALT-ENTER all; " <>
        "INS adds one, DEL removes it."

  defp row({style, text}),
    do: [{if(style == :selected, do: :box_selected, else: :box), " " <> text}]

  # for each calendar its name and state, address, and settings: a group
  defp groups(state, mode) do
    case Database.calendars(state.db) do
      [] ->
        [[{:normal, "No calendars yet · INS subscribes to one"}]]

      calendars ->
        calendars
        |> Enum.with_index()
        |> Enum.map(fn {cal, i} ->
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
