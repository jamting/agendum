# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Update.Sounds do
  @moduledoc """
  Which keys make which of Agenda's sounds (R76; the tones are
  `Agendum.TUI.Sound`). Decided once for every key, after it did its work,
  by comparing the state before it with the state after, as undo is
  (`Agendum.TUI.History`): no key handler asks for a beep itself.

  - automatic completion (R32): a high beep when the typing comes down to
    exactly one category, a low one when no category matches any more;
    once on getting there, as Agenda, not again for each key while it
    stays so; only with Beep on auto-completion on
  - an error message: the error beep
  - Learn mode clicks for each key it records (`Agendum.TUI.Macros.record/3`)

  With Sound off, no sound is asked for at all (`quiet/2`). Pure.
  """

  alias Agendum.TUI.{State, Typing.Completion}

  @doc "Adds the sound `key` makes, going from `before` to `state`, to its effects."
  @spec after_key(State.t(), term, State.t()) :: State.t()
  def after_key(before, key, state) do
    sound = completion(before, key, state) || error(before, state)
    state = if sound, do: State.effect(state, {:sound, sound}), else: state
    %{state | effects: quiet(state, state.effects)}
  end

  @doc "The effects without their sounds when Sound is off (Customize)."
  @spec quiet(State.t(), [term]) :: [term]
  def quiet(%State{prefs: %{sound: false}}, effects),
    do: Enum.reject(effects, &match?({:sound, _}, &1))

  def quiet(_state, effects), do: effects

  # Typing that comes to one match, or to none. A new edit only counts when
  # it was started by typing: F2 on a cell that holds "High" is not typing
  # it.
  defp completion(before, key, state) do
    was = matching(before)
    now = matching(state)
    typed = was != nil or match?({:char, _}, key)

    cond do
      not state.prefs.beep_completion or not typed or now == was -> nil
      now == :one -> :high
      now == :none -> :low
      true -> nil
    end
  end

  # nil when completion does not apply (no category being typed)
  defp matching(state) do
    if Completion.active?(state) do
      case Completion.matches(state) do
        [] -> :none
        [_] -> :one
        _ -> :many
      end
    end
  end

  # `before`'s message was cleared as the key began (`Update.handle/2`), so
  # an error message now is this key's
  defp error(before, state) do
    if match?({:error, _}, state.message) and state.message != before.message, do: :error
  end
end
