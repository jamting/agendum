defmodule Agendum.TUI.Boxes.UpdateDefaultsBox do
  @moduledoc """
  Agenda's question for File Properties ▸ Update defaults (R82a; User's
  Guide 22-14; checked in Agenda 2.0, 2026-10-26): one field, "Update new
  file properties? Yes", and the bottom edge "Press ENTER to accept, ESC to
  cancel". SPACE (or Y and N) changes it. ENTER on Yes keeps the file's
  settings as the person's defaults for new files, in their preferences
  (`Agendum.Core.FileDefaults`, ADR 0008), at once; File Properties then
  keeps its changes even if ESC follows, as Agenda's did
  (`Agendum.TUI.Boxes.BoxCancel.keep/1`). ENTER on No and ESC keep nothing.
  The file itself does not change, so this is no undo step. Drawn from
  `@layout` (`Agendum.TUI.Boxes.Template`). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :accept, choices: true

  alias Agendum.Core
  alias Agendum.TUI.Boxes.{Box, BoxCancel, Template}
  alias Agendum.TUI.State

  @layout """

     Update new file properties?  [yes]

  """

  @grid Template.grid(@layout, [:yes])

  @doc "Opens the question over File Properties, Yes first, as Agenda's."
  def open(state), do: State.push(state, %Agendum.TUI.Modes.UpdateDefaults{yes: true, cursor: 0})

  @impl Box
  def about(_state, _mode) do
    """
    Update new file properties? Yes keeps this file's File Properties
    settings, with its global date settings, display format and auto-assign
    settings, as the defaults for every new, empty file you make. Files you
    have already are unchanged; the description and password are not
    copied.

    SPACE, Y or N changes the answer; ENTER accepts it, ESC keeps nothing.
    The defaults are kept in your preferences, and F8 in File Properties
    gives them back.
    """
  end

  @impl Box
  def handle(state, mode, {:char, c}) when c in ["y", "Y"],
    do: State.put_mode(state, %{mode | yes: true})

  def handle(state, mode, {:char, c}) when c in ["n", "N"],
    do: State.put_mode(state, %{mode | yes: false})

  def handle(state, _mode, _key), do: state

  @impl Box
  def keymap(_mode), do: Box.settings_keymap()

  @impl Box
  def commands(_mode),
    do: Box.settings_commands([{:done, "Accept", "Keep as defaults for new files, or not"}])

  @impl Box
  def run(state, mode, :change), do: State.put_mode(state, %{mode | yes: not mode.yes})

  # Domain: the defaults are the file's settings as they are now, those
  # that differ from Agenda's; `State.change_preference/3` saves them in
  # the preferences file (an effect for the shell)
  def run(state, %{yes: true}, :done) do
    defaults = Core.file_defaults(state.db)

    state
    |> State.pop()
    |> State.change_preference(& &1, &%{&1 | defaults: defaults})
    |> BoxCancel.keep()
  end

  def run(state, _mode, :done), do: State.pop(state)
  def run(state, mode, id), do: Box.run_settings(state, mode, @grid, id)

  @impl Box
  def title(_state, _mode), do: ""

  @impl Box
  def width(state, _mode), do: min(state.width - 8, 46)

  @impl Box
  def content(_state, mode, _inner, _max_rows) do
    Template.render(@layout, %{yes: if(mode.yes, do: "Yes", else: "No")}, selected: :yes)
  end

  @impl Box
  def keys(_state, _mode), do: Box.settings_keys()

  # Agenda shows no help line for the question; this is the row's
  @impl Box
  def help, do: "Use these File Properties as defaults when creating a new file."

  @impl Box
  def field(_state, _mode), do: :yes
end
