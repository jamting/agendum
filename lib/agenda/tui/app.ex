defmodule Agenda.TUI.App do
  @moduledoc """
  The main loop (imperative shell): reads keys, feeds them to the pure
  `Update`, performs the resulting effects, and draws `Render` output.
  """

  alias Agenda.Store
  alias Agenda.TUI.{Keys, Layout, Render, Screen, State, Terminal, Update}

  # How long to wait for the rest of an escape sequence before treating ESC as a key.
  @escape_timeout 40
  # How often to check for terminal resizes and date changes when idle.
  @idle_timeout 500

  @spec run(State.t()) :: :ok | {:error, term}
  def run(%State{} = state) do
    case Terminal.start() do
      :ok ->
        Terminal.start_reader(self())

        try do
          loop(state, nil, "")
        after
          Terminal.stop()
        end

      error ->
        error
    end
  end

  defp loop(state, previous, buffer) do
    {state, previous} = draw(state, previous)
    timeout = if buffer == "", do: @idle_timeout, else: @escape_timeout

    receive do
      {:input, data} ->
        {keys, rest} = Keys.decode(buffer <> data)
        continue(state, previous, keys, rest)

      :input_closed ->
        :ok
    after
      timeout ->
        continue(state, previous, Keys.flush(buffer), "")
    end
  end

  defp continue(state, previous, keys, rest) do
    case apply_keys(state, keys) do
      {:quit, _state} -> :ok
      {:ok, state} -> loop(state, previous, rest)
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
        {:save, path} -> Update.saved(state, path, Store.save(state.db, path))
        {:load, path} -> Update.loaded(state, path, Store.load(path))
        {:write_text, path, text} -> Update.written(state, path, File.write(path, text))
      end

    run_effects(state, rest)
  end

  defp draw(state, previous) do
    {width, height} = Terminal.size()
    today = local_today()
    resized = {width, height} != {state.width, state.height}
    state = %{state | width: width, height: height, today: today}
    state = if resized, do: Layout.settle(state), else: state
    previous = if resized, do: nil, else: previous

    screen = Render.render(state)
    if previous == nil, do: Terminal.write("\e[2J")
    Terminal.write(Screen.frame(previous, screen))
    {state, screen}
  end

  @doc false
  def local_today do
    {date, _time} = :calendar.local_time()
    Date.from_erl!(date)
  end
end
