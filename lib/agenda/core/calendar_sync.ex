defmodule Agenda.Core.CalendarSync do
  @moduledoc """
  Applies a calendar's events to the file (SPEC R45), mirroring the
  calendar:

    * an event not seen before becomes an item in the calendar's category,
      when its date is from today up to `ahead_days` ahead: the title is the
      item text (read like typed text, so text matching files it too), the
      description its note, and the start its When date and time, set as by
      hand; a repeating event gets its next date and, where Agenda can
      repeat it the same way, its rule
    * an event seen before updates its item, but only in what the calendar
      changed since the last refresh, so the person's own edits, categories
      and done marks stay
    * an event gone from the calendar, or cancelled, removes its item; an
      item the person discarded is not brought back

  Uses the facade's own item functions, so conditions and actions run as
  for typed items. Pure.
  """

  alias Agenda.Core
  alias Agenda.Core.{Calendar, Context, Database}
  alias Agenda.Core.ICal.Event

  @type counts :: %{added: non_neg_integer, updated: non_neg_integer, removed: non_neg_integer}

  @spec sync(Database.t(), pos_integer, [Event.t()], Context.clock()) ::
          {Database.t(), counts}
  def sync(db, cal_id, events, clock) do
    cal = db.calendars[cal_id]
    today = Context.today(clock)
    limit = Date.add(today, cal.ahead_days)
    active = events |> Enum.reject(&(&1.status == :cancelled)) |> Enum.uniq_by(& &1.uid)
    uids = MapSet.new(active, & &1.uid)

    {db, snaps, counts} =
      Enum.reduce(active, {db, cal.events, %{added: 0, updated: 0, removed: 0}}, fn event, acc ->
        apply_event(acc, cal, event, today, limit, clock)
      end)

    {db, snaps, counts} =
      Enum.reduce(snaps, {db, snaps, counts}, fn {uid, snap}, {db, snaps, counts} ->
        cond do
          MapSet.member?(uids, uid) ->
            {db, snaps, counts}

          Map.has_key?(db.items, snap.item) ->
            {Core.discard_item(db, snap.item), Map.delete(snaps, uid), bump(counts, :removed)}

          true ->
            {db, Map.delete(snaps, uid), counts}
        end
      end)

    cal = %{db.calendars[cal_id] | events: snaps, refreshed_at: Context.now(clock), error: nil}
    {%{db | calendars: Map.put(db.calendars, cal_id, cal)}, counts}
  end

  defp apply_event({db, snaps, counts}, cal, event, today, limit, clock) do
    occurrence = Calendar.occurrence(event, today)
    text = if String.trim(event.summary) == "", do: "(no title)", else: event.summary
    wanted = %{summary: text, description: event.description || ""}

    case {snaps[event.uid], occurrence} do
      {nil, :ended} ->
        {db, snaps, counts}

      {nil, {date, time, rec}} ->
        if Date.compare(date, today) == :lt or Date.compare(date, limit) == :gt do
          {db, snaps, counts}
        else
          {db, id} = Core.add_item(db, text, clock, section: cal.category_id)

          db =
            if wanted.description != "",
              do: Core.set_note(db, id, wanted.description, clock),
              else: db

          db = set_when(db, id, date, time, rec, clock)
          snap = Map.merge(wanted, %{item: id, date: date, time: time, recurrence: rec})
          {db, Map.put(snaps, event.uid, snap), bump(counts, :added)}
        end

      {snap, _} ->
        update(db, snaps, counts, event.uid, snap, wanted, occurrence, clock)
    end
  end

  # Only what the calendar changed since the last refresh reaches the item.
  defp update(db, snaps, counts, uid, snap, wanted, occurrence, clock) do
    when_now =
      case occurrence do
        {date, time, rec} -> %{date: date, time: time, recurrence: rec}
        :ended -> Map.take(snap, [:date, :time, :recurrence])
      end

    id = snap.item

    if Map.has_key?(db.items, id) do
      changes = [
        {wanted.summary != snap.summary, &Core.edit_item(&1, id, wanted.summary, clock)},
        {wanted.description != snap.description,
         &Core.set_note(&1, id, wanted.description, clock)},
        {when_now != Map.take(snap, [:date, :time, :recurrence]),
         &set_when(&1, id, when_now.date, when_now.time, when_now.recurrence, clock)}
      ]

      changed = for {true, change} <- changes, do: change
      db = Enum.reduce(changed, db, fn change, db -> change.(db) end)
      counts = if changed == [], do: counts, else: bump(counts, :updated)
      {db, Map.put(snaps, uid, Map.merge(snap, Map.merge(wanted, when_now))), counts}
    else
      # discarded by the person: remembered, never brought back
      {db, Map.put(snaps, uid, Map.merge(snap, Map.merge(wanted, when_now))), counts}
    end
  end

  # The When date as set by hand, then its time and rule.
  defp set_when(db, id, date, time, rec, clock) do
    db
    |> Core.set_date(id, db.special.when, date, clock)
    |> Database.update_item(id, &%{&1 | when_time: time, recurrence: rec})
  end

  defp bump(counts, key), do: Map.update!(counts, key, &(&1 + 1))
end
