defmodule Agenda.TUIHelpers do
  @moduledoc "Drive the pure TUI with keys and inspect the rendered text."

  alias Agenda.TUI.{Draw, Layout, Render, State, Update}

  def start(db, opts \\ []) do
    db
    |> State.new(Keyword.merge([today: ~D[2026-10-08], width: 100, height: 24], opts))
    |> Layout.settle()
  end

  @doc "Presses keys; a string is typed character by character. Effects are collected in `:effects_seen`."
  def press(state, keys) do
    keys
    |> List.wrap()
    |> Enum.flat_map(fn
      text when is_binary(text) -> text |> String.graphemes() |> Enum.map(&{:char, &1})
      key -> [key]
    end)
    |> Enum.reduce(state, fn key, state ->
      {state, effects} = Update.handle(state, key)
      Process.put(:effects_seen, (Process.get(:effects_seen) || []) ++ effects)
      state
    end)
  end

  def effects, do: Process.get(:effects_seen) || []

  def screen(state), do: state |> Render.render() |> Draw.to_text()

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
