# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Extras.PublishUploadTest do
  @moduledoc """
  Extras ▸ Publish ▸ Upload (R74; meeting 2026-11-02-1255, § 10): where
  the blog is written and how it is uploaded, kept in the person's
  preferences by the file's path, never in the file; an older file's
  settings move there as it opens.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.Core.Extras.Upload
  alias Agendum.{Preferences, Store}
  alias Agendum.TUI.{State, Update}

  @path "/Users/owl/blog.agendum"

  setup do
    db = Core.new_file()
    {:ok, db, posts} = Core.add_category(db, db.main_id, "Posts")
    {db, _} = Core.add_item(db, "Hello, Wood", ~D[2026-10-01], section: posts)
    {:ok, db} = Core.set_blog(db, %{posts: posts})
    Process.delete(:effects_seen)
    %{state: %{start(db, extras: true) | path: @path}}
  end

  defp upload_box(state), do: press(state, [{:f, 10}, "e", "p", "u"])
  defp type(state, text), do: press(state, String.graphemes(text) ++ [:enter])

  test "a file not saved yet is refused: the settings are kept by its name", %{state: state} do
    state = upload_box(%{state | path: nil})
    refute match?(%{type: :publish_upload}, State.mode(state))
    assert screen(state) =~ "Save the file first"
  end

  test "the box shows the folder site and no upload, and says whose they are", %{state: state} do
    state = upload_box(state)
    text = screen(state)
    assert text =~ "Publish: upload"
    assert text =~ ~r/Folder\s*: site/
    assert text =~ ~r/Upload\s*: None/
    refute text =~ "Upload to"
    assert text =~ "Yours, for blog.agendum on this computer; not kept in the file."
  end

  test "SPACE on Upload chooses rsync, then SFTP, and shows their rows", %{state: state} do
    state = state |> upload_box() |> to_setting("Upload") |> press(" ")
    assert screen(state) =~ "rsync over ssh"
    assert screen(state) =~ "Upload to"
    refute screen(state) =~ "Folder on server"

    state = press(state, " ")
    assert screen(state) =~ "SFTP"
    assert screen(state) =~ "Folder on server"
  end

  test "ENTER keeps them in the preferences, by the file's path; the file is unchanged", %{
    state: state
  } do
    state = %{state | prefs: %{state.prefs | path: "/prefs"}}

    after_ =
      state
      |> upload_box()
      |> to_setting("Upload")
      |> press(" ")
      |> to_setting("Upload to")
      |> type("owl@wood:www")
      |> press(:enter)

    assert Preferences.upload(after_.prefs, @path) ==
             %Upload{folder: "site", method: :rsync, target: "owl@wood:www"}

    assert after_.db == state.db

    assert {:save_preferences, "/prefs", _} =
             Enum.find(effects(), &match?({:save_preferences, _, _}, &1))

    assert screen(after_) =~ "Kept the upload settings for blog.agendum"
  end

  test "ESC changes nothing", %{state: state} do
    after_ = state |> upload_box() |> to_setting("Folder") |> type("www") |> press(:esc)
    assert after_.prefs == state.prefs
  end

  test "Publish writes to the person's folder, beside the file", %{state: state} do
    prefs = Preferences.put_upload(state.prefs, @path, %Upload{folder: "www"})
    press(%{state | prefs: prefs}, [{:f, 10}, "e", "p", "p"])

    assert {:publish_scan, "/Users/owl/www", _} =
             Enum.find(effects(), &match?({:publish_scan, _, _}, &1))
  end

  test "the preview says where the site goes, from the person's settings", %{state: state} do
    upload = %Upload{method: :sftp, target: "wood.example", user: "owl"}
    state = %{state | prefs: Preferences.put_upload(state.prefs, @path, upload)}
    state = press(state, [{:f, 10}, "e", "p", "p"])
    {:publish_scan, folder, files} = Enum.find(effects(), &match?({:publish_scan, _, _}, &1))

    state =
      Agendum.TUI.Extras.Publish.Results.publish_scanned(state, folder, files, {
        :ok,
        %{existing: %{}, published: []}
      })

    assert screen(state) =~ "then uploaded by SFTP to wood.example"
  end

  describe "an older file's settings" do
    @old %Upload{folder: "blog", method: :sftp, target: "wood.example", user: "owl"}

    test "move to the preferences as it opens, said once; the file stays unchanged", %{
      state: state
    } do
      db = %{state.db | blog: %{state.db.blog | moved_upload: @old}}
      prefs = %{state.prefs | path: "/prefs"}
      state = %{state | db: db, prefs: prefs, saved: %{state.saved | db: db}} |> Update.arrive()

      assert Preferences.upload(state.prefs, @path) == @old
      assert Enum.any?(state.effects, &match?({:save_preferences, "/prefs", _}, &1))
      refute state.dirty
      assert screen(state) =~ "moved to your preferences"
    end

    test "settings the person already has for the file are kept", %{state: state} do
      mine = %Upload{folder: "mine"}
      prefs = Preferences.put_upload(state.prefs, @path, mine)
      db = %{state.db | blog: %{state.db.blog | moved_upload: @old}}

      state =
        %{state | db: db, prefs: prefs, saved: %{state.saved | db: db}} |> Update.arrive()

      assert Preferences.upload(state.prefs, @path) == mine
    end

    @tag :tmp_dir
    test "the format 46 golden file holds them, and saving leaves them out", %{tmp_dir: dir} do
      {:ok, db} = Store.load("test/fixtures/formats/v46.agendum")

      assert db.blog.moved_upload ==
               %Upload{
                 folder: "site",
                 method: :sftp,
                 target: "owl.example:2222",
                 user: "owl",
                 remote_dir: "public_html"
               }

      path = Path.join(dir, "again.agendum")
      :ok = Store.save(db, path)
      assert {:ok, %{blog: %{moved_upload: nil}}} = Store.load(path)
    end
  end

  test "the preferences keep each file's settings on an upload line, read back the same" do
    prefs =
      %Preferences{}
      |> Preferences.put_upload("/a b/my=blog.agendum", %Upload{
        folder: "/Volumes/web site",
        method: :sftp,
        target: "host:2222",
        user: "owl",
        remote_dir: "www"
      })
      |> Preferences.put_upload("/other.agendum", %Upload{method: :rsync, target: "me@h:www"})

    text = Preferences.format(prefs)
    assert text =~ ~s(upload = {)
    assert Preferences.parse(text).uploads == prefs.uploads
  end

  test "an upload line that does not read, or names an unknown way, is ignored or None" do
    prefs =
      Preferences.parse("""
      upload = not json
      upload = {"folder":"x"}
      upload = {"file":"/f.agendum","method":"carrier_pigeon","folder":7}
      """)

    assert prefs.uploads == [{"/f.agendum", %Upload{}}]
  end

  test "an empty folder on an upload line reads as site, never the file's own folder" do
    prefs = Preferences.parse(~s(upload = {"file":"/a/b.agendum","folder":"  "}\n))
    assert Preferences.upload(prefs, "/a/b.agendum").folder == "site"
  end

  test "without a preferences file, the move says it lasts for this session", %{state: state} do
    old = %Upload{method: :rsync, target: "me@h:www"}
    db = %{state.db | blog: %{state.db.blog | moved_upload: old}}
    state = %{state | db: db, saved: %{state.saved | db: db}} |> Update.arrive()
    assert Preferences.upload(state.prefs, @path) == old
    assert screen(state) =~ "this session only"
  end

  test "saved under another name, the file's upload settings go with it", %{state: state} do
    mine = %Upload{method: :rsync, target: "me@h:www"}
    state = %{state | prefs: Preferences.put_upload(state.prefs, @path, mine)}

    saved =
      Agendum.TUI.Update.Results.saved(state, "/Users/owl/new.agendum", {:ok, nil}, %{then: nil})

    assert Preferences.upload(saved.prefs, "/Users/owl/new.agendum") == mine
    assert Preferences.upload(saved.prefs, @path) == mine
  end

  @tag :tmp_dir
  test "saving keeps the upload lines another session wrote for other files", %{tmp_dir: dir} do
    path = Path.join(dir, "preferences")
    other = %Preferences{} |> Preferences.put_upload("/other.agendum", %Upload{method: :sftp})
    :ok = Preferences.save(other, path)

    mine = %Preferences{} |> Preferences.put_upload("/mine.agendum", %Upload{folder: "www"})
    :ok = Preferences.save(mine, path)

    uploads = Preferences.load(path).uploads
    assert {"/mine.agendum", %Upload{folder: "www"}} in uploads
    assert {"/other.agendum", %Upload{method: :sftp}} in uploads
  end
end
