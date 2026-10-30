# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.BlogIngestedTest do
  @moduledoc """
  The blog's Posts and Drafts are the person's categories, never a feed's
  or a calendar's (R74, R75a; the owner, 2026-10-27): an ingested Drafts
  could not be filed into by hand, and an ingested Posts would publish
  other people's writing.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core

  setup do
    db = Core.new_file()
    {:ok, db, feed} = Core.subscribe_feed(db, "Heffalump News", "https://h.example/rss")
    %{db: db, news: db.feeds[feed].category_id}
  end

  test "an ingested category is refused as posts or drafts", %{db: db, news: news} do
    assert {:error, :ingested} = Core.prepare_publish(db, %{posts: news})
    {:ok, db, mine} = Core.add_category(db, db.main_id, "Posts")
    assert {:error, :ingested} = Core.prepare_publish(db, %{posts: mine, drafts: news})
  end

  test "a name is looked up among the person's categories only", %{db: db} do
    # the feed's category is the only one called Heffalump News: the
    # blog gets a category of the person's of that name instead
    {:ok, db, _} = Core.prepare_publish(db, %{posts: {:name, "Heffalump News"}})
    posts = db.blog.posts
    refute Core.ingested?(db, posts)
    assert db.categories[posts].name == "Heffalump News"
  end
end
