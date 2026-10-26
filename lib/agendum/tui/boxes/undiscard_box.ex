defmodule Agendum.TUI.Boxes.UndiscardBox do
  @moduledoc """
  Agenda's Item Undiscard box (Item ▸ Undisc with more than one item in
  the trash; R24a; checked in Agenda 2.0, 2026-10-26): no title, one
  field, "Undiscard:", All items in trash (first) or Last item in trash.
  SPACE (or F3) changes it; ENTER brings the items back into the section
  the highlight was in, below the highlighted item; ESC leaves them in the
  trash. Drawn from `@layout` (`Agendum.TUI.Boxes.Template`). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, choices: true

  alias Agendum.TUI.Boxes.{Box, Template}
  alias Agendum.TUI.State

  @layout """

     Undiscard:     [which             ]

  """

  @grid Template.grid(@layout, [:which])

  @doc """
  Opens the box to bring items back into `category`, after the item
  `after_id` (nil: in their usual place), in the section `sidx`.
  """
  def open(state, category, after_id, sidx),
    do:
      State.push(state, %Agendum.TUI.Modes.Undiscard{
        all: true,
        category: category,
        after: after_id,
        sidx: sidx,
        cursor: 0
      })

  @impl Box
  def handle(state, _mode, _key), do: state

  @impl Box
  def keymap(_mode), do: Box.settings_keymap()

  @impl Box
  def commands(_mode), do: Box.settings_commands([{:done, "Undiscard", "Bring them back"}])

  @impl Box
  def run(state, mode, :change), do: State.put_mode(state, %{mode | all: not mode.all})

  def run(state, mode, :done) do
    which = if mode.all, do: :all, else: :last
    Agendum.TUI.Update.Actions.undiscard(State.pop(state), which, mode)
  end

  def run(state, mode, id), do: Box.run_settings(state, mode, @grid, id)

  # Agenda's box has none
  @impl Box
  def title(_state, _mode), do: ""

  @impl Box
  def width(state, _mode), do: min(state.width - 8, 42)

  @impl Box
  def content(_state, mode, _inner, _max_rows) do
    which = if mode.all, do: "All items in trash", else: "Last item in trash"
    Template.render(@layout, %{which: which}, selected: :which)
  end

  @impl Box
  def keys(_state, _mode), do: Box.settings_keys()

  # Agenda's help line
  @impl Box
  def help,
    do: "Retrieve all discarded items in the Trash or only the last item you discarded."

  @impl Box
  def field(_state, _mode), do: :which
end
