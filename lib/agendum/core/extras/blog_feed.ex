# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.BlogFeed do
  @moduledoc """
  One of the blog's own feeds (R74; meeting 2026-11-02-1255, § 9): each
  child category of the Posts category is a feed, with its own index page
  and its own RSS and JSON Feed under `/<slug>/`; the site's main index and
  feeds keep every post. Its settings are kept in the file with the blog
  (`Agendum.Core.Extras.Blog.feeds`, by the category's id), changed in
  Extras ▸ Publish ▸ Feeds:

    * `title`: the feed's name on its page and in its feeds; empty: the
      category's name
    * `description`: a line about it, on its page and in its feeds
    * `slug`: its folder on the site, a–z, 0–9 and `-`; empty until the
      first publish makes it from the name, then kept until the person
      changes it (and then the feed moves; the owner's choice, 2026-11-02)
  """

  @type t :: %__MODULE__{title: String.t(), description: String.t(), slug: String.t()}
  defstruct title: "", description: "", slug: ""

  @doc "Whether `slug` can be a feed's folder: a–z, 0–9 and `-`, not empty, at most 60."
  @spec slug?(term) :: boolean
  def slug?(slug) when is_binary(slug),
    do: Regex.match?(~r/^[a-z0-9]+(-[a-z0-9]+)*$/, slug) and String.length(slug) <= 60

  def slug?(_slug), do: false
end
