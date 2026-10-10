defmodule Agenda.TUI.Completion do
  @moduledoc """
  Automatic completion while typing a column entry (SPEC R32): which
  categories match what has been typed, and which one is shown. Pure; the
  matching rules themselves are `Agenda.Core.completions/3`.

  It applies to column cells and to the Item Properties box, where any
  category can be typed. The edit in progress carries a `:choice` index that NEXTSEL / PREVSEL
  move; typing resets it to the first match.
  """

  alias Agenda.Core
  alias Agenda.Core.Database
  alias Agenda.TUI.State

  @doc "True while typing a category (not a date) into a column cell."
  @spec column_entry?(State.t()) :: boolean
  def column_entry?(%State{edit: %{target: {:column_entry, _, _, _}}} = state), do: active?(state)
  def column_entry?(_state), do: false

  @doc """
  True while typing a category name that completion applies to: a column
  cell (not a date column), or the Item Properties box's assign field.
  """
  @spec active?(State.t()) :: boolean
  def active?(state), do: head(state) != nil

  @doc "The matching categories, or [] when nothing matches or completion does not apply."
  @spec matches(State.t()) :: [Database.id()]
  def matches(%State{} = state) do
    case head(state) do
      nil -> []
      head -> Core.completions(state.db, head, state.edit.line.text)
    end
  end

  # The category whose subcategories are searched.
  defp head(%State{edit: %{target: {:column_entry, _item, head, _}}, db: db}),
    do: if(Database.date_field(db, head), do: nil, else: head)

  defp head(%State{edit: %{target: {:assign_category, _item}}, db: db}), do: db.main_id
  defp head(_state), do: nil

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
