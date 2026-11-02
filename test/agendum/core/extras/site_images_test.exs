# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.SiteImagesTest do
  @moduledoc """
  Images from the site folder's `assets/` in posts and pages (R74c;
  plans/PUBLISHER_2.md step 2, meeting 2026-11-02-1954, § 6; the owner's
  choices, 2026-11-02): `![alt](assets/owl.jpg)` is written from the site's
  root, and each page gets the address that leads there from it; an image
  naming an asset that is not there stops publishing, saying which and
  where. An image without alt text is allowed (`alt=""`).
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.Extras.Markdown

  @today ~D[2026-11-02]
  @png <<137, 80, 78, 71, 0, 1, 2>>

  setup do
    db = Core.new_file()
    {:ok, db, posts} = Core.add_category(db, db.main_id, "Posts")
    {:ok, db, devlog} = Core.add_category(db, posts, "Devlog")
    {:ok, db, pages} = Core.add_category(db, db.main_id, "Pages")
    {db, hello} = Core.add_item(db, "Hello, Wood", ~D[2026-10-01], section: devlog)
    db = Core.set_note(db, hello, "Me by the tree: ![Owl](assets/img/owl.png)", @today)
    {db, about} = Core.add_item(db, "About", ~D[2026-10-02], section: pages)
    db = Core.set_note(db, about, "![](assets/img/owl.png)", @today)

    {:ok, db} =
      Core.set_blog(db, %{
        posts: posts,
        pages: pages,
        title: "Owl's Notes",
        base_url: "https://owl.example/"
      })

    {:ok, db, _} = Core.prepare_publish(db, %{})
    %{db: db, hello: hello, about: about}
  end

  defp file(files, path), do: files |> List.keyfind(path, 0) |> elem(1)
  defp inputs(assets), do: %{templates: %{}, assets: assets}
  defp site(db), do: Core.site(db, @today, inputs([{"assets/img/owl.png", @png}]))

  describe "Markdown" do
    test "an image from assets/ is read; its path is kept for the site to place" do
      assert Markdown.to_html("![Owl](assets/owl.png)") ==
               ~s(<p><img src="assets/owl.png" alt="Owl"></p>)
    end

    test "an image without alt text has an empty alt" do
      assert Markdown.to_html("![](assets/owl.png)") ==
               ~s(<p><img src="assets/owl.png" alt=""></p>)
    end

    test "only assets/ and whole web addresses are images; other paths stay text" do
      for text <- ["![x](owl.png)", "![x](/assets/owl.png)", "![x](assets/my owl.png)"] do
        refute Markdown.to_html(text) =~ "<img"
      end
    end

    test "a huge or unclosed asset path is text, quickly" do
      long = String.duplicate("a", 600)
      refute Markdown.to_html("![x](assets/#{long}.png)") =~ "<img"
      unclosed = String.duplicate("![x](assets/aaaa ", 20_000)
      {time, _} = :timer.tc(fn -> Markdown.to_html(unclosed) end)
      assert time < 2_000_000
    end

    test "the assets a text's images name, in order, once each" do
      text =
        "![a](assets/a.png) ![b](https://x.example/b.png) ![a](assets/a.png)\n\n![c](assets/c.png)"

      assert Markdown.assets(text) == ["assets/a.png", "assets/c.png"]
    end

    test "an image written in a code span or block, or escaped, names no asset" do
      assert Markdown.assets("`![a](assets/a.png)`\n\n```\n![b](assets/b.png)\n```") == []
      assert Markdown.assets("\\![a](assets/a.png)") == []
    end
  end

  describe "the site" do
    test "each page gets the address from where it is", %{db: db} do
      {:ok, files} = site(db)
      # the main index is at the root
      assert file(files, "index.html") =~ ~s(<img src="assets/img/owl.png" alt="Owl">)
      # the feed's index is one folder down
      assert file(files, "devlog/index.html") =~ ~s(<img src="../assets/img/owl.png" alt="Owl">)
      # the post's own page, in posts/
      post = Enum.find(files, &String.starts_with?(elem(&1, 0), "posts/")) |> elem(1)
      assert post =~ ~s(<img src="../assets/img/owl.png" alt="Owl">)
      # a page at the root, without alt text
      assert file(files, "about.html") =~ ~s(<img src="assets/img/owl.png" alt="">)
    end

    test "a post deeper in folders goes back up each one", %{db: db} do
      {:ok, db} = Core.set_blog(db, %{address: "{year}/{month}/{day}-{slug}.html"})
      {:ok, files} = site(db)
      {_path, post} = Enum.find(files, fn {p, _} -> String.starts_with?(p, "2026/") end)
      assert post =~ ~s(<img src="../../assets/img/owl.png")
    end

    test "the feeds give the whole address", %{db: db} do
      {:ok, files} = site(db)
      assert file(files, "rss.xml") =~ "https://owl.example/assets/img/owl.png"
      assert file(files, "devlog/feed.json") =~ "https://owl.example/assets/img/owl.png"
      refute file(files, "rss.xml") =~ ~s(src=&quot;assets/)
    end

    test "without a base address the feeds keep the address from the site's root", %{db: db} do
      {:ok, db} = Core.set_blog(db, %{base_url: ""})
      {:ok, files} = site(db)
      assert file(files, "feed.json") =~ ~s(src=\\"assets/img/owl.png\\")
    end

    test "an image naming an asset that is not there stops publishing, saying which and where",
         %{db: db} do
      assert {:error, {:missing_asset, "assets/img/owl.png", "Hello, Wood"}} =
               Core.site(db, @today, inputs([]))
    end

    test "a title is read as its page shows it", %{db: db, hello: hello} do
      # a code fence at the start of a note is a block; in a title it is not
      db = Core.set_note(db, hello, "", @today)
      db = Core.edit_item(db, hello, "```![a](assets/none.png)", @today)

      assert {:error, {:missing_asset, "assets/none.png", _title}} = site(db)
    end

    test "a path leading out of assets/ is not there", %{db: db, hello: hello} do
      db = Core.set_note(db, hello, "![x](assets/../index.html)", @today)

      assert {:error, {:missing_asset, "assets/../index.html", "Hello, Wood"}} = site(db)
    end

    test "a draft's or a waiting post's image is not asked for", %{db: db, hello: hello} do
      db = Core.set_note(db, hello, "![x](assets/gone.png)", @today)
      db = Core.set_date(db, hello, db.special.when, ~D[2026-12-24])
      assert {:ok, _files} = site(db)
    end

    test "the site without inputs still builds, as before", %{db: db} do
      assert is_list(Core.site(db, @today))
    end
  end
end
