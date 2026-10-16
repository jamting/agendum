defmodule Agendum.TUI.App do
  @moduledoc """
  The main loop (imperative shell): reads keys, feeds them to the pure
  `Update`, performs the resulting effects, and draws `Render` output.
  """

  alias Agendum.{CalendarFetch, Preferences, Publish, Store}

  alias Agendum.TUI.{
    DebugLog,
    Terminal.Keys,
    Layout,
    Render,
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

        # `try … after` runs `after` however `loop` ends, by returning or
        # by a crash, so the terminal is always given back in a usable
        # state (cursor shown, normal mode).
        try do
          loop(state, nil, "", state.theme)
        after
          Terminal.stop()
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

      # a calendar read in the background (R45)
      {:calendar_read, id, result, ms} ->
        DebugLog.write("calendar #{id} read: #{elem(result, 0)} in #{ms} ms")
        state = logged(state, fn -> Update.calendar_read(state, id, result) end)
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
  defp logged(state, fun) do
    fun.()
  catch
    kind, reason ->
      DebugLog.crash(kind, reason, __STACKTRACE__, state)
      :erlang.raise(kind, reason, __STACKTRACE__)
  end

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
  # `Update` (`saved/3`, `loaded/3` …), which decides what the person sees:
  # `Update` never touches a file, and `App` never decides anything. A
  # `case` on the effect's shape is the dispatch.
  defp run_effects(state, []), do: {:ok, state}
  defp run_effects(state, [:quit | _]), do: {:quit, state}

  defp run_effects(state, [effect | rest]) do
    started = now_ms()
    before = state.prefs
    before_path = state.path

    state =
      case effect do
        {:save, path, opts} ->
          Update.saved(state, path, Store.save(state.db, path, opts.expect), opts)

        {:load, path} ->
          Update.loaded(state, path, Store.load_with_stamp(path))

        {:open_or_create, path} ->
          Update.opened(state, path, Store.load_with_stamp(path))

        {:write_text, path, text} ->
          Update.written(state, path, File.write(path, text))

        {:import_json, path} ->
          Update.imported(state, path, File.read(path))

        {:list_dir, dir} ->
          Update.dir_listed(state, dir, Store.list_dir(dir))

        # the micro-blog (R74): what the folder holds, then writing and
        # uploading it
        {:publish_scan, folder, files} ->
          Update.publish_scanned(state, folder, files, Publish.scan(Path.expand(folder), files))

        {:publish, folder, files, changes, password} ->
          dir = Path.expand(folder)

          result =
            with :ok <- Publish.write(dir, files, changes),
                 do: Publish.upload(state.db.blog, dir, files, changes, password)

          Update.published(state, changes, result)

        {:save_preferences, path, prefs} ->
          Update.preferences_saved(state, Preferences.save(prefs, path))

        {:fetch_calendar, id, url} ->
          # `self()` is read here, in the loop's process: inside the `fn`
          # below it would be the task's own pid. The task reads the
          # calendar in the background and mails the result back, which
          # `wait/5` receives as `{:calendar_read, …}`.
          loop = self()

          Task.start(fn ->
            started = now_ms()
            result = CalendarFetch.read(url)
            send(loop, {:calendar_read, id, result, now_ms() - started})
          end)

          state
      end

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

  # 24-bit colour when the terminal says it takes it (Theme.depth/1)
  defp colour_depth, do: Theme.depth(System.get_env("COLORTERM"))

  defp draw(state, previous, theme) do
    {width, height} = Terminal.size()
    before = state
    {state, effects} = Update.tick(state, local_now())
    if :bell in effects, do: Terminal.write("\a")
    {:ok, state} = run_effects(state, List.delete(effects, :bell))
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
