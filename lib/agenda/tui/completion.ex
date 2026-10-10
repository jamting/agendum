defmodule Agenda.TUI.Completion do
  @moduledoc """
  Automatic completion while typing a column entry (SPEC R32): which
  categories match what has been typed, and which one is shown. Pure; the
  matching rules themselves are `Agenda.Core.completions/3`.

  The edit in progress carries a `:choice` index that NEXTSEL / PREVSEL
  move; typing resets it to the first match.
  """

  alias Agenda.Core
  alias Agenda.Core.Database
  alias Agenda.TUI.State

  @doc "True while typing a category (not a date) into a column cell."
  @spec column_entry?(State.t()) :: boolean
  def column_entry?(%State{edit: %{target: {:column_entry, _item, head, _}}, db: db}),
    do: Database.date_field(db, head) == nil

  def column_entry?(_state), do: false

  @doc "The matching categories, or [] when nothing matches or completion does not apply."
  @spec matches(State.t()) :: [Database.id()]
  def matches(%State{} = state) do
    if column_entry?(state) do
      {:column_entry, _item, head, _} = state.edit.target
      Core.completions(state.db, head, state.edit.line.text)
    else
      []
    end
  end

  @doc "The category currently shown as the completion, if any."
  @spec shown(State.t()) :: Database.id() | nil
  def shown(state) do
    case matches(state) do
      [] -> nil
      matches -> Enum.at(matches, Integer.mod(choice(state), length(matches)))
    end
  end

  @doc "Moves to the next (+1) or previous (-1) match."
  @spec cycle(State.t(), integer) :: State.t()
  def cycle(%State{edit: edit} = state, step),
    do: %{state | edit: Map.put(edit, :choice, choice(state) + step)}

  defp choice(%State{edit: edit}), do: Map.get(edit, :choice, 0)
end
