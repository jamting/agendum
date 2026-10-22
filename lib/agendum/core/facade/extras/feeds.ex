defmodule Agendum.Core.Facade.Extras.Feeds do
  @moduledoc """
  Feed subscriptions (R75): subscribing to an RSS or Atom feed, applying
  its entries to the file (`Agendum.Core.Extras.FeedSync`), when to read it
  again, and feed lists as OPML. Like calendar subscriptions (R45).

  Called through `Agendum.Core`.
  """

  alias Agendum.Core.Database
  alias Agendum.Core.Extras.{Feed, FeedParser, Xml}
  alias Agendum.Core.Facade.{Categories, Changes, Items}
  alias Agendum.Core.View.{Column, SortKey}

  @typep db :: Agendum.Core.db()
  @typep id :: Agendum.Core.id()
  @typep clock :: Agendum.Core.clock()

  @feeds "Feeds"
  @news "News"

  @doc """
  Subscribes to a feed: its entries will become items in Feeds ▸ `name`
  (both made when missing, without name matching). The first feed also
  makes the News view: a section per feed, newest first, done items
  hidden; each later feed gets its section there.
  """
  @spec subscribe_feed(db, String.t(), String.t()) ::
          {:ok, db, id} | {:error, :no_name | :bad_url}
  def subscribe_feed(db, name, url) do
    name = String.trim(name)

    with {:name, true} <- {:name, name != ""},
         {:ok, url} <- Feed.normalize_url(url) do
      {db, parent} = category(db, db.main_id, @feeds)
      {db, category} = category(db, parent, name)
      {db, id} = Database.add_feed(db, %Feed{name: name, url: url, category_id: category})
      {:ok, news(db, category), id}
    else
      {:name, false} -> {:error, :no_name}
      :error -> {:error, :bad_url}
    end
  end

  # the child of that name, or a new one
  defp category(db, parent, name) do
    wanted = Database.normalize(name)

    case Enum.find(
           db.categories[parent].children,
           &(Database.normalize(db.categories[&1].name) == wanted)
         ) do
      nil ->
        {:ok, db, id} = Categories.add_category(db, parent, name, match_name: false)
        {db, id}

      id ->
        {db, id}
    end
  end

  # The News view, made with the first feed: newest first by Entry date,
  # which a column shows, done items hidden
  defp news(db, category) do
    case Enum.find(Database.views(db), &(&1.name == @news)) do
      nil ->
        entry = db.special.entry

        {db, view} =
          Database.insert_view(db, @news,
            sections: [category],
            columns: [%Column{category_id: entry, width: 16}]
          )

        sort = [%SortKey{on: {:category, entry}, order: :desc}]
        Database.update_view(db, view, &%{&1 | hide_done: true, sort: sort})

      view ->
        if Enum.any?(view.sections, &(&1.category_id == category)),
          do: db,
          else:
            Agendum.Core.Facade.Views.add_section(db, view.id, category, length(view.sections))
    end
  end

  @doc "Ends a subscription; with `remove_items`, its items are discarded too."
  @spec unsubscribe_feed(db, id, boolean) :: db
  def unsubscribe_feed(db, feed_id, remove_items) do
    items =
      if remove_items,
        do: for({_, %{item: id}} <- db.feeds[feed_id].entries, id != nil, do: id),
        else: []

    items
    |> Enum.filter(&Map.has_key?(db.items, &1))
    |> Enum.reduce(db, &Items.discard_item(&2, &1))
    |> Database.delete_feed(feed_id)
  end

  @doc """
  Applies a feed's entries, read from it, to the file (`FeedSync`): new
  entries become items, changed ones update them, old ones fade. Returns
  how many of each.
  """
  @spec sync_feed(db, id, [FeedParser.entry()], clock) ::
          {:ok, db, Agendum.Core.Extras.FeedSync.counts()} | {:error, :unknown_feed}
  def sync_feed(db, feed_id, entries, clock) do
    if Map.has_key?(db.feeds, feed_id) do
      {db, counts} = Agendum.Core.Extras.FeedSync.sync(db, feed_id, entries, clock)
      {:ok, db, counts}
    else
      {:error, :unknown_feed}
    end
  end

  @doc "Remembers that reading a feed failed, so it is not retried at once."
  @spec feed_failed(db, id, String.t(), clock) :: db
  def feed_failed(db, feed_id, message, clock) do
    if Map.has_key?(db.feeds, feed_id),
      do:
        Database.update_feed(
          db,
          feed_id,
          &%{&1 | error: message, refreshed_at: Changes.now_of(clock)}
        ),
      else: db
  end

  @doc "The next or previous choice for how often a feed is read, or how long entries stay."
  @spec cycle_feed_setting(db, id, :refresh_minutes | :keep_days, 1 | -1) :: db
  def cycle_feed_setting(db, feed_id, setting, step),
    do: Database.update_feed(db, feed_id, &Feed.cycle(&1, setting, step))

  @doc "The feeds due to be read again at `now`."
  @spec feeds_due(db, NaiveDateTime.t()) :: [Feed.t()]
  def feeds_due(db, now), do: db |> Database.feeds() |> Enum.filter(&Feed.due?(&1, now))

  @doc "A feed read from the web: its entries, or `{:error, :not_a_feed}` (`FeedParser`)."
  @spec parse_feed(String.t()) ::
          {:ok, %{title: String.t(), entries: [FeedParser.entry()]}} | {:error, :not_a_feed}
  def parse_feed(text), do: FeedParser.parse(text)

  # --- OPML ---------------------------------------------------------------------------

  @doc "The file's feeds as OPML 2.0, the feed list other readers read."
  @spec export_opml(db) :: String.t()
  def export_opml(db) do
    outlines =
      Enum.map_join(Database.feeds(db), "", fn feed ->
        name = attr(feed.name)
        ~s(    <outline type="rss" text="#{name}" title="#{name}" xmlUrl="#{attr(feed.url)}"/>\n)
      end)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <opml version="2.0">
      <head>
        <title>Feeds from Wol's Agendum</title>
      </head>
      <body>
    #{outlines}  </body>
    </opml>
    """
  end

  @doc """
  Subscribes to every feed in an OPML feed list that the file does not
  have yet (by address); folders in the list are read through. Returns how
  many were added, or `{:error, :not_opml}`.
  """
  @spec import_opml(db, String.t()) :: {:ok, db, [id]} | {:error, :not_opml}
  def import_opml(db, text) do
    root = text |> Xml.parse() |> Xml.elements() |> List.first()

    if root && Xml.local(elem(root, 0)) == "opml" do
      have = MapSet.new(Database.feeds(db), & &1.url)

      {db, added} =
        root
        |> outlines()
        |> Enum.uniq_by(& &1.url)
        |> Enum.reduce({db, []}, fn %{url: url, name: name}, {db, added} ->
          with false <- MapSet.member?(have, url),
               {:ok, db, id} <- subscribe_feed(db, name, url) do
            {db, [id | added]}
          else
            _ -> {db, added}
          end
        end)

      {:ok, db, Enum.reverse(added)}
    else
      {:error, :not_opml}
    end
  end

  # every outline with a feed address, at any depth
  defp outlines(node) do
    Enum.flat_map(Xml.elements(node), fn {name, attrs, _} = child ->
      found =
        case {Xml.local(name), attrs["xmlUrl"] || attrs["xmlurl"]} do
          {"outline", url} when is_binary(url) ->
            title = attrs["title"] || attrs["text"] || url
            [%{url: String.trim(url), name: title}]

          _ ->
            []
        end

      found ++ outlines(child)
    end)
  end

  defp attr(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
end
