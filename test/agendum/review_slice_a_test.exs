# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.ReviewSliceATest do
  @moduledoc """
  The findings of the cloud review of slice A, the file and the shell
  (docs/CODE_REVIEW_SLICES.md; 2026-10-26), each as the case that showed it.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.{Core, Store}
  alias Agendum.Core.{AgFile, JSONFile}
  alias Agendum.TUI.{DebugLog, Update}

  @moduletag :tmp_dir
  @now ~N[2026-10-26 22:00:00]

  # 1. a read asked for by one file is not filed into another
  test "a calendar or feed read nobody asked for is left alone" do
    db = Core.new_file()
    {:ok, db, cal} = Core.subscribe_calendar(db, "Work", "https://w.example/w.ics")
    {:ok, db, feed} = Core.subscribe_feed(db, "News", "https://n.example/rss")
    # another file opened since: nothing is being read for it
    state = start(db, extras: true)
    assert state.fetching == %{}

    event = %Agendum.Core.Extras.ICal.Event{
      uid: "x",
      summary: "Foreign",
      start: {:date, ~D[2026-10-27]}
    }

    after_cal =
      Update.Results.calendar_read(state, cal, "https://w.example/w.ics", {:ok, [event]})

    assert after_cal.db == state.db

    entry = %{
      id: "1",
      title: "Foreign",
      link: "",
      summary: "",
      published: ~N[2026-10-26 08:00:00]
    }

    after_feed = Update.Results.feed_read(state, feed, "https://n.example/rss", {:ok, [entry]})
    assert after_feed.db == state.db
  end

  # 2. a log that cannot be written is left off, never a crash
  test "a failing log write turns the log off instead of crashing", %{tmp_dir: dir} do
    task =
      Task.async(fn ->
        DebugLog.start(%{"AGENDUM_LOG" => dir}, [])
        # the log's device gone, as on a full disk or a lost drive
        :agendum_debug_log |> Process.whereis() |> File.close()
        result = DebugLog.write("still running")
        {result, Process.whereis(:agendum_debug_log)}
      end)

    assert Task.await(task) == {:ok, nil}
  end

  # 3. a damaged .AG file cannot make the reader work for ever: each
  # category block is read once, however many parents point at it (blocks
  # 2..60, each pointing at the next two, as a crafted file can)
  test "a block reachable from many parents is read once" do
    children = fn n -> if n < 60, do: Enum.filter([n + 1, n + 2], &(&1 <= 60)), else: [] end
    count = :counters.new(1, [])

    {tree, seen} =
      AgFile.Reader.depth_first(2, children, fn n, kids ->
        :counters.add(count, 1, 1)
        {n, kids}
      end)

    assert :counters.get(count, 1) == 59
    assert MapSet.size(seen) == 59
    assert {2, [_ | _]} = tree
  end

  # 4. a JSON file whose trash ids clash with live ones is refused
  test "trash item ids count among a JSON file's ids" do
    db = Core.new_file()
    {db, id} = Core.add_item(db, "Live", @now)
    trashed = %{db.items[id] | text: "In the trash"}
    db = %{db | trash: %{db.trash | items: [trashed]}}

    assert {:error, message} = db |> JSONFile.encode() |> JSONFile.decode()
    assert message =~ "unique"
  end

  # 5. an encrypted file's header keeps a short description, so its length
  # always fits, and the file opens again
  test "an encrypted file with a very long description opens again", %{tmp_dir: dir} do
    path = Path.join(dir, "long.agendum")
    db = %{Core.new_file() | description: String.duplicate("x", 70_000), password: "Hoot"}
    :ok = Store.save(db, path)
    assert {:ok, loaded} = Store.load(path, "Hoot")
    assert loaded.description == db.description
  end

  # 6. a crash dump never holds a password from an open box
  test "the crash dump hides passwords held in the boxes" do
    state = start(Core.new_file())
    asked = Update.Results.loaded(state, "/tmp/nowhere/x.agendum", {:error, :enoent})
    typed = press(asked, [:down, "H", "o", "o", "t", :enter])
    assert typed |> Agendum.TUI.State.mode() |> Map.get(:password) == "Hoot"

    refute DebugLog.modes_text(typed) =~ "Hoot"
  end

  # 7. a batch of several keys never logs its characters: the key opening a
  # password prompt may come in the same batch as the password
  test "several keys in one batch are logged without their characters" do
    state = start(Core.new_file())

    text =
      DebugLog.input_text(
        "x\rHoot",
        [{:char, "x"}, :enter | Enum.map(~w(H o o t), &{:char, &1})],
        state
      )

    refute text =~ "Hoot"
    refute text =~ "\"x"
    assert text =~ ":enter"
    assert text =~ "5 characters"

    # a single key is logged as it was
    assert DebugLog.input_text("a", [{:char, "a"}], state) =~ ~s(char: "a")
  end

  # 8. an address's userinfo never reaches the log
  test "redaction drops the userinfo, with or without a path" do
    assert DebugLog.redact("https://me:SECRET@cal.example/private.ics") == "https://cal.example/…"
    assert DebugLog.redact("https://me:SECRET@cal.example") == "https://cal.example"
    assert DebugLog.redact("webcal://cal.example") == "webcal://cal.example"
  end

  # 9. "every N working days" is said in the import report, as the other
  # simplifications are
  test "a working-day repeat is noted in the report" do
    assignment = %{
      value: "2026-10-26T09:00",
      given_as: %{kind: "recurring", unit: "working days", interval: 1}
    }

    {rule, ctx} =
      AgFile.Convert.recurrence(assignment, %{text: "Stand-up"}, %{notes: []})

    assert rule == %{"every" => 1, "unit" => "day"}
    assert [note] = ctx.notes
    assert note =~ "Stand-up"
    assert note =~ "working days"
  end

  # 10. no backup asked for a file that is not on disk yet
  test "a new file with Make backup on open asks for no backup" do
    db = Core.set_backup_on_open(Core.new_file(), true)
    state = start(db) |> Map.put(:path, "/tmp/nowhere/new.agendum")
    state = %{state | saved: %{state.saved | stamp: nil}, effects: []}
    refute Enum.any?(Update.arrive(state).effects, &match?({:backup_file, _}, &1))
  end
end
