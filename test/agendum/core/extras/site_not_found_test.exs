# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.SiteNotFoundTest do
  @moduledoc """
  The 404 page (R74d; plans/PUBLISHER_2.md step 5, meeting 2026-11-02-1954,
  § 13, the owner's choices of 2026-11-03): `404.html`, always written,
  drawn from the `404.html` template, which GitHub Pages and most servers
  show for an address that leads nowhere. It says the page is not here,
  links home (and the archive), and lists the five newest posts; as a
  server shows it at any address, its links start with the Base address.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core

  @today ~D[2026-11-03]

  setup do
    db = Core.new_file()
    {:ok, db, posts} = Core.add_category(db, db.main_id, "Posts")

    db =
      Enum.reduce(1..7, db, fn n, db ->
        elem(Core.add_item(db, "Post #{n}", Date.add(~D[2026-10-01], n), section: posts), 0)
      end)

    {:ok, db} =
      Core.set_blog(db, %{posts: posts, title: "Owl", base_url: "https://owl.example/blog/"})

    {:ok, db, _} = Core.prepare_publish(db, %{})
    %{db: Core.record_published(db, @today)}
  end

  defp file(files, path), do: files |> List.keyfind(path, 0) |> elem(1)

  test "404.html says the page is not here, links home and the five newest", %{db: db} do
    page = Core.site(db, @today) |> file("404.html")
    assert page =~ "This page is not here"
    assert page =~ ~s(<a href="https://owl.example/blog/index.html">← Owl</a>)
    assert page =~ ~s(href="https://owl.example/blog/style.css")

    for n <- 3..7,
        do:
          assert(page =~ ~r{<a href="https://owl.example/blog/posts/[a-z]+\.html">Post #{n}</a>})

    refute page =~ "Post 2"
    refute page =~ "All posts"
  end

  test "it links the archive when there is one", %{db: db} do
    {:ok, db} = Core.set_blog(db, %{newest: 3})
    page = Core.site(db, @today) |> file("404.html")
    assert page =~ ~s(<a href="https://owl.example/blog/archive.html">All posts</a>)
  end

  test "without a Base address its links are from the site's top folder", %{db: db} do
    {:ok, db} = Core.set_blog(db, %{base_url: ""})
    page = Core.site(db, @today) |> file("404.html")
    assert page =~ ~s(<a href="index.html">← Owl</a>)
    assert page =~ ~s(href="style.css")
  end

  test "404.html is a template Agendum writes for the person; a post never takes it", %{db: db} do
    assert List.keymember?(Core.site_default_templates(), "templates/404.html", 0)

    {:ok, files} =
      Core.site(db, @today, %{templates: %{"404" => "<p>Lost, {{site.title}}?</p>\n"}, assets: []})

    assert file(files, "404.html") =~ "<p>Lost, Owl?</p>"

    {:ok, db} = Core.set_blog(db, %{address: "{slug}.html"})
    {db, item} = Core.add_item(db, "404", @today, section: db.blog.posts)
    {:ok, db, _} = Core.prepare_publish(db, %{})
    db = Core.record_published(db, @today)
    refute Core.Extras.Blog.record(db, item).path == "404.html"
  end

  test "a page published at 404.html before keeps it; the 404 page is not written over it", %{
    db: db
  } do
    [post | _] = Core.blog_posts(db)
    db = put_in(db.blog.published[post.id], %Core.Extras.PostRecord{path: "404.html", print: 0})
    files = Core.site(db, @today)
    assert Enum.count(files, &(elem(&1, 0) == "404.html")) == 1
    refute file(files, "404.html") =~ "This page is not here"
  end
end
