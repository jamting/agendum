# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.SiteRssTemplateTest do
  @moduledoc """
  The RSS feed as a template (R74c, R74e; plans/PUBLISHER_2.md, the
  owner's addendum to meeting 2026-11-02-2244, § 6): `templates/rss.xml`
  draws every RSS feed, Agendum's own giving what it wrote before; dates in
  RSS's form are a value of their own; and every feed written is read back
  before publishing, one that does not read stopping it.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.Extras.Site

  @today ~D[2026-11-02]

  setup do
    db = Core.new_file()
    {:ok, db, posts} = Core.add_category(db, db.main_id, "Posts")
    {:ok, db, devlog} = Core.add_category(db, posts, "Devlog")
    {db, _} = Core.add_item(db, "Owl's first post", ~D[2026-10-03], section: posts)
    {db, _} = Core.add_item(db, "Built the importer", ~D[2026-10-01], section: devlog)

    {:ok, db} =
      Core.set_blog(db, %{posts: posts, title: "Owl's Notes", base_url: "https://owl.example/"})

    # Devlog a list with everything on, as a feed of format 50 opens
    {:ok, db, _} = Core.add_blog_list(db, devlog)

    {:ok, db} =
      Core.set_blog_list(db, devlog, %{index: true, feeds: true, item_pages: true, notes: true})

    {:ok, db, _} = Core.prepare_publish(db, %{})
    %{db: db}
  end

  defp file(files, path), do: files |> List.keyfind(path, 0) |> elem(1)
  defp inputs(templates), do: %{templates: templates, assets: []}

  test "Agendum's own rss.xml is written for the person, and gives the feed as before" do
    assert {"templates/rss.xml", text} =
             List.keyfind(Site.default_templates(), "templates/rss.xml", 0)

    assert text =~ "{{#items}}"
  end

  test "the RSS feeds come from the template, the main one and a feed's", %{db: db} do
    {:ok, files} = Core.site(db, @today, inputs(%{}))
    rss = file(files, "rss.xml")

    # word for word as before: the apostrophe too, as XML has it
    assert rss =~ "<title>Owl&apos;s Notes</title>"
    assert rss =~ "<title>Owl&apos;s first post</title>"
    assert rss =~ "<pubDate>Sat, 03 Oct 2026 00:00:00 +0000</pubDate>"
    assert rss =~ ~s(<atom:link href="https://owl.example/rss.xml" rel="self")
    assert String.ends_with?(rss, "</channel>\n</rss>\n")
    assert file(files, "devlog/rss.xml") =~ "<title>Owl&apos;s Notes · Devlog</title>"

    mine = """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0"><channel><title>{{feed.title}}!</title>
    {{#items}}<item><title>{{title}}</title><link>{{url}}</link><pubDate>{{date_rss}}</pubDate></item>
    {{/items}}</channel></rss>
    """

    {:ok, files} = Core.site(db, @today, inputs(%{"rss.xml" => mine}))
    assert file(files, "rss.xml") =~ "<title>Owl&apos;s Notes!</title>"
    assert file(files, "devlog/rss.xml") =~ "<title>Owl&apos;s Notes · Devlog!</title>"
    # the JSON Feed stays Agendum's own
    assert file(files, "feed.json") =~ ~s("version":"https://jsonfeed.org/version/1.1")
  end

  test "a post's date in RSS's form is a value of the pages' templates too", %{db: db} do
    post = "{{#post}}<p>{{date_rss}}</p>{{/post}}\n"
    {:ok, files} = Core.site(db, @today, inputs(%{"post" => post}))
    page = Enum.find(files, &String.starts_with?(elem(&1, 0), "posts/")) |> elem(1)
    assert page =~ ~r/<p>(Sat, 03 Oct|Thu, 01 Oct) 2026 00:00:00 \+0000<\/p>/
  end

  test "a feed that does not read back stops publishing, saying which", %{db: db} do
    assert {:error, {:bad_feed, "rss.xml"}} =
             Core.site(db, @today, inputs(%{"rss.xml" => "Hello, Wood\n"}))

    # one that leaves posts out reads, but not as the feed it should be
    dropped = """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0"><channel><title>{{feed.title}}</title></channel></rss>
    """

    assert {:error, {:bad_feed, "rss.xml"}} =
             Core.site(db, @today, inputs(%{"rss.xml" => dropped}))
  end

  test "a mistake in rss.xml is said with its own name", %{db: db} do
    assert {:error, {:template, "rss.xml", 1, {:not_closed, "items"}} = error} =
             Core.site(db, @today, inputs(%{"rss.xml" => "{{#items}}"}))

    assert Agendum.TUI.Extras.Publish.Messages.site_error(error) ==
             "templates/rss.xml line 1: {{#items}} is not closed"

    assert Agendum.TUI.Extras.Publish.Messages.site_error({:bad_feed, "devlog/rss.xml"}) ==
             "devlog/rss.xml does not read back as a feed: look at its template"
  end
end
