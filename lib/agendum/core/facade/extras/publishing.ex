defmodule Agendum.Core.Facade.Extras.Publishing do
  @moduledoc """
  The micro-blog (R74): its settings, its posts, and the site made from
  them (`Agendum.Core.Extras.Blog`, `Agendum.Core.Extras.Site`). The shell writes and
  uploads the site (`Agendum.Extras.Publish`).

  Called through `Agendum.Core`.
  """

  alias Agendum.Core.Database
  alias Agendum.Core.Extras.{Blog, Site}
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

  @text_fields ~w(title description author language base_url me folder target user remote_dir)a

  @doc "Changes the blog's settings (see `t:changes/0`)."
  @spec set_blog(db, changes) :: {:ok, db} | {:error, :bad_setting | :no_posts_category}
  def set_blog(db, changes) do
    # `with` runs each step while it matches; an `{:error, _}` stops it
    with {:ok, db, posts} <- category(db, Map.get(changes, :posts, db.blog.posts)),
         {:ok, db, drafts} <- category(db, Map.get(changes, :drafts, db.blog.drafts)),
         {:ok, settings} <- settings(changes) do
      cond do
        posts == nil ->
          {:error, :no_posts_category}

        drafts == posts ->
          {:error, :bad_setting}

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
    case Enum.reject(Database.find_categories(db, name), &Database.protected?(db, &1)) do
      [id | _] ->
        {:ok, db, id}

      [] ->
        case Categories.add_category(db, db.main_id, name) do
          {:ok, db, id} -> {:ok, db, id}
          {:error, _} -> {:error, :bad_setting}
        end
    end
  end

  defp settings(changes) do
    fields = Map.take(changes, [:upload | @text_fields])

    valid =
      Enum.all?(fields, fn
        {:upload, upload} -> upload in Blog.uploads()
        {_text, value} -> is_binary(value)
      end)

    if valid,
      do:
        {:ok,
         Map.new(fields, fn {k, v} -> {k, if(is_binary(v), do: String.trim(v), else: v)} end)},
      else: {:error, :bad_setting}
  end

  @doc """
  Publish, the part in the file (R74): the settings are kept, and each
  post without a Zettel id is given one, for its page's address (R73).
  Returns the ids given, `{item, word}`.
  """
  @spec prepare_publish(db, changes) ::
          {:ok, db, [{id, String.t()}]}
          | {:error, :bad_setting | :no_posts_category | :zettels_full}
  def prepare_publish(db, changes) do
    with {:ok, db} <- set_blog(db, changes) do
      ids = for item <- Blog.posts(db), item.zettel == nil, do: item.id
      Zettels.attach_zettels(db, ids)
    end
  end

  @doc "The posts, newest first (`Agendum.Core.Extras.Blog.posts/1`)."
  @spec blog_posts(db) :: [Agendum.Core.Item.t()]
  def blog_posts(db), do: Blog.posts(db)

  @doc "Every file of the site, `{path, content}` (`Agendum.Core.Extras.Site.build/1`)."
  @spec site(db) :: [Site.file()]
  def site(db), do: Site.build(db)

  @doc "What writing the site would change in a folder (`Agendum.Core.Extras.Site.changes/3`)."
  @spec site_changes([Site.file()], %{optional(String.t()) => String.t()}, [String.t()]) ::
          Site.changes()
  def site_changes(files, existing, published), do: Site.changes(files, existing, published)
end
