defmodule Agendum.TUI.DebugLog do
  @moduledoc """
  A log of each session for debugging, on when the `AGENDUM_LOG`
  environment variable is set: `1` writes to
  `$XDG_STATE_HOME/agendum/logs` (`~/.local/state/agendum/logs`), a path
  writes to that folder.

  One file a session (`session-<time>.log`). It holds the program,
  terminal and arguments, every input as bytes and decoded keys (with the
  boxes open), the keys a macro plays, the effects run, new messages and
  errors, and a crash: the exception, its stack trace and the state as
  the developer screen (`Agendum.TUI.DevTools`) shows it. Starting a
  session deletes all but the newest four, so five are kept.

  What is typed is in the log, so it stays on this computer. Logging
  never stops the program: a log that cannot be written is left off.
  `dir/1`, `file_name/1` and `old_sessions/1` are pure; the rest writes
  (imperative shell, called by `Agendum.CLI` and `Agendum.TUI.App`).
  """

  alias Agendum.TUI.{DevTools, State}

  # the open log file is a process (an Erlang IO device) registered under
  # this name, so the main loop does not have to carry it around
  @name :agendum_debug_log
  @keep 5
  @version Mix.Project.config()[:version]

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
  def input(bytes, keys, state),
    do: write("input #{inspect(bytes)} → #{inspect(keys)}#{modes(state)}")

  @doc "Keys a macro plays."
  @spec macro([term]) :: :ok
  def macro(keys), do: write("macro plays #{inspect(keys)}")

  @doc "An effect `App` runs; text written to a file is counted, not copied."
  @spec effect(term) :: :ok
  def effect({:write_text, path, text}),
    do: write("effect write_text #{path} (#{byte_size(text)} bytes)")

  def effect({:save_preferences, path, _prefs}), do: write("effect save_preferences #{path}")
  def effect(effect), do: write("effect #{inspect(effect)}")

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
    Wol's Agendum #{@version} · Elixir #{System.version()} / OTP #{System.otp_release()} · \
    #{family}/#{name} #{:os.version() |> Tuple.to_list() |> Enum.join(".")}
    TERM #{env["TERM"]} · COLORTERM #{env["COLORTERM"]} · TERM_PROGRAM #{env["TERM_PROGRAM"]} · \
    LANG #{env["LANG"]}
    args #{inspect(args)}\
    """)
  end

  defp modes(%State{modes: []}), do: ""
  defp modes(state), do: "  [#{Enum.map_join(state.modes, " > ", & &1.type)}]"
end
