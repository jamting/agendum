# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Extras.PublishTest do
  @moduledoc "Extras ▸ Publish: the micro-blog's boxes (R74)."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.TUI.State

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

  # Extras ▸ Publish ▸ Publish: before the blog has settings, the Site box
  defp open(state), do: press(state, [{:f, 10}, "e", "p", "p"])
  defp type(state, text), do: press(state, String.graphemes(text) ++ [:enter])

  defp scan_effect do
    Enum.find(effects(), &match?({:publish_scan, _, _}, &1))
  end

  test "the first Publish opens the Site box: Posts by default, no upload rows", %{state: state} do
    state = open(state)
    assert screen(state) =~ "Publish: the site"
    assert screen(state) =~ ~r/Posts category : Posts/
    assert screen(state) =~ "ENTER shows what will change"
    # where it is written and uploaded is Publish ▸ Upload, the person's
    refute screen(state) =~ "Folder"
    refute screen(state) =~ "Upload"
  end

  test "ESC closes it and changes nothing", %{state: state} do
    after_ = state |> open() |> to_setting("Site title") |> type("Owl") |> press(:esc)
    assert after_.db == state.db
    refute match?(%{type: :publish}, State.mode(after_))
  end

  test "its ENTER keeps the settings, gives the posts ids and reads the folder", %{state: state} do
    state = state |> open() |> to_setting("Site title") |> type("Owl's Notes") |> press(:enter)

    assert state.db.blog.title == "Owl's Notes"
    assert state.db.blog.posts == hd(Database.find_categories(state.db, "Posts"))
    assert Enum.all?(Core.blog_posts(state.db), & &1.zettel)
    assert {:publish_scan, "site", files} = scan_effect()
    assert List.keymember?(files, "posts/bonalaku.html", 0)
    # one change, one undo step
    assert Agendum.TUI.History.undo(state).db.blog.title == ""
  end

  test "once the blog has settings, Publish goes straight to reading the folder", %{
    state: state
  } do
    state = state |> open() |> press(:enter) |> Agendum.TUI.Extras.PublishPreviewBox.done()
    Process.delete(:effects_seen)
    state = open(%{state | modes: []})
    refute match?(%{type: :publish}, State.mode(state))
    assert {:publish_scan, "site", _files} = scan_effect()
  end

  test "Site from the menu: ENTER keeps the settings and publishes nothing", %{state: state} do
    state = press(state, [{:f, 10}, "e", "p", "s"])
    assert screen(state) =~ "ENTER keeps the settings"
    state = state |> to_setting("Author") |> type("Owl") |> press(:enter)
    assert state.db.blog.author == "Owl"
    assert screen(state) =~ "Kept the site settings"
    refute scan_effect()
  end

  test "Site's Address takes a pattern; one that cannot work is refused, and says why", %{
    state: state
  } do
    site = press(state, [{:f, 10}, "e", "p", "s"])
    assert screen(site) =~ ~r/Address\s*: posts\/\{zettel\}\.html/

    kept = site |> to_setting("Address") |> press({:f, 2}) |> press({:ctrl, "u"})
    kept = kept |> type("{year}/{slug}.html") |> press(:enter)
    assert kept.db.blog.address == "{year}/{slug}.html"

    refused = site |> to_setting("Address") |> press({:f, 2}) |> press({:ctrl, "u"})
    refused = refused |> type("posts/{year}.html") |> press(:enter)
    assert refused.db.blog.address == "posts/{zettel}.html"
    assert screen(refused) =~ "needs {zettel} or {slug}"
  end

  test "the preview says when a post waits for its day", %{state: state} do
    {db, _} =
      Core.add_item(state.db, "Soon", ~D[2026-10-01],
        section: hd(Database.find_categories(state.db, "Posts"))
      )

    soon = Enum.max(Map.keys(db.items))
    db = Core.set_date(db, soon, db.special.when, Date.add(state.today, 3))
    state = %{state | db: db} |> open() |> press(:enter)
    {:publish_scan, folder, files} = scan_effect()

    state =
      Agendum.TUI.Extras.Publish.Results.publish_scanned(state, folder, files, {
        :ok,
        %{existing: %{}, published: []}
      })

    assert screen(state) =~ "1 post waits for its day"
    refute Enum.any?(files, &(elem(&1, 1) =~ "Soon"))
  end

  describe "the preview" do
    setup %{state: state} do
      state = state |> open() |> press(:enter)
      {:publish_scan, folder, files} = scan_effect()
      empty = %{existing: %{}, published: []}

      %{
        state:
          Agendum.TUI.Extras.Publish.Results.publish_scanned(state, folder, files, {:ok, empty}),
        files: files
      }
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

      state = Agendum.TUI.Extras.Publish.Results.published(state, changes, :ok)
      assert State.mode(state) == nil
      assert screen(state) =~ "Published: 12 added, 0 changed, 0 removed"
      # the file has no Base address, so the feeds' links are not whole
      assert screen(state) =~ "The feeds need a Base address"
    end

    test "ESC writes nothing", %{state: state} do
      Process.delete(:effects_seen)
      state = press(state, :esc)
      refute Enum.any?(effects(), &(elem(&1, 0) == :publish))
      assert screen(state) =~ "Nothing was published"
    end

    test "an SFTP server that wants a password asks, in stars, and tries again", %{state: state} do
      changes = State.mode(state).changes
      state = Agendum.TUI.Extras.Publish.Results.published(state, changes, {:error, :password})
      assert screen(state) =~ "(not kept)"

      Process.delete(:effects_seen)
      state = press(state, ["h", "o", "n", "e", "y"])
      assert screen(state) =~ "*****"
      refute screen(state) =~ "honey"

      press(state, :enter)
      assert {:publish, _, _, _, "honey"} = Enum.find(effects(), &(elem(&1, 0) == :publish))
    end

    # Found by the fuzz walk (2026-10-27): the upload runs in the
    # background, so the server's question can come while the help is open
    # over the preview, or after the preview was closed; typing the
    # password crashed, as it looked for the preview on top.
    test "the password asked while the help covers the preview still publishes", %{
      state: state
    } do
      changes = State.mode(state).changes
      state = state |> press(:enter) |> press({:f, 1})
      state = Agendum.TUI.Extras.Publish.Results.published(state, changes, {:error, :password})

      Process.delete(:effects_seen)
      press(state, ["p", "w", :enter])

      assert {:publish, "site", _, ^changes, "pw"} =
               Enum.find(effects(), &(elem(&1, 0) == :publish))
    end

    test "the password asked after the preview was closed says to publish again", %{
      state: state
    } do
      changes = State.mode(state).changes
      state = state |> press(:enter) |> press(:esc)
      state = Agendum.TUI.Extras.Publish.Results.published(state, changes, {:error, :password})

      # no prompt: nothing is left to publish with it
      assert State.mode(state) == nil
      assert screen(state) =~ "Publish again"
    end

    # Found by the richer fuzz walks (2026-10-27): the preview stays open
    # while the site is written and uploaded in the background, and ESC
    # then said "Nothing was published", though the upload went on.
    test "ESC while publishing says it goes on, not that nothing was published", %{
      state: state
    } do
      state = state |> press(:enter) |> press(:esc)
      assert State.mode(state) == nil
      refute screen(state) =~ "Nothing was published"
      assert screen(state) =~ "Publishing goes on"
    end

    test "while publishing, the preview says so, and ENTER does not publish twice", %{
      state: state
    } do
      state = press(state, :enter)
      assert screen(state) =~ "ESC closes this box; publishing goes on"

      Process.delete(:effects_seen)
      press(state, :enter)
      refute Enum.any?(effects(), &(elem(&1, 0) == :publish))
    end

    # Found by the nightly fuzz walk (2026-11-01): the server's question
    # came while a prompt was being typed in (the Macro Manager's, over the
    # preview), opened a second prompt over it, and the one line both typed
    # into was gone when the top one closed: drawing the first crashed.
    test "the password asked while another prompt is typed in waits, and says so", %{
      state: state
    } do
      changes = State.mode(state).changes
      state = state |> press(:enter) |> press([{:alt_f, 3}, "h"])
      assert %{type: :prompt} = State.mode(state)
      typing = state.edit

      state = Agendum.TUI.Extras.Publish.Results.published(state, changes, {:error, :password})

      # the prompt typed in is left as it was, with its text
      assert %{type: :prompt} = State.mode(state)
      assert state.edit == typing
      refute Enum.any?(state.modes, &match?(%{type: :publish_preview}, &1))
      assert state.message == {:error, Agendum.TUI.Extras.Publish.Messages.text(:password_later)}

      # ENTER and ESC close what is open without a crash
      state |> press(:enter) |> press(:esc) |> screen()
    end

    test "a password asked and not given leaves nothing published", %{state: state} do
      changes = State.mode(state).changes
      state = press(state, :enter)
      state = Agendum.TUI.Extras.Publish.Results.published(state, changes, {:error, :password})
      # ESC leaves the password prompt, then the preview
      state = state |> press(:esc) |> press(:esc)
      assert screen(state) =~ "Nothing was published"
    end

    test "published while the help covers the preview: the preview goes too", %{state: state} do
      changes = State.mode(state).changes
      state = state |> press(:enter) |> press({:f, 1})
      state = Agendum.TUI.Extras.Publish.Results.published(state, changes, :ok)

      refute Enum.any?(state.modes, &match?(%{type: :publish_preview}, &1))
      assert screen(state) =~ "Published: 12 added"
      assert State.mode(press(state, :esc)) == nil
    end

    test "an error is said, and the preview closes", %{state: state} do
      changes = State.mode(state).changes

      state =
        Agendum.TUI.Extras.Publish.Results.published(
          state,
          changes,
          {:error, "rsync is not installed"}
        )

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
