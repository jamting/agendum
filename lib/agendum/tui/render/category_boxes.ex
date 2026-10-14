defmodule Agendum.TUI.Render.CategoryBoxes do
  @moduledoc """
  The boxes listing an item's assignment profile and the marked items'
  profile, and the choice boxes. Pure.
  """

  alias Agendum.Core.Database
  alias Agendum.TUI.CategoryScreens
  alias Agendum.TUI.CategoryScreens.Choices

  @doc "The content of one of these boxes, `inner` wide, at most `max_rows` of list."
  def content(state, %{type: type} = mode, inner, max_rows)
      when type in [:profile, :group_profile] do
    CategoryScreens.list_lines(state, mode, inner, max_rows, &profile_marker/3) ++
      [[], box_footer(state, mode, inner)]
  end

  def content(_state, %{type: :choice} = mode, _inner, _max_rows) do
    options = Choices.choice_options(mode)
    [problem, question] = Choices.choice_lines(mode)
    {_, description, _} = Enum.at(options, mode.cursor)

    choices =
      options
      |> Enum.with_index()
      |> Enum.map(fn {{label, _, _}, i} ->
        [{:box, "   "}, {if(i == mode.cursor, do: :box_selected, else: :box), " #{label} "}]
      end)

    [[{:box, " " <> problem}], [], [{:box, " " <> question}]] ++
      choices ++ [[], [{:box, " " <> description}]]
  end

  defp box_footer(_state, %{type: :group_profile}, _inner),
    do: [{:box, " N = marked items assigned · SPACE assigns or unassigns all"}]

  defp box_footer(_state, %{type: :profile}, _inner),
    do: [{:box, " * assigned  c by a condition  + via subcategory  SPACE"}]

  defp profile_marker(state, %{type: :group_profile, item_ids: ids}, id) do
    case CategoryScreens.group_count(state.db, ids, id) do
      0 -> " "
      n when n < 10 -> Integer.to_string(n)
      _ -> "+"
    end
  end

  defp profile_marker(state, %{type: :profile, item_id: item_id}, id) do
    db = state.db

    cond do
      Database.date_category?(db, id) ->
        if Database.item_date(db, item_id, id), do: "◊", else: " "

      Database.conditional?(db, item_id, id) ->
        "c"

      Database.explicit?(db, item_id, id) ->
        "*"

      Database.member?(db, item_id, id) ->
        "+"

      true ->
        " "
    end
  end

  defp profile_marker(_state, _mode, _id), do: " "
end
