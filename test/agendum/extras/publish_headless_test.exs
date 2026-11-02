# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Extras.PublishHeadlessTest do
  @moduledoc """
  Publishing a blog without the screen (R74; plans/archive/PUBLISHER.md step 7):
  `mix agendum.publish FILE` and `agendum --publish FILE`, as Extras ▸
  Publish ▸ Publish and its preview's ENTER.
  """
  use ExUnit.Case, async: true

  alias Agendum.{Core, Preferences, Store}
  alias Agendum.Core.Extras.Upload
  alias Agendum.Extras.Publish.Headless

  @today ~D[2026-11-02]
  @moduletag :tmp_dir

  setup %{tmp_dir: dir} do
    db = Core.new_file()
    {:ok, db, posts} = Core.add_category(db, db.main_id, "Posts")
    {db, _} = Core.add_item(db, "Hello, Wood", ~D[2026-10-01], section: posts)
    {db, later} = Core.add_item(db, "Soon", ~D[2026-10-02], section: posts)
    db = Core.set_date(db, later, db.special.when, ~D[2026-12-24])
    {:ok, db} = Core.set_blog(db, %{posts: posts, title: "Owl's Notes"})
    path = Path.join(dir, "blog.agendum")
    :ok = Store.save(db, path)
    prefs = Preferences.put_upload(%Preferences{extras: true}, path, %Upload{folder: "out"})
    %{path: path, prefs: prefs, site: Path.join(dir, "out")}
  end

  test "writes the site into the person's folder and saves what publishing keeps", ctx do
    assert {:ok, lines} = Headless.run(ctx.path, ctx.prefs, @today)
    assert List.last(lines) =~ "Published: "
    assert Enum.any?(lines, &(&1 =~ "1 post waits for its day"))
    assert File.read!(Path.join(ctx.site, "index.html")) =~ "Hello, Wood"
    assert File.exists?(Path.join(ctx.site, "templates/post.html"))

    {:ok, saved} = Store.load(ctx.path)
    post = Enum.find(Core.blog_posts(saved), &(&1.text == "Hello, Wood"))
    assert saved.blog.published[post.id].path == "posts/#{Core.zettel(post)}.html"
  end

  test "--preview says what would change and writes nothing", ctx do
    before = File.read!(ctx.path)
    assert {:ok, lines} = Headless.run(ctx.path, ctx.prefs, @today, preview: true)
    assert Enum.any?(lines, &(&1 =~ "+ index.html"))
    refute File.exists?(ctx.site)
    assert File.read!(ctx.path) == before
  end

  test "publishing again, with nothing new, leaves the file as it is", ctx do
    {:ok, _} = Headless.run(ctx.path, ctx.prefs, @today)
    stamp = Store.stamp(ctx.path)
    {:ok, lines} = Headless.run(ctx.path, ctx.prefs, @today)
    assert List.last(lines) =~ "0 added, 0 changed, 0 removed"
    assert Store.stamp(ctx.path) == stamp
  end

  test "the path as typed, without the extension, is the file", ctx do
    assert {:ok, _} = Headless.run(Path.rootname(ctx.path), ctx.prefs, @today, preview: true)
  end

  test "a file with a password, or with no blog, is refused, saying why", ctx do
    {:ok, db} = Store.load(ctx.path)
    locked = Path.join(Path.dirname(ctx.path), "locked.agendum")
    :ok = Store.save(%{db | password: "Hoot"}, locked)
    assert {:error, message} = Headless.run(locked, ctx.prefs, @today)
    assert message =~ "has a password"

    bare = Path.join(Path.dirname(ctx.path), "bare.agendum")
    :ok = Store.save(Core.new_file(), bare)
    assert {:error, message} = Headless.run(bare, ctx.prefs, @today)
    assert message =~ "no posts category"
  end

  test "a template's mistake stops it, saying where; nothing is written", ctx do
    File.mkdir_p!(Path.join(ctx.site, "templates"))
    File.write!(Path.join(ctx.site, "templates/post.html"), "{{#post}}")
    assert {:error, message} = Headless.run(ctx.path, ctx.prefs, @today)
    assert message =~ "templates/post.html line 1"
    refute File.exists?(Path.join(ctx.site, "index.html"))
  end

  test "an image's missing asset stops it, saying which and where; once there, it goes out",
       ctx do
    {:ok, db} = Store.load(ctx.path)
    post = Enum.find(Core.blog_posts(db), &(&1.text == "Hello, Wood"))
    :ok = Store.save(Core.set_note(db, post.id, "![Owl](assets/owl.png)", @today), ctx.path)

    assert {:error, message} = Headless.run(ctx.path, ctx.prefs, @today)

    assert message ==
             "assets/owl.png, an image in Hello, Wood, is not in the site folder's assets/"

    refute File.exists?(Path.join(ctx.site, "index.html"))

    File.mkdir_p!(Path.join(ctx.site, "assets"))
    File.write!(Path.join(ctx.site, "assets/owl.png"), "png")
    assert {:ok, _lines} = Headless.run(ctx.path, ctx.prefs, @today)

    assert File.read!(Path.join(ctx.site, "index.html")) =~
             ~s(<img src="assets/owl.png" alt="Owl">)
  end

  test "the binary's --publish flag is read; a mistyped or lone flag is refused" do
    assert {:publish, "blog", true} =
             Agendum.CLI.parse_args(["--publish", "blog", "--preview"], %{})

    assert {:error, "Unknown option: --previw" <> _} =
             Agendum.CLI.parse_args(["--publish", "blog", "--previw"], %{})

    assert {:error, "--preview goes with --publish FILE"} =
             Agendum.CLI.parse_args(["--preview", "blog"], %{})

    assert {:error, "--publish takes one file" <> _} =
             Agendum.CLI.parse_args(["--publish", "a", "b"], %{})
  end

  describe "found in review" do
    test "with the extras off, publishing is not there", ctx do
      assert {:error, "Publishing is one of the extras" <> _} =
               Headless.run(ctx.path, %{ctx.prefs | extras: false}, @today)
    end

    test "an older file's upload settings move to the preferences, not lost", %{tmp_dir: dir} do
      # the format 46 golden file still holds them in its blog
      path = Path.join(dir, "old.agendum")
      File.cp!("test/fixtures/formats/v46.agendum", path)
      prefs_path = Path.join(dir, "preferences")
      prefs = %Preferences{extras: true, path: prefs_path}

      # stopped by a template's mistake, after the move and before any
      # upload: no test reaches out to a server
      File.mkdir_p!(Path.join(dir, "site/templates"))
      File.write!(Path.join(dir, "site/templates/post.html"), "{{#post}}")
      assert {:error, "templates/post.html" <> _} = Headless.run(path, prefs, @today)

      kept = Preferences.load(prefs_path)
      assert %Upload{method: :sftp, target: "owl.example:2222"} = Preferences.upload(kept, path)
    end

    test "a failed upload still saves what publishing keeps", ctx do
      prefs =
        Preferences.put_upload(ctx.prefs, ctx.path, %Upload{
          folder: "out",
          method: :rsync,
          target: "-bad"
        })

      assert {:error, "Written, not uploaded: " <> _} = Headless.run(ctx.path, prefs, @today)
      {:ok, saved} = Store.load(ctx.path)
      assert saved.blog.published != %{}
    end

    test "without a Base address it says so, as the screen does", ctx do
      {:ok, lines} = Headless.run(ctx.path, ctx.prefs, @today)
      assert List.last(lines) =~ "The feeds need a Base address"
    end

    test "a blog whose categories went wrong says so, never crashes", ctx do
      {:ok, db} = Store.load(ctx.path)
      {:ok, db, pages} = Core.add_category(db, db.blog.posts, "Pages")
      :ok = Store.save(put_in(db.blog.pages, pages), ctx.path)

      assert {:error, "The posts, drafts and pages categories must differ" <> _} =
               Headless.run(ctx.path, ctx.prefs, @today)
    end
  end
end
