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
    Core.site(db)
  end

  test "the stylesheet is The Proportional Web's, credited, with its fonts self-hosted" do
    css = site() |> Map.new() |> Map.fetch!("style.css")
    assert css =~ "Oskar Wickström"
    assert css =~ "MIT"
    assert css =~ "@font-face"
    assert css =~ ~s{url("fonts/alegreya-latin-wght-normal.woff2")}
    refute css =~ "googleapis"
    refute css =~ "@import"
    # dark when the reader's system is
    assert css =~ "prefers-color-scheme: dark"
  end

  test "the fonts and their licence are files of the site" do
    files = Map.new(site())

    for font <-
          ~w(alegreya-latin-wght-normal alegreya-latin-wght-italic alegreya-sc-latin-400-normal
                   alegreya-sc-latin-500-normal courier-prime-latin-400-normal) do
      assert <<"wOF2", _::binary>> = Map.fetch!(files, "fonts/#{font}.woff2")
    end

    assert files["fonts/OFL.txt"] =~ "SIL Open Font License"
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
