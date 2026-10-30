defmodule Agendum.TUI.AppBackgroundTest do
  @moduledoc """
  What a background task mails back to the shell's loop (a feed or calendar
  read, the blog published) goes through `Agendum.TUI.App.background/2`:
  its debug-log line, then `Update.Results`. Every shape a task can send
  is tried here, with the log open, as v0.69.1 crashed on a bare `:ok` in
  the log line, out of reach of the pure tests and the fuzz walks
  (meeting 2026-10-26-2234, § 7).

  `async: false`: the debug log is one registered process for the whole
  test run.
  """
  use ExUnit.Case, async: false

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.Core.Extras.ICal.Event
  alias Agendum.TUI.{App, DebugLog, State, Update}

  @moduletag :tmp_dir

  @entry %{
    id: "1",
    title: "Heffalump sighted",
    link: "https://owl.example/heffalump",
    summary: "Piglet says so.",
    published: ~N[2026-10-07 07:00:00]
  }
  @event %Event{uid: "a", summary: "Tea", start: {:date, ~D[2026-10-13]}}
  @changes %{added: ["index.html"], changed: [], removed: []}
  @feed_url "https://owl.example/rss"
  @cal_url "https://w.example/w.ics"

  # A read that crashed outright: `App.fetched/1` turns each of Erlang's
  # three kinds of failure (error, throw, exit) into an error to show.
  defp crashed(kind) do
    App.fetched(fn ->
      case kind do
        :error -> raise "boom"
        :throw -> throw(:boom)
        :exit -> exit(:boom)
      end
    end)
  end

  # a file with a feed and a calendar, each being read by hand
  defp reading do
    db = Core.new_file()
    {:ok, db, feed} = Core.subscribe_feed(db, "Gazette", @feed_url)
    {:ok, db, cal} = Core.subscribe_calendar(db, "Work", @cal_url)

    state =
      start(db, extras: true)
      |> Update.fetch_feed(feed, :manual)
      |> Update.fetch_calendar(cal, :manual)

    {%{state | effects: []}, feed, cal}
  end

  # Runs `fun` with a debug log open in `dir`, and gives its result and the
  # log's lines. `Task.async/1` runs it in a process of its own, so the log
  # it registers goes when the task ends.
  defp logged(dir, fun) do
    Task.async(fn ->
      path = DebugLog.start(%{"AGENDUM_LOG" => dir}, [])
      result = fun.()
      DebugLog.stop()
      {result, File.read!(path)}
    end)
    |> Task.await()
  end

  test "every shape of feed and calendar read is logged and answered", %{tmp_dir: dir} do
    results =
      [ok: :ok, error: {:error, "the server answered 503"}] ++
        for(kind <- [:error, :throw, :exit], do: {:crash, crashed(kind)})

    for {_label, result} <- results, which <- [:feed_read, :calendar_read] do
      {state, feed, cal} = reading()

      {id, url, payload} =
        case {which, result} do
          {:feed_read, :ok} -> {feed, @feed_url, {:ok, [@entry]}}
          {:calendar_read, :ok} -> {cal, @cal_url, {:ok, [@event]}}
          {:feed_read, error} -> {feed, @feed_url, error}
          {:calendar_read, error} -> {cal, @cal_url, error}
        end

      {after_state, log} =
        logged(dir, fn -> App.background(state, {which, id, url, payload, 12}) end)

      assert %State{} = after_state
      # the read is no longer waited for, and the person is told
      refute Map.has_key?(after_state.fetching, id)
      assert {_kind, text} = after_state.message
      assert is_binary(text)
      word = if which == :feed_read, do: "feed", else: "calendar"
      assert log =~ "#{word} #{id} read: #{elem(payload, 0)} in 12 ms"
    end
  end

  test "every shape of a publish's result is logged and answered", %{tmp_dir: dir} do
    state = start(Core.new_file(), extras: true)

    for result <- [:ok, {:error, :password}, {:error, "rsync is not installed"}] do
      {{after_state, publishing}, log} =
        logged(dir, fn ->
          Process.put(:agendum_publishing, true)
          s = App.background(state, {:published, @changes, result})
          {s, Process.get(:agendum_publishing)}
        end)

      assert %State{} = after_state
      # the next publish may start
      assert publishing == nil
      assert log =~ "published: #{DebugLog.outcome(result)}"
    end
  end

  test "a read crashed outright comes back as an error to show" do
    for kind <- [:error, :throw, :exit],
        do: assert({:error, "could not be read" <> _} = crashed(kind))
  end

  # Found by the fuzz walk (2026-10-27): every file counts its ids from
  # one, so another file opened while a read is under way may have a feed
  # of the same id, and read it too. The first file's answer is for its
  # own address, and must not be filed into the other file's feed.
  test "a read for another file's feed of the same id is not filed into this one" do
    db = Core.new_file()
    {:ok, a, feed} = Core.subscribe_feed(db, "Gazette", "https://owl.example/rss")
    {:ok, a, cal} = Core.subscribe_calendar(a, "Work", "https://w.example/w.ics")
    {:ok, b, ^feed} = Core.subscribe_feed(db, "Bugle", "https://rabbit.example/rss")
    {:ok, b, ^cal} = Core.subscribe_calendar(b, "Home", "https://h.example/h.ics")

    # file A asks for both; then file B is opened, and asks for its own
    state =
      start(a, extras: true)
      |> Update.fetch_feed(feed, :auto)
      |> Update.fetch_calendar(cal, :auto)
      |> Update.Results.loaded("b.agendum", {:ok, b, "stamp"})
      |> Update.fetch_feed(feed, :auto)
      |> Update.fetch_calendar(cal, :auto)

    state = %{state | effects: []}

    # A's answers come back first: B is left alone, and still waits
    stale_feed = {:feed_read, feed, "https://owl.example/rss", {:ok, [@entry]}, 1}
    stale_cal = {:calendar_read, cal, "https://w.example/w.ics", {:ok, [@event]}, 1}
    after_stale = state |> App.background(stale_feed) |> App.background(stale_cal)
    assert after_stale.db == state.db
    assert Map.keys(after_stale.fetching) |> Enum.sort() == Enum.sort([feed, cal])

    # then B's own: filed
    own = {:feed_read, feed, "https://rabbit.example/rss", {:ok, [@entry]}, 1}
    after_own = App.background(after_stale, own)
    assert after_own.db != state.db
    refute Map.has_key?(after_own.fetching, feed)
  end

  # Found by the richer fuzz walks (2026-10-27): the wait was cleared only
  # by an answer for the address the feed or calendar has now, so one
  # unsubscribed (or undone) while being read, or whose address changed,
  # was waited for ever: "reading…" in its box, WRKG on the control panel,
  # and never read again.
  test "a feed or calendar unsubscribed while being read is no longer waited for" do
    {state, feed, cal} = reading()

    state =
      state
      |> State.run({:unsubscribe_feed, feed, false})
      |> State.run({:unsubscribe_calendar, cal, false})

    after_state =
      state
      |> App.background({:feed_read, feed, @feed_url, {:ok, [@entry]}, 1})
      |> App.background({:calendar_read, cal, @cal_url, {:ok, [@event]}, 1})

    assert after_state.db == state.db
    assert after_state.fetching == %{}
  end

  test "an answer for an address since changed is dropped, and the new one is read" do
    {state, feed, cal} = reading()

    db = %{
      state.db
      | feeds: Map.update!(state.db.feeds, feed, &%{&1 | url: "https://owl.example/new"}),
        calendars: Map.update!(state.db.calendars, cal, &%{&1 | url: "https://w.example/new"})
    }

    state = %{state | db: db}

    after_state =
      state
      |> App.background({:feed_read, feed, @feed_url, {:ok, [@entry]}, 1})
      |> App.background({:calendar_read, cal, @cal_url, {:ok, [@event]}, 1})

    # the old address's entries are not filed under the new one
    assert after_state.db == state.db
    assert after_state.fetching == %{}

    again = after_state |> Update.fetch_feed(feed, :manual) |> Update.fetch_calendar(cal, :manual)
    assert {:fetch_feed, feed, "https://owl.example/new"} in again.effects
    assert {:fetch_calendar, cal, "https://w.example/new"} in again.effects
  end

  test "a result nobody in this file asked for changes nothing" do
    {state, feed, cal} = reading()
    state = %{state | fetching: %{}}

    assert App.background(state, {:feed_read, feed, @feed_url, {:ok, [@entry]}, 1}).db == state.db

    assert App.background(state, {:calendar_read, cal, @cal_url, {:ok, [@event]}, 1}).db ==
             state.db
  end
end
