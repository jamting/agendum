defmodule Agendum.TUI.DebugLog do
  @moduledoc """
  A log of each session for debugging, on when the `AGENDUM_LOG`
  environment variable is set: `1` writes to
  `$XDG_STATE_HOME/agendum/logs` (`~/.local/state/agendum/logs`), a path
  writes to that folder.

  One file a session (`session-<time>.log`). It holds the program (with
  the commit it was built from), terminal and arguments, every input as
  bytes and decoded keys (with the boxes open), the keys a macro plays,
  the effects run and how long each took, new messages and errors, the
  file in use (at the start and whenever another is opened or saved under
  a new name) with its size, time and fingerprint on disk, answers to keys
  that took 100 ms or more (with the view on screen and the memory used),
  and a crash: the exception, its stack trace and the state as
  the developer screen (`Agendum.TUI.DevTools`) shows it. Starting a
  session deletes all but the newest four, so five are kept.

  What is typed is in the log, so it stays on this computer. Logging
  never stops the program: a log that cannot be written is left off.
  `dir/1`, `file_name/1`, `old_sessions/1`, `build_text/0`, `file_text/2`,
  `view_text/1`, `slow_text/1` and `effect_text/2` are pure; the rest writes
  (imperative shell, called by `Agendum.CLI` and `Agendum.TUI.App`).
  """

  alias Agendum.TUI.{DevTools, State}

  # the open log file is a process (an Erlang IO device) registered under
  # this name, so the main loop does not have to carry it around
  @name :agendum_debug_log
  @keep 5
  @version Mix.Project.config()[:version]
  # dev, test or prod: an escript is built for prod (CLAUDE.md)
  @build_env Mix.env()

  # The commit the program was built from, read from git when this module
  # is compiled ("unknown" without git). `@external_resource` names files
  # whose change recompiles the module: HEAD and the branch it points to,
  # which moves at each commit, so the commit named is never an old one.
  # (Edits not yet committed are not seen: a dev build may be ahead of it.)
  @git_ref (case File.read(".git/HEAD") do
              {:ok, "ref: " <> ref} -> Path.join(".git", String.trim(ref))
              _ -> ".git/HEAD"
            end)
  @external_resource ".git/HEAD"
  @external_resource @git_ref
  @commit (try do
             case System.cmd("git", ["rev-parse", "--short", "HEAD"], stderr_to_stdout: true) do
               {sha, 0} -> String.trim(sha)
               _ -> "unknown"
             end
           rescue
             # no git program at all
             _ -> "unknown"
           end)

  @doc "The folder to log in, from the environment; nil when logging is off."
  @spec dir(%{String.t() => String.t()}) :: String.t() | nil
  def dir(env) do
    case {Map.get(env, "AGENDUM_LOG", ""), env} do
      {off, _} when off in ["", "0"] -> nil
      {"~/" <> rest, %{"HOME" => home}} -> Path.join(home, rest)
      {"/" <> _ = path, _} -> path
      {_, %{"XDG_STATE_HOME" => dir}} when dir != "" -> Path.join([dir, "agendum", "logs"])
      {_, %{"HOME" => home}} when home != "" -> Path.join([home, ".local/state/agendum/logs"])
      _ -> nil
    end
  end

  @doc "A session's file name; names sort by time."
  @spec file_name(NaiveDateTime.t()) :: String.t()
  def file_name(time) do
    stamp = time |> NaiveDateTime.truncate(:millisecond) |> NaiveDateTime.to_iso8601()
    "session-#{String.replace(stamp, ":", "-")}.log"
  end

  @doc "The sessions among `names` to delete before a new one starts."
  @spec old_sessions([String.t()]) :: [String.t()]
  def old_sessions(names) do
    sessions = names |> Enum.filter(&(&1 =~ ~r/^session-.*\.log$/)) |> Enum.sort()
    Enum.drop(sessions, -(@keep - 1))
  end

  @doc """
  Starts the session's log when `env` asks for one: deletes old sessions,
  opens a new file and writes the header. Returns its path, or nil.
  """
  @spec start(%{String.t() => String.t()}, [String.t()]) :: String.t() | nil
  def start(env, args) do
    with dir when dir != nil <- dir(env),
         :ok <- File.mkdir_p(dir),
         {:ok, names} <- File.ls(dir),
         _ <- Enum.each(old_sessions(names), &File.rm(Path.join(dir, &1))),
         path = Path.join(dir, file_name(now())),
         # no :delayed_write: each line is on disk before the next key, so
         # a crash cannot lose it
         {:ok, file} <- File.open(path, [:append, :utf8]) do
      Process.register(file, @name)
      header(env, args)
      path
    else
      _ -> nil
    end
  end

  @doc "Ends the session's log."
  @spec stop() :: :ok
  def stop do
    with pid when pid != nil <- Process.whereis(@name) do
      write("session ends")
      File.close(pid)
    end

    :ok
  end

  @doc "Writes a line, with the time, when a log is open."
  @spec write(String.t()) :: :ok
  def write(text) do
    case Process.whereis(@name) do
      nil ->
        :ok

      pid ->
        IO.write(pid, "#{now() |> NaiveDateTime.to_time() |> Time.to_iso8601()} #{text}\n")
    end
  end

  # local time to the millisecond (`NaiveDateTime.local_now/0` gives whole
  # seconds), so keys a moment apart can be told apart
  defp now do
    ms = rem(System.os_time(:millisecond), 1000)
    %{NaiveDateTime.local_now() | microsecond: {ms * 1000, 3}}
  end

  @doc "Input from the terminal: its bytes, the keys read from them, the boxes open."
  @spec input(binary, [term], State.t()) :: :ok
  def input(bytes, keys, state) do
    # an Agenda file's password (R72) stays out of the log: only how many
    # keys came
    if Agendum.TUI.Update.Prompts.password_prompt?(state),
      do: write("input (#{length(keys)} keys hidden: a password)#{modes(state)}"),
      else: write("input #{inspect(bytes)} → #{inspect(keys)}#{modes(state)}")
  end

  @doc "Keys a macro plays."
  @spec macro([term]) :: :ok
  def macro(keys), do: write("macro plays #{inspect(keys)}")

  @doc """
  An effect `App` has run, and how long it took in milliseconds
  (`effect_text/2`). It is logged when done, so a crash in it is logged
  with the state instead (`crash/4`).
  """
  @spec effect(term, non_neg_integer) :: :ok
  def effect(effect, ms), do: write(effect_text(effect, ms))

  @doc "The log line for an effect; text written to a file is counted, not copied."
  @spec effect_text(term, non_neg_integer) :: String.t()
  def effect_text({:write_text, path, text}, ms),
    do: "effect write_text #{path} (#{byte_size(text)} bytes) in #{ms} ms"

  def effect_text({:save_preferences, path, _prefs}, ms),
    do: "effect save_preferences #{path} in #{ms} ms"

  def effect_text(effect, ms), do: "effect #{inspect(effect)} in #{ms} ms"

  @doc "The file in use, with its size, time and fingerprint on disk (`file_text/2`)."
  @spec file(State.t()) :: :ok
  def file(state), do: write(file_text(state, on_disk(state.path)))

  @typedoc """
  A file as it is on disk: its size in bytes, when it was last changed
  (local time), and a fingerprint of its bytes, which tells whether a copy
  is the same file.
  """
  @type disk :: %{size: non_neg_integer, modified: NaiveDateTime.t(), fingerprint: String.t()}

  @doc """
  The log line naming the file in use and its size, and how it is on disk
  (nil: not there, as a new file not saved yet). To replay a session's
  keys on a copy of the file, the copy's fingerprint must be the same.
  """
  @spec file_text(State.t(), disk | nil) :: String.t()
  def file_text(%State{path: path, db: db}, disk) do
    "file #{path || "not saved yet"} " <>
      "(#{map_size(db.items)} items, #{map_size(db.categories)} categories)" <>
      disk_text(path, disk)
  end

  defp disk_text(nil, _disk), do: ""
  defp disk_text(_path, nil), do: " · not on disk"

  defp disk_text(_path, disk) do
    " · on disk #{disk.size} bytes, changed #{NaiveDateTime.to_iso8601(disk.modified)}, " <>
      "fingerprint #{disk.fingerprint}"
  end

  @doc "The fingerprint of a file's bytes: eight hex digits."
  @spec fingerprint(binary) :: String.t()
  def fingerprint(bytes) do
    # `phash2/2` is a hash built into the runtime, enough to tell files
    # apart (it is no proof against tampering, nor needs to be)
    bytes
    |> :erlang.phash2(0x100000000)
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(8, "0")
  end

  defp on_disk(nil), do: nil

  defp on_disk(path) do
    with {:ok, %File.Stat{size: size, mtime: mtime}} <- File.stat(path, time: :local),
         {:ok, bytes} <- File.read(path) do
      %{size: size, modified: NaiveDateTime.from_erl!(mtime), fingerprint: fingerprint(bytes)}
    else
      _ -> nil
    end
  end

  # an answer this slow, from key to screen, is noticed: log it
  @slow_ms 100

  @typedoc """
  How long the answer to some keys took, in milliseconds: `total` from the
  first key's arrival to the screen drawn, of which `update` handling the
  keys and `draw` drawing; the rest was waiting (keys queued behind an
  earlier answer, or the rest of an escape sequence awaited).
  """
  @type answer :: %{keys: [term], total: integer, update: integer, draw: integer}

  @typedoc """
  The runtime's work at a moment (`runtime/0`): garbage collections so
  far, and memory in bytes, all of it and the main loop's own.
  """
  @type runtime :: %{collections: non_neg_integer, memory: pos_integer, loop: pos_integer}

  @doc """
  The runtime's work now. Taken before and after an answer, it tells
  whether time went to freeing memory rather than to our code.
  """
  @spec runtime() :: runtime
  def runtime do
    {collections, _words, _} = :erlang.statistics(:garbage_collection)
    {:memory, loop} = Process.info(self(), :memory)
    %{collections: collections, memory: :erlang.memory(:total), loop: loop}
  end

  @doc """
  An answer to keys that took #{@slow_ms} ms or more (`slow_text/1`), with
  the view on screen (`view_text/1`) and the runtime's work during it
  (`runtime/0` at the start, `before`).
  """
  @spec slow(answer, State.t(), runtime) :: :ok
  def slow(answer, state, before) do
    case slow_text(answer) do
      nil -> :ok
      text -> write(text <> " · " <> view_text(state) <> " · " <> runtime_text(before, runtime()))
    end
  end

  @doc "The log line for a slow answer, nil for a quick one."
  @spec slow_text(answer) :: String.t() | nil
  def slow_text(%{total: total}) when total < @slow_ms, do: nil

  def slow_text(%{keys: keys, total: total, update: update, draw: draw}) do
    waiting = max(total - update - draw, 0)

    "slow answer #{total} ms to #{inspect(keys, limit: 8)} " <>
      "(waiting #{waiting} ms, update #{update} ms, draw #{draw} ms)"
  end

  @doc """
  The view on screen, and what makes one slow to show: its sections and
  filters, which a view reads for every item ("filters 1" in the clinic's
  Overdue view). Counted from the view, not built, so it costs nothing.
  """
  @spec view_text(State.t()) :: String.t()
  def view_text(state) do
    view = State.view(state)
    filters = length(view.filter) + Enum.sum_by(view.sections, &length(&1.filter))
    kind = if view.datebook, do: "datebook, ", else: ""

    "view #{inspect(view.name)} (#{kind}#{count(length(view.sections), "section")}, " <>
      "#{count(filters, "filter")})"
  end

  @doc "The runtime's work between two `runtime/0`s, as the log shows it."
  @spec runtime_text(runtime, runtime) :: String.t()
  def runtime_text(before, now) do
    "#{count(now.collections - before.collections, "garbage collection")}, " <>
      "memory #{mb(now.memory)} (main loop #{mb(now.loop)})"
  end

  defp count(1, word), do: "1 #{word}"
  defp count(n, word), do: "#{n} #{word}s"

  defp mb(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  @doc "The program and the build: version, commit, and dev or prod."
  @spec build_text() :: String.t()
  def build_text, do: "Wol's Agendum #{@version} (commit #{@commit}, #{@build_env} build)"

  @doc "A message or error new on the screen since `before`."
  @spec message(State.t() | nil, State.t()) :: :ok
  def message(%State{message: same}, %State{message: same}), do: :ok
  def message(_before, %State{message: {kind, text}}), do: write("#{kind} #{text}")
  def message(_before, _state), do: :ok

  @doc "A crash: what was raised, where, and the state it happened in."
  @spec crash(atom, term, Exception.stacktrace(), State.t()) :: :ok
  def crash(kind, reason, stacktrace, state) do
    context =
      state
      |> DevTools.lines(%{key: nil})
      # from Screen on: the key tester's part means nothing here
      |> Enum.drop_while(&(&1 != "Screen"))
      |> Enum.map_join("\n", fn
        {label, value} -> "  #{label}: #{value}"
        heading -> heading
      end)

    write("""
    CRASH
    #{Exception.format(kind, reason, stacktrace)}
    State before it:
    #{context}
    Mode stack: #{inspect(state.modes, limit: 50, printable_limit: 200)}\
    """)
  end

  defp header(env, args) do
    {family, name} = :os.type()

    write("""
    #{build_text()} · Elixir #{System.version()} / OTP #{System.otp_release()} · \
    #{family}/#{name} #{:os.version() |> Tuple.to_list() |> Enum.join(".")}
    TERM #{env["TERM"]} · COLORTERM #{env["COLORTERM"]} · TERM_PROGRAM #{env["TERM_PROGRAM"]} · \
    LANG #{env["LANG"]}
    args #{inspect(args)}\
    """)
  end

  defp modes(%State{modes: []}), do: ""
  defp modes(state), do: "  [#{Enum.map_join(state.modes, " > ", & &1.type)}]"
end
