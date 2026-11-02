# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.SiteFeedsTest do
  @moduledoc """
  The blog's own feeds (R74; plans/PUBLISHER.md step 5, meeting
  2026-11-02-1255, §§ 9–10): each child category of Posts is a feed, with
  its own index page and feeds in its folder; the site's main index and
  feeds keep every post, and the main index names the feeds.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.Extras.Site

  @today ~D[2026-11-02]

  setup do
    db = Core.new_file()
    {:ok, db, posts} = Core.add_category(db, db.main_id, "Posts")
    {:ok, db, devlog} = Core.add_category(db, posts, "Devlog")
    {:ok, db, links} = Core.add_category(db, posts, "Links")
    {:ok, db, releases} = Core.add_category(db, devlog, "Releases")
    {db, a} = Core.add_item(db, "Built the importer", ~D[2026-10-01], section: devlog)
    {db, _} = Core.add_item(db, "v0.80 is out", ~D[2026-10-02], section: releases)
    {db, _} = Core.add_item(db, "A good read", ~D[2026-10-03], section: links)
    {db, _} = Core.add_item(db, "Plain post", ~D[2026-10-04], section: posts)

    {:ok, db} =
      Core.set_blog(db, %{posts: posts, title: "Owl's Notes", base_url: "https://owl.example/"})

    {:ok, db, _} = Core.prepare_publish(db, %{})
    %{db: db, posts: posts, devlog: devlog, links: links, releases: releases, a: a}
  end

  defp file(files, path), do: files |> List.keyfind(path, 0) |> elem(1)

  test "each child of Posts is a feed, its folder from its name; a grandchild is not", %{db: db} do
    feeds = Core.blog_feeds(db, @today)
    assert Enum.map(feeds, & &1.slug) == ["devlog", "links"]
    devlog = hd(feeds)
    # a post in Releases is in Devlog's feed, under it
    assert Enum.map(devlog.posts, & &1.text) == ["v0.80 is out", "Built the importer"]
  end

  test "a feed has its own index page, RSS and JSON Feed; the main ones keep every post",
       %{db: db} do
    files = Core.site(db, @today)
    index = file(files, "devlog/index.html")
    assert index =~ ~s(<h1 class="p-name">Devlog</h1>)
    assert index =~ "Built the importer"
    refute index =~ "A good read"
    assert index =~ ~s(href="../style.css")

    rss = file(files, "devlog/rss.xml")
    assert rss =~ "<title>Owl&apos;s Notes · Devlog</title>"
    assert rss =~ ~s(href="https://owl.example/devlog/rss.xml")
    refute rss =~ "A good read"

    assert file(files, "devlog/feed.json") =~
             ~s("feed_url":"https://owl.example/devlog/feed.json")

    for post <- ["Built the importer", "A good read", "Plain post"],
        do: assert(file(files, "rss.xml") =~ post)
  end

  test "the main index names the feeds", %{db: db} do
    assert file(Core.site(db, @today), "index.html") =~
             ~s(<p class="feeds">Feeds: <a href="devlog/index.html">Devlog</a>) <>
               ~s( · <a href="links/index.html">Links</a></p>)
  end

  test "a feed's settings: title, description, folder; the folder moves it", ctx do
    {:ok, db} =
      Core.set_blog_feed(ctx.db, ctx.devlog, %{
        title: "Workshop",
        description: "How it is made",
        slug: "workshop"
      })

    files = Core.site(db, @today)
    refute List.keymember?(files, "devlog/index.html", 0)
    assert file(files, "workshop/index.html") =~ "How it is made"
    assert file(files, "index.html") =~ ~s(<a href="workshop/index.html">Workshop</a>)
  end

  test "the folder is made at the first publish and kept, the category renamed", ctx do
    db = Core.record_published(ctx.db, @today)
    assert db.blog.feeds[ctx.devlog].slug == "devlog"
    {:ok, db} = Core.rename_category(db, ctx.devlog, "Building")
    assert List.keymember?(Core.site(db, @today), "devlog/index.html", 0)
  end

  test "a folder that is not plain, the site's own, or another feed's is refused", ctx do
    for bad <- ["Dev log", "../x", "fonts", "assets", ""] |> Enum.drop(-1) do
      assert {:error, :bad_slug} = Core.set_blog_feed(ctx.db, ctx.devlog, %{slug: bad}), bad
    end

    {:ok, db} = Core.set_blog_feed(ctx.db, ctx.links, %{slug: "notes"})
    assert {:error, :bad_slug} = Core.set_blog_feed(db, ctx.devlog, %{slug: "notes"})
    assert {:error, :not_a_feed} = Core.set_blog_feed(db, ctx.releases, %{title: "x"})
  end

  test "a post's address never lands in a feed's folder", ctx do
    {:ok, db} = Core.set_blog(ctx.db, %{address: "{slug}/index.html"})
    db = Core.set_note(db, ctx.a, "# Devlog\nx", @today)
    paths = for {path, _} <- Core.site(db, @today), do: path
    assert Enum.count(paths, &(&1 == "devlog/index.html")) == 1
    assert "devlog/index-2.html" in paths
  end

  test "an index.html still as Agendum 0.81 wrote it is replaced" do
    old = File.read!("lib/agendum/core/extras/site_assets/templates/index-0.81.html")
    assert Site.legacy_template?("templates/index.html", old)
  end

  test "a file's feed folder that is not plain is refused on reading", ctx do
    {:ok, db} = Core.set_blog_feed(ctx.db, ctx.devlog, %{slug: "devlog"})
    crafted = put_in(db.blog.feeds[ctx.devlog].slug, "../../x")
    assert {:error, message} = Core.JSONFile.decode(Core.JSONFile.encode(crafted))
    assert message =~ "not a feed's folder"
  end

  describe "found in review" do
    test "a long name's folder with -2 still fits, and the file opens again", ctx do
      long = String.duplicate("a", 70)
      {:ok, db} = Core.rename_category(ctx.db, ctx.devlog, long)
      {:ok, db} = Core.rename_category(db, ctx.links, long <> "b")
      db = Core.record_published(db, @today)
      slugs = for feed <- Core.blog_feeds(db, @today), do: feed.slug
      assert Enum.all?(slugs, &(String.length(&1) <= 60))
      assert {:ok, _} = Core.JSONFile.decode(Core.JSONFile.encode(db))
    end

    test "a discarded feed's settings go, and a new feed of its name can be kept", ctx do
      db = Core.record_published(ctx.db, @today)
      {:ok, db} = Core.discard_category(db, ctx.devlog)
      refute Map.has_key?(db.blog.feeds, ctx.devlog)
      {:ok, db, again} = Core.add_category(db, ctx.posts, "Devlog")
      feed = Enum.find(Core.blog_feeds(db, @today), &(&1.category == again))
      assert {:ok, _} = Core.set_blog_feed(db, again, %{slug: feed.slug, description: "x"})
    end

    test "a folder set wins over one made from another feed's name", ctx do
      {:ok, db} = Core.set_blog_feed(ctx.db, ctx.links, %{slug: "devlog"})
      slugs = Map.new(Core.blog_feeds(db, @today), &{&1.category, &1.slug})
      assert slugs[ctx.links] == "devlog"
      assert slugs[ctx.devlog] == "devlog-2"
    end

    test "an index template written before feeds still links posts from a feed's page", ctx do
      old = File.read!("lib/agendum/core/extras/site_assets/templates/index-0.81.html")

      {:ok, files} =
        Core.site(ctx.db, @today, %{templates: %{"index" => old}, assets: []})

      page = file(files, "devlog/index.html")
      assert page =~ ~s(<a class="u-url" href="../posts/)
      refute page =~ ~s(<a class="u-url" href="posts/)
    end

    test "a feed named Posts leaves the posts' own folder to them", ctx do
      {:ok, db} = Core.set_blog_feed(ctx.db, ctx.devlog, %{slug: "posts"})
      paths = for {path, _} <- Core.site(db, @today), do: path
      refute Enum.any?(paths, &String.starts_with?(&1, "posts-2/"))
      assert "posts/index.html" in paths
    end

    test "a crafted folder in the file is not used when building", ctx do
      db = ctx.db
      crafted = put_in(db.blog.feeds[ctx.devlog], %Agendum.Core.Extras.BlogFeed{slug: "../x"})
      refute Enum.any?(Core.site(crafted, @today), &(elem(&1, 0) =~ ".."))
    end

    test "the category's own name as a title follows a rename", ctx do
      {:ok, db} = Core.set_blog_feed(ctx.db, ctx.devlog, %{title: "Devlog"})
      assert db.blog.feeds[ctx.devlog].title == ""
    end
  end
end
