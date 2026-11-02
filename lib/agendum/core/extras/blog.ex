# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.Blog do
  @moduledoc """
  The file's micro-blog (R74): which items are its posts and what the site
  says about itself (Extras ▸ Publish ▸ Site). Kept in the file
  (`Database.blog`), so the blog goes with its posts. Where the site is
  written and how it is uploaded are the person's, kept in their
  preferences (`Agendum.Core.Extras.Upload`; format 47).

    * `posts`: the category whose items are the posts; `drafts`: the
      category that keeps a post out until it is ready (nil: none);
      `pages`: the category whose items are pages, such as About, outside
      the index and the feeds (nil: none; format 49)
    * `title`, `description`, `author`, `language` (`"en"`, `"sv"` …):
      what the pages and feeds say about the blog
    * `base_url`: where the site is on the web (`https://example.com/`),
      for the feeds' links, which must be whole addresses
    * `me`: addresses of the person's other profiles, for `rel="me"`
      links (a fediverse account, micro.blog), separated by spaces
    * `address`: where a post's page goes, a pattern such as
      `posts/{zettel}.html` (`Agendum.Core.Extras.Address`)
    * `published`: what publishing remembers of each post, by the item's
      id: its address, a fingerprint, the day it was found changed
      (`Agendum.Core.Extras.PostRecord`; format 48)
    * `moved_upload`: the upload settings an older file kept here (format
      46 and before), on their way to the person's preferences; never
      written (`Agendum.Store` leaves it out)
  """

  alias Agendum.Core.Database
  alias Agendum.Core.Extras.{Address, Fingerprint, PostRecord}

  @type t :: %__MODULE__{
          posts: Database.id() | nil,
          drafts: Database.id() | nil,
          pages: Database.id() | nil,
          title: String.t(),
          description: String.t(),
          author: String.t(),
          language: String.t(),
          base_url: String.t(),
          me: String.t(),
          address: String.t(),
          published: %{optional(Database.id()) => PostRecord.t()},
          moved_upload: Agendum.Core.Extras.Upload.t() | nil
        }

  defstruct posts: nil,
            drafts: nil,
            pages: nil,
            title: "",
            description: "",
            author: "",
            language: "en",
            base_url: "",
            me: "",
            address: "posts/{zettel}.html",
            published: %{},
            moved_upload: nil

  @doc """
  The posts, newest first: the items in the posts category (or under it),
  not in the drafts category, nor in the pages category (an item in both
  is a page). A post's date is its When date, else its
  Entry date; posts of one day come newest made first.
  """
  @spec posts(Database.t()) :: [Agendum.Core.Item.t()]
  def posts(%Database{blog: %__MODULE__{posts: nil}}), do: []

  def posts(%Database{blog: blog} = db) do
    db
    |> Database.items()
    |> Enum.filter(&Database.member?(db, &1.id, blog.posts))
    # not a draft; and an item in Pages too is a page, not a post (the
    # owner, 2026-11-02)
    |> Enum.reject(&(in?(db, &1, blog.drafts) or in?(db, &1, blog.pages)))
    # Domain: a `Date` is a struct (a map), and maps compare by their
    # keys, not as dates; `Date.to_erl/1` gives `{year, month, day}`, which
    # compares as dates do. With the id after it, posts of one day come
    # newest made first; `&>=/2` sorts descending.
    |> Enum.sort_by(&{sortable(date(&1)), &1.id}, &>=/2)
  end

  @doc """
  The posts due on `today`, newest first: those whose date (When, else
  Entry) is not after it; a post with a When still to come waits for its
  day (meeting 2026-11-02-1255, § 6).
  """
  @spec posts(Database.t(), Date.t()) :: [Agendum.Core.Item.t()]
  def posts(db, today), do: Enum.filter(posts(db), &due?(&1, today))

  @doc """
  The pages due on `today` (R74; meeting 2026-11-02-1255, § 8): the items
  in the pages category (or under it), not in the drafts category, a When
  still to come waiting as a post's does; by title, A to Z.
  """
  @spec pages(Database.t(), Date.t()) :: [Agendum.Core.Item.t()]
  def pages(db, today), do: Enum.filter(pages(db), &due?(&1, today))

  @doc "Every page, due or not, by title A to Z."
  @spec pages(Database.t()) :: [Agendum.Core.Item.t()]
  def pages(%Database{blog: %__MODULE__{pages: nil}}), do: []

  def pages(%Database{blog: blog} = db) do
    db
    |> Database.items()
    |> Enum.filter(&Database.member?(db, &1.id, blog.pages))
    |> Enum.reject(&in?(db, &1, blog.drafts))
    |> Enum.sort_by(&{alphabetical(title(&1), blog.language), &1.id})
  end

  @doc "The posts and pages still waiting for their day on `today`, the soonest first."
  @spec waiting(Database.t(), Date.t()) :: [Agendum.Core.Item.t()]
  def waiting(db, today) do
    (posts(db) ++ pages(db))
    |> Enum.reject(&due?(&1, today))
    |> Enum.sort_by(&{sortable(date(&1)), &1.id})
  end

  defp due?(item, today), do: date(item) == nil or Date.compare(date(item), today) != :gt

  @doc """
  A post's title: a note whose first line is a `# Heading` gives that
  heading (`##` and later lines do not count); else the item's text. The
  heading stays in the note's body too (the owner's choice, 2026-11-02).
  """
  # Domain: `%{text: …}` in a spec would mean a map with only those keys;
  # `optional(atom) => term` lets an item (or any map holding them) in
  @spec title(%{:text => String.t(), :note => String.t(), optional(atom) => term}) ::
          String.t()
  def title(%{text: text, note: note}) do
    first = note |> String.split("\n", parts: 2) |> hd()

    case Regex.run(~r/^#[ \t]+(\S.*)$/u, first) do
      [_, heading] -> String.trim(heading)
      nil -> text
    end
  end

  @doc "What publishing remembers of the post `id` (`PostRecord`), or nil before its first time."
  @spec record(Database.t(), Database.id()) :: PostRecord.t() | nil
  def record(db, id), do: Map.get(db.blog.published, id)

  @doc """
  Publishing on `today`: each post and page due gets its record, the first time an
  address from the Site's pattern (unique among all addresses made, never
  one of the site's own files and folders, `own`), and later a modified
  date when its title, note or date changed since. Posts without a Zettel
  id are left out (Publish gives them one first). The site is built from
  the records this would make; they are kept once the person publishes.
  """
  @spec record_posts(Database.t(), Date.t(), {[String.t()], [String.t()]}) :: Database.t()
  def record_posts(db, today, own) do
    blog = db.blog
    taken = MapSet.new(Map.values(blog.published), & &1.path)

    # posts by the Site's pattern (oldest first, so the first of two posts
    # with one slug keeps it), then pages at the top, by their slug
    posts = db |> posts(today) |> Enum.reverse() |> Enum.map(&{&1, blog.address})
    pages = db |> pages(today) |> Enum.map(&{&1, "{slug}.html"})

    # `{published, taken}` is carried through: a new address joins `taken`
    # at once, so it is built once, not once per post
    {published, _taken} =
      (posts ++ pages)
      |> Enum.filter(fn {item, _pattern} -> item.zettel end)
      |> Enum.reduce({blog.published, taken}, fn {item, pattern}, {published, taken} ->
        print = print(item)

        case published[item.id] do
          nil ->
            date = date(item) || today
            word = Agendum.Core.Facade.Extras.Zettels.zettel(item)
            path = Address.path(pattern, title(item), word, date, taken, own)
            record = %PostRecord{path: path, print: print}
            {Map.put(published, item.id, record), MapSet.put(taken, path)}

          %PostRecord{print: ^print} ->
            {published, taken}

          record ->
            {Map.put(published, item.id, %{record | print: print, modified: today}), taken}
        end
      end)

    %{db | blog: %{blog | published: published}}
  end

  @doc """
  A file from before format 48 kept no records, but its posts with a Zettel
  id may be out already, at `posts/<zettel id>.html`: each gets a record
  there, so a new address pattern never moves them.
  """
  @spec seed_records(Database.t()) :: Database.t()
  def seed_records(db) do
    published =
      for item <- posts(db), item.zettel, into: db.blog.published do
        word = Agendum.Core.Facade.Extras.Zettels.zettel(item)
        {item.id, %PostRecord{path: "posts/#{word}.html", print: print(item)}}
      end

    %{db | blog: %{db.blog | published: published}}
  end

  # what a reader sees of a post, as one number: its title, note and date
  defp print(item),
    do: Fingerprint.of(Enum.join([title(item), item.note, inspect(date(item))], "\0"))

  # Domain: A to Z as the blog's language has it. Swedish puts å ä ö
  # after z, in that order ({ | } come after z in ASCII); elsewhere an
  # accent is dropped, so é sorts as e
  defp alphabetical(title, language) do
    text = String.downcase(title)

    text =
      if String.starts_with?(language, "sv"),
        do:
          text |> String.replace("å", "{") |> String.replace("ä", "|") |> String.replace("ö", "}"),
        else: text

    text |> :unicode.characters_to_nfd_binary() |> String.replace(~r/\p{Mn}/u, "")
  end

  defp in?(_db, _item, nil), do: false
  defp in?(db, item, category), do: Database.member?(db, item.id, category)

  @doc "A post's date: When, else Entry (nil only for an item with neither)."
  @spec date(Agendum.Core.Item.t()) :: Date.t() | nil
  def date(item), do: item.when || item.entry

  defp sortable(nil), do: {0, 0, 0}
  defp sortable(date), do: Date.to_erl(date)
end
