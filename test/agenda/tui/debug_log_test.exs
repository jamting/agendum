defmodule Agenda.TUI.DebugLogTest do
  @moduledoc """
  The debug log (AGENDUM_LOG): where it goes, which old sessions are
  deleted, and what a session writes, crashes included.
  """
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers

  alias Agenda.Core
  alias Agenda.TUI.DebugLog

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

  test "old sessions: all but the newest four go, so the new one makes five" do
    names =
      for d <- 1..7,
          do: DebugLog.file_name(NaiveDateTime.new!(Date.new!(2026, 10, d), ~T[12:00:00.000]))

    old = DebugLog.old_sessions(Enum.shuffle(["notes.txt" | names]))
    assert old == Enum.take(names, 3)
    assert DebugLog.old_sessions(Enum.take(names, 4)) == []
  end

  @tag :tmp_dir
  test "a session: header, keys, messages, a crash with the state, five files kept",
       %{tmp_dir: dir} do
    for d <- 1..6,
        do: File.write!(Path.join(dir, "session-2026-10-0#{d}T00-00-00.000.log"), "")

    env = %{"AGENDUM_LOG" => dir}
    # the log is a named process: run it in its own test process
    task =
      Task.async(fn ->
        path = DebugLog.start(env, ["my.agendum"])
        state = Core.new_file() |> start()
        DebugLog.input("\e[A", [:up], state)
        DebugLog.message(nil, state |> Agenda.TUI.State.error("No such thing"))

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
    assert dir |> File.ls!() |> length() == 5
  end

  test "without a log every call does nothing" do
    assert DebugLog.start(%{"HOME" => "/h"}, []) == nil
    assert DebugLog.write("nothing") == :ok
  end
end
