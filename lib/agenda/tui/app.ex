defmodule Agenda.TUI.App do
  @moduledoc """
  The main loop (imperative shell): reads keys, feeds them to the pure
  `Update`, performs the resulting effects, and draws `Render` output.
  """

  alias Agenda.{Preferences, Store}
  alias Agenda.TUI.{Keys, Layout, Render, Screen, State, Terminal, Update}

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
    {state, previous} = draw(state, previous, theme)
    timeout = if buffer == "", do: @idle_timeout, else: @escape_timeout

    receive do
      {:input, data} ->
        {keys, rest} = Keys.decode(buffer <> data)
        continue(state, previous, keys, rest, theme)

      :input_closed ->
        :ok
    after
      timeout ->
        continue(state, previous, Keys.flush(buffer), "", theme)
    end
  end

  defp continue(state, previous, keys, rest, theme) do
    case apply_keys(state, keys) do
      {:quit, _state} -> :ok
      {:ok, state} -> loop(state, previous, rest, theme)
    end
  end

  defp apply_keys(state, []), do: {:ok, state}

  defp apply_keys(state, [key | keys]) do
    {state, effects} = Update.handle(state, key)

    case run_effects(state, effects) do
      {:quit, state} -> {:quit, state}
      {:ok, state} -> apply_keys(state, keys)
    end
  end

  defp run_effects(state, []), do: {:ok, state}
  defp run_effects(state, [:quit | _]), do: {:quit, state}

  defp run_effects(state, [effect | rest]) do
    state =
      case effect do
        {:save, path} ->
          Update.saved(state, path, Store.save(state.db, path))

        {:load, path} ->
          Update.loaded(state, path, Store.load(path))

        {:write_text, path, text} ->
          Update.written(state, path, File.write(path, text))

        {:import_json, path} ->
          Update.imported(state, path, File.read(path))

        {:save_preferences, path, prefs} ->
          Update.preferences_saved(state, Preferences.save(prefs, path))
      end

    run_effects(state, rest)
  end

  defp draw(state, previous, theme) do
    {width, height} = Terminal.size()
    {state, effects} = Update.tick(state, local_now())
    if :bell in effects, do: Terminal.write("\a")
    resized = {width, height} != {state.width, state.height}
    state = %{state | width: width, height: height}
    state = if resized, do: Layout.settle(state), else: state
    previous = if resized, do: nil, else: previous

    screen = Render.render(state)
    if previous == nil, do: Terminal.write("\e[2J")
    Terminal.write(Screen.frame(previous, screen, theme))
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
