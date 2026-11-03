# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.SiteTest do
  @moduledoc "The micro-blog: its settings, its posts and the site (R74)."
  use ExUnit.Case, async: true

  import Agendum.Fixtures
  alias Agendum.Core
  alias Agendum.Core.{Database, Invariants, JSONFile}

  # Posts: "Hello, Wood" (2026-10-01) with a note, "Honey report"
  # (2026-10-05, a draft), "Party" (2026-10-03) linking to Hello; and
  # "Shopping", not a post
  setup do
    db = Core.new_file()

    {:ok, db} =
      Core.set_blog(db, %{
        posts: {:name, "Posts"},
        drafts: {:name, "Draft"},
        title: "Owl's Notes",
        author: "Owl",
        base_url: "https://owl.example",
        me: "https://mastodon.example/@owl"
      })

    posts = cat(db, "Posts")
    {db, hello} = Core.add_item(db, "Hello, Wood", ~D[2026-10-01], section: posts)
    db = Core.set_note(db, hello, "First *post*.\n\n- [x] write it\n- [ ] publish it", today())
    {db, honey} = Core.add_item(db, "Honey report", ~D[2026-10-05], section: posts)
    db = Core.assign(db, honey, cat(db, "Draft"))
    {db, party} = Core.add_item(db, "Party", ~D[2026-10-03], section: posts)
    {db, shopping} = Core.add_item(db, "Shopping", ~D[2026-10-04])
    %{db: db, hello: hello, honey: honey, party: party, shopping: shopping}
  end

  defp file(files, path), do: files |> List.keyfind(path, 0) |> elem(1)

  test "set_blog makes the posts and drafts categories when there are none", %{db: db} do
    assert db.blog.posts == cat(db, "Posts")
    assert db.blog.drafts == cat(db, "Draft")
    assert db.blog.title == "Owl's Notes"
    assert {:error, :bad_setting} = Core.set_blog(db, %{title: :carrier_pigeon})
    # the folder and the upload are the person's since format 47: ignored
    assert {:ok, ^db} = Core.set_blog(db, %{upload: :sftp, folder: "elsewhere"})
    assert {:error, :no_posts_category} = Core.set_blog(Core.new_file(), %{title: "x"})
  end

  test "an existing category of that name is used, not made again", %{db: db} do
    {:ok, again} = Core.set_blog(db, %{posts: {:name, "posts"}})
    assert again.categories == db.categories
  end

  test "the posts: in Posts, not drafts, newest first", ctx do
    assert Enum.map(Core.blog_posts(ctx.db), & &1.id) == [ctx.party, ctx.hello]
  end

  test "prepare_publish gives each post a Zettel id, once", ctx do
    assert {:ok, db, given} = Core.prepare_publish(ctx.db, %{})
    assert given == [{ctx.party, "bonalaku"}, {ctx.hello, "pigavono"}]
    assert db.items[ctx.shopping].zettel == nil
    assert {:ok, ^db, []} = Core.prepare_publish(db, %{})
    assert Invariants.violations(db) == []
  end

  describe "the site" do
    setup ctx do
      {:ok, db, _} = Core.prepare_publish(ctx.db, %{})
      db = Core.set_note(db, ctx.party, "After [[pigavono]]; not [[kitolido]].", today())
      %{db: db, files: Core.site(db, ~D[2026-11-02])}
    end

    test "its files: index, feeds, stylesheet, 404 page, fonts and a page per post", %{
      files: files
    } do
      fonts =
        ~w(fonts/alegreya-latin-wght-normal.woff2 fonts/alegreya-latin-wght-italic.woff2
           fonts/alegreya-sc-latin-400-normal.woff2 fonts/alegreya-sc-latin-500-normal.woff2
           fonts/inconsolata-latin-400-normal.woff2 fonts/inconsolata-latin-700-normal.woff2
           fonts/courier-prime-latin-400-normal.woff2 fonts/OFL.txt)

      assert Enum.map(files, &elem(&1, 0)) ==
               ~w(index.html rss.xml feed.json style.css 404.html posts/bonalaku.html
                  posts/pigavono.html) ++
                 fonts
    end

    test "the index shows the posts, newest first, as h-entries", %{files: files} do
      index = file(files, "index.html")
      assert index =~ ~s(<main class="h-feed">)
      assert index =~ ~s(<a class="u-url" href="posts/bonalaku.html">Party</a>)
      [party, hello] = Regex.scan(~r/<article class="h-entry card"/, index)
      assert party == hello
      {party_at, _} = :binary.match(index, "Party")
      {hello_at, _} = :binary.match(index, "Hello, Wood")
      assert party_at < hello_at
      refute index =~ "Honey report"
      refute index =~ "Shopping"
      assert index =~ ~s(<link rel="me" href="https://mastodon.example/@owl">)
    end

    test "a post's page: content as HTML, links to other posts, the tasks", %{files: files} do
      party = file(files, "posts/bonalaku.html")
      assert party =~ ~s(<link rel="stylesheet" href="../style.css">)

      assert party =~
               ~s(After <a href="../posts/pigavono.html">Hello, Wood</a>; not [[kitolido]].)

      assert party =~ ~s(<time class="dt-published" datetime="2026-10-03">)
      assert party =~ ~s(href="https://owl.example/posts/bonalaku.html">permalink</a>)

      hello = file(files, "posts/pigavono.html")
      assert hello =~ "First <em>post</em>."
      assert hello =~ ~s(<li class="done"><span class="box">[x]</span> write it</li>)
    end

    test "the RSS feed: whole addresses, dates, the content escaped", %{files: files} do
      rss = file(files, "rss.xml")
      assert rss =~ ~s(<?xml version="1.0" encoding="UTF-8"?>)
      assert rss =~ "<link>https://owl.example/</link>"
      assert rss =~ "<guid isPermaLink=\"true\">https://owl.example/posts/bonalaku.html</guid>"
      assert rss =~ "<pubDate>Sat, 03 Oct 2026 00:00:00 +0000</pubDate>"
      assert rss =~ "&lt;a href=&quot;https://owl.example/posts/pigavono.html&quot;&gt;"
    end

    test "the JSON Feed is JSON, with its keys in order", %{files: files} do
      json = file(files, "feed.json")
      assert {:ok, feed} = JSON.decode(json)
      assert feed["version"] == "https://jsonfeed.org/version/1.1"

      assert [%{"title" => "Party", "date_published" => "2026-10-03T00:00:00Z"}, _] =
               feed["items"]

      assert String.starts_with?(json, ~s({"version":))
    end

    test "building twice gives the same files", %{db: db, files: files} do
      assert Core.site(db, ~D[2026-11-02]) == files
    end

    # without a Base address there is nowhere to link the author to, and a
    # post's own page links to itself by its file name
    test "without a Base address: the author unlinked, the permalink relative", %{db: db} do
      {:ok, db} = Core.set_blog(db, %{base_url: ""})
      files = Core.site(db, ~D[2026-11-02])
      index = file(files, "index.html")
      party = file(files, "posts/bonalaku.html")

      refute index =~ ~s(href="")
      refute party =~ ~s(href="")
      assert index =~ ~s(<span class="p-name">Owl</span>)
      assert party =~ ~s(<span class="p-author h-card">Owl</span>)
      assert party =~ ~s(<a class="u-url" href="bonalaku.html">permalink</a>)
      assert Core.blog_needs_base_url?(db)
      refute Core.blog_needs_base_url?(Core.new_file())
    end
  end

  test "changes: added, changed and removed, the person's stylesheet never changed", ctx do
    files = [{"index.html", "new"}, {"style.css", "ours"}, {"posts/a.html", "a"}]
    existing = %{"index.html" => "old", "style.css" => "theirs", "posts/b.html" => "b"}

    assert Core.site_changes(files, existing, ["index.html", "posts/b.html"]) ==
             %{added: ["posts/a.html"], changed: ["index.html"], removed: ["posts/b.html"]}

    _ = ctx
  end

  test "a discarded posts category leaves the blog without one", %{db: db} do
    {:ok, db} = Core.discard_category(db, cat(db, "Posts"))
    assert db.blog.posts == nil
    assert Invariants.violations(db) == []
  end

  test "the blog goes through JSON and back", %{db: db} do
    assert {:ok, read} = db |> JSONFile.encode() |> JSONFile.decode()
    assert read.blog == db.blog
    assert %Database{} = read
  end
end
