defmodule Agendum.TUI.DebugLogTest do
  @moduledoc """
  The debug log (AGENDUM_LOG): where it goes, which old sessions are
  deleted, and what a session writes, crashes included.
  """
  # not async: its tests register the log under its one global name,
  # which another async module's would clash with (2026-10-27)
  use ExUnit.Case, async: false

  import Agendum.TUIHelpers

  alias Agendum.Core
  alias Agendum.TUI.DebugLog

  describe "dir/1" do
    test "off unless AGENDUM_LOG is set" do
      assert DebugLog.dir(%{"HOME" => "/h"}) == nil
      assert DebugLog.dir(%{"HOME" => "/h", "AGENDUM_LOG" => ""}) == nil
      assert DebugLog.dir(%{"HOME" => "/h", "AGENDUM_LOG" => "0"}) == nil
    end

    test "the state directory, or a folder named in the variable" do
      assert DebugLog.dir(%{"HOME" => "/h", "AGENDUM_LOG" => "1"}) ==
               "/h/.local/state/agendum/logs"

      assert DebugLog.dir(%{"XDG_STATE_HOME" => "/s", "HOME" => "/h", "AGENDUM_LOG" => "1"}) ==
               "/s/agendum/logs"

      assert DebugLog.dir(%{"HOME" => "/h", "AGENDUM_LOG" => "/tmp/logs"}) == "/tmp/logs"
      assert DebugLog.dir(%{"HOME" => "/h", "AGENDUM_LOG" => "~/logs"}) == "/h/logs"
    end
  end

  test "file names sort by time" do
    assert DebugLog.file_name(~N[2026-10-13 09:05:03.042]) ==
             "session-2026-10-13T09-05-03.042.log"
  end

  test "old sessions: all but the newest nine go, so the new one makes ten" do
    names =
      for d <- 1..12,
          do: DebugLog.file_name(NaiveDateTime.new!(Date.new!(2026, 10, d), ~T[12:00:00.000]))

    old = DebugLog.old_sessions(Enum.shuffle(["notes.txt" | names]))
    assert old == Enum.take(names, 3)
    assert DebugLog.old_sessions(Enum.take(names, 9)) == []
  end

  # meeting 2026-10-26-4, § 7: a calendar's address can hold a private
  # token, so the log keeps only where it is
  test "web addresses are written by their host, never their path or query" do
    assert DebugLog.redact(
             ~s(effect {:fetch_calendar, 4, "https://cal.example/private/abc123/basic.ics?token=s3cret"} in 9 ms)
           ) ==
             ~s(effect {:fetch_calendar, 4, "https://cal.example/…"} in 9 ms)

    assert DebugLog.redact("webcal://cal.example/x.ics and feed://owl.example/rss") ==
             "webcal://cal.example/… and feed://owl.example/…"

    assert DebugLog.redact("https://owl.example and no address") ==
             "https://owl.example and no address"
  end

  @tag :tmp_dir
  test "a session: header, keys, messages, a crash with the state, ten files kept",
       %{tmp_dir: dir} do
    for d <- 1..11,
        do: File.write!(Path.join(dir, "session-2026-10-0#{d}T00-00-00.000.log"), "")

    env = %{"AGENDUM_LOG" => dir}
    # the log is a named process: run it in its own test process
    task =
      Task.async(fn ->
        path = DebugLog.start(env, ["my.agendum"])
        state = Core.new_file() |> start()
        DebugLog.input("\e[A", [:up], state)
        DebugLog.message(nil, state |> Agendum.TUI.State.error("No such thing"))
        DebugLog.write("effect {:fetch_feed, 1, \"https://owl.example/feed?key=s3cret\"}")

        try do
          raise ArgumentError, "boom"
        rescue
          e -> DebugLog.crash(:error, e, __STACKTRACE__, state)
        end

        DebugLog.stop()
        path
      end)

    path = Task.await(task)
    text = File.read!(path)
    assert text =~ "Wol's Agendum"
    assert text =~ ~s(args ["my.agendum"])
    assert text =~ ~s(input "\\e[A" → [:up])
    assert text =~ "error No such thing"
    assert text =~ "CRASH"
    assert text =~ "** (ArgumentError) boom"
    assert text =~ "Modes"
    refute text =~ "s3cret"
    assert dir |> File.ls!() |> length() == 10
  end

  test "without a log every call does nothing" do
    assert DebugLog.start(%{"HOME" => "/h"}, []) == nil
    assert DebugLog.write("nothing") == :ok
  end

  describe "file_text/2" do
    test "the file in use, with its size, and how it is on disk" do
      state = Core.new_file() |> start() |> Map.put(:path, "/h/my.agendum")
      items = map_size(state.db.items)
      categories = map_size(state.db.categories)
      disk = %{size: 2048, modified: ~N[2026-10-15 13:20:01], fingerprint: "0a1b2c3d"}

      assert DebugLog.file_text(state, disk) ==
               "file /h/my.agendum (#{items} items, #{categories} categories) · " <>
                 "on disk 2048 bytes, changed 2026-10-15T13:20:01, fingerprint 0a1b2c3d"

      assert DebugLog.file_text(state, nil) =~ ~r/categories\) · not on disk$/
    end

    test "a file never saved (a sample, a starter) has no path" do
      text = Core.new_file() |> start() |> DebugLog.file_text(nil)
      assert text =~ ~r/^file not saved yet \(/
      refute text =~ "disk"
    end

    @tag :tmp_dir
    test "the log line reads the file on disk", %{tmp_dir: dir} do
      path = Path.join(dir, "my.agendum")
      File.write!(path, "hello")
      state = Core.new_file() |> start() |> Map.put(:path, path)

      text =
        Task.async(fn ->
          log = DebugLog.start(%{"AGENDUM_LOG" => Path.join(dir, "logs")}, [])
          DebugLog.file(state)
          DebugLog.stop()
          File.read!(log)
        end)
        |> Task.await()

      assert text =~ "on disk 5 bytes"
      assert text =~ "fingerprint #{DebugLog.fingerprint("hello")}"
    end
  end

  test "fingerprints are eight hex digits, the same for the same bytes" do
    assert DebugLog.fingerprint("hello") =~ ~r/^[0-9a-f]{8}$/
    assert DebugLog.fingerprint("hello") == DebugLog.fingerprint("hello")
    assert DebugLog.fingerprint("hello") != DebugLog.fingerprint("hello!")
  end

  test "the header names the version, the commit and the build" do
    assert DebugLog.build_text() =~ ~r/^Wol's Agendum \d+\.\d+\.\d+ \(commit \w+, test build\)$/
  end

  test "effects are logged with how long they took; written text is counted" do
    assert DebugLog.effect_text({:save, "/h/my.agendum"}, 12) ==
             ~s(effect {:save, "/h/my.agendum"} in 12 ms)

    assert DebugLog.effect_text({:write_text, "/h/out.txt", "abc"}, 0) ==
             "effect write_text /h/out.txt (3 bytes) in 0 ms"
  end

  # ADR 0046, R82: a file's password and a copied database stay out
  test "a password and a copied file are not written to the log" do
    assert DebugLog.effect_text({:load_password, "/h/owl.agendum", "Hoot"}, 60) ==
             "effect load_password /h/owl.agendum (password hidden) in 60 ms"

    text = DebugLog.effect_text({:save_copy, "/h/copy.agendum", Core.new_file()}, 3)
    assert text == "effect save_copy /h/copy.agendum in 3 ms"
  end

  test "the view on screen: its sections and filters" do
    state = Core.new_file() |> start()

    assert DebugLog.view_text(state) ==
             ~s(view "#{Agendum.TUI.State.view(state).name}" (1 section, 0 filters\))
  end

  test "the runtime's work: collections between two moments, memory now" do
    before = %{collections: 10, memory: 50 * 1_048_576, loop: 1_048_576}
    now = %{collections: 13, memory: 52 * 1_048_576, loop: 3 * 1_048_576}

    assert DebugLog.runtime_text(before, now) ==
             "3 garbage collections, memory 52.0 MB (main loop 3.0 MB)"

    assert %{collections: _, memory: _, loop: _} = DebugLog.runtime()
  end

  describe "slow_text/1" do
    test "an answer of 100 ms or more is logged, split into its parts" do
      answer = %{keys: [:down], total: 230, update: 20, draw: 205}

      assert DebugLog.slow_text(answer) ==
               "slow answer 230 ms to [:down] (waiting 5 ms, update 20 ms, draw 205 ms)"
    end

    test "a quick answer is not" do
      assert DebugLog.slow_text(%{keys: [:down], total: 99, update: 40, draw: 50}) == nil
    end

    test "a long run of keys is cut short" do
      text =
        DebugLog.slow_text(%{keys: List.duplicate(:down, 40), total: 500, update: 0, draw: 0})

      assert text =~ "..."
      assert String.length(text) < 200
    end
  end

  # a publish ends with a bare :ok, a read with a tuple: the log line names
  # either without crashing (v0.68.4 crashed after every publish)
  test "the outcome of background work, whatever shape it has" do
    assert DebugLog.outcome(:ok) == "ok"
    assert DebugLog.outcome({:ok, []}) == "ok"
    assert DebugLog.outcome({:error, "SFTP: timeout"}) == "error"
    assert DebugLog.outcome("odd") == "?"
  end

  test "App's log lines for background results never take a tuple apart by hand" do
    refute File.read!("lib/agendum/tui/app.ex") =~ "elem(result"
  end

  test "a log whose device dies as a line is written is left off, never a crash" do
    # the device takes its name with it as it dies, between the lookup and
    # the write: the race the full suite hit once (2026-10-27)
    task =
      Task.async(fn ->
        device =
          spawn(fn ->
            receive do
              {:io_request, _, _, _} ->
                Process.unregister(:agendum_debug_log)
                exit(:gone)
            end
          end)

        Process.register(device, :agendum_debug_log)
        DebugLog.write("still running")
      end)

    assert Task.await(task) == :ok
  end
end
