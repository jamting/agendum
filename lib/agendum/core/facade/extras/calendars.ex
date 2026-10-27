defmodule Agendum.Core.Facade.Extras.Calendars do
  @moduledoc """
  Calendar subscriptions (R45): subscribing to a calendar on the web,
  applying its events to the file, and when to read it again.

  Called through `Agendum.Core`.
  """

  alias Agendum.Core.Database
  alias Agendum.Core.Extras.Calendar
  alias Agendum.Core.Facade.{Categories, Changes, Items}
  alias Agendum.Core.Facade.Extras.Feeds

  @typep db :: Agendum.Core.db()
  @typep id :: Agendum.Core.id()
  @typep clock :: Agendum.Core.clock()

  # --- calendar subscriptions (R45) -------------------------------------------------

  # the calendars' family under MAIN (R75a)
  @calendars "Calendars"

  @doc "A calendar's address as it is read (`webcal://` as `https://`), or `{:error, :bad_url}`."
  @spec calendar_url(String.t()) :: {:ok, String.t()} | {:error, :bad_url}
  def calendar_url(url) do
    case Calendar.normalize_url(url) do
      {:ok, url} -> {:ok, url}
      :error -> {:error, :bad_url}
    end
  end

  @doc """
  Subscribes to a calendar on the web: its events will become items in its
  own category `name`, in the Calendars family under MAIN (both made when
  missing, without name matching; R75a): never a category or a family of
  the person's. A name is one calendar's. `webcal://` addresses are read as
  `https://`.
  """
  @spec subscribe_calendar(db, String.t(), String.t()) ::
          {:ok, db, id} | {:error, :no_name | :bad_url | :duplicate}
  def subscribe_calendar(db, name, url) do
    name = String.trim(name)

    # Tagging a step (`{:name, true} <- {:name, ...}`) lets `else` tell which
    # step failed: a bare `false` could come from anywhere.
    with {:name, true} <- {:name, name != ""},
         {:taken, false} <- {:taken, Feeds.taken?(db.calendars, nil, name)},
         {:ok, url} <- Calendar.normalize_url(url) do
      {db, parent} = Categories.child_named(db, db.main_id, @calendars)
      # the calendars older versions made straight under MAIN join it now
      db = move_stray(db, parent)
      {db, category} = Categories.child_named(db, parent, name)

      {db, id} = Database.add_calendar(db, %Calendar{name: name, url: url, category_id: category})
      {:ok, db, id}
    else
      {:name, false} -> {:error, :no_name}
      {:taken, true} -> {:error, :duplicate}
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

    cond do
      name == "" ->
        {:error, :empty_text}

      Feeds.taken?(db.calendars, cal_id, name) ->
        {:error, :duplicate}

      true ->
        db = Database.rename_category(db, cal.category_id, name)
        {:ok, %{db | calendars: Map.put(db.calendars, cal_id, %{cal | name: name})}}
    end
  end

  @doc """
  As a file is opened (`Agendum.Store.upgrade/1`, R75a): a family of the
  person's under MAIN that holds only calendars' categories (the owner's
  "Kalender", 2026-10-26) is the calendars' family, and is named Calendars,
  unless a Calendars is already there. Nothing moves: calendars an older
  version made straight under MAIN join the family when the next calendar
  is subscribed (a file opened keeps the shape it was saved with, as its
  golden file says). Doing it again changes nothing.
  """
  @spec name_family(db) :: db
  def name_family(db) when db.calendars == %{}, do: db

  def name_family(db),
    do: name_family(db, MapSet.new(for {_, cal} <- db.calendars, do: cal.category_id))

  # The calendars' categories straight under MAIN join the family. One made
  # for the calendar (only its events' items in it, no children) moves; one
  # that was the person's before (versions before 0.68 filed a calendar into
  # any category of its name) stays theirs, where it is, and the calendar
  # gets a category of its own in the family, its events' items with it
  # (code review 2026-10-26).
  defp move_stray(db, family) do
    for({_, cal} <- db.calendars, db.categories[cal.category_id].parent_id == db.main_id, do: cal)
    |> Enum.reduce(db, fn cal, db ->
      if made_for?(db, cal), do: move_into(db, cal, family), else: own_category(db, cal, family)
    end)
  end

  defp made_for?(db, cal) do
    events = MapSet.new(for {_, %{item: id}} <- cal.events, do: id)
    cat = db.categories[cal.category_id]

    cat.children == [] and
      Enum.all?(Database.items_in(db, cat.id), &MapSet.member?(events, &1))
  end

  defp move_into(db, cal, family) do
    case Database.move_category(db, cal.category_id, family, nil) do
      {:ok, db} -> db
      {:error, _} -> own_category(db, cal, family)
    end
  end

  defp own_category(db, cal, family) do
    {db, own} = Categories.child_named(db, family, cal.name)

    db =
      for({_, %{item: id}} <- cal.events, Map.has_key?(db.items, id), do: id)
      |> Enum.reduce(db, fn id, db ->
        db |> Database.unlink(id, cal.category_id) |> Database.link(id, own)
      end)

    %{db | calendars: Map.put(db.calendars, cal.id, %{cal | category_id: own})}
  end

  defp name_family(db, own) do
    if Agendum.Core.Extras.Ingested.family(db, @calendars) do
      db
    else
      family =
        Enum.find(db.categories[db.main_id].children, fn id ->
          children = db.categories[id].children
          children != [] and Enum.all?(children, &MapSet.member?(own, &1))
        end)

      if family, do: Database.rename_category(db, family, @calendars), else: db
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
  @spec cycle_calendar_setting(db, id, :refresh_minutes | :ahead_days, integer) :: db
  def cycle_calendar_setting(db, cal_id, setting, step),
    do: Database.update_calendar(db, cal_id, &Calendar.cycle(&1, setting, step))

  @doc "The calendars due to be read again at `now`."
  @spec calendars_due(db, NaiveDateTime.t()) :: [Calendar.t()]
  def calendars_due(db, now),
    do: db |> Database.calendars() |> Enum.filter(&Calendar.due?(&1, now))
end
