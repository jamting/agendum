defmodule Agenda.TUI.Render.Text do
  @moduledoc """
  Words shared by several parts of the screen: a filter beside a view's or
  section's name, a category's conditions and actions, the "..." after a
  collapsed family. Pure.
  """

  alias Agenda.TUI.State

  @doc "Whether a column holds numbers."
  def numeric?(state, column), do: state.db.categories[column.category_id].kind == :numeric

  @doc "Category names, comma-separated."
  def names_text(db, ids), do: Enum.map_join(ids, ", ", &db.categories[&1].name)

  @doc """
  A category's assignment actions in words:
  "Sales, -Receivables, When=tomorrow, Amount=150" (R15b).
  """
  def actions_text(%State{db: db} = state, cat) do
    name = &db.categories[&1].name

    Enum.map(cat.also_assign, name)
    |> Enum.concat(
      Enum.map(cat.actions, fn
        {id, action} when action in [:remove, :clear] ->
          "-" <> name.(id)

        {id, {:set, value}} when is_number(value) ->
          name.(id) <> "=" <> Agenda.TUI.Update.number_text(value, State.number_opts(state))

        {id, {:set, value}} ->
          name.(id) <> "=" <> value
      end)
    )
    |> Enum.join(", ")
  end

  @doc "\"Taxes, not People\": a category's assignment conditions in words."
  def conditions_text(%State{db: db} = state, cat) do
    Enum.map_join(cat.conditions, ", ", fn
      {id, :assigned} ->
        db.categories[id].name

      {id, :not_assigned} ->
        "not " <> db.categories[id].name

      {id, range} ->
        db.categories[id].name <>
          " " <> Agenda.Core.RangeFilter.describe(db, range, State.context(state))
    end)
  end

  @doc "\" [High, -People]\": a filter as Agenda shows it beside the view name."
  def filter_text(_state, []), do: ""

  def filter_text(%State{db: db} = state, filter) do
    names =
      Enum.map_join(filter, ", ", fn
        {id, :assigned} ->
          db.categories[id].name

        {id, :not_assigned} ->
          "-" <> db.categories[id].name

        {id, range} ->
          db.categories[id].name <>
            " " <> Agenda.Core.RangeFilter.describe(db, range, State.context(state))
      end)

    " [#{names}]"
  end

  @doc "\"...\" after a collapsed family's parent (User's Guide 16-8)."
  def ellipsis(state, cat) do
    if cat.children != [] and MapSet.member?(state.collapsed, cat.id), do: "...", else: ""
  end
end
