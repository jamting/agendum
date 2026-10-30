# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Boxes.ConditionsActionsBox do
  @moduledoc """
  Agenda's Copy Conditions/Actions and Clear Conditions/Actions boxes
  (ALT-F9 and ALT-F8 in the category manager, when the category has both;
  R15f; Help "Copy Conditions/Actions Box", "Clear Conditions/Actions
  Box"): no title, one field, "Copy:" or "Clear:", Condition & action
  (first), Condition or Action. SPACE (or F3) changes it; ENTER copies or
  clears that; ESC leaves things as they were. Drawn from `@layouts`
  (`Agendum.TUI.Boxes.Template`). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :accept, choices: true

  alias Agendum.TUI.Boxes.{Box, Template}
  alias Agendum.TUI.State

  @layouts %{
    copy: """

       Copy:    [which             ]

    """,
    clear: """

       Clear:   [which             ]

    """
  }

  @order [:both, :conditions, :actions]
  @labels %{both: "Condition & action", conditions: "Condition", actions: "Action"}

  @doc "Opens the box to copy (`:copy`, from `from` to `to`) or clear (`:clear`, `from`)."
  def open(state, verb, from, to),
    do:
      State.push(state, %Agendum.TUI.Modes.ConditionsActions{
        verb: verb,
        from: from,
        to: to,
        which: :both
      })

  @impl Box
  def handle(state, _mode, _key), do: state

  @impl Box
  def keymap(_mode), do: Box.settings_keymap()

  @impl Box
  def commands(%{verb: :copy}), do: Box.settings_commands([{:done, "Copy", "Copy that"}])
  def commands(_mode), do: Box.settings_commands([{:done, "Clear", "Clear that"}])

  @impl Box
  def run(state, mode, :change) do
    next = Enum.at(@order, rem(Enum.find_index(@order, &(&1 == mode.which)) + 1, 3))
    State.put_mode(state, %{mode | which: next})
  end

  def run(state, %{verb: :copy} = mode, :done),
    do: Agendum.TUI.CategoryScreens.Manager.copy(State.pop(state), mode.from, mode.to, mode.which)

  def run(state, %{verb: :clear} = mode, :done),
    do: State.run(State.pop(state), {:clear_conditions_actions, mode.from, mode.which})

  def run(state, mode, id),
    do: Box.run_settings(state, mode, Template.grid(@layouts[mode.verb], [:which]), id)

  # Agenda's boxes have none
  @impl Box
  def title(_state, _mode), do: ""

  @impl Box
  def width(state, _mode), do: min(state.width - 8, 40)

  @impl Box
  def content(_state, mode, _inner, _max_rows),
    do: Template.render(@layouts[mode.verb], %{which: @labels[mode.which]}, selected: :which)

  @impl Box
  def keys(_state, _mode), do: Box.settings_keys()

  # Agenda's words, from its help for the box's setting
  @impl Box
  def help,
    do: "Choose what to copy or clear: the conditions, the actions, or both."

  @impl Box
  def field(_state, _mode), do: :which
end
