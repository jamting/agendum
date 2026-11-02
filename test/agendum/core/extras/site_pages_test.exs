# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.SitePagesTest do
  @moduledoc """
  The site's pages (R74; plans/PUBLISHER.md step 4, meeting 2026-11-02-1255,
  § 8): the items of a Pages category are pages such as About, each at
  `/<slug>.html`, drawn from `page.html`, outside the index and the feeds,
  and listed in the menu after Home, A to Z.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.Extras.{Blog, Site}

  @today ~D[2026-11-02]

  setup do
    db = Core.new_file()
    {:ok, db, posts} = Core.add_category(db, db.main_id, "Posts")
    {:ok, db, pages} = Core.add_category(db, db.main_id, "Pages")
    {db, hello} = Core.add_item(db, "Hello, Wood", ~D[2026-10-01], section: posts)
    {db, now} = Core.add_item(db, "Now", ~D[2026-10-02], section: pages)
    db = Core.set_note(db, now, "Reading Milne.", @today)
    {db, about} = Core.add_item(db, "About", ~D[2026-10-02], section: pages)
    db = Core.set_note(db, about, "# About Owl\nA bird of letters.", @today)
    {:ok, db} = Core.set_blog(db, %{posts: posts, pages: pages, title: "Owl's Notes"})
    {:ok, db, _} = Core.prepare_publish(db, %{})
    %{db: db, hello: hello, about: about, now: now, posts: posts, pages: pages}
  end

  defp file(files, path), do: files |> List.keyfind(path, 0) |> elem(1)

  test "each page is at /<slug>.html, from page.html, with its title", %{db: db} do
    files = Core.site(db, @today)
    about = file(files, "about-owl.html")
    assert about =~ "<title>About Owl · Owl's Notes</title>"
    assert about =~ ~s(<article class="page")
    assert about =~ "A bird of letters."
    assert file(files, "now.html") =~ "Reading Milne."
  end

  test "pages are not posts: not in the index, nor in the feeds", %{db: db} do
    files = Core.site(db, @today)
    refute file(files, "index.html") =~ "Reading Milne"
    refute file(files, "rss.xml") =~ "About Owl"
    refute file(files, "feed.json") =~ "About Owl"
    assert file(files, "index.html") =~ "Hello, Wood"
  end

  test "an item in both Posts and Pages is a page only", ctx do
    db = Core.assign(ctx.db, ctx.hello, ctx.pages)
    assert Core.blog_posts(db) == []
    files = Core.site(db, @today)
    refute file(files, "rss.xml") =~ "Hello, Wood"
    assert List.keymember?(files, "hello-wood.html", 0)
  end

  test "the menu lists Home, then the pages A to Z, the page shown marked", %{db: db} do
    files = Core.site(db, @today)

    assert file(files, "index.html") =~
             ~s(<nav class="menu"><a href="index.html" aria-current="page">Home</a>) <>
               ~s( · <a href="about-owl.html">About Owl</a> · <a href="now.html">Now</a></nav>)

    assert file(files, "now.html") =~ ~s(<a href="now.html" aria-current="page">Now</a>)
    post = Enum.find(files, &String.starts_with?(elem(&1, 0), "posts/")) |> elem(1)
    assert post =~ ~s(<a href="../about-owl.html">About Owl</a>)
  end

  test "without pages there is no menu: the site is as before", ctx do
    {:ok, db} = Core.set_blog(ctx.db, %{pages: nil})
    refute file(Core.site(db, @today), "index.html") =~ "<nav"
  end

  test "a page's address is made once and kept, as a post's", ctx do
    db = Core.record_published(ctx.db, @today)
    assert Blog.record(db, ctx.about).path == "about-owl.html"
    db = Core.set_note(db, ctx.about, "# Who I am\nx", @today)
    db = Core.record_published(db, @today)
    assert Blog.record(db, ctx.about).path == "about-owl.html"
  end

  test "Pages must differ from Posts and Drafts", ctx do
    assert {:error, :bad_setting} = Core.set_blog(ctx.db, %{pages: ctx.posts})
  end

  test "deleting the Pages category forgets it", ctx do
    {:ok, db} = Core.discard_category(ctx.db, ctx.pages)
    assert db.blog.pages == nil
  end

  test "the menu template Agendum wrote in 0.81 is replaced; one changed stays" do
    {_, old} =
      {"templates/menu.html",
       File.read!("lib/agendum/core/extras/site_assets/templates/menu-0.81.html")}

    assert Site.legacy_template?("templates/menu.html", old)
    refute Site.legacy_template?("templates/menu.html", old <> "<nav>mine</nav>")
  end

  describe "found in review" do
    test "Pages above Posts, or Drafts above Pages, is refused: it would take them all", ctx do
      {:ok, db, site} = Core.add_category(ctx.db, ctx.db.main_id, "Site")
      {:ok, db} = Core.move_category(db, ctx.posts, site, 0)
      assert {:error, :bad_setting} = Core.set_blog(db, %{pages: site})

      {:ok, db, under} = Core.add_category(db, ctx.pages, "Hidden")
      assert {:error, :bad_setting} = Core.set_blog(db, %{drafts: ctx.pages, pages: under})
    end

    test "a page waiting for its day is listed with the posts that wait", ctx do
      db = Core.set_date(ctx.db, ctx.now, ctx.db.special.when, ~D[2026-11-20])
      assert [{%{id: id}, ~D[2026-11-20]}] = Core.blog_waiting(db, @today)
      assert id == ctx.now
    end

    test "pages A to Z as the blog's language has it", ctx do
      db =
        for title <- ["Åsikter", "Ämnen", "Om", "Éloge", "Zebra"], reduce: ctx.db do
          db -> elem(Core.add_item(db, title, @today, section: ctx.pages), 0)
        end

      titles = fn db -> for item <- Blog.pages(db), do: Blog.title(item) end
      {:ok, sv} = Core.set_blog(db, %{language: "sv"})
      assert titles.(sv) == ["About Owl", "Éloge", "Now", "Om", "Zebra", "Åsikter", "Ämnen"]
      assert titles.(db) == ["About Owl", "Ämnen", "Åsikter", "Éloge", "Now", "Om", "Zebra"]
    end
  end
end
