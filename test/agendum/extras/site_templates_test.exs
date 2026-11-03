# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Extras.SiteTemplatesTest do
  @moduledoc """
  The site's templates and assets (R74; plans/archive/PUBLISHER.md step 3,
  meeting 2026-11-02-1255, § 7): the pages are drawn from the folder's
  `templates/` (Agendum's own where one is missing, written there for the
  person to change, never uploaded), and `assets/` is copied as it is.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Extras.Publish

  @today ~D[2026-11-02]
  @moduletag :tmp_dir

  setup do
    db = Core.new_file()
    {:ok, db, posts} = Core.add_category(db, db.main_id, "Posts")
    {db, _} = Core.add_item(db, "Hello, Wood", ~D[2026-10-01], section: posts)
    {:ok, db} = Core.set_blog(db, %{posts: posts, title: "Owl's Notes"})
    {:ok, db, _} = Core.prepare_publish(db, %{})
    %{db: db}
  end

  defp file(files, path), do: files |> List.keyfind(path, 0) |> elem(1)
  defp inputs(templates, assets \\ []), do: %{templates: templates, assets: assets}

  test "Agendum's own templates give the site as before", %{db: db} do
    assert Core.site(db, @today, inputs(%{})) == {:ok, Core.site(db, @today)}
  end

  test "a template of the folder's draws the pages; the others stay Agendum's", %{db: db} do
    menu = ~s(<nav><a href="{{root}}index.html">Home</a></nav>\n)
    {:ok, files} = Core.site(db, @today, inputs(%{"menu" => menu}))

    assert file(files, "index.html") =~
             ~s(</header><nav><a href="index.html">Home</a></nav>\n<main)

    post = Enum.find(files, &String.starts_with?(elem(&1, 0), "posts/")) |> elem(1)
    assert post =~ ~s(<nav><a href="../index.html">Home</a></nav>)
  end

  test "a whole new layout: the site's values, and each page's body as content", %{db: db} do
    layout = "<html>{{page.title}}|{{site.title}}|{{{content}}}</html>\n"
    {:ok, files} = Core.site(db, @today, inputs(%{"layout" => layout}))
    assert file(files, "index.html") =~ ~r/^<html>Owl's Notes\|Owl's Notes\|<main class="h-feed">/
  end

  test "a template's mistake stops publishing, saying where", %{db: db} do
    assert {:error, {:template, "post", 3, {:not_closed, "post"}}} =
             Core.site(db, @today, inputs(%{"post" => "<main>\n\n{{#post}}\n"}))

    assert {:error, {:template, "layout", nil, {:no_partial, "footer"}}} =
             Core.site(db, @today, inputs(%{"layout" => "{{> footer}}"}))
  end

  test "assets are files of the site as they are; a name the web cannot carry is refused", %{
    db: db
  } do
    image = <<137, 80, 78, 71, 0, 1, 2>>
    {:ok, files} = Core.site(db, @today, inputs(%{}, [{"assets/me.png", image}]))
    assert file(files, "assets/me.png") == image

    assert {:error, {:asset_name, "assets/my photo.png"}} =
             Core.site(db, @today, inputs(%{}, [{"assets/my photo.png", image}]))
  end

  describe "the folder" do
    test "its templates and assets are read; hidden files, links and other files are not",
         %{tmp_dir: dir} do
      File.mkdir_p!(Path.join(dir, "templates"))
      File.write!(Path.join(dir, "templates/menu.html"), "<nav/>")
      File.write!(Path.join(dir, "templates/notes.txt"), "not a template")
      File.mkdir_p!(Path.join(dir, "assets/img"))
      File.write!(Path.join(dir, "assets/img/me.png"), "png")
      File.write!(Path.join(dir, "assets/.DS_Store"), "hidden")
      File.ln_s!("/etc/hosts", Path.join(dir, "assets/hosts"))

      assert {:ok, %{templates: %{"menu" => "<nav/>"}, assets: [{"assets/img/me.png", "png"}]}} =
               Publish.inputs(dir)
    end

    test "templates/rss.xml is read by its whole name, and written where missing", %{
      tmp_dir: dir
    } do
      File.mkdir_p!(Path.join(dir, "templates"))
      File.write!(Path.join(dir, "templates/rss.xml"), "<rss/>")
      assert {:ok, %{templates: %{"rss.xml" => "<rss/>"}}} = Publish.inputs(dir)

      File.rm!(Path.join(dir, "templates/rss.xml"))
      {:ok, scan} = Publish.scan(dir, [])
      assert "templates/rss.xml" in scan.templates_missing
    end

    test "a list's own templates are read from templates/<folder>/, by folder and name", %{
      tmp_dir: dir
    } do
      File.mkdir_p!(Path.join(dir, "templates/gym/deeper"))
      File.write!(Path.join(dir, "templates/gym/index.html"), "<table/>")
      File.write!(Path.join(dir, "templates/gym/rss.xml"), "<rss/>")
      File.write!(Path.join(dir, "templates/gym/deeper/x.html"), "not read")
      File.ln_s!("/etc/hosts", Path.join(dir, "templates/gym/item.html"))

      assert {:error, "templates/gym/item.html is a link; put the template itself there"} =
               Publish.inputs(dir)

      File.rm!(Path.join(dir, "templates/gym/item.html"))

      assert {:ok, %{templates: %{"gym/index" => "<table/>", "gym/rss.xml" => "<rss/>"} = t}} =
               Publish.inputs(dir)

      assert map_size(t) == 2
    end

    test "a folder without them has none", %{tmp_dir: dir} do
      assert Publish.inputs(dir) == {:ok, %{templates: %{}, assets: []}}
    end

    test "Agendum's templates are written where missing; one that is there stays", %{
      tmp_dir: dir
    } do
      File.mkdir_p!(Path.join(dir, "templates"))
      File.write!(Path.join(dir, "templates/menu.html"), "mine")

      assert :ok = Publish.write_templates(dir, Core.site_default_templates())
      assert File.read!(Path.join(dir, "templates/menu.html")) == "mine"
      assert File.read!(Path.join(dir, "templates/post.html")) =~ "{{#post}}"

      assert {:ok, %{templates_missing: []}} = Publish.scan(dir, [])
    end

    test "the scan names the templates it would write", %{tmp_dir: dir} do
      {:ok, scan} = Publish.scan(dir, [])
      assert "templates/layout.html" in scan.templates_missing
    end
  end

  describe "found in review" do
    test "a post's address never lands in templates/ or assets/", %{db: db} do
      {:ok, db} = Core.set_blog(db, %{address: "{slug}/index.html"})
      db = Core.set_note(db, Enum.at(Core.blog_posts(db), 0).id, "# Templates\n", @today)
      paths = for {path, _} <- Core.site(db, @today), do: path
      assert "templates-2/index.html" in paths
      refute Enum.any?(paths, &String.starts_with?(&1, "templates/"))
    end

    test "an asset deleted from the folder is removed from the site too" do
      changes =
        Core.site_changes([{"index.html", "x"}], %{"index.html" => "x"}, [
          "index.html",
          "assets/old.png"
        ])

      assert changes.removed == ["assets/old.png"]
    end

    test "a template that is a link, or too big, stops publishing and says so", %{tmp_dir: dir} do
      File.mkdir_p!(Path.join(dir, "templates"))
      File.ln_s!("/etc/hosts", Path.join(dir, "templates/post.html"))
      assert {:error, "templates/post.html is a link" <> _} = Publish.inputs(dir)

      File.rm!(Path.join(dir, "templates/post.html"))
      File.write!(Path.join(dir, "templates/post.html"), String.duplicate("x", 1_000_001))
      assert {:error, "templates/post.html is larger than 1 MB"} = Publish.inputs(dir)
    end

    test "an asset is not read twice: the scan takes it as read", %{tmp_dir: dir} do
      File.mkdir_p!(Path.join(dir, "assets"))
      File.write!(Path.join(dir, "assets/me.png"), "png")
      {:ok, scan} = Publish.scan(dir, [{"assets/me.png", "png"}])
      assert scan.existing["assets/me.png"] == "png"
    end
  end

  test "a menu.html still as Agendum 0.81 wrote it is replaced; one changed stays", %{
    tmp_dir: dir
  } do
    old = File.read!("lib/agendum/core/extras/site_assets/templates/menu-0.81.html")
    File.mkdir_p!(Path.join(dir, "templates"))
    File.write!(Path.join(dir, "templates/menu.html"), old)

    {:ok, scan} = Publish.scan(dir, [])
    assert "templates/menu.html" in scan.templates_missing
    assert {:ok, %{templates: templates}} = Publish.inputs(dir)
    refute Map.has_key?(templates, "menu")

    :ok = Publish.write_templates(dir, Core.site_default_templates())
    assert File.read!(Path.join(dir, "templates/menu.html")) =~ "has_pages"

    File.write!(Path.join(dir, "templates/menu.html"), old <> "<nav>mine</nav>")
    :ok = Publish.write_templates(dir, Core.site_default_templates())
    assert File.read!(Path.join(dir, "templates/menu.html")) =~ "<nav>mine</nav>"
  end
end
