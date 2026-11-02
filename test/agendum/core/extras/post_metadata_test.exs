# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.PostMetadataTest do
  @moduledoc """
  A post's metadata (R74; plans/PUBLISHER.md step 2, meeting
  2026-11-02-1255, § 6): the title from a note's first-line `# Heading`, a
  future When held back until its day, the modified date stamped when
  publishing finds a post changed, and its address made once from the
  Site's address pattern.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.Extras.{Address, Blog}

  @today ~D[2026-11-02]

  setup do
    db = Core.new_file()
    {:ok, db, posts} = Core.add_category(db, db.main_id, "Posts")
    {db, hello} = Core.add_item(db, "Hello", ~D[2026-10-01], section: posts)

    db =
      Core.set_note(db, hello, "# Reverse engineering .AG\nIt started with a hex dump.", @today)

    {db, plain} = Core.add_item(db, "Plain post", ~D[2026-10-02], section: posts)
    {:ok, db} = Core.set_blog(db, %{posts: posts, title: "Owl's Notes"})
    %{db: db, hello: hello, plain: plain, posts: posts}
  end

  defp file(files, path), do: files |> List.keyfind(path, 0) |> elem(1)

  # Publish, then ENTER on the preview: the records are kept then
  defp publish(db, today \\ @today) do
    {:ok, db, _} = Core.prepare_publish(db, %{})
    Core.record_published(db, today)
  end

  describe "the title" do
    test "a note's first-line # heading is the title; the heading stays in the body", ctx do
      db = publish(ctx.db)
      files = Core.site(db, @today)
      page = file(files, Blog.record(db, ctx.hello).path)
      assert page =~ ~s(<h1 class="p-name">Reverse engineering .AG</h1>)
      assert page =~ "<title>Reverse engineering .AG · Owl's Notes</title>"
      # kept in the body too (the owner's choice, 2026-11-02)
      assert page =~ ~r/<div class="e-content">\s*<h1>Reverse engineering .AG<\/h1>/
      assert file(files, "rss.xml") =~ "<title>Reverse engineering .AG</title>"
    end

    test "without one the item's text is the title; ## or a later line does not count" do
      assert Blog.title(%{text: "Plain post", note: ""}) == "Plain post"
      assert Blog.title(%{text: "T", note: "## Sub\nx"}) == "T"
      assert Blog.title(%{text: "T", note: "intro\n# Later"}) == "T"
      assert Blog.title(%{text: "T", note: "#   Spaced  \nx"}) == "Spaced"
    end
  end

  describe "a future When" do
    test "waits until its day, and is listed as waiting", ctx do
      db = Core.set_date(ctx.db, ctx.plain, ctx.db.special.when, ~D[2026-11-05])
      db = publish(db)
      refute Enum.any?(Core.site(db, @today), &(elem(&1, 0) =~ "plain"))
      assert [{%{id: id}, ~D[2026-11-05]}] = Core.blog_waiting(db, @today)
      assert id == ctx.plain
      assert Blog.record(db, ctx.plain) == nil

      # on its day it goes out
      db = publish(db, ~D[2026-11-05])
      assert Blog.record(db, ctx.plain)
      assert Core.blog_waiting(db, ~D[2026-11-05]) == []
    end
  end

  describe "the modified date" do
    test "none at first; stamped when a later publish finds the post changed", ctx do
      db = publish(ctx.db)
      assert Blog.record(db, ctx.hello).modified == nil
      refute file(Core.site(db, @today), Blog.record(db, ctx.hello).path) =~ "Updated"

      # unchanged: nothing stamped
      assert publish(db, ~D[2026-11-03]) == db

      db = Core.set_note(db, ctx.hello, "# Reverse engineering .AG\nNow with pictures.", @today)
      db = publish(db, ~D[2026-11-04])
      assert Blog.record(db, ctx.hello).modified == ~D[2026-11-04]

      files = Core.site(db, ~D[2026-11-04])
      assert file(files, Blog.record(db, ctx.hello).path) =~ ~s(datetime="2026-11-04">)
      assert file(files, Blog.record(db, ctx.hello).path) =~ "Updated"
      assert file(files, "feed.json") =~ ~s("date_modified":"2026-11-04T00:00:00Z")
    end
  end

  describe "the address" do
    test "by default posts/<zettel id>.html, as before", ctx do
      db = publish(ctx.db)
      assert Blog.record(db, ctx.hello).path == "posts/#{Core.zettel(db.items[ctx.hello])}.html"
    end

    test "a date-and-slug pattern makes the slug from the title, once", ctx do
      {:ok, db} = Core.set_blog(ctx.db, %{address: "{year}/{month}/{day}-{slug}.html"})
      db = publish(db)
      assert Blog.record(db, ctx.hello).path == "2026/10/01-reverse-engineering-ag.html"
      assert Blog.record(db, ctx.plain).path == "2026/10/02-plain-post.html"

      # a new title, or a new pattern, never moves a published post
      db = Core.set_note(db, ctx.hello, "# Something else\nx", @today)
      {:ok, db} = Core.set_blog(db, %{address: "posts/{zettel}.html"})
      db = publish(db)
      assert Blog.record(db, ctx.hello).path == "2026/10/01-reverse-engineering-ag.html"

      files = Core.site(db, @today)
      page = file(files, "2026/10/01-reverse-engineering-ag.html")
      # the page's links reach the root three folders up
      assert page =~ ~s(href="../../style.css")
      assert file(files, "index.html") =~ ~s(href="2026/10/01-reverse-engineering-ag.html")
    end

    test "two posts with one slug get their own addresses", ctx do
      {:ok, db} = Core.set_blog(ctx.db, %{address: "{slug}.html"})
      db = Core.set_note(db, ctx.plain, "# Reverse engineering .AG\n", @today)
      db = publish(db)
      paths = [Blog.record(db, ctx.hello).path, Blog.record(db, ctx.plain).path]
      assert Enum.sort(paths) == ["reverse-engineering-ag-2.html", "reverse-engineering-ag.html"]
    end

    test "a slug never takes the site's own files' names", ctx do
      {:ok, db} = Core.set_blog(ctx.db, %{address: "{slug}.html"})
      db = Core.set_note(db, ctx.plain, "# Index\n", @today)
      db = publish(db)
      assert Blog.record(db, ctx.plain).path == "index-2.html"
    end

    test "slugs fold Swedish letters and accents, and keep to a-z 0-9 -" do
      assert Address.slug("Räksmörgås på Åland — del 2!") == "raksmorgas-pa-aland-del-2"
      assert Address.slug("Ünïcödé café") == "unicode-cafe"
      assert Address.slug("!!!") == ""
      assert String.length(Address.slug(String.duplicate("long word ", 20))) <= 60
    end

    test "a pattern that cannot give each post its own address is refused", %{db: db} do
      for bad <- [
            "posts/{year}.html",
            "posts/{zettel}.htm",
            "../{zettel}.html",
            "/abs/{zettel}.html",
            "posts/{zettel}/{nope}.html",
            ""
          ] do
        assert {:error, :bad_address} = Core.set_blog(db, %{address: bad}), bad
      end

      assert {:ok, _} = Core.set_blog(db, %{address: "notes/{year}-{slug}.html"})
    end
  end

  describe "found in review" do
    @own Agendum.Core.Extras.Site.own()

    test "an address in the site's own fonts folder takes another folder, and ends" do
      path = Address.path("{slug}/{zettel}.html", "Fonts", "bonalaku", @today, MapSet.new(), @own)
      assert path == "fonts-2/bonalaku.html"

      assert Address.path("fonts/{zettel}.html", "x", "bonalaku", @today, MapSet.new(), @own) ==
               "fonts-2/bonalaku.html"
    end

    test "characters with a meaning in a web address are refused in a pattern" do
      for bad <- ["a#b/{slug}.html", "my posts/{slug}.html", "a?b/{slug}.html", "%20/{slug}.html"] do
        refute Address.valid?(bad), bad
      end
    end

    test "a file whose stored address leads out of the site is refused on reading", ctx do
      db = publish(ctx.db)
      record = %{Blog.record(db, ctx.hello) | path: "../../.zshrc.html"}
      crafted = put_in(db.blog.published[ctx.hello], record)

      assert {:error, message} =
               Agendum.Core.JSONFile.decode(Agendum.Core.JSONFile.encode(crafted))

      assert message =~ "not a safe address"

      # and the site never writes it, should one get through
      refute Enum.any?(Core.site(crafted, @today), &(elem(&1, 0) =~ ".."))
    end

    test "nothing is recorded until the person publishes: ESC on the preview keeps none", ctx do
      {:ok, db, _} = Core.prepare_publish(ctx.db, %{})
      assert db.blog.published == %{}
      # the site shows the addresses the records would have
      {:ok, dated} = Core.set_blog(db, %{address: "{slug}.html"})
      assert List.keymember?(Core.site(dated, @today), "reverse-engineering-ag.html", 0)
    end

    test "posts out before format 48 keep posts/<zettel id>.html when the pattern changes",
         ctx do
      # a blog as format 47 saved it: posts with Zettel ids, no records
      {:ok, db, _} = Core.prepare_publish(ctx.db, %{})
      old_blog = db.blog |> Map.from_struct() |> Map.delete(:published)
      old = %{db | blog: Map.put(old_blog, :__struct__, Blog)}

      db = Agendum.Store.upgrade(old)
      ids = for item <- Core.blog_posts(db), item.zettel, do: item.id
      assert length(ids) == 2

      {:ok, db} = Core.set_blog(db, %{address: "{year}/{slug}.html"})
      db = Core.record_published(db, @today)

      for id <- ids,
          do: assert(Blog.record(db, id).path == "posts/#{Core.zettel(db.items[id])}.html")
    end

    test "a future date from Entry alone waits, and the preview's date is that day", ctx do
      {db, later} = Core.add_item(ctx.db, "Later", ~D[2026-12-24], section: ctx.posts)
      assert [{%{id: ^later}, ~D[2026-12-24]}] = Core.blog_waiting(db, @today)
    end
  end
end
