# SPDX-License-Identifier: AGPL-3.0-only
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
  the developer screen (`Agendum.TUI.DevTools`) shows it, and
  Erlang's logger reports (`capture_logger/0`). Starting a
  session deletes all but the newest nine, so ten are kept (meeting
  2026-10-26-1524, § 7). A web address is written by its host only
  (`redact/1`): a calendar's or feed's address can hold a private token.

  What is typed is in the log, so it stays on this computer; but while the
  file has a password (ADR 0046), and so is encrypted on disk, its text is
  kept out of the log too: typed characters are counted, not written, and
  messages, the view's name, a crash's message and the arguments in its
  stack trace are left out (`encrypted?/1`). Logging
  never stops the program: a log that cannot be written is left off.
  `dir/1`, `file_name/1`, `old_sessions/1`, `build_text/0`, `file_text/2`,
  `view_text/1`, `slow_text/1`, `effect_text/2` and `redact/1` are pure; the rest writes
  (imperative shell, called by `Agendum.CLI` and `Agendum.TUI.App`).
  """

  alias Agendum.TUI.{DevTools, State}

  # the open log file is a process (an Erlang IO device) registered under
  # this name, so the main loop does not have to carry it around
  @name :agendum_debug_log
  @keep 10
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
      # where the log is, for `follow/2` to rewrite it; `persistent_term`
      # is the runtime's store for values set once and read often
      :persistent_term.put({__MODULE__, :path}, path)
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

  @doc """
  While the terminal UI runs, Erlang's logger must not print over the
  screen (it did once, offline, on a closed laptop: meeting 2026-10-26-1524,
  § 6). This takes its default handler away and puts one in its place that
  writes each report to the debug log, or nowhere when it is off. Returns
  what `release_logger/1` needs to put the default back.
  """
  @spec capture_logger(State.t() | nil) :: map | nil
  def capture_logger(state \\ nil) do
    # `:logger` is Erlang's logging system; a handler is a module whose
    # `log/2` gets each report. The default one writes to the terminal.
    saved =
      case :logger.get_handler_config(:default) do
        {:ok, config} -> config
        {:error, _} -> nil
      end

    if saved, do: :logger.remove_handler(:default)
    # `config` is the handler's own data, given to `log/2` with each report:
    # whether the file has a password, kept up to date by `follow/2`
    hidden = state != nil and encrypted?(state)
    :logger.add_handler(@name, __MODULE__, %{level: :all, config: %{hidden: hidden}})
    saved
  end

  @doc "Puts the logger's default handler back when the terminal UI ends."
  @spec release_logger(map | nil) :: :ok
  def release_logger(saved) do
    :logger.remove_handler(@name)
    if saved, do: :logger.add_handler(:default, saved.module, saved)
    :ok
  end

  @doc false
  # the logger handler's callback (`capture_logger/1`): one report, on one
  # line; only its level while the file has a password, as a crashed
  # background task's report can carry the file's text (a publish's posts).
  # It runs in the process that reported, which cannot see the main loop's
  # state: hence the handler's own `hidden`.
  def log(%{level: level}, %{config: %{hidden: true}}),
    do: write("logger #{level} (report hidden: a file with a password)")

  def log(event, _config) do
    text = :logger_formatter.format(event, %{single_line: true, template: [:level, " ", :msg]})
    write("logger " <> IO.iodata_to_binary(text))
  end

  @doc """
  How background work ended, for a log line: `ok` or `error`. A result is
  `:ok` alone (a site published) or a tuple (`{:ok, entries}`,
  `{:error, reason}`); `elem/2` on a bare `:ok` crashed Agendum after every
  publish (v0.68.4, found by the owner 2026-10-26).
  """
  @spec outcome(term) :: String.t()
  def outcome(result) when is_tuple(result) and tuple_size(result) > 0,
    do: to_string(elem(result, 0))

  def outcome(result) when is_atom(result), do: to_string(result)
  def outcome(_result), do: "?"

  @doc "Writes a line, with the time, when a log is open."
  @spec write(String.t()) :: :ok
  def write(text) do
    case Process.whereis(@name) do
      nil ->
        :ok

      pid ->
        line = "#{now() |> NaiveDateTime.to_time() |> Time.to_iso8601()} #{redact(text)}\n"

        # Domain: logging never stops the program (code review 2026-10-26: a
        # full disk raised here, outside the crash guard, and lost the
        # unsaved changes); a log that cannot be written is left off
        try do
          IO.write(pid, line)
        catch
          _kind, _reason ->
            forget_log()
        end
    end
  end

  # the log's name dropped; a device that died (a lost drive) took its
  # name with it already, and unregistering it again would raise (the
  # full suite, 2026-10-27: a flaky crash of the very write meant never
  # to crash)
  defp forget_log do
    Process.unregister(@name)
    :ok
  rescue
    ArgumentError -> :ok
  end

  @doc """
  A line with every web address cut to its host (`https://cal.example/…`):
  the path and query of a calendar's or feed's address can hold a private
  token, and a log may be sent to someone (meeting 2026-10-26-1524, § 7).
  """
  @spec redact(String.t()) :: String.t()
  def redact(text) do
    # the scheme (1), any `user:password@` (2, always dropped), the host (3)
    # and what follows it (4, a path, query or fragment: "/…")
    Regex.replace(
      ~r{\b(https?|webcal|feed)://([^/\s"?#@]*@)?([^/\s"?#@]+)([/?#][^\s"]*)?}i,
      text,
      fn _all, scheme, _userinfo, host, rest ->
        scheme <> "://" <> host <> if(rest == "", do: "", else: "/…")
      end
    )
  end

  # local time to the millisecond (`NaiveDateTime.local_now/0` gives whole
  # seconds), so keys a moment apart can be told apart
  defp now do
    ms = rem(System.os_time(:millisecond), 1000)
    %{NaiveDateTime.local_now() | microsecond: {ms * 1000, 3}}
  end

  @doc "Input from the terminal: its bytes, the keys read from them, the boxes open."
  @spec input(binary, [term], State.t()) :: :ok
  def input(bytes, keys, state), do: write(input_text(bytes, keys, state))

  @doc """
  The log line for input: the bytes and keys of a single key, as typed; a
  password's keys only counted. A batch of several keys (a paste, keys typed
  while Agendum was busy) never shows its characters, only how many, its
  other keys by name: the key that opens a password prompt can come in the
  same batch as the password typed after it (code review 2026-10-26), and
  the state the batch arrived in cannot tell. In a file with a password a
  single character is counted too (`encrypted?/1`). Pure.
  """
  @spec input_text(binary, [term], State.t()) :: String.t()
  def input_text(bytes, keys, state) do
    cond do
      Agendum.TUI.Update.Prompts.password_prompt?(state) ->
        "input (#{length(keys)} keys hidden: a password)#{modes(state)}"

      match?([_], keys) and not hide_keys?(keys, state) ->
        "input #{inspect(bytes)} → #{inspect(keys)}#{modes(state)}"

      true ->
        "input #{keys_counted(keys)}#{modes(state)}"
    end
  end

  @doc """
  Whether the file in use has a password (ADR 0046): it is encrypted on
  disk, so its text (items, notes, names, what is typed into it) stays out
  of the log as well.
  """
  @spec encrypted?(State.t()) :: boolean
  def encrypted?(%State{db: db}), do: db.password != nil

  @doc """
  Follows the file in use after a key (`before`, then `now`): Erlang's
  reports are hidden while it has a password, and when the open file gets
  one (File Properties ▸ Set file password, an undoable change, not a file
  opened), what this session's log holds after its header is taken out:
  it was written before the file was protected (SECURITY.md, door 5).
  Older sessions' logs are left as they are.
  """
  @spec follow(State.t(), State.t()) :: :ok
  def follow(before, now) do
    was = encrypted?(before)
    is = encrypted?(now)
    if was != is, do: :logger.update_handler_config(@name, :config, %{hidden: is})
    # a file just opened starts its history afresh; a password set in it
    # is a step of that history
    if is and not was and now.history.undo != [], do: take_out_earlier()
    :ok
  end

  # the header (three lines: the program, the terminal, the arguments)
  # kept, the rest replaced by one line saying how much went; the log is
  # open for appending, so later lines follow the rewritten file
  defp take_out_earlier do
    with pid when pid != nil <- Process.whereis(@name),
         path when path != nil <- :persistent_term.get({__MODULE__, :path}, nil),
         {:ok, text} <- File.read(path) do
      {header, rest} = text |> String.split("\n", trim: true) |> Enum.split(3)
      File.write(path, Enum.join(header, "\n") <> "\n")
      write("#{count(length(rest), "earlier line")} taken out: the file got a password")
    end

    :ok
  end

  # keys whose characters must not be written: any typed text, while the
  # file has a password
  defp hide_keys?(keys, state),
    do: encrypted?(state) and Enum.any?(keys, &match?({:char, _}, &1))

  # keys with their characters counted, not shown, and the rest by name
  # ("3 keys: 2 characters (not shown) and [:enter]")
  defp keys_counted(keys) do
    {chars, others} = Enum.split_with(keys, &match?({:char, _}, &1))

    "#{count(length(keys), "key")}: #{count(length(chars), "character")} (not shown) and " <>
      inspect(others, limit: 8)
  end

  # keys as the log shows them: by name, or counted where text is hidden
  defp keys_text(keys, state) do
    if hide_keys?(keys, state), do: keys_counted(keys), else: inspect(keys, limit: 8)
  end

  @doc """
  Keys a macro plays; a macro is part of the file, so its typed text is
  counted, not written, while the file has a password.
  """
  @spec macro([term], State.t()) :: :ok
  def macro(keys, state), do: write("macro plays #{keys_text(keys, state)}")

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

  # the site's files are counted, and a password never written (R74)
  def effect_text({:publish_scan, folder, files}, ms),
    do: "effect publish_scan #{folder} (#{length(files)} files) in #{ms} ms"

  def effect_text({:publish, folder, _files, changes, password}, ms),
    do:
      "effect publish #{folder} (#{length(changes.added)} added, #{length(changes.changed)} " <>
        "changed, #{length(changes.removed)} removed#{if password, do: ", with a password"}) " <>
        "in #{ms} ms"

  # a file's password never (ADR 0046), nor a whole database copied (R82)
  def effect_text({:load_password, path, _password}, ms),
    do: "effect load_password #{path} (password hidden) in #{ms} ms"

  def effect_text({:save_copy, path, _db}, ms), do: "effect save_copy #{path} in #{ms} ms"

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
    case slow_text(answer, state) do
      nil -> :ok
      text -> write(text <> " · " <> view_text(state) <> " · " <> runtime_text(before, runtime()))
    end
  end

  @doc """
  The log line for a slow answer, nil for a quick one; with the state, its
  typed text is counted in a file with a password.
  """
  @spec slow_text(answer, State.t() | nil) :: String.t() | nil
  def slow_text(answer, state \\ nil)
  def slow_text(%{total: total}, _state) when total < @slow_ms, do: nil

  def slow_text(%{keys: keys, total: total, update: update, draw: draw}, state) do
    waiting = max(total - update - draw, 0)
    keys = if state, do: keys_text(keys, state), else: inspect(keys, limit: 8)

    "slow answer #{total} ms to #{keys} " <>
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
    name = if encrypted?(state), do: "(name hidden)", else: inspect(view.name)

    "view #{name} (#{kind}#{count(length(view.sections), "section")}, " <>
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

  @doc """
  A message or error new on the screen since `before`; only its kind in a
  file with a password, as a message can quote an item or a category.
  """
  @spec message(State.t() | nil, State.t()) :: :ok
  def message(%State{message: same}, %State{message: same}), do: :ok

  def message(_before, %State{message: {kind, text}} = state) do
    if encrypted?(state),
      do: write("#{kind} (text hidden: a file with a password)"),
      else: write("#{kind} #{text}")
  end

  def message(_before, _state), do: :ok

  @doc """
  A crash: what was raised, where, and the state it happened in. In a file
  with a password only the kind of exception and where it happened: its
  message and the arguments in the stack trace can quote the file's text.
  """
  @spec crash(atom, term, Exception.stacktrace(), State.t()) :: :ok
  def crash(kind, reason, stacktrace, state) do
    hidden = encrypted?(state)

    context =
      state
      |> DevTools.lines(%{key: nil})
      # from Screen on: the key tester's part means nothing here
      |> Enum.drop_while(&(&1 != "Screen"))
      |> Enum.map_join("\n", fn
        # the view's name is the file's text
        {"View", _value} when hidden -> "  View: (name hidden)"
        {label, value} -> "  #{label}: #{value}"
        heading -> heading
      end)

    write("""
    CRASH
    #{crash_header(kind, reason, stacktrace, state)}
    State before it:
    #{context}
    Mode stack: #{modes_text(state)}\
    """)
  end

  defp crash_header(kind, reason, stacktrace, state) do
    if encrypted?(state) do
      # `Exception.normalize/3` turns an Erlang error (`:badarg`) into an
      # Elixir exception struct, whose module names the kind of error
      name =
        case Exception.normalize(kind, reason, stacktrace) do
          %{__exception__: true, __struct__: module} -> inspect(module)
          _ -> to_string(kind)
        end

      # a stack frame is {module, function, arguments or arity, place}:
      # the arguments become their count
      frames =
        Enum.map(stacktrace, fn
          {module, fun, args, place} when is_list(args) -> {module, fun, length(args), place}
          frame -> frame
        end)

      "** (#{name}) (message hidden: a file with a password)\n" <>
        Exception.format_stacktrace(frames)
    else
      Exception.format(kind, reason, stacktrace)
    end
  end

  # the fields of a box that can hold a password (ADR 0046): the New File
  # box's, and the Set file password boxes' typed ones
  @secret_fields [:password, :first, :line]

  @doc """
  The mode stack as the crash dump writes it, with every password a box
  still holds hidden (code review 2026-10-26: a crash in the New File box
  wrote it in plain text). Pure.
  """
  @spec modes_text(State.t()) :: String.t()
  # in a file with a password, the boxes' kinds alone: what they hold is
  # the file's text
  def modes_text(%State{db: %{password: password}} = state) when password != nil,
    do: Enum.map_join(state.modes, " > ", &Atom.to_string(&1.type))

  def modes_text(state) do
    state.modes
    |> Enum.map(fn
      %{type: type} = mode when type in [:new_file, :password_box] ->
        Enum.reduce(@secret_fields, mode, fn field, mode ->
          if Map.get(mode, field) in [nil, ""], do: mode, else: Map.put(mode, field, "(hidden)")
        end)
        |> hide_typing()

      mode ->
        mode
    end)
    |> inspect(limit: 50, printable_limit: 200)
  end

  defp hide_typing(%{typing: {field, _text}} = mode), do: %{mode | typing: {field, "(hidden)"}}
  defp hide_typing(mode), do: mode

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
