# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Boxes.FindTopicBox do
  @moduledoc """
  Agenda's Find Topic box (F5 in the help, R65e; checked in Agenda 2.0,
  2026-10-26): one field, "Topic to find:", typed at once. ENTER looks for
  the word in the help's topics and opens the Select Help Screen box with
  what it found (`Agendum.TUI.Boxes.SelectHelpScreenBox`); ESC goes back
  to the topic being read. Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done

  alias Agendum.TUI.Boxes.Box
  alias Agendum.TUI.State
  alias Agendum.TUI.Typing.LineEdit

  @doc "Opens the box over the help."
  def open(state),
    do: State.push(state, %Agendum.TUI.Modes.FindTopic{line: LineEdit.new("")})

  @impl Box
  # a box that types gets every key: ENTER finds, ESC goes back, the others
  # type the word
  def handle(state, mode, :enter), do: run(state, mode, :done)
  def handle(state, mode, :esc), do: run(state, mode, :close)

  def handle(state, mode, key) do
    case LineEdit.handle(mode.line, key) do
      {:ok, line} -> State.put_mode(state, %{mode | line: line})
      :unhandled -> state
    end
  end

  @impl Box
  def typing?(_state, _mode), do: true

  # R65
  @impl Box
  def keymap(_mode), do: %{:enter => :done, :esc => :close}

  @impl Box
  def commands(_mode),
    do: [
      {:done, "Find", "Find the topics with the word"},
      {:close, "Cancel", "Back to the topic"}
    ]

  @impl Box
  def run(state, _mode, :close), do: State.pop(state)

  def run(state, mode, :done),
    do: Agendum.TUI.HelpScreen.find(State.pop(state), mode.line.text)

  @impl Box
  def title(_state, _mode), do: "Find Topic"

  # Agenda's box is 52 wide
  @impl Box
  def width(state, _mode), do: min(state.width - 8, 52)

  @impl Box
  def content(_state, mode, _inner, _max_rows),
    do: [[], [{:box, "  Topic to find:  "}, {:box_selected, mode.line.text <> " "}], []]

  @impl Box
  def keys(_state, _mode), do: [{"ENTER", "Find"}, {"ESC", "Cancel"}]

  # Agenda's words on the control panel, with our name
  @impl Box
  def help,
    do:
      "Type the topic or term you want help on.  Agendum displays a list of " <>
        "help screens you can select."
end
