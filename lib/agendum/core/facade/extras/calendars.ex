defmodule Agendum.Core.Facade.Extras.Calendars do
  @moduledoc """
  Calendar subscriptions (R45): subscribing to a calendar on the web,
  applying its events to the file, and when to read it again.

  Called through `Agendum.Core`.
  """

  alias Agendum.Core.Database
  alias Agendum.Core.Extras.Calendar
  alias Agendum.Core.Facade.{Categories, Changes, Items}

  @typep db :: Agendum.Core.db()
  @typep id :: Agendum.Core.id()
  @typep clock :: Agendum.Core.clock()

  # --- calendar subscriptions (R45) -------------------------------------------------

  @doc """
  Subscribes to a calendar on the web: its events will become items in the
  category `name` (made under MAIN, without name matching, unless one of
  that name exists). `webcal://` addresses are read as `https://`.
  """
  @spec subscribe_calendar(db, String.t(), String.t()) ::
          {:ok, db, id} | {:error, :no_name | :bad_url}
  def subscribe_calendar(db, name, url) do
    name = String.trim(name)

    # Tagging a step (`{:name, true} <- {:name, ...}`) lets `else` tell which
    # step failed: a bare `false` could come from anywhere.
    with {:name, true} <- {:name, name != ""},
         {:ok, url} <- Calendar.normalize_url(url) do
      {db, category} =
        case Database.find_categories(db, name) do
          [existing | _] ->
            {db, existing}

          [] ->
            {:ok, db, id} = Categories.add_category(db, db.main_id, name, match_name: false)
            {db, id}
        end

      {db, id} = Database.add_calendar(db, %Calendar{name: name, url: url, category_id: category})
      {:ok, db, id}
    else
      {:name, false} -> {:error, :no_name}
      :error -> {:error, :bad_url}
    end
  end

  @doc """
  Renames a calendar and its category (R75a): the one way to rename an
  ingested category, from the Calendars box. Two calendars cannot share a
  name.
  """
  @spec rename_calendar(db, id, String.t()) :: {:ok, db} | {:error, :empty_text | :duplicate}
  def rename_calendar(db, cal_id, name) do
    name = String.trim(name)
    cal = db.calendars[cal_id]
    wanted = Database.normalize(name)

    taken =
      Enum.any?(db.calendars, fn {id, other} ->
        id != cal_id and Database.normalize(other.name) == wanted
      end)

    cond do
      name == "" ->
        {:error, :empty_text}

      taken ->
        {:error, :duplicate}

      true ->
        db = Database.rename_category(db, cal.category_id, name)
        {:ok, %{db | calendars: Map.put(db.calendars, cal_id, %{cal | name: name})}}
    end
  end

  @doc "Ends a subscription; with `remove_items`, its items are discarded too."
  @spec unsubscribe_calendar(db, id, boolean) :: db
  def unsubscribe_calendar(db, cal_id, remove_items) do
    items =
      if remove_items,
        # iterating a map yields `{key, value}` tuples; the pattern takes the
        # `item` field out of each value
        do: for({_, %{item: id}} <- db.calendars[cal_id].events, do: id),
        else: []

    items
    |> Enum.filter(&Map.has_key?(db.items, &1))
    |> Enum.reduce(db, &Items.discard_item(&2, &1))
    |> Database.delete_calendar(cal_id)
  end

  @doc """
  Applies a calendar's events, read from its iCalendar file, to the file
  (`Agendum.Core.Extras.CalendarSync`): new events become items, changed ones
  update them, gone ones remove them. Returns how many of each.
  """
  @spec sync_calendar(db, id, [Agendum.Core.Extras.ICal.Event.t()], clock) ::
          {:ok, db, Agendum.Core.Extras.CalendarSync.counts()} | {:error, :unknown_calendar}
  def sync_calendar(db, cal_id, events, clock) do
    if Map.has_key?(db.calendars, cal_id) do
      {db, counts} = Agendum.Core.Extras.CalendarSync.sync(db, cal_id, events, clock)
      {:ok, db, counts}
    else
      {:error, :unknown_calendar}
    end
  end

  @doc "Remembers that reading a calendar failed, so it is not retried at once."
  @spec calendar_failed(db, id, String.t(), clock) :: db
  def calendar_failed(db, cal_id, message, clock) do
    if Map.has_key?(db.calendars, cal_id),
      do:
        Database.update_calendar(
          db,
          cal_id,
          &%{&1 | error: message, refreshed_at: Changes.now_of(clock)}
        ),
      else: db
  end

  @doc "The next or previous choice for how often a calendar is read, or how far ahead."
  @spec cycle_calendar_setting(db, id, :refresh_minutes | :ahead_days, 1 | -1) :: db
  def cycle_calendar_setting(db, cal_id, setting, step),
    do: Database.update_calendar(db, cal_id, &Calendar.cycle(&1, setting, step))

  @doc "The calendars due to be read again at `now`."
  @spec calendars_due(db, NaiveDateTime.t()) :: [Calendar.t()]
  def calendars_due(db, now),
    do: db |> Database.calendars() |> Enum.filter(&Calendar.due?(&1, now))
end
