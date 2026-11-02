# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.Blog do
  @moduledoc """
  The file's micro-blog (R74): which items are its posts and what the site
  says about itself (Extras ▸ Publish ▸ Site). Kept in the file
  (`Database.blog`), so the blog goes with its posts. Where the site is
  written and how it is uploaded are the person's, kept in their
  preferences (`Agendum.Core.Extras.Upload`; format 47).

    * `posts`: the category whose items are the posts; `drafts`: the
      category that keeps a post out until it is ready (nil: none)
    * `title`, `description`, `author`, `language` (`"en"`, `"sv"` …):
      what the pages and feeds say about the blog
    * `base_url`: where the site is on the web (`https://example.com/`),
      for the feeds' links, which must be whole addresses
    * `me`: addresses of the person's other profiles, for `rel="me"`
      links (a fediverse account, micro.blog), separated by spaces
    * `moved_upload`: the upload settings an older file kept here (format
      46 and before), on their way to the person's preferences; never
      written (`Agendum.Store` leaves it out)
  """

  alias Agendum.Core.Database

  @type t :: %__MODULE__{
          posts: Database.id() | nil,
          drafts: Database.id() | nil,
          title: String.t(),
          description: String.t(),
          author: String.t(),
          language: String.t(),
          base_url: String.t(),
          me: String.t(),
          moved_upload: Agendum.Core.Extras.Upload.t() | nil
        }

  defstruct posts: nil,
            drafts: nil,
            title: "",
            description: "",
            author: "",
            language: "en",
            base_url: "",
            me: "",
            moved_upload: nil

  @doc """
  The posts, newest first: the items in the posts category (or under it),
  not in the drafts category. A post's date is its When date, else its
  Entry date; posts of one day come newest made first.
  """
  @spec posts(Database.t()) :: [Agendum.Core.Item.t()]
  def posts(%Database{blog: %__MODULE__{posts: nil}}), do: []

  def posts(%Database{blog: blog} = db) do
    db
    |> Database.items()
    |> Enum.filter(&Database.member?(db, &1.id, blog.posts))
    |> Enum.reject(&(blog.drafts && Database.member?(db, &1.id, blog.drafts)))
    # Domain: a `Date` is a struct (a map), and maps compare by their
    # keys, not as dates; `Date.to_erl/1` gives `{year, month, day}`, which
    # compares as dates do. With the id after it, posts of one day come
    # newest made first; `&>=/2` sorts descending.
    |> Enum.sort_by(&{sortable(date(&1)), &1.id}, &>=/2)
  end

  @doc "A post's date: When, else Entry (nil only for an item with neither)."
  @spec date(Agendum.Core.Item.t()) :: Date.t() | nil
  def date(item), do: item.when || item.entry

  defp sortable(nil), do: {0, 0, 0}
  defp sortable(date), do: Date.to_erl(date)
end
