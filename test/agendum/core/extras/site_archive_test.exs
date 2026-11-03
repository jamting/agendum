# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.SiteArchiveTest do
  @moduledoc """
  The newest N and an archive (R74, R74e; plans/PUBLISHER_2.md step 4,
  meeting 2026-11-02-1954, § 7, the owner's choices of 2026-11-03): the
  main index, each list's index and the feeds carry the newest N items (the
  Site's Newest, 20 by default; a list may set its own, 0 for all); once
  an index no longer shows everything, an archive lists every item's title
  and date by month, in the blog's language, and the index links to it.
  Every page stays where it is.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core

  @today ~D[2026-11-03]

  # 5 posts, two in October and three in November, the newest 3 shown;
  # Devlog a list with everything on; Co-workers an index-only list
  setup do
    db = Core.new_file()
    {:ok, db, posts} = Core.add_category(db, db.main_id, "Posts")
    {:ok, db, devlog} = Core.add_category(db, posts, "Devlog")

    db =
      Enum.reduce(
        [{"First", ~D[2026-10-01]}, {"Second", ~D[2026-10-20]}, {"Third", ~D[2026-11-01]}],
        db,
        fn {text, day}, db -> elem(Core.add_item(db, text, day, section: devlog), 0) end
      )

    {db, _} = Core.add_item(db, "Fourth", ~D[2026-11-02], section: posts)
    {db, _} = Core.add_item(db, "Fifth", ~D[2026-11-03], section: posts)

    {:ok, db, coworkers} = Core.add_category(db, db.main_id, "Co-workers")

    db =
      Enum.reduce(~w(Anna Bo Cy), db, fn name, db ->
        elem(Core.add_item(db, name, ~D[2026-09-01], section: coworkers), 0)
      end)

    {:ok, db} =
      Core.set_blog(db, %{posts: posts, title: "Owl", base_url: "https://owl.example/", newest: 3})

    {:ok, db, _} = Core.add_blog_list(db, devlog)

    {:ok, db} =
      Core.set_blog_list(db, devlog, %{index: true, feeds: true, item_pages: true, notes: true})

    {:ok, db, _} = Core.add_blog_list(db, coworkers)
    {:ok, db} = Core.set_blog_list(db, coworkers, %{newest: 2})
    {:ok, db, _} = Core.prepare_publish(db, %{})
    db = Core.record_published(db, @today)
    %{db: db, devlog: devlog, coworkers: coworkers}
  end

  defp file(files, path), do: files |> List.keyfind(path, 0) |> elem(1)
  defp has?(files, path), do: List.keymember?(files, path, 0)
  defp inputs(templates), do: %{templates: templates, assets: []}

  test "a new blog shows the newest 20" do
    assert %Agendum.Core.Extras.Blog{}.newest == 20
    assert %Agendum.Core.Extras.BlogList{}.newest == nil
  end

  test "the main index and feeds carry the newest N; every post keeps its page", %{db: db} do
    files = Core.site(db, @today)
    index = file(files, "index.html")
    assert index =~ "Fifth"
    assert index =~ "Third"
    refute index =~ "Second"
    refute file(files, "rss.xml") =~ "Second"
    assert length(JSON.decode!(file(files, "feed.json"))["items"]) == 3
    assert Enum.count(files, fn {path, _} -> String.starts_with?(path, "posts/") end) == 5
  end

  test "past N, the index links its archive, which lists every post by month", %{db: db} do
    files = Core.site(db, @today)

    assert file(files, "index.html") =~
             ~s(<p class="archive"><a href="archive.html">All posts</a></p>)

    archive = file(files, "archive.html")
    assert archive =~ "November 2026"
    assert archive =~ "October 2026"
    # newest month first, and each title linked to its page
    assert :binary.match(archive, "November") < :binary.match(archive, "October")

    for title <- ~w(First Second Third Fourth Fifth),
        do: assert(archive =~ ~r{<a href="posts/[a-z]+\.html"[^>]*>#{title}</a>})
  end

  test "the months in the blog's language", %{db: db} do
    {:ok, db} = Core.set_blog(db, %{language: "sv"})
    archive = Core.site(db, @today) |> file("archive.html")
    assert archive =~ "november 2026"
    assert archive =~ "oktober 2026"
  end

  test "no archive while the index shows everything", %{db: db} do
    {:ok, db} = Core.set_blog(db, %{newest: 0})
    files = Core.site(db, @today)
    refute has?(files, "archive.html")
    refute file(files, "index.html") =~ "archive.html"
    assert file(files, "index.html") =~ "First"

    {:ok, db} = Core.set_blog(db, %{newest: 5})
    refute has?(Core.site(db, @today), "archive.html")
  end

  test "a list follows the Site's N unless it sets its own", ctx do
    files = Core.site(ctx.db, @today)
    # Devlog (the site's 3) has 3 items: no archive
    refute has?(files, "devlog/archive.html")
    # Co-workers (its own 2) has 3: Anna, the first made, only in its archive
    index = file(files, "co-workers/index.html")
    assert index =~ ~s(<a href="archive.html">All of Co-workers</a>)
    archive = file(files, "co-workers/archive.html")
    assert archive =~ "September 2026"
    # no page of its own: listed, linked nowhere
    assert archive =~ "Anna"
    refute archive =~ ~r{<a [^>]*>Anna</a>}

    {:ok, db} = Core.set_blog_list(ctx.db, ctx.coworkers, %{newest: 0})
    refute has?(Core.site(db, @today), "co-workers/archive.html")
  end

  test "a list's feeds carry its newest N", ctx do
    {:ok, db} = Core.set_blog_list(ctx.db, ctx.devlog, %{newest: 1})
    files = Core.site(db, @today)
    assert length(JSON.decode!(file(files, "devlog/feed.json"))["items"]) == 1
    assert has?(files, "devlog/archive.html")
  end

  test "archive.html is a template, written for the person; a list may have its own", ctx do
    assert List.keymember?(Core.site_default_templates(), "templates/archive.html", 0)
    mine = "{{#months}}[{{title}}|{{month_iso}}:{{#posts}}{{title}};{{/posts}}]{{/months}}\n"

    {:ok, files} =
      Core.site(ctx.db, @today, inputs(%{"archive" => mine, "co-workers/archive" => "own\n"}))

    assert file(files, "archive.html") =~
             "[November 2026|2026-11:Fifth;Fourth;Third;][October 2026|2026-10:Second;First;]"

    assert file(files, "co-workers/archive.html") =~ "own"
  end

  test "Newest: a number from 0; anything else is refused", %{db: db, coworkers: coworkers} do
    for bad <- [-1, "3", 1.5],
        do: assert({:error, :bad_setting} = Core.set_blog(db, %{newest: bad}))

    assert {:error, :bad_setting} = Core.set_blog_list(db, coworkers, %{newest: -2})
    assert {:ok, db} = Core.set_blog_list(db, coworkers, %{newest: nil})
    assert db.blog.lists[coworkers].newest == nil
  end

  test "the site's archive.html is its own: a post's address never takes it", %{db: db} do
    {:ok, db} = Core.set_blog(db, %{address: "{slug}.html"})
    {db, item} = Core.add_item(db, "Archive", @today, section: db.blog.posts)
    {:ok, db, _} = Core.prepare_publish(db, %{})
    db = Core.record_published(db, @today)
    assert Core.Extras.Blog.record(db, item).path == "archive-2.html"
  end

  describe "found in review (2026-11-03)" do
    test "a page already at archive.html keeps it; the archive takes the next name", %{db: db} do
      {:ok, db, pages} = Core.add_category(db, db.main_id, "Pages")
      {:ok, db} = Core.set_blog(db, %{pages: pages})
      {db, about} = Core.add_item(db, "Archive", @today, section: pages)
      {:ok, db, _} = Core.prepare_publish(db, %{})
      # as an older Agendum recorded it, before archive.html was the site's own
      record = %Core.Extras.PostRecord{path: "archive.html", print: 0}
      db = put_in(db.blog.published[about], record)
      files = Core.site(db, @today)
      assert Enum.count(files, &(elem(&1, 0) == "archive.html")) == 1
      assert file(files, "archive-2.html") =~ "November 2026"
      assert file(files, "index.html") =~ ~s(<a href="archive-2.html">All posts</a>)
    end

    test "a list's item page at archive.html does not move the list's folder", ctx do
      {:ok, db} = Core.set_blog_list(ctx.db, ctx.coworkers, %{item_pages: true, newest: 1})
      {:ok, db, _} = Core.prepare_publish(db, %{})
      [anna | _] = for {id, i} <- db.items, i.text == "Anna", do: id
      record = %Core.Extras.PostRecord{path: "co-workers/archive.html", print: 0}
      db = put_in(db.blog.published[anna], record)
      files = Core.site(db, @today)
      assert List.keymember?(files, "co-workers/index.html", 0)
      assert file(files, "co-workers/archive-2.html") =~ "September 2026"
      assert file(files, "co-workers/index.html") =~ ~s(<a href="archive-2.html">)
    end

    @tag :tmp_dir
    test "a crafted file's Newest that is no number from 0 is refused", %{db: db, tmp_dir: dir} do
      for bad <- [-1, :many] do
        path = Path.join(dir, "crafted.agendum")
        blog = %{db.blog | newest: bad}
        File.write!(path, :erlang.term_to_binary({:agenda, 52, %{db | blog: blog}}))
        assert {:error, {:damaged, _}} = Agendum.Store.load(path)
      end
    end
  end

  test "an index.html as Agendum 0.89 wrote it is replaced" do
    old = File.read!("lib/agendum/core/extras/site_assets/templates/index-0.89.html")
    assert Core.Extras.Site.legacy_template?("templates/index.html", old)
  end
end
