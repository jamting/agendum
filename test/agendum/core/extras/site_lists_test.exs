# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.SiteListsTest do
  @moduledoc """
  The blog's lists (R74e; plans/PUBLISHER_2.md step 3, meeting
  2026-11-02-2244, § 6, the owner's choices of 2026-11-03): any of the
  person's own categories published as a list, its items handed to the
  templates. Per list an index page, RSS and JSON Feed, and a page per
  item are switched on or off; its notes are published only when it says
  so, and only the fields it names leave the file. Drafts holds back every
  list's items; only posts wait for their day. The feeds of format 50, each
  child of Posts, are kept as lists with everything on.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.Extras.{BlogList, Site}

  @today ~D[2026-11-02]

  # Posts with Devlog (Releases under it) and Links, the two kept as lists
  # with everything on, as a file of format 50 opens; and Co-workers, a
  # category outside Posts with a Role family and an Email text
  setup do
    db = Core.new_file()
    {:ok, db, posts} = Core.add_category(db, db.main_id, "Posts")
    {:ok, db, devlog} = Core.add_category(db, posts, "Devlog")
    {:ok, db, links} = Core.add_category(db, posts, "Links")
    {:ok, db, releases} = Core.add_category(db, devlog, "Releases")
    {:ok, db, drafts} = Core.add_category(db, db.main_id, "Drafts")
    {db, a} = Core.add_item(db, "Built the importer", ~D[2026-10-01], section: devlog)
    {db, _} = Core.add_item(db, "v0.80 is out", ~D[2026-10-02], section: releases)
    {db, _} = Core.add_item(db, "A good read", ~D[2026-10-03], section: links)
    {db, _} = Core.add_item(db, "Plain post", ~D[2026-10-04], section: posts)

    {:ok, db, coworkers} = Core.add_category(db, db.main_id, "Co-workers")
    {:ok, db, role} = Core.add_category(db, db.main_id, "Role")
    {:ok, db, designer} = Core.add_category(db, role, "Designer")
    {:ok, db, tester} = Core.add_category(db, role, "Tester")
    {:ok, db, email} = Core.add_category(db, db.main_id, "Email")
    {:ok, db} = Core.make_unindexed(db, email)
    {db, anna} = Core.add_item(db, "Anna", ~D[2026-09-01], section: coworkers)
    {db, bo} = Core.add_item(db, "Bo", ~D[2026-09-02], section: coworkers)
    db = Core.assign(db, anna, designer)
    db = Core.assign(db, anna, tester)
    {:ok, db} = Core.set_text(db, anna, email, "anna@wood.example")
    db = Core.set_note(db, anna, "Likes honey; private.", @today)

    {:ok, db} =
      Core.set_blog(db, %{
        posts: posts,
        drafts: drafts,
        title: "Owl's Notes",
        base_url: "https://owl.example/"
      })

    all_on = %{index: true, feeds: true, item_pages: true, notes: true}
    {:ok, db, ^devlog} = Core.add_blog_list(db, devlog)
    {:ok, db} = Core.set_blog_list(db, devlog, all_on)
    {:ok, db, ^links} = Core.add_blog_list(db, links)
    {:ok, db} = Core.set_blog_list(db, links, all_on)
    {:ok, db, _} = Core.prepare_publish(db, %{})

    %{
      db: db,
      posts: posts,
      devlog: devlog,
      links: links,
      releases: releases,
      drafts: drafts,
      coworkers: coworkers,
      role: role,
      email: email,
      anna: anna,
      bo: bo,
      a: a
    }
  end

  defp file(files, path), do: files |> List.keyfind(path, 0) |> elem(1)
  defp paths(files), do: for({path, _} <- files, do: path)
  defp inputs(templates), do: %{templates: templates, assets: []}

  # Co-workers made a list, then the site published once (Zettel ids given)
  defp coworkers(ctx, changes \\ %{}) do
    {:ok, db, _} = Core.add_blog_list(ctx.db, ctx.coworkers)
    {:ok, db} = Core.set_blog_list(db, ctx.coworkers, changes)
    {:ok, db, _} = Core.prepare_publish(db, %{})
    db
  end

  describe "the feeds kept as lists" do
    test "each list has its folder from its name, and its posts", %{db: db} do
      lists = Core.blog_lists(db, @today)
      assert Enum.map(lists, & &1.slug) == ["devlog", "links"]
      # a post in Releases is in Devlog's, under it
      assert Enum.map(hd(lists).items, & &1.text) == ["v0.80 is out", "Built the importer"]
    end

    test "a list has its own index page, RSS and JSON Feed; the main ones keep every post",
         %{db: db} do
      files = Core.site(db, @today)
      index = file(files, "devlog/index.html")
      assert index =~ ~s(<h1 class="p-name">Devlog</h1>)
      assert index =~ "Built the importer"
      refute index =~ "A good read"
      assert index =~ ~s(href="../style.css")
      assert index =~ ~s(<a href="rss.xml">RSS</a>)

      rss = file(files, "devlog/rss.xml")
      assert rss =~ "<title>Owl&apos;s Notes · Devlog</title>"
      assert rss =~ ~s(href="https://owl.example/devlog/rss.xml")
      refute rss =~ "A good read"

      assert file(files, "devlog/feed.json") =~
               ~s("feed_url":"https://owl.example/devlog/feed.json")

      for post <- ["Built the importer", "A good read", "Plain post"],
          do: assert(file(files, "rss.xml") =~ post)
    end

    test "a post in a list keeps its post page: no item page of its own", %{db: db} do
      files = Core.site(db, @today)
      refute Enum.any?(paths(files), &(&1 =~ ~r{^devlog/(?!index|rss|feed)}))
      assert file(files, "devlog/index.html") =~ ~s(href="../posts/)
    end

    test "the main index names the lists with feeds", %{db: db} do
      assert file(Core.site(db, @today), "index.html") =~
               ~s(<p class="feeds">Feeds: <a href="devlog/index.html">Devlog</a>) <>
                 ~s( · <a href="links/index.html">Links</a></p>)
    end
  end

  describe "files from before lists" do
    test "a file of format 50 opens with each child of Posts a list, everything on" do
      db = Core.new_file()
      {:ok, db, posts} = Core.add_category(db, db.main_id, "Posts")
      {:ok, db, devlog} = Core.add_category(db, posts, "Devlog")
      {:ok, db, links} = Core.add_category(db, posts, "Links")
      {:ok, db, releases} = Core.add_category(db, devlog, "Releases")
      {:ok, db} = Core.set_blog(db, %{posts: posts})

      feed = %{
        __struct__: Agendum.Core.Extras.BlogFeed,
        title: "Workshop",
        description: "How it is made",
        slug: "devlog"
      }

      old_blog =
        db.blog |> Map.from_struct() |> Map.delete(:lists) |> Map.put(:feeds, %{devlog => feed})

      upgraded =
        Agendum.Store.upgrade(%{
          db
          | blog: Map.put(old_blog, :__struct__, Agendum.Core.Extras.Blog)
        })

      on = %{index: true, feeds: true, item_pages: true, notes: true}

      assert upgraded.blog.lists[devlog] ==
               struct(
                 BlogList,
                 Map.merge(on, %{title: "Workshop", description: "How it is made", slug: "devlog"})
               )

      assert upgraded.blog.lists[links] == struct(BlogList, on)
      refute Map.has_key?(upgraded.blog.lists, releases)
      # a file of today's format keeps its lists as they are
      assert Agendum.Store.upgrade(upgraded).blog.lists == upgraded.blog.lists
    end

    test "a JSON file from before lists reads its feeds as lists", %{db: db, devlog: devlog} do
      doc = db |> Core.JSONFile.encode() |> JSON.decode!()
      blog = doc["blog"] |> Map.delete("lists")

      blog =
        Map.put(blog, "feeds", [
          %{"category" => devlog, "title" => "Workshop", "description" => "", "slug" => "devlog"}
        ])

      {:ok, read} = Core.JSONFile.decode(JSON.encode!(%{doc | "blog" => blog}))
      assert %BlogList{title: "Workshop", feeds: true, notes: true} = read.blog.lists[devlog]
      assert Map.has_key?(read.blog.lists, db.blog.lists |> Map.keys() |> Enum.max())
    end
  end

  describe "a new list" do
    test "starts with only its index page: no feeds, no item pages, no notes", ctx do
      db = coworkers(ctx)
      list = Enum.find(Core.blog_lists(db, @today), &(&1.category == ctx.coworkers))
      assert %{index: true, feeds: false, item_pages: false, notes: false, fields: []} = list

      files = Core.site(db, @today)
      index = file(files, "co-workers/index.html")
      assert index =~ "Anna"
      assert index =~ "Bo"
      refute index =~ "Likes honey"
      refute index =~ ~s(href="rss.xml")
      refute List.keymember?(files, "co-workers/rss.xml", 0)
      refute Enum.any?(paths(files), &(&1 =~ ~r{^co-workers/(?!index)}))
      # not a post: not on the main index nor in its feeds
      refute file(files, "index.html") =~ "Anna"
      refute file(files, "rss.xml") =~ "Anna"
      # and an index-only list is not on the Feeds line
      refute file(files, "index.html") =~ "co-workers/index.html"
    end

    test "an index-only list gives its items no Zettel id", ctx do
      db = coworkers(ctx)
      assert db.items[ctx.anna].zettel == nil
      assert Core.site(db, @today) |> file("co-workers/index.html") =~ "Anna"
    end

    test "every list with an index is in {{#lists}}, for a template's own menu", ctx do
      db = coworkers(ctx)
      menu = "{{#lists}}[{{title}}={{url}}]{{/lists}}\n"
      {:ok, files} = Core.site(db, @today, inputs(%{"menu" => menu}))

      assert file(files, "index.html") =~
               "[Devlog=devlog/index.html][Links=links/index.html][Co-workers=co-workers/index.html]"
    end
  end

  describe "fields" do
    test "only the named fields reach a template, by name and as columns", ctx do
      db = coworkers(ctx, %{fields: ["Role", "email"]})

      template =
        "{{#posts}}<{{title}}|{{fields.role}}|{{fields.email}}|{{fields.when}}>" <>
          "{{#columns}}({{name}}={{value}}){{/columns}}{{/posts}}\n"

      {:ok, files} = Core.site(db, @today, inputs(%{"co-workers/index" => template}))
      index = file(files, "co-workers/index.html")
      assert index =~ "<Anna|Designer, Tester|anna@wood.example|>"
      assert index =~ "(Role=Designer, Tester)(Email=anna@wood.example)"
      assert index =~ "<Bo|||>(Role=)(Email=)"
    end

    test "Agendum's index shows them", ctx do
      db = coworkers(ctx, %{fields: ["Role"]})
      index = Core.site(db, @today) |> file("co-workers/index.html")
      assert index =~ ~s(<p class="fields">Role: Designer, Tester</p>)
    end

    test "a field's name: lowercase, spaces as _, letters folded; two alike get _2", ctx do
      {:ok, db, due} = Core.add_category(ctx.db, db_main(ctx), "Due date")
      {:ok, db, owner} = Core.add_category(db, db_main(ctx), "Ägare")
      {:ok, db, owner2} = Core.add_category(db, ctx.role, "Agare")
      db = coworkers(%{ctx | db: db}, %{fields: [due, owner, owner2]})
      template = "{{#items}}{{#first}}{{#columns}}[{{key}}]{{/columns}}{{/first}}{{/items}}\n"
      {:ok, files} = Core.site(db, @today, inputs(%{"co-workers/index" => template}))
      assert file(files, "co-workers/index.html") =~ "[due_date][agare][agare_2]"
    end

    test "a name not a category, or two categories', is refused, naming it", ctx do
      {:ok, db, _} = Core.add_blog_list(ctx.db, ctx.coworkers)

      assert {:error, {:unknown_field, "Shoe size"}} =
               Core.set_blog_list(db, ctx.coworkers, %{fields: ["Role", "Shoe size"]})

      {:ok, db, _} = Core.add_category(db, ctx.posts, "Role")

      assert {:error, {:ambiguous_field, "role"}} =
               Core.set_blog_list(db, ctx.coworkers, %{fields: ["role"]})

      assert {:error, {:unknown_field, "MAIN"}} =
               Core.set_blog_list(db, ctx.coworkers, %{fields: ["MAIN"]})
    end

    test "a field's category discarded leaves the list's fields", ctx do
      db = coworkers(ctx, %{fields: ["Role", "Email"]})
      {:ok, db} = Core.discard_category(db, ctx.role)
      assert db.blog.lists[ctx.coworkers].fields == [ctx.email]
    end
  end

  describe "the switches" do
    test "notes on: the items' notes are their bodies", ctx do
      db = coworkers(ctx, %{notes: true})
      assert Core.site(db, @today) |> file("co-workers/index.html") =~ "Likes honey"
    end

    test "feeds on: RSS and JSON Feed in its folder, linking into the index", ctx do
      db = coworkers(ctx, %{feeds: true})
      assert db.items[ctx.anna].zettel != nil
      files = Core.site(db, @today)
      rss = file(files, "co-workers/rss.xml")
      zettel = Core.zettel(db.items[ctx.anna])
      assert rss =~ "<link>https://owl.example/co-workers/index.html##{zettel}</link>"
      # notes off: no body in the feeds either
      refute rss =~ "honey"
      refute file(files, "co-workers/feed.json") =~ "honey"
      assert file(files, "index.html") =~ ~s(<a href="co-workers/index.html">Co-workers</a>)
    end

    test "item pages on: a page each, at the list's address, from post.html", ctx do
      db = coworkers(ctx, %{item_pages: true, fields: ["Role"]})
      db = Core.record_published(db, @today)
      zettel = Core.zettel(db.items[ctx.anna])
      files = Core.site(db, @today)
      page = file(files, "co-workers/#{zettel}.html")
      assert page =~ "Anna"
      assert page =~ ~s(<p class="fields">Role: Designer, Tester</p>)
      assert page =~ ~s(href="../style.css")
      assert file(files, "co-workers/index.html") =~ ~s(href="../co-workers/#{zettel}.html")
    end

    test "index off: no index page, and not in the lists", ctx do
      db = coworkers(ctx, %{index: false, item_pages: true})
      files = Core.site(db, @today)
      refute List.keymember?(files, "co-workers/index.html", 0)
      assert Enum.any?(paths(files), &String.starts_with?(&1, "co-workers/"))
    end

    test "a list's own address pattern, kept once published", ctx do
      db = coworkers(ctx, %{item_pages: true, address: "people/{slug}.html"})
      db = Core.record_published(db, @today)
      assert "people/anna.html" in paths(Core.site(db, @today))
      {:ok, db} = Core.set_blog_list(db, ctx.coworkers, %{slug: "team"})
      paths = paths(Core.site(db, @today))
      assert "people/anna.html" in paths
      assert "team/index.html" in paths
    end

    test "an address pattern that is not one is refused", ctx do
      {:ok, db, _} = Core.add_blog_list(ctx.db, ctx.coworkers)

      for bad <- ["people/x.html", "../{slug}.html", "{slug}.txt"],
          do:
            assert(
              {:error, :bad_address} = Core.set_blog_list(db, ctx.coworkers, %{address: bad})
            )
    end

    test "an item in two lists with item pages has one page, the first list's", ctx do
      {:ok, db, gym} = Core.add_category(ctx.db, db_main(ctx), "Friends")
      db = Core.assign(db, ctx.anna, gym)
      db = %{ctx | db: db} |> coworkers(%{item_pages: true})
      {:ok, db, _} = Core.add_blog_list(db, gym)
      {:ok, db} = Core.set_blog_list(db, gym, %{item_pages: true})
      db = Core.record_published(db, @today)
      zettel = Core.zettel(db.items[ctx.anna])
      paths = paths(Core.site(db, @today))
      assert "co-workers/#{zettel}.html" in paths
      refute "friends/#{zettel}.html" in paths
      assert Core.site(db, @today) |> file("friends/index.html") =~ "../co-workers/#{zettel}.html"
    end
  end

  describe "what is held back" do
    test "Drafts holds back every list's items", ctx do
      db = Core.assign(ctx.db, ctx.bo, ctx.drafts)
      db = coworkers(%{ctx | db: db})
      refute Core.site(db, @today) |> file("co-workers/index.html") =~ "Bo"
    end

    test "a list item with a When to come is published; a post in a list waits", ctx do
      db = Core.set_date(ctx.db, ctx.bo, ctx.db.special.when, ~D[2026-12-24])
      db = Core.set_date(db, ctx.a, db.special.when, ~D[2026-12-24])
      db = coworkers(%{ctx | db: db})
      files = Core.site(db, @today)
      assert file(files, "co-workers/index.html") =~ "Bo"
      refute file(files, "devlog/index.html") =~ "Built the importer"
    end

    test "an item of the Pages category is a page only", ctx do
      {:ok, db, pages} = Core.add_category(ctx.db, db_main(ctx), "Pages")
      {:ok, db} = Core.set_blog(db, %{pages: pages})
      db = Core.assign(db, ctx.bo, pages)
      db = coworkers(%{ctx | db: db})
      # in the menu, as a page; not one of the list's items
      refute Core.site(db, @today) |> file("co-workers/index.html") =~
               ~r{<h2 class="p-name">[^\n]*Bo<}
    end
  end

  describe "templates of a list's own" do
    test "templates/<folder>/ draws its index, items and RSS, else the shared ones", ctx do
      db = coworkers(ctx, %{feeds: true, item_pages: true})
      db = Core.record_published(db, @today)

      own = %{
        "co-workers/index" => "<ul>{{#items}}<li>{{title}}</li>{{/items}}</ul>\n",
        "co-workers/item" => "{{#item}}<h1>{{title}}!</h1>{{/item}}\n"
      }

      {:ok, files} = Core.site(db, @today, inputs(own))
      assert file(files, "co-workers/index.html") =~ "<ul><li>Bo</li><li>Anna</li></ul>"
      zettel = Core.zettel(db.items[ctx.anna])
      assert file(files, "co-workers/#{zettel}.html") =~ "<h1>Anna!</h1>"
      # the other lists keep the shared ones
      assert file(files, "devlog/index.html") =~ ~s(<h1 class="p-name">Devlog</h1>)
    end

    test "a mistake in one says its whole path", ctx do
      db = coworkers(ctx)

      assert {:error, {:template, "co-workers/index", 1, {:not_closed, "items"}} = error} =
               Core.site(db, @today, inputs(%{"co-workers/index" => "{{#items}}"}))

      assert Agendum.TUI.Extras.Publish.Messages.site_error(error) =~
               "templates/co-workers/index.html line 1"
    end
  end

  describe "adding and removing" do
    test "a list is added by id or by name; never twice, never MAIN or a feed's", ctx do
      assert {:ok, _db, id} = Core.add_blog_list(ctx.db, {:name, "Co-workers"})
      assert id == ctx.coworkers
      assert {:error, :already_a_list} = Core.add_blog_list(ctx.db, ctx.devlog)
      assert {:error, :bad_setting} = Core.add_blog_list(ctx.db, ctx.db.main_id)
      assert {:ok, db, gym} = Core.add_blog_list(ctx.db, {:name, "Gym"})
      assert db.categories[gym].name == "Gym"
    end

    test "removing a list takes its files from the site, the category stays", ctx do
      {:ok, db} = Core.remove_blog_list(ctx.db, ctx.links)
      refute List.keymember?(Core.site(db, @today), "links/index.html", 0)
      assert Map.has_key?(db.categories, ctx.links)
      assert {:error, :not_a_list} = Core.remove_blog_list(db, ctx.links)
    end

    test "a discarded category's list goes with it", ctx do
      {:ok, db} = Core.discard_category(ctx.db, ctx.devlog)
      refute Map.has_key?(db.blog.lists, ctx.devlog)
    end
  end

  describe "the folder" do
    test "a list's settings: title, description, folder; the folder moves it", ctx do
      {:ok, db} =
        Core.set_blog_list(ctx.db, ctx.devlog, %{
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
      assert db.blog.lists[ctx.devlog].slug == "devlog"
      {:ok, db} = Core.rename_category(db, ctx.devlog, "Building")
      assert List.keymember?(Core.site(db, @today), "devlog/index.html", 0)
    end

    test "a folder that is not plain, the site's own, or another list's is refused", ctx do
      for bad <- ["Dev log", "../x", "fonts", "assets", "templates"] do
        assert {:error, :bad_slug} = Core.set_blog_list(ctx.db, ctx.devlog, %{slug: bad}), bad
      end

      {:ok, db} = Core.set_blog_list(ctx.db, ctx.links, %{slug: "notes"})
      assert {:error, :bad_slug} = Core.set_blog_list(db, ctx.devlog, %{slug: "notes"})
      assert {:error, :not_a_list} = Core.set_blog_list(db, ctx.releases, %{title: "x"})
    end

    test "a post's address never lands on a list's index or feeds", ctx do
      {:ok, db} = Core.set_blog(ctx.db, %{address: "{slug}/index.html"})
      db = Core.set_note(db, ctx.a, "# Devlog\nx", @today)
      paths = paths(Core.site(db, @today))
      assert Enum.count(paths, &(&1 == "devlog/index.html")) == 1
      assert "devlog/index-2.html" in paths
    end

    test "a file's list folder or address that is not plain is refused on reading", ctx do
      db = ctx.db
      crafted = put_in(db.blog.lists[ctx.devlog].slug, "../../x")
      assert {:error, message} = Core.JSONFile.decode(Core.JSONFile.encode(crafted))
      assert message =~ "not a list's folder"

      crafted = put_in(db.blog.lists[ctx.devlog].address, "../{slug}.html")
      assert {:error, message} = Core.JSONFile.decode(Core.JSONFile.encode(crafted))
      assert message =~ "not an address pattern"
    end
  end

  describe "templates Agendum wrote before" do
    test "index.html and post.html still as Agendum 0.87 wrote them are replaced" do
      for name <- ~w(index post) do
        old = File.read!("lib/agendum/core/extras/site_assets/templates/#{name}-0.87.html")
        assert Site.legacy_template?("templates/#{name}.html", old)
      end

      old = File.read!("lib/agendum/core/extras/site_assets/templates/index-0.81.html")
      assert Site.legacy_template?("templates/index.html", old)
    end

    test "an index template written before lists still links posts from a list's page", ctx do
      old = File.read!("lib/agendum/core/extras/site_assets/templates/index-0.81.html")
      {:ok, files} = Core.site(ctx.db, @today, inputs(%{"index" => old}))
      page = file(files, "devlog/index.html")
      assert page =~ ~s(<a class="u-url" href="../posts/)
      refute page =~ ~s(<a class="u-url" href="posts/)
    end
  end

  describe "found in review (2026-11-03)" do
    test "a hidden note's heading, links and changes stay home", ctx do
      db = Core.set_note(ctx.db, ctx.anna, "# Anna, on sick leave\nprivate", @today)
      db = coworkers(%{ctx | db: db}, %{feeds: true, item_pages: true, address: "co/{slug}.html"})

      {db, post} =
        Core.add_item(db, "See [[#{Core.zettel(db.items[ctx.anna])}]]", @today,
          section: ctx.posts
        )

      {:ok, db, _} = Core.prepare_publish(db, %{})
      _ = post
      db = Core.record_published(db, @today)
      files = Core.site(db, @today)

      for {path, text} <- files,
          is_binary(text),
          String.valid?(text),
          do: refute(text =~ "sick leave", path)

      assert "co/anna.html" in paths(files)
      # the note changed: no "Updated" for it, its fingerprint is of no note
      db = Core.set_note(db, ctx.anna, "# Anna, back\nprivate", @today)
      db = Core.record_published(db, Date.add(@today, 1))
      assert Core.Extras.Blog.record(db, ctx.anna).modified == nil
      # the file keeps the note itself
      assert db.items[ctx.anna].note =~ "Anna, back"
    end

    test "feeds without index or item pages give each entry its own address", ctx do
      db = coworkers(ctx, %{index: false, feeds: true})
      json = Core.site(db, @today) |> file("co-workers/feed.json") |> JSON.decode!()
      ids = for item <- json["items"], do: item["id"]
      assert length(ids) == 2
      assert ids == Enum.uniq(ids)
    end

    test "a list's box keeps fields by id: a comma or a twin name does not stop it", ctx do
      {:ok, db, smith} = Core.add_category(ctx.db, db_main(ctx), "Smith, John")
      db = coworkers(%{ctx | db: db}, %{fields: [smith, ctx.role]})
      {:ok, db, _} = Core.add_category(db, ctx.posts, "Role")
      assert {:ok, _} = Core.set_blog_list(db, ctx.coworkers, %{fields: [smith, ctx.role]})
    end

    test "a date category of one's own is no list", ctx do
      {:ok, db, due} = Core.add_category(ctx.db, db_main(ctx), "Due")
      {:ok, db} = Core.make_date(db, due, @today)
      assert {:error, :bad_setting} = Core.add_blog_list(db, due)
    end

    test "an old JSON file's feed folder that is not plain is refused", %{db: db, devlog: devlog} do
      doc = db |> Core.JSONFile.encode() |> JSON.decode!()
      feeds = [%{"category" => devlog, "title" => "", "description" => "", "slug" => "../x"}]
      blog = doc["blog"] |> Map.delete("lists") |> Map.put("feeds", feeds)
      assert {:error, message} = Core.JSONFile.decode(JSON.encode!(%{doc | "blog" => blog}))
      assert message =~ "not a list's folder"
    end

    @tag :tmp_dir
    test "a crafted file whose lists are not lists is refused, not a crash", %{
      db: db,
      tmp_dir: dir
    } do
      for blog <- [%{db.blog | lists: "x"}, %{db.blog | lists: %{1 => 7}}] do
        path = Path.join(dir, "crafted.agendum")
        File.write!(path, :erlang.term_to_binary({:agenda, 51, %{db | blog: blog}}))
        assert {:error, {:damaged, _}} = Agendum.Store.load(path)
      end

      old = db.blog |> Map.from_struct() |> Map.delete(:lists) |> Map.put(:feeds, [1])
      path = Path.join(dir, "old.agendum")

      File.write!(
        path,
        :erlang.term_to_binary(
          {:agenda, 50, %{db | blog: Map.put(old, :__struct__, Agendum.Core.Extras.Blog)}}
        )
      )

      assert {:ok, _} = Agendum.Store.load(path)
    end
  end

  describe "found in review (from the feeds)" do
    test "a long name's folder with -2 still fits, and the file opens again", ctx do
      long = String.duplicate("a", 70)
      {:ok, db} = Core.rename_category(ctx.db, ctx.devlog, long)
      {:ok, db} = Core.rename_category(db, ctx.links, long <> "b")
      db = Core.record_published(db, @today)
      slugs = for list <- Core.blog_lists(db, @today), do: list.slug
      assert Enum.all?(slugs, &(String.length(&1) <= 60))
      assert {:ok, _} = Core.JSONFile.decode(Core.JSONFile.encode(db))
    end

    test "a folder set wins over one made from another list's name", ctx do
      {:ok, db} = Core.set_blog_list(ctx.db, ctx.links, %{slug: "devlog"})
      slugs = Map.new(Core.blog_lists(db, @today), &{&1.category, &1.slug})
      assert slugs[ctx.links] == "devlog"
      assert slugs[ctx.devlog] == "devlog-2"
    end

    test "a list named Posts leaves the posts' own folder to them", ctx do
      {:ok, db} = Core.set_blog_list(ctx.db, ctx.devlog, %{slug: "posts"})
      paths = paths(Core.site(db, @today))
      refute Enum.any?(paths, &String.starts_with?(&1, "posts-2/"))
      assert "posts/index.html" in paths
    end

    test "a crafted folder in the file is not used when building", ctx do
      db = ctx.db
      crafted = put_in(db.blog.lists[ctx.devlog], %BlogList{slug: "../x"})
      refute Enum.any?(Core.site(crafted, @today), &(elem(&1, 0) =~ ".."))
    end

    test "the category's own name as a title follows a rename", ctx do
      {:ok, db} = Core.set_blog_list(ctx.db, ctx.devlog, %{title: "Devlog"})
      assert db.blog.lists[ctx.devlog].title == ""
    end
  end

  defp db_main(ctx), do: ctx.db.main_id
end
