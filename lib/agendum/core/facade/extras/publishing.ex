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
  alias Agendum.Core.Extras.{Address, Blog, Ingested, Site}
  alias Agendum.Core.Facade.Categories
  alias Agendum.Core.Facade.Extras.Zettels

  @typep db :: Agendum.Core.db()
  @typep id :: Agendum.Core.id()

  @typedoc """
  Settings to change: any of `Agendum.Core.Extras.Blog`'s fields, the posts and
  drafts categories given by id or by name (`{:name, "Posts"}`, made
  under MAIN when there is none of that name; `""` for no drafts).
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
         {:ok, settings} <- settings(changes) do
      cond do
        posts == nil ->
          {:error, :no_posts_category}

        # a feed's or a calendar's category (R75a) is never the blog's:
        # drafts are filed by hand, which it refuses, and its items are
        # other people's writing (the owner, 2026-10-27)
        Enum.any?([posts, drafts], &(&1 && Ingested.ingested?(db, &1))) ->
          {:error, :ingested}

        drafts == posts ->
          {:error, :bad_setting}

        # each post must be able to have an address of its own, inside the
        # site (`Agendum.Core.Extras.Address`)
        Map.has_key?(settings, :address) and not Address.valid?(settings.address) ->
          {:error, :bad_address}

        true ->
          {:ok,
           %{db | blog: struct(db.blog, Map.merge(settings, %{posts: posts, drafts: drafts}))}}
      end
    end
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
      ids = for item <- Blog.posts(db), item.zettel == nil, do: item.id
      Zettels.attach_zettels(db, ids)
    end
  end

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
  The posts whose date (When, else Entry) is still to come on `today`,
  the soonest first, each with that date (R74).
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

  @doc "What writing the site would change in a folder (`Agendum.Core.Extras.Site.changes/3`)."
  @spec site_changes([Site.file()], %{optional(String.t()) => String.t()}, [String.t()]) ::
          Site.changes()
  def site_changes(files, existing, published), do: Site.changes(files, existing, published)
end
