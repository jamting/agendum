defmodule Agendum.TUI.Boxes.AbandonBox do
  @moduledoc """
  Agenda's Abandon File box (File ▸ Abandon; User's Guide 22-8; checked in
  Agenda 2.0, 2026-10-25): one field, "Revert to last saved version: No".
  SPACE (or Y and N) changes it; ENTER on Yes puts the file back as it was
  last saved (or as it was opened, when it has not been saved since),
  ENTER on No and ESC leave it as it is.

  Going back is one change like any other, so undo (CTRL-Z) brings the
  abandoned changes back: Agenda could not. Drawn from `@layout`
  (`Agendum.TUI.Boxes.Template`). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, choices: true

  alias Agendum.TUI.Boxes.{Box, Template}
  alias Agendum.TUI.State

  @layout """

     Revert to last saved version:   [revert]

  """

  @grid Template.grid(@layout, [:revert])

  def open(state), do: State.push(state, %Agendum.TUI.Modes.Abandon{revert: false, cursor: 0})

  @impl Box
  def handle(state, mode, {:char, c}) when c in ["y", "Y"],
    do: State.put_mode(state, %{mode | revert: true})

  def handle(state, mode, {:char, c}) when c in ["n", "N"],
    do: State.put_mode(state, %{mode | revert: false})

  def handle(state, _mode, _key), do: state

  @impl Box
  def keymap(_mode), do: Box.settings_keymap()

  @impl Box
  def commands(_mode), do: Box.settings_commands([{:done, "Done", "Revert, or not"}])

  @impl Box
  def run(state, mode, :change), do: State.put_mode(state, %{mode | revert: not mode.revert})

  # the database as last saved, the place in it kept where it still is
  def run(state, %{revert: true}, :done) do
    state = State.pop(state)
    %{state | db: state.saved.db, dirty: false}
  end

  def run(state, _mode, :done), do: State.pop(state)
  def run(state, mode, id), do: Box.run_settings(state, mode, @grid, id)

  @impl Box
  def title(_state, _mode), do: "Abandon File"

  @impl Box
  def width(state, _mode), do: min(state.width - 8, 72)

  @impl Box
  def content(_state, mode, _inner, _max_rows) do
    values = %{revert: if(mode.revert, do: "Yes", else: "No")}
    Template.render(@layout, values, selected: :revert)
  end

  @impl Box
  def keys(_state, _mode), do: Box.settings_keys()

  # Agenda's help line
  @impl Box
  def help,
    do:
      "Type Y to abandon all changes made since the last time you saved the file " <>
        "and revert to the previously saved version."

  @impl Box
  def field(_state, _mode), do: :revert
end
