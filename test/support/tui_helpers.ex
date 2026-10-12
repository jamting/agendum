defmodule Agenda.TUIHelpers do
  @moduledoc "Drive the pure TUI with keys and inspect the rendered text."

  alias Agenda.TUI.{Draw, Layout, Render, State, Update}

  def start(db, opts \\ []) do
    db
    |> State.new(Keyword.merge([today: ~D[2026-10-08], width: 100, height: 24], opts))
    |> Layout.settle()
  end

  @doc """
  Presses keys; a string is typed character by character. Effects are
  collected in `:effects_seen`; a macro run's keys are played next, as the
  shell plays them (`{:play, keys}`, then `:macro_done`).
  """
  def press(state, keys) do
    keys
    |> List.wrap()
    |> Enum.flat_map(fn
      text when is_binary(text) -> text |> String.graphemes() |> Enum.map(&{:char, &1})
      key -> [key]
    end)
    |> play(state)
  end

  defp play([], state), do: state

  defp play([key | keys], state) do
    {state, effects} = Update.handle(state, key)
    Process.put(:effects_seen, (Process.get(:effects_seen) || []) ++ effects)
    played = for {:play, played} <- effects, k <- played ++ [:macro_done], do: k
    play(played ++ keys, state)
  end

  def effects, do: Process.get(:effects_seen) || []

  def screen(state), do: state |> Render.render() |> Draw.to_text()

  @doc """
  The text of the control panel (the two top lines) without the indicators
  and the time, its words joined by single spaces: a long question or message
  wraps there.
  """
  def panel(state) do
    state
    |> Render.render()
    |> Enum.take(2)
    |> Enum.map_join(" ", fn line ->
      line |> Enum.reject(&(elem(&1, 0) == :indicator)) |> Enum.map_join(&elem(&1, 1))
    end)
    |> String.split()
    |> Enum.join(" ")
  end

  @doc """
  The sample file with an empty Meetings that matches no text: with
  Agenda's Ignore suffixes (R16a) its name pulls in the items about a
  "meeting", which tests that use Meetings as an empty category do not want.
  """
  def quiet_meetings(db) do
    alias Agenda.Core
    meetings = hd(Agenda.Core.Database.find_categories(db, "Meetings"))
    db = Core.toggle_match_name(db, meetings)

    db
    |> Agenda.Core.Database.items_in(meetings)
    |> Enum.reduce(db, &Core.remove_from_category(&2, &1.id, meetings))
  end
end
