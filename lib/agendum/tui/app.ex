defmodule Agendum.TUI.App do
  @moduledoc """
  The main loop (imperative shell): reads keys, feeds them to the pure
  `Update`, performs the resulting effects, and draws `Render` output.
  """

  alias Agendum.{Preferences, Store}
  alias Agendum.Extras.{CalendarFetch, FeedFetch, Publish}

  alias Agendum.TUI.{
    DebugLog,
    Effect,
    Terminal.Keys,
    Layout,
    Render,
    Speaker,
    Terminal.Screen,
    State,
    Terminal,
    Terminal.Theme,
    Update
  }

  # How long to wait for the rest of an escape sequence before treating ESC
  # as a key: a lone ESC is answered this much later. A terminal sends a
  # key's bytes together; the debug logs show the rest of a split sequence
  # 0.3–2 ms after the ESC. (40 ms until 2026-10-15; a slow remote link
  # might need more.)
  @escape_timeout 25
  # How often to check for terminal resizes and date changes when idle.
  @idle_timeout 500

  @doc "Runs the program until it quits, drawing with the state's `Agendum.TUI.Terminal.Theme`."
  @spec run(State.t()) :: :ok | {:error, term}
  def run(%State{} = state) do
    case Terminal.start() do
      :ok ->
        Terminal.start_reader(self())
        DebugLog.file(state)

        # the file opened at startup is backed up first, when it asks for it
        # (R82); its other effects stay as they were left (the alarms rung
        # while it was closed ring quietly, R70)
        {backups, others} = Enum.split_with(state.effects, &match?({:backup_file, _}, &1))
        {:ok, state} = run_effects(%{state | effects: others}, backups)

        # `try … after` runs `after` however `loop` ends, by returning or
        # by a crash, so the terminal is always given back in a usable
        # state (cursor shown, normal mode).
        # Erlang's logger reports go to the debug log, never over the
        # screen, until the terminal is given back
        logger = DebugLog.capture_logger()

        try do
          loop(state, nil, "", state.theme)
        after
          Terminal.stop()
          DebugLog.release_logger(logger)
        end

      error ->
        error
    end
  end

  # `theme` is the theme `previous` was drawn with; a new one redraws all.
  # `answer` times the keys just handled (`DebugLog.slow/1`), or is nil.
  #
  # There are no mutable variables: the program's whole memory between keys
  # is these arguments. `loop`, `wait` and `continue` call each other as
  # their last step (tail calls), each with the new values, so the loop
  # runs forever without growing the stack. `previous` is the screen last
  # drawn, `buffer` the bytes of a key not yet complete.
  # `answer \\ nil` is a default argument: it defines `loop/4` as well.
  defp loop(state, previous, buffer, theme, answer \\ nil) do
    previous = if state.theme == theme, do: previous, else: nil
    theme = state.theme
    started = now_ms()
    {state, previous} = logged(state, fn -> draw(state, previous, theme) end)

    if answer do
      done = now_ms()
      %{keys: keys, since: since, update: update, runtime: runtime} = answer

      DebugLog.slow(
        %{keys: keys, total: done - since, update: update, draw: done - started},
        state,
        runtime
      )
    end

    wait(state, previous, buffer, theme, nil)
  end

  # Waits for input without drawing. `since` is when the first byte not
  # yet answered arrived (monotonic ms), or nil.
  defp wait(state, previous, buffer, theme, since) do
    timeout = if buffer == "", do: @idle_timeout, else: @escape_timeout

    # `receive` takes the first message in this process's mailbox that
    # matches one of the patterns, waiting until one comes. `after` gives
    # up after `timeout` milliseconds: half a second when idle, so the
    # clock and alarms move on with no key pressed (`draw/3` calls
    # `Update.tick/2`), or a few ms when half an escape sequence is waiting.
    receive do
      {:input, data, at} ->
        # everything typed meanwhile is answered with one drawing, so keys
        # held down or typed fast never queue up behind the screen
        data = data <> pending_input()
        {keys, rest} = Keys.decode(buffer <> data)
        DebugLog.input(data, keys, state)
        # `||` keeps the first arrival: the wait for the rest counts too
        since = since || at

        # only part of an escape sequence (a key's first bytes): nothing
        # to draw until the rest comes
        if keys == [],
          do: wait(state, previous, rest, theme, since),
          else: continue(state, previous, keys, rest, theme, since)

      :input_closed ->
        DebugLog.write("input closed")
        :ok

      # a feed read in the background (R75)
      {:feed_read, id, result, ms} ->
        DebugLog.write("feed #{id} read: #{elem(result, 0)} in #{ms} ms")
        state = logged(state, fn -> Update.Results.feed_read(state, id, result) end)
        loop(state, previous, buffer, theme)

      # the blog written and uploaded in the background (R74)
      {:published, changes, result} ->
        Process.delete(:agendum_publishing)
        DebugLog.write("published: #{elem(result, 0)}")
        state = logged(state, fn -> Update.Results.published(state, changes, result) end)
        loop(state, previous, buffer, theme)

      # a calendar read in the background (R45)
      {:calendar_read, id, result, ms} ->
        DebugLog.write("calendar #{id} read: #{elem(result, 0)} in #{ms} ms")
        state = logged(state, fn -> Update.Results.calendar_read(state, id, result) end)
        loop(state, previous, buffer, theme)
    after
      timeout ->
        keys = Keys.flush(buffer)
        if keys != [], do: DebugLog.input(buffer, keys, state)
        continue(state, previous, keys, "", theme, since)
    end
  end

  # The input already in the mailbox, taken without waiting (`after 0`):
  # `receive` with a zero timeout returns at once when nothing matches.
  defp pending_input(acc \\ "") do
    receive do
      {:input, data, _at} -> pending_input(acc <> data)
    after
      0 -> acc
    end
  end

  defp continue(state, previous, keys, rest, theme, since) do
    started = now_ms()
    # garbage collections and memory now, for a slow answer's log line
    runtime = DebugLog.runtime()

    case logged(state, fn -> apply_keys(state, keys) end) do
      {:quit, _state} ->
        :ok

      {:ok, state} ->
        # `&&` gives nil when there is nothing to time (an idle tick)
        answer =
          since && %{keys: keys, since: since, update: now_ms() - started, runtime: runtime}

        loop(state, previous, rest, theme, answer)
    end
  end

  defp now_ms, do: System.monotonic_time(:millisecond)

  # A crash in `fun` goes to the debug log with `state`, the state it
  # started from, and is then raised again unchanged. (`catch kind, reason`
  # catches all three kinds of Erlang failure: error, throw and exit.)
  # `fun.()` calls a function value; the dot tells it apart from calling a
  # named function. A `def` body can have `catch` (and `rescue`, `after`)
  # without writing `try`.
  # The unsaved changes are kept first, beside the file (R82b), and their
  # path put in this process's dictionary for `Agendum.CLI` to name once
  # the terminal is back (the crash itself unwinds everything else).
  defp logged(state, fun) do
    fun.()
  catch
    kind, reason ->
      DebugLog.crash(kind, reason, __STACKTRACE__, state)
      kept = keep_unsaved(state, System.get_env())
      if kept, do: Process.put(:agendum_recovered, kept)
      :erlang.raise(kind, reason, __STACKTRACE__)
  end

  @doc """
  On a crash: the unsaved changes written to the recovery file
  (`Store.recovery_path/2`, R82b; `env` places an untitled file's), and its
  path; nil when nothing was unsaved or it could not be written. Never
  raises: a crash is already under way.
  """
  @spec keep_unsaved(State.t(), %{String.t() => String.t()}) :: String.t() | nil
  def keep_unsaved(%State{dirty: true} = state, env) do
    path = Store.recovery_path(state.path, env)

    with path when path != nil <- path,
         :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- Store.save(state.db, path) do
      DebugLog.write("unsaved changes kept in #{path}")
      path
    else
      _ -> nil
    end
  catch
    _kind, _reason -> nil
  end

  def keep_unsaved(_state, _env), do: nil

  @doc """
  After a file at `path` was opened: when a crash kept changes beside it
  (R82b), they are read (with the file's password) and offered
  (`Update.recovery_found/3`).
  """
  @spec check_recovery(State.t(), String.t() | nil) :: State.t()
  def check_recovery(state, path) when is_binary(path) do
    rpath = Store.recovery_path(path)

    if state.path == path and File.exists?(rpath) do
      result =
        with {:ok, db} <- Store.load(rpath, state.db.password),
             {:ok, stat} <- File.stat(rpath, time: :local),
             do: {:ok, db, NaiveDateTime.from_erl!(stat.mtime)}

      Update.Results.recovery_found(state, path, result)
    else
      state
    end
  end

  def check_recovery(state, _path), do: state

  defp apply_keys(state, []), do: {:ok, state}

  # Domain: the heart of the shell. For each key, the pure `Update.handle/2`
  # gives a new state and a list of effects (data saying "save this file",
  # "quit" …), and only here are they carried out. Keys are handled one by
  # one; the screen is drawn once after all of them (`loop/5`).
  defp apply_keys(state, [key | keys]) do
    before = state
    {state, effects} = Update.handle(state, key)

    # a macro run (R50): its keys come next, one by one, before the rest
    {plays, effects} = Enum.split_with(effects, &match?({:play, _}, &1))
    played = Enum.flat_map(plays, fn {:play, played} -> played ++ [:macro_done] end)
    if played != [], do: DebugLog.macro(played)
    keys = played ++ keys

    case run_effects(state, effects) do
      {:quit, state} ->
        DebugLog.write("quit")
        {:quit, state}

      {:ok, state} ->
        DebugLog.message(before, state)
        apply_keys(state, keys)
    end
  end

  # Each effect is done, and its result handed back to a pure function of
  # `Update.Results` (`saved/4`, `loaded/3` …), which decides what the person sees:
  # `Update` never touches a file, and `App` never decides anything.
  # `perform/2`'s clauses, one per shape of effect, are the dispatch; the
  # shapes are listed in `Agendum.TUI.Effect`. Public only for its test
  # (`@doc false` keeps it out of the API docs).
  @doc false
  @spec run_effects(State.t(), [Effect.t()]) :: {:ok | :quit, State.t()}
  def run_effects(state, []), do: {:ok, state}
  def run_effects(state, [:quit | _]), do: {:quit, state}

  def run_effects(state, [effect | rest]) do
    started = now_ms()
    before = state.prefs
    before_path = state.path

    state = perform(state, effect)

    DebugLog.effect(effect, now_ms() - started)

    # another file opened, or this one saved under a new name
    if state.path != before_path or
         match?({kind, _} when kind in [:load, :open_or_create], effect),
       do: DebugLog.file(state)

    # the last file used changed the preferences (R52): keep them
    if state.prefs != before and state.prefs.path,
      do: Preferences.save(state.prefs, state.prefs.path)

    # what the result asked for next, such as quitting once the file is
    # saved (R71), comes before the effects still waiting
    run_effects(%{state | effects: []}, state.effects ++ rest)
  end

  # One clause per kind of effect (`Agendum.TUI.Effect`), each giving the
  # new state; the last takes whatever is left. (Function clauses are tried
  # top to bottom, as the clauses of a `case` are.)
  # one of Agenda's sounds (R76)
  defp perform(state, {:sound, name}) do
    Speaker.play(name)
    state
  end

  defp perform(state, {:save, path, opts}),
    do: Update.Results.saved(state, path, Store.save(state.db, path, opts.expect), opts)

  # File ▸ Maintenance ▸ MakeCopy and Transfer ▸ Template (R82): another
  # file written, whatever is there (Agenda's caution), this one unchanged
  defp perform(state, {:save_copy, path, db}),
    do: Update.Results.copied(state, path, Store.save(db, path, :any))

  # F8 in the Select File box (R82)
  defp perform(state, {:read_descriptions, dir, names}),
    do: Update.Results.descriptions_read(state, dir, Store.descriptions(dir, names))

  # File Properties ▸ Make backup on open (R82)
  defp perform(state, {:backup_file, path}),
    do: Update.Results.backed_up(state, path, Store.backup(path))

  # File ▸ Maintenance ▸ Erase (R82): to the system's Trash
  defp perform(state, {:trash_file, path}),
    do: Update.Results.trashed(state, path, Store.trash(path))

  # a crash's changes beside the file are offered once it is open (R82b)
  defp perform(state, {:load_password, path, password}),
    do:
      state
      |> Update.Results.loaded(path, Store.load_with_stamp(path, password))
      |> check_recovery(path)

  defp perform(state, {:load, path}),
    do: state |> Update.Results.loaded(path, Store.load_with_stamp(path)) |> check_recovery(path)

  defp perform(state, {:open_or_create, path}),
    do: state |> Update.Results.opened(path, Store.load_with_stamp(path)) |> check_recovery(path)

  # a crash's changes, now saved into the file (R82b)
  defp perform(state, {:remove_recovery, path}) do
    File.rm(path)
    state
  end

  defp perform(state, {:write_text, path, text}),
    do: Update.Results.written(state, path, File.write(path, text))

  defp perform(state, {:import_json, path}),
    do: Update.Results.imported(state, path, File.read(path))

  # a note's Import (R64c)
  defp perform(state, {:read_note_text, path}),
    do: Update.Results.note_text_read(state, path, File.read(path))

  defp perform(state, {:list_dir, dir}),
    do: Update.Results.dir_listed(state, dir, Store.list_dir(dir))

  # a feed read in the background, as a calendar is (R75)
  defp perform(state, {:fetch_feed, id, url}) do
    loop = self()

    Task.start(fn ->
      started = now_ms()
      result = fetched(fn -> FeedFetch.read(url) end)
      send(loop, {:feed_read, id, result, now_ms() - started})
    end)

    state
  end

  # an entry's link in the browser (R75), and a feed list (OPML)
  defp perform(state, {:open_url, url}),
    do: Update.Results.url_opened(state, url, FeedFetch.open_url(url))

  defp perform(state, {:read_opml, path}),
    do: Update.Results.opml_read(state, path, File.read(Path.expand(path)))

  # the micro-blog (R74): what the folder holds, then writing and
  # uploading it
  defp perform(state, {:publish_scan, folder, files}),
    do:
      Update.Results.publish_scanned(
        state,
        folder,
        files,
        Publish.scan(Path.expand(folder), files)
      )

  # in the background, as a feed is read: an upload that stalls must not
  # stop the program (code review 2026-10-26); one at a time
  defp perform(state, {:publish, folder, files, changes, password}) do
    if Process.get(:agendum_publishing) do
      state
    else
      Process.put(:agendum_publishing, true)
      loop = self()
      dir = Path.expand(folder)
      blog = state.db.blog

      Task.start(fn ->
        result = fetched(fn -> publish_site(blog, dir, files, changes, password) end)
        send(loop, {:published, changes, result})
      end)

      State.info(state, "Publishing …")
    end
  end

  defp perform(state, {:save_preferences, path, prefs}),
    do: Update.Results.preferences_saved(state, Preferences.save(prefs, path))

  defp perform(state, {:fetch_calendar, id, url}) do
    # `self()` is read here, in the loop's process: inside the `fn`
    # below it would be the task's own pid. The task reads the
    # calendar in the background and mails the result back, which
    # `wait/5` receives as `{:calendar_read, …}`.
    loop = self()

    Task.start(fn ->
      started = now_ms()
      result = fetched(fn -> CalendarFetch.read(url) end)
      send(loop, {:calendar_read, id, result, now_ms() - started})
    end)

    state
  end

  # an effect not on the closed list (`Effect.known?/1` is false): a bug in
  # the TUI. It goes to the debug log and is skipped, so the person keeps
  # their unsaved work rather than losing it to a crash (a `:bell` did that
  # on 2026-10-17).
  defp perform(state, unknown) do
    DebugLog.write("unknown effect skipped: #{inspect(unknown)}")
    state
  end

  # the site written into its folder, then uploaded, in the background task
  defp publish_site(blog, dir, files, changes, password) do
    with :ok <- Publish.write(dir, files, changes),
         do: Publish.upload(blog, dir, files, changes, password)
  end

  @doc """
  A feed's or calendar's read (`fun`), run in its background task: a read
  that crashes outright comes back as an error the person is shown, rather
  than ending the task silently with a report on the screen (meeting
  2026-10-26-4, § 6). The crash itself goes to the debug log.
  """
  @spec fetched((-> {:ok, term} | {:error, String.t()})) :: {:ok, term} | {:error, String.t()}
  def fetched(fun) do
    fun.()
  catch
    kind, reason ->
      DebugLog.write("fetch crashed: " <> Exception.format(kind, reason, __STACKTRACE__))
      {:error, "could not be read (#{Exception.format_banner(kind, reason)})"}
  end

  # 24-bit colour when the terminal says it takes it (Theme.depth/1)
  defp colour_depth, do: Theme.depth(System.get_env("COLORTERM"))

  defp draw(state, previous, theme) do
    {width, height} = Terminal.size()
    before = state
    {state, effects} = Update.tick(state, local_now())
    {:ok, state} = run_effects(state, effects)
    # an alarm or an auto-save says so
    DebugLog.message(before, state)
    resized = {width, height} != {state.width, state.height}
    if resized, do: DebugLog.write("terminal #{width}×#{height}")
    state = %{state | width: width, height: height}
    state = if resized, do: Layout.settle(state), else: state
    previous = if resized, do: nil, else: previous

    screen = Render.render(state)
    if previous == nil, do: Terminal.write("\e[2J")
    Terminal.write(Screen.frame(previous, screen, theme, colour_depth()))
    {state, screen}
  end

  @doc false
  def local_now do
    {date, {h, m, s}} = :calendar.local_time()
    NaiveDateTime.new!(Date.from_erl!(date), Time.new!(h, m, s))
  end

  @doc false
  def local_today do
    {date, _time} = :calendar.local_time()
    Date.from_erl!(date)
  end
end
