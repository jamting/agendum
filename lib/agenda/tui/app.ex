defmodule Agenda.TUI.App do
  @moduledoc """
  The main loop (imperative shell): reads keys, feeds them to the pure
  `Update`, performs the resulting effects, and draws `Render` output.
  """

  alias Agenda.{CalendarFetch, Preferences, Store}
  alias Agenda.TUI.{DebugLog, Keys, Layout, Render, Screen, State, Terminal, Theme, Update}

  # How long to wait for the rest of an escape sequence before treating ESC as a key.
  @escape_timeout 40
  # How often to check for terminal resizes and date changes when idle.
  @idle_timeout 500

  @doc "Runs the program until it quits, drawing with the state's `Agenda.TUI.Theme`."
  @spec run(State.t()) :: :ok | {:error, term}
  def run(%State{} = state) do
    case Terminal.start() do
      :ok ->
        Terminal.start_reader(self())

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
  defp loop(state, previous, buffer, theme) do
    previous = if state.theme == theme, do: previous, else: nil
    theme = state.theme
    {state, previous} = logged(state, fn -> draw(state, previous, theme) end)
    timeout = if buffer == "", do: @idle_timeout, else: @escape_timeout

    receive do
      {:input, data} ->
        {keys, rest} = Keys.decode(buffer <> data)
        DebugLog.input(data, keys, state)
        continue(state, previous, keys, rest, theme)

      :input_closed ->
        DebugLog.write("input closed")
        :ok

      # a calendar read in the background (R45)
      {:calendar_read, id, result} ->
        DebugLog.write("calendar #{id} read: #{elem(result, 0)}")
        state = logged(state, fn -> Update.calendar_read(state, id, result) end)
        loop(state, previous, buffer, theme)
    after
      timeout ->
        keys = Keys.flush(buffer)
        if keys != [], do: DebugLog.input(buffer, keys, state)
        continue(state, previous, keys, "", theme)
    end
  end

  defp continue(state, previous, keys, rest, theme) do
    case logged(state, fn -> apply_keys(state, keys) end) do
      {:quit, _state} -> :ok
      {:ok, state} -> loop(state, previous, rest, theme)
    end
  end

  # A crash in `fun` goes to the debug log with `state`, the state it
  # started from, and is then raised again unchanged. (`catch kind, reason`
  # catches all three kinds of Erlang failure: error, throw and exit.)
  defp logged(state, fun) do
    fun.()
  catch
    kind, reason ->
      DebugLog.crash(kind, reason, __STACKTRACE__, state)
      :erlang.raise(kind, reason, __STACKTRACE__)
  end

  defp apply_keys(state, []), do: {:ok, state}

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

  defp run_effects(state, []), do: {:ok, state}
  defp run_effects(state, [:quit | _]), do: {:quit, state}

  defp run_effects(state, [effect | rest]) do
    DebugLog.effect(effect)
    before = state.prefs

    state =
      case effect do
        {:save, path} ->
          Update.saved(state, path, Store.save(state.db, path))

        {:load, path} ->
          Update.loaded(state, path, Store.load(path))

        {:open_or_create, path} ->
          Update.opened(state, path, Store.load(path))

        {:write_text, path, text} ->
          Update.written(state, path, File.write(path, text))

        {:import_json, path} ->
          Update.imported(state, path, File.read(path))

        {:list_dir, dir} ->
          Update.dir_listed(state, dir, Store.list_dir(dir))

        {:save_preferences, path, prefs} ->
          Update.preferences_saved(state, Preferences.save(prefs, path))

        {:fetch_calendar, id, url} ->
          loop = self()
          Task.start(fn -> send(loop, {:calendar_read, id, CalendarFetch.read(url)}) end)
          state
      end

    # the last file used changed the preferences (R52): keep them
    if state.prefs != before and state.prefs.path,
      do: Preferences.save(state.prefs, state.prefs.path)

    run_effects(state, rest)
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
