# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Facade.Extras.Publishing do
  @moduledoc """
  The micro-blog (R74): its settings, its posts, and the site made from
  them (`Agendum.Core.Extras.Blog`, `Agendum.Core.Extras.Site`). The shell writes and
  uploads the site (`Agendum.Extras.Publish`).

  Called through `Agendum.Core`.
  """

  alias Agendum.Core.Database
  alias Agendum.Core.Context
  alias Agendum.Core.Extras.{Address, Blog, BlogFeed, Ingested, Markdown, Site}
  alias Agendum.Core.Facade.Categories
  alias Agendum.Core.Facade.Extras.Zettels

  @typep db :: Agendum.Core.db()
  @typep id :: Agendum.Core.id()

  @typedoc """
  Settings to change: any of `Agendum.Core.Extras.Blog`'s fields, the
  posts, drafts and pages categories given by id or by name
  (`{:name, "Posts"}`, made under MAIN when there is none of that name;
  `{:name, ""}` or nil for no drafts or pages).
  """
  @type changes :: %{optional(atom) => term}

  # the folder and the upload are the person's since format 47 (in their
  # preferences, `Agendum.Core.Extras.Upload`): given here, they are ignored
  @text_fields ~w(title description author language base_url me address)a

  @doc "Changes the blog's settings (see `t:changes/0`)."
  @spec set_blog(db, changes) ::
          {:ok, db}
          | {:error, :bad_setting | :bad_address | :no_posts_category | :ambiguous | :ingested}
  def set_blog(db, changes) do
    # `with` runs each step while it matches; an `{:error, _}` stops it
    with {:ok, db, posts} <- category(db, Map.get(changes, :posts, db.blog.posts)),
         {:ok, db, drafts} <- category(db, Map.get(changes, :drafts, db.blog.drafts)),
         {:ok, db, pages} <- category(db, Map.get(changes, :pages, db.blog.pages)),
         {:ok, settings} <- settings(changes) do
      cond do
        posts == nil ->
          {:error, :no_posts_category}

        # a feed's or a calendar's category (R75a) is never the blog's:
        # drafts are filed by hand, which it refuses, and its items are
        # other people's writing (the owner, 2026-10-27)
        Enum.any?([posts, drafts, pages], &(&1 && Ingested.ingested?(db, &1))) ->
          {:error, :ingested}

        # three different categories, Pages and Drafts each optional, none
        # inside another: an item in a category is in its parents too, so
        # Pages above Posts would take every post (code review 2026-11-02)
        tangled?(db, [posts, drafts, pages]) ->
          {:error, :bad_setting}

        # each post must be able to have an address of its own, inside the
        # site (`Agendum.Core.Extras.Address`)
        Map.has_key?(settings, :address) and not Address.valid?(settings.address) ->
          {:error, :bad_address}

        true ->
          {:ok,
           %{
             db
             | blog:
                 struct(
                   db.blog,
                   Map.merge(settings, %{posts: posts, drafts: drafts, pages: pages})
                 )
           }}
      end
    end
  end

  # two of the categories the same, or one above another
  defp tangled?(db, ids) do
    set = ids |> Enum.reject(&is_nil/1) |> Enum.with_index()

    Enum.any?(
      for {a, i} <- set, {b, j} <- set, i != j, do: a == b or a in Database.ancestors(db, b)
    )
  end

  # a category by id, or by name: the first of that name, else a new one
  defp category(db, nil), do: {:ok, db, nil}
  defp category(db, {:name, name}) when is_binary(name), do: named(db, String.trim(name))
  defp category(db, id) when is_integer(id) and is_map_key(db.categories, id), do: {:ok, db, id}
  defp category(_db, _other), do: {:error, :bad_setting}

  defp named(db, ""), do: {:ok, db, nil}

  defp named(db, name) do
    # the person's categories only: not MAIN or a date category, nor a
    # feed's or a calendar's (R75a)
    mine = &(not Database.protected?(db, &1) and not Ingested.ingested?(db, &1))

    case Enum.filter(Database.find_categories(db, name), mine) do
      [id] ->
        {:ok, db, id}

      # two of that name: which is meant cannot be told
      [_, _ | _] ->
        {:error, :ambiguous}

      [] ->
        case Categories.add_category(db, db.main_id, name) do
          {:ok, db, id} -> {:ok, db, id}
          {:error, _} -> {:error, :bad_setting}
        end
    end
  end

  defp settings(changes) do
    fields = Map.take(changes, @text_fields)
    valid = Enum.all?(fields, fn {_text, value} -> is_binary(value) end)

    if valid,
      do:
        {:ok,
         Map.new(fields, fn {k, v} -> {k, if(is_binary(v), do: String.trim(v), else: v)} end)},
      else: {:error, :bad_setting}
  end

  @doc """
  Publish, the part in the file before the preview (R74): the settings are
  kept, and each post without a Zettel id is given one (R73). Returns the
  ids given, `{item, word}`.
  """
  @spec prepare_publish(db, changes) ::
          {:ok, db, [{id, String.t()}]}
          | {:error,
             :bad_setting
             | :bad_address
             | :no_posts_category
             | :zettels_full
             | :ambiguous
             | :ingested}
  def prepare_publish(db, changes) do
    with {:ok, db} <- set_blog(db, changes) do
      # pages too: a page whose title gives no slug has its Zettel id
      ids = for item <- Blog.posts(db) ++ Blog.pages(db), item.zettel == nil, do: item.id
      Zettels.attach_zettels(db, ids)
    end
  end

  @doc """
  The blog's own feeds on `today` (R74, § 9): one for each child category
  of Posts, with its title, description, folder and posts
  (`Agendum.Core.Extras.Blog.feeds/3`).
  """
  @spec blog_feeds(db, Date.t()) :: [Blog.feed()]
  def blog_feeds(db, today), do: Site.feeds(db, today)

  @doc """
  Changes a feed's settings (Extras ▸ Publish ▸ Feeds): its `title`
  (the category's own name, or empty, follows the category when it is
  renamed), `description` and `slug`, its folder on the site (a–z, 0–9
  and `-`; `""` to make it from the name at the next publish). A folder
  set takes its place before one made from a name. Refused for a category
  that is not a child of Posts, and for a folder the site or another of
  today's feeds has set.
  """
  @spec set_blog_feed(db, id, %{optional(atom) => String.t()}) ::
          {:ok, db} | {:error, :not_a_feed | :bad_slug | :bad_setting}
  def set_blog_feed(db, id, changes) do
    changes = Map.take(changes, [:title, :description, :slug])

    cond do
      db.blog.posts == nil or id not in db.categories[db.blog.posts].children ->
        {:error, :not_a_feed}

      not Enum.all?(Map.values(changes), &is_binary/1) ->
        {:error, :bad_setting}

      true ->
        changes = Map.new(changes, fn {k, v} -> {k, String.trim(v)} end)
        put_feed(db, id, changes)
    end
  end

  defp put_feed(db, id, changes) do
    settings = struct(Map.get(db.blog.feeds, id, %BlogFeed{}), changes)
    # the category's own name is no title of its own: a rename follows
    settings =
      if settings.title == db.categories[id].name, do: %{settings | title: ""}, else: settings

    siblings = db.categories[db.blog.posts].children -- [id]
    others = for {other, %{slug: slug}} <- db.blog.feeds, other in siblings, slug != "", do: slug

    if settings.slug == "" or
         (BlogFeed.slug?(settings.slug) and settings.slug not in elem(Site.own(), 1) and
            settings.slug not in others),
       do: {:ok, put_in(db.blog.feeds[id], settings)},
       else: {:error, :bad_slug}
  end

  @doc "What a line of a note is, as Markdown (R64h; `Agendum.Core.Extras.Markdown.line/1`)."
  @spec markdown_line(String.t()) :: Markdown.line()
  def markdown_line(text), do: Markdown.line(text)

  @doc "What ENTER at the end of a note's line starts the next with (R64h)."
  @spec markdown_continue(String.t()) :: {:continue, String.t()} | {:end, String.t()} | :none
  def markdown_continue(text), do: Markdown.continue(text)

  @doc """
  A note's line with its task box ticked or unticked (R64h), with where the
  change begins; nil for a line that is no list item.
  """
  @spec markdown_toggle(String.t()) :: {String.t(), non_neg_integer} | nil
  def markdown_toggle(text), do: Markdown.toggle(text)

  @doc "The rows of a note inside a code block, where Markdown is only text (R64h)."
  @spec markdown_code_rows([String.t()]) :: MapSet.t(non_neg_integer)
  def markdown_code_rows(lines), do: Markdown.code_rows(lines)

  @doc "How many pages the site has on `today` (R74)."
  @spec blog_page_count(db, Date.t()) :: non_neg_integer
  def blog_page_count(db, today), do: db |> Blog.pages(today) |> Enum.count(& &1.zettel)

  @doc """
  Published, on the clock's day (R74): each post's record kept as the
  site was built (its address the first time, a modified date when it
  changed since; `Agendum.Core.Extras.Site.record/2`). Only once the
  person publishes, so a preview left with ESC records nothing.
  """
  @spec record_published(db, Agendum.Core.clock()) :: db
  def record_published(db, clock), do: Site.record(db, Context.today(clock))

  @doc "How many posts the site has on `today`: those due, with a Zettel id (R74)."
  @spec blog_post_count(db, Date.t()) :: non_neg_integer
  def blog_post_count(db, today), do: db |> Blog.posts(today) |> Enum.count(& &1.zettel)

  @doc "The address pattern a new blog has: `posts/{zettel}.html` (R74)."
  @spec blog_address_default() :: String.t()
  def blog_address_default, do: Address.default()

  @doc """
  The posts and pages whose date (When, else Entry) is still to come on
  `today`, the soonest first, each with that date (R74).
  """
  @spec blog_waiting(db, Date.t()) :: [{Agendum.Core.Item.t(), Date.t()}]
  def blog_waiting(db, today),
    do: for(item <- Blog.waiting(db, today), do: {item, Blog.date(item)})

  @doc """
  An older file's blog upload settings (format 46 and before kept them in
  the file; `Blog.moved_upload`), for the person's preferences (R74);
  nil when it had none. Never written: the file's next save leaves them
  out.
  """
  @spec moved_upload(db) :: Agendum.Core.Extras.Upload.t() | nil
  def moved_upload(db), do: db.blog.moved_upload

  @doc "The ways of uploading the blog, in the order they are offered (R74)."
  @spec upload_methods() :: [Agendum.Core.Extras.Upload.method()]
  def upload_methods, do: Agendum.Core.Extras.Upload.methods()

  @doc "The posts, newest first (`Agendum.Core.Extras.Blog.posts/1`)."
  @spec blog_posts(db) :: [Agendum.Core.Item.t()]
  def blog_posts(db), do: Blog.posts(db)

  @doc """
  Whether the blog has no Base address (R74): the site is still written,
  but the feeds' links are not whole addresses, which feed readers need.
  False for a file without a blog (no posts category set).
  """
  @spec blog_needs_base_url?(db) :: boolean
  def blog_needs_base_url?(db), do: db.blog.posts != nil and db.blog.base_url == ""

  @doc """
  Every file of the site on `today`, `{path, content}`
  (`Agendum.Core.Extras.Site.build/2`): the posts due then.
  """
  @spec site(db, Date.t()) :: [Site.file()]
  def site(db, today), do: Site.build(db, today)

  @doc """
  Every file of the site on `today`, made from what its folder holds: its
  templates and assets (`Agendum.Core.Extras.Site.build/3`); or why not, a
  template's mistake with where it is.
  """
  @spec site(db, Date.t(), Site.inputs()) :: {:ok, [Site.file()]} | {:error, Site.error()}
  def site(db, today, inputs), do: Site.build(db, today, inputs)

  @doc "The templates Agendum writes into a site's folder where one is missing (R74)."
  @spec site_default_templates() :: [Site.file()]
  def site_default_templates, do: Site.default_templates()

  @doc "What writing the site would change in a folder (`Agendum.Core.Extras.Site.changes/3`)."
  @spec site_changes([Site.file()], %{optional(String.t()) => String.t()}, [String.t()]) ::
          Site.changes()
  def site_changes(files, existing, published), do: Site.changes(files, existing, published)
end
