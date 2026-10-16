defmodule Agendum.Core.FeedSync do
  @moduledoc """
  Applies a feed's entries to the file (R75), as `Agendum.Core.CalendarSync`
  does a calendar's events:

    * an entry not seen before, published within the feed's keep days,
      becomes an item in the feed's category: its title the item text, its
      summary (plain text) and its link the note, its publish date the
      Entry date. Text matching, conditions and actions file it as a typed
      item, but dates in a title are not read as its When date: news is
      not a to-do
    * an entry seen before updates its item where the feed changed it and
      the person did not
    * an entry older than the keep days **fades**: its item is discarded,
      unless the person kept it, by giving it a Zettel id (R73), changing
      its text or note, or giving it a category by hand. Done does not
      keep: it only dismisses
    * an entry whose item faded or that the person discarded keeps its
      snapshot (without an item), so it is never brought back; the
      snapshot goes once the feed no longer has the entry

  Pure.
  """

  alias Agendum.Core
  alias Agendum.Core.{Assign, Context, Database, Feed, FeedParser}
  alias Agendum.Core.Facade.Changes

  @type counts :: %{added: non_neg_integer, updated: non_neg_integer, faded: non_neg_integer}

  # the most of a summary an item's note takes
  @summary_room 2_000

  @spec sync(Database.t(), pos_integer, [FeedParser.entry()], Context.clock()) ::
          {Database.t(), counts}
  def sync(db, feed_id, entries, clock) do
    feed = db.feeds[feed_id]
    today = Context.today(clock)
    cutoff = feed.keep_days && Date.add(today, -feed.keep_days)
    entries = Enum.uniq_by(entries, & &1.id)
    ids = MapSet.new(entries, & &1.id)

    # the entries the person discarded lose their items
    snaps =
      Map.new(feed.entries, fn {id, snap} ->
        if snap.item && not Map.has_key?(db.items, snap.item),
          do: {id, %{snap | item: nil}},
          else: {id, snap}
      end)

    {db, snaps, counts} =
      Enum.reduce(entries, {db, snaps, %{added: 0, updated: 0, faded: 0}}, fn entry, acc ->
        apply_entry(acc, feed, entry, today, cutoff, clock)
      end)

    {db, snaps, counts} = fade(db, snaps, counts, feed, cutoff)

    # a snapshot without an item goes once the feed no longer has it
    snaps =
      Map.reject(snaps, fn {id, snap} -> snap.item == nil and not MapSet.member?(ids, id) end)

    feed = %{db.feeds[feed_id] | entries: snaps, refreshed_at: Context.now(clock), error: nil}
    {%{db | feeds: Map.put(db.feeds, feed_id, feed)}, counts}
  end

  defp apply_entry({db, snaps, counts}, feed, entry, today, cutoff, clock) do
    published = if entry.published, do: NaiveDateTime.to_date(entry.published), else: today
    wanted = %{title: entry.title, note: note(entry), link: entry.link, published: published}

    case snaps[entry.id] do
      nil ->
        if cutoff && Date.compare(published, cutoff) == :lt do
          # already past its days when first seen: remembered, not added
          {db, Map.put(snaps, entry.id, Map.put(wanted, :item, nil)), counts}
        else
          {db, item} = add(db, feed, wanted, clock)
          {db, Map.put(snaps, entry.id, Map.put(wanted, :item, item)), bump(counts, :added)}
        end

      %{item: nil} ->
        {db, snaps, counts}

      snap ->
        {db, changed?} = update(db, snap, wanted, clock)
        snap = Map.merge(snap, wanted)

        {db, Map.put(snaps, entry.id, snap),
         if(changed?, do: bump(counts, :updated), else: counts)}
    end
  end

  # The item for a new entry, through the same rules as a typed item
  # (`Items.add_item/4`) but without reading dates from its title
  defp add(db, feed, wanted, clock) do
    before = db
    {db, id} = Database.insert_item(db, wanted.title, wanted.published)

    db =
      db
      |> Database.update_item(id, &%{&1 | note: wanted.note})
      |> Changes.user_assign(id, feed.category_id)
      |> Assign.auto_assign(id, [])
      |> Changes.settle(before, id, clock)

    {db, id}
  end

  # Only what the feed changed, and only where the item still says what the
  # feed said before: the person's edits stay
  defp update(db, snap, wanted, clock) do
    item = db.items[snap.item]

    {db, title?} =
      if wanted.title != snap.title and item.text == snap.title,
        do: {retitle(db, snap.item, wanted.title, clock), true},
        else: {db, false}

    {db, note?} =
      if wanted.note != snap.note and db.items[snap.item].note == snap.note,
        do: {Database.update_item(db, snap.item, &%{&1 | note: wanted.note}), true},
        else: {db, false}

    {db, title? or note?}
  end

  # a new title is filed again by what it says, its dates not read
  defp retitle(db, id, title, clock) do
    before = db

    db
    |> Database.update_item(id, &%{&1 | text: title})
    |> Assign.auto_assign(id, [])
    |> Changes.settle(before, id, clock)
  end

  defp fade(db, snaps, counts, %Feed{keep_days: nil}, _cutoff), do: {db, snaps, counts}

  defp fade(db, snaps, counts, feed, cutoff) do
    Enum.reduce(snaps, {db, snaps, counts}, fn {id, snap}, {db, snaps, counts} ->
      if snap.item != nil and Date.compare(snap.published, cutoff) == :lt and
           not kept?(db, snap, feed) do
        {Core.discard_item(db, snap.item), Map.put(snaps, id, %{snap | item: nil}),
         bump(counts, :faded)}
      else
        {db, snaps, counts}
      end
    end)
  end

  @doc """
  Whether the person kept an entry's item, so it does not fade: it has a
  Zettel id, its text or note is no longer what the feed wrote, or it is
  in a category given by hand (not by text matching or a condition).
  """
  @spec kept?(Database.t(), Feed.snapshot(), Feed.t()) :: boolean
  def kept?(db, snap, feed) do
    item = db.items[snap.item]

    by_hand =
      db
      |> Database.explicit_categories(item.id)
      |> Enum.reject(&(&1 == feed.category_id or MapSet.member?(db.conditional, {item.id, &1})))

    item.zettel != nil or item.text != snap.title or item.note != snap.note or by_hand != []
  end

  @doc "An entry's note: its summary, at most about 2,000 characters, then its link."
  @spec note(FeedParser.entry()) :: String.t()
  def note(entry) do
    summary =
      if String.length(entry.summary) > @summary_room,
        do: String.slice(entry.summary, 0, @summary_room) <> " …",
        else: entry.summary

    [summary, entry.link] |> Enum.reject(&(&1 == "")) |> Enum.join("\n\n")
  end

  defp bump(counts, key), do: Map.update!(counts, key, &(&1 + 1))
end
