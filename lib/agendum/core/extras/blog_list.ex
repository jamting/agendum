# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.BlogList do
  @moduledoc """
  One of the blog's lists (R74e; meeting 2026-11-02-2244, § 6, the owner's
  choices of 2026-11-03): any of the person's own categories, its items
  handed to the site's templates, which decide what it becomes (a blog
  stream, a page of co-workers, a gym table). Kept in the file with the
  blog (`Agendum.Core.Extras.Blog.lists`, by the category's id; format 51),
  changed in Extras ▸ Publish ▸ Lists:

    * `title`: the list's name on its page and in its feeds; empty: the
      category's name
    * `description`: a line about it, on its page and in its feeds
    * `slug`: its folder on the site, a–z, 0–9 and `-`; empty until the
      first publish makes it from the name, then kept until the person
      changes it (and then the list moves)
    * `index`, `feeds`, `item_pages`: whether it has an index page, an RSS
      feed and a JSON Feed, and a page per item; a new list has only its
      index page (the owner, 2026-11-03: as little as possible goes out
      until the person says so)
    * `tag_pages`: whether each child of its category gets a page of its
      items (a Tags family: a page per tag), and an item's page its tags
      (format 53)
    * `notes`: whether its items' notes are published, as their bodies
    * `newest`: how many items its index and feeds carry, the newest; nil
      for the Site's number, 0 for all; past them, an archive (format 52)
    * `fields`: the categories (families) whose values a template sees,
      by id, in order; nothing else of an item leaves the file
    * `address`: where an item's page goes, a pattern as the posts' is
      (`Agendum.Core.Extras.Address`); empty: `<folder>/{zettel}.html`
  """

  @type t :: %__MODULE__{
          title: String.t(),
          description: String.t(),
          slug: String.t(),
          index: boolean,
          feeds: boolean,
          item_pages: boolean,
          tag_pages: boolean,
          notes: boolean,
          newest: non_neg_integer | nil,
          fields: [pos_integer],
          address: String.t()
        }

  defstruct title: "",
            description: "",
            slug: "",
            index: true,
            feeds: false,
            item_pages: false,
            tag_pages: false,
            notes: false,
            newest: nil,
            fields: [],
            address: ""

  @doc """
  A list kept from a feed of format 50 (each child category of Posts was
  one, with an index page, feeds and its posts' notes): everything on, so
  the site does not change (meeting 2026-11-02-2244, § 6).
  """
  @spec from_feed(term) :: t
  def from_feed(feed) do
    # a crafted file's feed that is no map gives the defaults
    feed = if is_map(feed), do: feed, else: %{}

    %__MODULE__{
      title: Map.get(feed, :title, ""),
      description: Map.get(feed, :description, ""),
      slug: Map.get(feed, :slug, ""),
      index: true,
      feeds: true,
      item_pages: true,
      notes: true
    }
  end

  @doc "Whether `slug` can be a list's folder: a–z, 0–9 and `-`, not empty, at most 60."
  @spec slug?(term) :: boolean
  def slug?(slug) when is_binary(slug),
    do: Regex.match?(~r/^[a-z0-9]+(-[a-z0-9]+)*$/, slug) and String.length(slug) <= 60

  def slug?(_slug), do: false

  @doc "The address pattern of its item pages: its own, else `<folder>/{zettel}.html`."
  @spec address(t, String.t()) :: String.t()
  def address(%__MODULE__{address: ""}, slug), do: slug <> "/{zettel}.html"
  def address(%__MODULE__{address: address}, _slug), do: address
end
