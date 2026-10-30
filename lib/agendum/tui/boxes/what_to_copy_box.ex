# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Boxes.WhatToCopyBox do
  @moduledoc """
  Agenda's "What to copy" box (checked in Agenda 2.0, 2026-10-25; the
  owner's choice): F3 (COPY), F4 (CUT) or ALT-F4 (DELETE) with nothing
  marked, in a note or a line being typed, asks how much to take. One
  field, untitled, "What to copy: Word": SPACE goes Word → Line → All text,
  F3 lists them, ENTER takes it, ESC goes back with nothing taken. In a
  line, Line and All text are the same: the whole line.

  Over a line being typed it keeps that line in its `edit`, which
  `State.pop/1` gives back (`Typing.LineClip`). Drawn from `@layout`
  (`Agendum.TUI.Boxes.Template`). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :accept, choices: true

  alias Agendum.TUI.Boxes.{Box, Template}
  alias Agendum.TUI.State

  @layout """

   [label            ]   [what                ]

  """

  @choices [{"Word", :word}, {"Line", :line}, {"All text", :all}]
  @grid Template.grid(@layout, [:what])

  @doc """
  Opens the box for `action` (`:copy`, `:cut`, `:delete`) on a note
  (`:note`) or on the line being typed (`:line`), which it keeps.
  """
  @spec open(State.t(), :copy | :cut | :delete, :note | :line) :: State.t()
  def open(state, action, on) do
    State.push(state, %Agendum.TUI.Modes.WhatToCopy{
      action: action,
      on: on,
      choice: 0,
      cursor: 0,
      edit: state.edit
    })
  end

  @impl Box
  def handle(state, _mode, _key), do: state

  @impl Box
  def keymap(_mode), do: Box.settings_keymap()

  @impl Box
  def commands(_mode), do: Box.settings_commands()

  @impl Box
  def run(state, mode, :change),
    do: State.put_mode(state, %{mode | choice: rem(mode.choice + 1, length(@choices))})

  # ENTER: back to the note or the line, then the text taken from it
  def run(state, mode, :done) do
    {_label, what} = Enum.at(@choices, mode.choice)
    state = State.pop(state)

    case mode.on do
      :note -> Agendum.TUI.Update.Notes.clip(state, mode.action, what)
      :line -> Agendum.TUI.Typing.LineClip.clip(state, mode.action, what)
    end
  end

  def run(state, _mode, :close), do: State.pop(state)
  def run(state, mode, id), do: Box.run_settings(state, mode, @grid, id)

  # Agenda's box has no title
  @impl Box
  def title(_state, _mode), do: ""

  @impl Box
  def width(_state, _mode), do: 42

  @impl Box
  def content(_state, mode, _inner, _max_rows) do
    {label, _} = Enum.at(@choices, mode.choice)
    values = %{label: label(mode.action), what: label}
    Template.render(@layout, values, selected: :what)
  end

  defp label(:copy), do: "What to copy:"
  defp label(:cut), do: "What to cut:"
  defp label(:delete), do: "What to delete:"

  @impl Box
  def keys(_state, _mode), do: Box.settings_keys()

  # Agenda's bar here: Help, Edit, Choices; no Default
  @impl Box
  def idle_keys(_state, _mode), do: [{:f, 8}, {:alt_f, 8}]

  @impl Box
  def about(_state, mode) do
    """
    What to #{mode.action}: nothing is marked (F7), so say how much of the text to take: the word at the cursor, the line, or all of it.

    SPACE (or the first letter) changes it, F3 lists the choices. ENTER takes it; ESC goes back with nothing taken.
    """
  end

  # Agenda's words on the top line ("Choose how much text to copy.  Press
  # ESC to cancel."), one for each action: the field has a name for each
  @impl Box
  def help do
    %{
      what_copy: "Choose how much text to copy. Press ESC to cancel.",
      what_cut: "Choose how much text to cut. Press ESC to cancel.",
      what_delete: "Choose how much text to delete. Press ESC to cancel."
    }
  end

  @impl Box
  def field(_state, mode), do: :"what_#{mode.action}"
end
