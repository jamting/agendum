# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.SiteTagsTest do
  @moduledoc """
  Tag pages (R74e; plans/PUBLISHER_2.md step 6, meetings 2026-11-02-1954,
  § 13, and 2026-11-02-2244, § 7, the owner's choices of 2026-11-03): a
  list's switch Tag pages gives each of its category's children a page of
  its items (those in it or under it), titles by month as the archive, at
  `<folder>/<the child's name>.html`, following the name; an item's own
  page shows its tags, linked.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core

  @today ~D[2026-11-03]

  # Posts; a Tags family (Elixir, with OTP under it; Agenda; Empty) made a
  # list with Tag pages on
  setup do
    db = Core.new_file()
    {:ok, db, posts} = Core.add_category(db, db.main_id, "Posts")
    {:ok, db, tags} = Core.add_category(db, db.main_id, "Tags")
    {:ok, db, elixir} = Core.add_category(db, tags, "Elixir")
    {:ok, db, otp} = Core.add_category(db, elixir, "OTP")
    {:ok, db, agenda} = Core.add_category(db, tags, "Agenda")
    {:ok, db, _empty} = Core.add_category(db, tags, "Empty")
    {db, lists} = Core.add_item(db, "Lists are here", ~D[2026-11-03], section: posts)
    {db, genserver} = Core.add_item(db, "A GenServer", ~D[2026-10-14], section: posts)
    {db, other} = Core.add_item(db, "Untagged", ~D[2026-10-15], section: posts)

    db =
      db
      |> Core.assign(lists, elixir)
      |> Core.assign(lists, agenda)
      |> Core.assign(genserver, otp)

    {:ok, db} = Core.set_blog(db, %{posts: posts, title: "Owl", base_url: "https://owl.example/"})
    {:ok, db, _} = Core.add_blog_list(db, tags)
    {:ok, db} = Core.set_blog_list(db, tags, %{tag_pages: true})
    {:ok, db, _} = Core.prepare_publish(db, %{})
    db = Core.record_published(db, @today)
    %{db: db, tags: tags, elixir: elixir, lists: lists, genserver: genserver, other: other}
  end

  defp file(files, path), do: files |> List.keyfind(path, 0) |> elem(1)
  defp has?(files, path), do: List.keymember?(files, path, 0)

  defp page_of(db, files, item),
    do: file(files, Core.Extras.Site.post_path(db, db.items[item]))

  test "a new list has no tag pages" do
    refute %Core.Extras.BlogList{}.tag_pages
  end

  test "each child with items gets a page of them by month, a grandchild's too", %{db: db} do
    files = Core.site(db, @today)
    elixir = file(files, "tags/elixir.html")
    assert elixir =~ "<h1 class=\"p-name\">Tags · Elixir</h1>"
    assert elixir =~ "November 2026"
    assert elixir =~ ~r{<a href="../posts/[a-z]+\.html"[^>]*>Lists are here</a>}
    # in OTP, under Elixir
    assert elixir =~ "A GenServer"
    refute elixir =~ "Untagged"
    assert file(files, "tags/agenda.html") =~ "Lists are here"
    # no items, no page; a grandchild has none of its own
    refute has?(files, "tags/empty.html")
    refute has?(files, "tags/otp.html")
  end

  test "an item's own page shows its tags, linked", ctx do
    files = Core.site(ctx.db, @today)

    assert page_of(ctx.db, files, ctx.lists) =~
             ~s(<p class="tags">Tags: <a href="../tags/elixir.html" rel="tag">Elixir</a>) <>
               ~s( · <a href="../tags/agenda.html" rel="tag">Agenda</a></p>)

    assert page_of(ctx.db, files, ctx.genserver) =~
             ~s(<a href="../tags/elixir.html" rel="tag">Elixir</a>)

    refute page_of(ctx.db, files, ctx.other) =~ ~s(class="tags")
    # the index stays as it is
    refute file(files, "index.html") =~ ~s(class="tags")
  end

  test "a tag's page follows its name", ctx do
    {:ok, db} = Core.rename_category(ctx.db, ctx.elixir, "Erlang & Elixir")
    files = Core.site(db, @today)
    assert has?(files, "tags/erlang-elixir.html")
    refute has?(files, "tags/elixir.html")
  end

  test "a tag named as one of the list's own files takes the next name", ctx do
    {:ok, db} = Core.rename_category(ctx.db, ctx.elixir, "Index")
    files = Core.site(db, @today)
    assert has?(files, "tags/index-2.html")
    assert file(files, "tags/index.html") =~ ~s(<h1 class="p-name">Tags</h1>)
  end

  test "a list's own child.html draws its tag pages", ctx do
    {:ok, files} =
      Core.site(ctx.db, @today, %{
        templates: %{
          "tags/child" =>
            "<p>{{tag.title}}: {{#months}}{{#posts}}{{title}};{{/posts}}{{/months}}</p>\n"
        },
        assets: []
      })

    assert file(files, "tags/elixir.html") =~ "<p>Elixir: Lists are here;A GenServer;</p>"
  end

  test "with the list's index off, a tag page leads home instead", ctx do
    {:ok, db} = Core.set_blog_list(ctx.db, ctx.tags, %{index: false})
    files = Core.site(db, @today)
    refute has?(files, "tags/index.html")
    page = file(files, "tags/elixir.html")
    assert page =~ ~s(<p class="back"><a href="../index.html">← Owl</a></p>)
    refute page =~ ~s(href="index.html")
  end

  test "Tag pages off: none, and no tags on the pages", ctx do
    {:ok, db} = Core.set_blog_list(ctx.db, ctx.tags, %{tag_pages: false})
    files = Core.site(db, @today)
    refute has?(files, "tags/elixir.html")
    refute page_of(db, files, ctx.lists) =~ ~s(class="tags")
  end

  test "post.html and archive.html as Agendum 0.91 wrote them are replaced" do
    for {name, version} <- [{"post", "0.89"}, {"archive", "0.90"}] do
      old = File.read!("lib/agendum/core/extras/site_assets/templates/#{name}-#{version}.html")
      assert Core.Extras.Site.legacy_template?("templates/#{name}.html", old)
    end
  end
end
