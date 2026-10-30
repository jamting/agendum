# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Boxes.SelectHelpScreenBox do
  @moduledoc """
  Agenda's Select Help Screen box (after Find Topic in the help, R65e;
  checked in Agenda 2.0, 2026-10-26): the topics Find found, titles that
  have the word first. ↑↓ HOME END highlight one, ENTER reads it, and
  ALT-N / ALT-P then step through the list from the topic; ESC goes back
  to the topic being read. Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done

  alias Agendum.TUI.Boxes.Box
  alias Agendum.TUI.State

  @doc "Opens the box with the titles found."
  def open(state, found),
    do: State.push(state, %Agendum.TUI.Modes.SelectHelpScreen{found: found, cursor: 0})

  @impl Box
  def handle(state, _mode, _key), do: state

  # R65
  @impl Box
  def keymap(_mode),
    do: %{
      :up => :up,
      :down => :down,
      :home => :first,
      :end => :last,
      :enter => :done,
      :esc => :close
    }

  @impl Box
  def commands(_mode),
    do:
      [{:done, "Read", "Read the highlighted topic"}] ++
        Box.list_moves() ++ [{:close, "Cancel", "Back to the topic"}]

  @impl Box
  def run(state, _mode, :close), do: State.pop(state)

  def run(state, mode, :done),
    do: Agendum.TUI.HelpScreen.read_found(State.pop(state), mode.found, mode.cursor)

  def run(state, mode, id), do: Box.list_move(state, mode, length(mode.found), id)

  @impl Box
  def title(_state, _mode), do: "Select Help Screen"

  @impl Box
  def width(state, _mode), do: min(state.width - 8, 52)

  # a blank line, then the titles, the highlighted one marked, scrolled to
  # keep it in sight
  @impl Box
  def content(_state, mode, _inner, max_rows) do
    rows = max(max_rows - 1, 1)
    top = max(mode.cursor - rows + 1, 0)

    [[]] ++
      (mode.found
       |> Enum.with_index()
       |> Enum.drop(top)
       |> Enum.take(rows)
       |> Enum.map(fn {title, i} ->
         [{:box, "  "}, {if(i == mode.cursor, do: :box_selected, else: :box), title}]
       end))
  end

  @impl Box
  def keys(_state, _mode),
    do: [{"↑↓", "Highlight", "Highlight a topic"}, {"ENTER", "Read"}, {"ESC", "Cancel"}]

  # Agenda's words on the control panel
  @impl Box
  def help,
    do:
      "Highlight Help screen to display.  Then use ALT-N or ALT-P to " <>
        "display next/previous help screen from list."
end
