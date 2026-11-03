# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.SiteDesignTest do
  @moduledoc """
  The blog's design (R74; the owner, 2026-10-26): The Proportional Web by
  Oskar Wickström (MIT), with its fonts written into the site (no visitor
  contacts Google), dark when the reader's system is, and the old
  stylesheet replaced only when it is still exactly Agendum's.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.Extras.Site

  defp site do
    db = Core.new_file()
    {:ok, db, posts} = Core.add_category(db, db.main_id, "Posts")
    {db, _} = Core.add_item(db, "Hello from the Wood", ~D[2026-10-26], section: posts)
    {:ok, db} = Core.set_blog(db, %{posts: posts, title: "Owl"})
    {:ok, db, _} = Core.prepare_publish(db, %{})
    Core.site(db, ~D[2026-11-02])
  end

  test "the stylesheet is Wood & Amber, its fonts self-hosted, light or dark" do
    css = site() |> Map.new() |> Map.fetch!("style.css")
    assert css =~ "Wood & Amber"
    assert css =~ "@font-face"
    assert css =~ ~s{url("fonts/alegreya-latin-wght-normal.woff2")}
    assert css =~ ~s{url("fonts/inconsolata-latin-400-normal.woff2")}
    refute css =~ "googleapis"
    refute css =~ "@import"
    # dark when the reader's system is, unless the button says otherwise
    assert css =~ "prefers-color-scheme: dark"
    assert css =~ ~s{:root[data-theme="dark"]}
    assert css =~ ~s{:root:not([data-theme="light"])}
  end

  test "the layout's one script switches light and dark, its button hidden without it" do
    index = site() |> Map.new() |> Map.fetch!("index.html")
    assert index =~ ~s(<button type="button" id="theme-toggle" class="theme-toggle" hidden>)
    assert index =~ "localStorage"
    # one script, the theme switch's, and nothing loaded from elsewhere
    assert length(Regex.scan(~r/<script/, index)) == 1
    refute index =~ ~r/<script[^>]* src=/
    # the phone's Menu button needs no script
    assert index =~ ~s(<input type="checkbox" id="menu-open" class="menu-open">)
  end

  test "a site folder's assets/logo.* is shown beside the site's name; none, no picture" do
    db = Core.new_file()
    {:ok, db, posts} = Core.add_category(db, db.main_id, "Posts")
    {db, _} = Core.add_item(db, "Hello", ~D[2026-10-26], section: posts)
    {:ok, db} = Core.set_blog(db, %{posts: posts, title: "Owl"})
    {:ok, db, _} = Core.prepare_publish(db, %{})
    logo = %{templates: %{}, assets: [{"assets/logo.png", <<137, 80, 78, 71>>}]}
    {:ok, files} = Core.site(db, ~D[2026-11-02], logo)
    files = Map.new(files)
    assert files["index.html"] =~ ~s(<img class="logo" src="assets/logo.png" alt="")
    post = Enum.find_value(files, fn {path, text} -> if path =~ ~r{^posts/}, do: text end)
    assert post =~ ~s(<img class="logo" src="../assets/logo.png")
    refute Map.new(site())["index.html"] =~ ~s(class="logo")
  end

  test "templates and the stylesheet as Agendum 0.92 wrote them are replaced" do
    for name <- ~w(layout menu index post) do
      old = File.read!("lib/agendum/core/extras/site_assets/templates/#{name}-0.92.html")
      assert Site.legacy_template?("templates/#{name}.html", old), name
    end

    old = File.read!("lib/agendum/core/extras/site_assets/style-0.92.css")
    assert "style.css" in Core.site_changes(site(), %{"style.css" => old}, []).changed
  end

  test "the fonts and their licence are files of the site" do
    files = Map.new(site())

    for font <-
          ~w(alegreya-latin-wght-normal alegreya-latin-wght-italic alegreya-sc-latin-400-normal
                   alegreya-sc-latin-500-normal inconsolata-latin-400-normal
                   inconsolata-latin-700-normal courier-prime-latin-400-normal) do
      assert <<"wOF2", _::binary>> = Map.fetch!(files, "fonts/#{font}.woff2")
    end

    assert files["fonts/OFL.txt"] =~ "SIL Open Font License"
    assert files["fonts/OFL.txt"] =~ "The Inconsolata Project Authors"
  end

  test "the old stylesheet is replaced only when it is still exactly Agendum's" do
    files = site()
    new = Map.new(files)["style.css"]

    # still Agendum's old one: replaced
    old = %{"style.css" => Site.legacy_stylesheet()}
    assert "style.css" in Core.site_changes(files, old, []).changed

    # one the person changed: left alone
    theirs = %{"style.css" => Site.legacy_stylesheet() <> "\nbody { color: hotpink; }\n"}
    refute "style.css" in Core.site_changes(files, theirs, []).changed

    # the new one: nothing to do
    refute "style.css" in Core.site_changes(files, %{"style.css" => new}, []).changed
  end

  test "rsync and SFTP take the fonts folder along" do
    args = Agendum.Extras.Publish.rsync_args("me@host:www", "site", ["fonts/OFL.txt"])
    assert "--include=/fonts/" in args
  end
end
