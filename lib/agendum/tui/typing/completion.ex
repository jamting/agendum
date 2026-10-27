defmodule Agendum.TUI.Typing.Completion do
  @moduledoc """
  Automatic completion while typing a column entry (SPEC R32): which
  categories match what has been typed, and which one is shown. Pure; the
  matching rules themselves are `Agendum.Core.completions/3`.

  It applies to column cells, to the Item Properties box, where any
  category can be typed, and to a box's field that holds a category (a
  column's or section's head, a new section: `Boxes.FieldTyping`, every
  category matching there, as Agenda's; checked in Agenda 2.0,
  2026-10-25). The edit in progress carries a `:choice` index that
  NEXTSEL / PREVSEL move (a box's mode, for its field); typing resets it
  to the first match.
  """

  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.TUI.State

  @doc "True while typing a category (not a date or number) into a column cell."
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
      head -> state.db |> Core.completions(head, text(state)) |> Enum.filter(&offered?(state, &1))
    end
  end

  # a box's category field may offer only some (`c:Box.category_choice?/4`)
  defp offered?(%State{edit: nil} = state, id) do
    case State.mode(state) do
      %{typing: {field, _}} = mode when is_atom(field) ->
        Agendum.TUI.Boxes.Box.module!(mode).category_choice?(state, mode, field, id)

      _ ->
        true
    end
  end

  defp offered?(_state, _id), do: true

  @doc "True while a box's field that holds a category is typed in."
  @spec box_field?(State.t()) :: boolean
  def box_field?(%State{edit: nil} = state), do: category_field(State.mode(state)) != nil
  def box_field?(_state), do: false

  @doc "Automatic completion's own place: a column cell, or a box's category field."
  @spec autoc?(State.t()) :: boolean
  def autoc?(state), do: column_entry?(state) or box_field?(state)

  # a box's field typed in that holds a category, with its line; F2 (EDIT)
  # edits the name as it is, without completion, as Agenda's (`choice: :off`)
  defp category_field(%{choice: :off}), do: nil

  defp category_field(%{typing: {field, line}} = mode) do
    if Agendum.TUI.Boxes.Box.category_field?(mode, field), do: line
  end

  defp category_field(_mode), do: nil

  defp text(%State{edit: %{line: line}}), do: line.text
  defp text(state), do: category_field(State.mode(state)).text

  # The category whose subcategories are searched.
  defp head(%State{edit: %{target: {:column_entry, _item, head, _}}, db: db}) do
    if db.categories[head].kind in [:date, :numeric, :unindexed],
      do: nil,
      else: head
  end

  defp head(%State{edit: %{target: {:assign_category, _item}}, db: db}), do: db.main_id

  defp head(%State{db: db} = state),
    do: if(box_field?(state), do: db.main_id, else: nil)

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
  def cycle(%State{edit: nil} = state, step),
    do: State.put_mode(state, %{State.mode(state) | choice: choice(state) + step})

  def cycle(%State{edit: edit} = state, step),
    do: %{state | edit: Map.put(edit, :choice, choice(state) + step)}

  defp choice(%State{edit: nil} = state), do: Map.get(State.mode(state), :choice) || 0
  defp choice(%State{edit: edit}), do: Map.get(edit, :choice, 0)
end
