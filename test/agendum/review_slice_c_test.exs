# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.ReviewSliceCTest do
  @moduledoc """
  The findings of the cloud review of slice C, the extras
  (docs/CODE_REVIEW_SLICES.md; 2026-10-26), each as the case that showed it.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.Extras.{ICal, Markdown}
  alias Agendum.Extras.Publish

  @moduletag :tmp_dir
  @now ~N[2026-10-26 23:30:00]

  defp calendar(events), do: "BEGIN:VCALENDAR\r\nVERSION:2.0\r\n" <> events <> "END:VCALENDAR\r\n"

  # 1. a line starting with # that is no heading is a paragraph, at once
  test "a hashtag line is a paragraph, and Markdown always ends" do
    task = Task.async(fn -> Markdown.to_html("#elixir is fun\n#\n####### x\n> #tag") end)
    assert {:ok, html} = Task.yield(task, 2_000) || Task.shutdown(task)
    assert html =~ "#elixir is fun"
  end

  # 2. an interval of 0 or below is read as 1
  test "an RRULE with INTERVAL=0 or below repeats every time" do
    text =
      calendar(
        "BEGIN:VEVENT\r\nUID:z\r\nDTSTART:20261026T090000\r\nSUMMARY:Stand-up\r\n" <>
          "RRULE:FREQ=WEEKLY;INTERVAL=0;BYDAY=MO,WE\r\nEND:VEVENT\r\n"
      )

    assert {:ok, [event]} = ICal.parse(text)
    assert event.rrule.interval == 1
    # and a sync with it does not crash
    db = Core.new_file()
    {:ok, db, cal} = Core.subscribe_calendar(db, "Work", "https://w.example/w.ics")
    assert {:ok, _, _} = Core.sync_calendar(db, cal, [event], @now)
  end

  # 3. an upload never waits for a password or a dead connection
  test "rsync runs ssh in batch mode with a connect timeout" do
    args = Publish.rsync_args("me@host:www", "/site", ["index.html"])
    ssh = Enum.find_index(args, &(&1 == "-e"))
    assert ssh
    command = Enum.at(args, ssh + 1)
    assert command =~ "BatchMode=yes"
    assert command =~ "ConnectTimeout="
    assert command =~ "ServerAliveInterval="
  end

  # 4. a calendar in an 8-bit encoding is read, its odd bytes kept
  test "a Latin-1 byte before a line's colon does not stop the calendar" do
    text =
      calendar(
        "BEGIN:VEVENT\r\nUID:l1\r\nDTSTART;VALUE=DATE:20261027\r\nSUMMARY:Lunch\r\n" <>
          "ORGANIZER;CN=M" <> <<0xFC>> <> "ller:mailto:m@example.com\r\nEND:VEVENT\r\n"
      )

    assert {:ok, [event]} = ICal.parse(text)
    assert event.summary == "Lunch"
  end

  # 5. ENTER in Publish keeps the categories it opened with
  test "a posts or drafts category is kept by its id, never swapped for a namesake" do
    db = Core.new_file()
    {:ok, db, mail} = Core.add_category(db, db.main_id, "Mail")
    {:ok, db, _mail_drafts} = Core.add_category(db, mail, "Drafts")
    {:ok, db, blog} = Core.add_category(db, db.main_id, "Blog")
    {:ok, db, posts} = Core.add_category(db, blog, "Posts")
    {:ok, db, drafts} = Core.add_category(db, blog, "Drafts")
    {:ok, db} = Core.set_blog(db, %{posts: posts, drafts: drafts})

    state = Agendum.TUIHelpers.start(db, extras: true)
    state = state |> Agendum.TUI.Extras.PublishBox.open() |> Agendum.TUIHelpers.press(:enter)
    assert state.db.blog.drafts == drafts
    assert state.db.blog.posts == posts

    # a name typed that two categories have is refused, not guessed
    assert {:error, :ambiguous} = Core.set_blog(db, %{drafts: {:name, "Drafts"}})
  end

  # 6. SFTP sends the whole site, and what an earlier failed upload left
  test "SFTP sends every file, and removals a failed upload did not make", %{tmp_dir: dir} do
    files = [{"index.html", "<p>"}, {"posts/a.html", "<p>"}]
    changes = %{added: [], changed: [], removed: ["posts/old.html"]}

    {sent, removed} = Publish.sftp_plan(dir, files, changes)
    assert "posts/a.html" in sent and "index.html" in sent
    assert removed == ["posts/old.html"]

    # the upload failed: the removal waits in the folder for the next one
    :ok = Publish.keep_unsent(dir, removed)
    {_sent, removed} = Publish.sftp_plan(dir, files, %{changes | removed: []})
    assert removed == ["posts/old.html"]

    :ok = Publish.keep_unsent(dir, [])
    assert {_, []} = Publish.sftp_plan(dir, files, %{changes | removed: []})
  end

  # 7. a Zettel id inside an address or code is left as it is
  test "a post's own address keeps its link" do
    {:ok, n} = Agendum.Core.Extras.ZettelId.decode("bonalaku")
    used = %{n => 7}
    link = fn _target, word -> "<a>#{word}</a>" end

    html =
      Markdown.inline(
        "see https://me.example/posts/bonalaku.html and `bonalaku` but bonalaku",
        used,
        link
      )

    assert html =~ "https://me.example/posts/bonalaku.html"
    assert html =~ "<code>bonalaku</code>"
    assert html =~ "but <a>bonalaku</a>"
  end

  # 8. a legacy calendar that took over a category of the person's leaves it
  test "an old calendar in a category of the person's gets its own; theirs is left alone" do
    db = Core.new_file()
    {:ok, db, work} = Core.add_category(db, db.main_id, "Work")
    {:ok, db, _own} = Core.add_category(db, work, "Clients")
    # as a version before 0.68 did: the calendar filed into the person's Work
    db = %{
      db
      | calendars: %{
          50 => %Agendum.Core.Extras.Calendar{
            id: 50,
            name: "Work",
            url: "https://w.example/w.ics",
            category_id: work
          }
        },
        next_id: 51
    }

    {:ok, db, _} = Core.subscribe_calendar(db, "Home", "https://h.example/h.ics")
    assert db.categories[work].parent_id == db.main_id
    refute Core.ingested?(db, work)
    own = db.calendars[50].category_id
    refute own == work
    assert db.categories[db.categories[own].parent_id].name == "Calendars"
  end

  # 9. an entry filed through a category link still fades
  test "a feed entry filed through a category link fades" do
    db = Core.new_file()
    {:ok, db, elixir} = Core.add_category(db, db.main_id, "Elixir")
    {:ok, db, programming} = Core.add_category(db, db.main_id, "Programming")
    db = Core.toggle_also_assign(db, elixir, programming)
    {:ok, db, feed} = Core.subscribe_feed(db, "News", "https://n.example/rss")

    entry = %{
      id: "1",
      title: "Elixir 2.0 out",
      link: "",
      summary: "",
      published: ~N[2026-10-01 08:00:00]
    }

    {:ok, db, %{added: 1}} = Core.sync_feed(db, feed, [entry], ~D[2026-10-02])
    {:ok, _db, counts} = Core.sync_feed(db, feed, [entry], ~D[2026-12-01])
    assert counts.faded == 1
  end

  # 10. an undated entry keeps the day it was first seen
  test "an entry without a date fades from the day it was first seen" do
    db = Core.new_file()
    {:ok, db, feed} = Core.subscribe_feed(db, "News", "https://n.example/rss")
    entry = %{id: "u", title: "Undated", link: "", summary: "", published: nil}

    {:ok, db, _} = Core.sync_feed(db, feed, [entry], ~D[2026-10-01])
    {:ok, db, _} = Core.sync_feed(db, feed, [entry], ~D[2026-10-20])
    assert db.feeds[feed].entries["u"].published == ~D[2026-10-01]
    {:ok, _db, counts} = Core.sync_feed(db, feed, [entry], ~D[2026-11-05])
    assert counts.faded == 1
  end
end
