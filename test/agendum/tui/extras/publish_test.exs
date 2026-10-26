defmodule Agendum.TUI.Extras.PublishTest do
  @moduledoc "File ▸ Transfer ▸ Publish: the micro-blog's boxes (R74)."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.TUI.{State, Update}

  # a file with a Posts category holding two items, one with a note
  setup do
    db = Core.new_file()
    {:ok, db, posts} = Core.add_category(db, db.main_id, "Posts")
    {db, hello} = Core.add_item(db, "Hello, Wood", ~D[2026-10-01], section: posts)
    db = Core.set_note(db, hello, "First *post*.", ~D[2026-10-01])
    {db, _} = Core.add_item(db, "Party", ~D[2026-10-03], section: posts)
    Process.delete(:effects_seen)
    %{state: start(db, extras: true), hello: hello}
  end

  defp open(state), do: press(state, [{:f, 10}, "f", "t", "p"])
  defp type(state, text), do: press(state, String.graphemes(text) ++ [:enter])

  defp scan_effect do
    Enum.find(effects(), &match?({:publish_scan, _, _}, &1))
  end

  test "the box shows the file's settings, Posts and the folder by default", %{state: state} do
    state = open(state)
    assert screen(state) =~ "Publish the blog"
    assert screen(state) =~ ~r/Posts category : Posts/
    assert screen(state) =~ ~r/Folder\s*: site/
    assert screen(state) =~ ~r/Upload\s*: None/
    # the server's rows only for a way of uploading that needs them
    refute screen(state) =~ "Upload to"
  end

  test "ESC closes it and changes nothing", %{state: state} do
    after_ = state |> open() |> to_setting("Site title") |> type("Owl") |> press(:esc)
    assert after_.db == state.db
    refute match?(%{type: :publish}, State.mode(after_))
  end

  test "ENTER keeps the settings, gives the posts ids and reads the folder", %{state: state} do
    state = state |> open() |> to_setting("Site title") |> type("Owl's Notes") |> press(:enter)

    assert state.db.blog.title == "Owl's Notes"
    assert state.db.blog.posts == hd(Database.find_categories(state.db, "Posts"))
    assert Enum.all?(Core.blog_posts(state.db), & &1.zettel)
    assert {:publish_scan, "site", files} = scan_effect()
    assert List.keymember?(files, "posts/bonalaku.html", 0)
    # one change, one undo step
    assert Agendum.TUI.History.undo(state).db.blog.title == ""
  end

  test "SPACE on Upload chooses rsync, then SFTP, and shows their rows", %{state: state} do
    state = state |> open() |> to_setting("Upload") |> press(" ")
    assert screen(state) =~ "rsync over ssh"
    assert screen(state) =~ "Upload to"
    refute screen(state) =~ "Folder on server"

    state = press(state, " ")
    assert screen(state) =~ "SFTP"
    assert screen(state) =~ "Folder on server"
  end

  describe "the preview" do
    setup %{state: state} do
      state = state |> open() |> press(:enter)
      {:publish_scan, folder, files} = scan_effect()
      empty = %{existing: %{}, published: []}
      %{state: Update.Results.publish_scanned(state, folder, files, {:ok, empty}), files: files}
    end

    test "shows what will be added before anything is written", %{state: state} do
      assert screen(state) =~ "Publish: what will change"
      assert screen(state) =~ "2 posts · 12 added, 0 changed, 0 removed"
      assert screen(state) =~ "+ posts/bonalaku.html"
      assert screen(state) =~ "Written to site; not uploaded."
    end

    test "ENTER writes and uploads; the result is said", %{state: state} do
      Process.delete(:effects_seen)
      state = press(state, :enter)

      assert {:publish, "site", _files, changes, nil} =
               Enum.find(effects(), &(elem(&1, 0) == :publish))

      state = Update.Results.published(state, changes, :ok)
      assert State.mode(state) == nil
      assert screen(state) =~ "Published: 12 added, 0 changed, 0 removed"
    end

    test "ESC writes nothing", %{state: state} do
      Process.delete(:effects_seen)
      state = press(state, :esc)
      refute Enum.any?(effects(), &(elem(&1, 0) == :publish))
      assert screen(state) =~ "Nothing was published"
    end

    test "an SFTP server that wants a password asks, in stars, and tries again", %{state: state} do
      changes = State.mode(state).changes
      state = Update.Results.published(state, changes, {:error, :password})
      assert screen(state) =~ "(not kept)"

      Process.delete(:effects_seen)
      state = press(state, ["h", "o", "n", "e", "y"])
      assert screen(state) =~ "*****"
      refute screen(state) =~ "honey"

      press(state, :enter)
      assert {:publish, _, _, _, "honey"} = Enum.find(effects(), &(elem(&1, 0) == :publish))
    end

    test "an error is said, and the preview closes", %{state: state} do
      changes = State.mode(state).changes
      state = Update.Results.published(state, changes, {:error, "rsync is not installed"})
      assert screen(state) =~ "Not published: rsync is not installed"
      assert State.mode(state) == nil
    end
  end

  test "the publish effects are logged without the files' contents or the password" do
    changes = %{added: ["a"], changed: [], removed: []}

    text =
      Agendum.TUI.DebugLog.effect_text(
        {:publish, "site", [{"a", "secret page"}], changes, "honey"},
        3
      )

    refute text =~ "honey"
    refute text =~ "secret page"
    assert text =~ "with a password"
  end
end
