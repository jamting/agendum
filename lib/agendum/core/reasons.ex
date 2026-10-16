defmodule Agendum.Core.Reasons do
  @moduledoc """
  Why an item is in a category (R67): the reasons, worked out from the
  file as it is, with the same rules that assigned it (`Agendum.Core.Assign`),
  for a front end to show or an agent to report ("filed under Kanga
  because its text says Kanga").

  The file keeps which assignments conditions made (R15) but not who made
  the others, so a reason is what holds now: a text match is given when
  the item's text matches the category, whether the match or the person
  assigned it first. Pure.
  """

  alias Agendum.Core.{Assign, Database}

  @typedoc """
  A reason, most telling first:

    * `:main`: every item is in MAIN (R5)
    * `{:date, date}`: a date category holds the item's date (R6)
    * `{:through, child}`: the item is in a child (or a deeper descendant)
      of the category, so in the category too (R3)
    * `{:condition, conditions}`: the category's conditions assigned it,
      as `[{category, :assigned | :not_assigned}]` (R15)
    * `:text_match`: the item's text (or note) matches the category's name
      or its Also match words (R10)
    * `{:action, category}`: being in that category also assigns this one
      (R15b)
    * `:assigned`: in it by hand, or kept from before; none of the above
  """
  @type reason ::
          :main
          | {:date, Date.t()}
          | {:through, Database.id()}
          | {:condition, [{Database.id(), term}]}
          | :text_match
          | {:action, Database.id()}
          | :assigned

  @doc """
  Why an item is in a category: its reasons, or [] when it is not in it.
  The clock reads date conditions ("this week", R15a).
  """
  @spec why(Database.t(), Database.id(), Database.id(), Agendum.Core.Context.clock() | nil) ::
          [reason]
  def why(db, item_id, cat_id, clock \\ nil) do
    cond do
      cat_id == db.main_id ->
        [:main]

      Database.date_category?(db, cat_id) ->
        case Database.item_date(db, item_id, cat_id) do
          nil -> []
          date -> [{:date, date}]
        end

      Database.explicit?(db, item_id, cat_id) ->
        case automatic(db, item_id, cat_id, clock) do
          [] -> [:assigned]
          reasons -> reasons
        end

      true ->
        through(db, item_id, cat_id)
    end
  end

  # what assigns a linked item on its own: a condition, its text, an action
  defp automatic(db, item_id, cat_id, clock) do
    cat = db.categories[cat_id]

    # a conditional link was made by conditions or by a text match (R15c):
    # a condition is the reason when the category has some and they hold
    condition =
      if Database.conditional?(db, item_id, cat_id) and
           Assign.conditions_met?(db, item_id, cat_id, clock),
         do: [{:condition, cat.conditions}],
         else: []

    text = if Assign.text_matches?(db, item_id, cat_id), do: [:text_match], else: []

    actions =
      for other <- db.categories |> Map.keys() |> Enum.sort(),
          cat_id in db.categories[other].also_assign,
          Database.member?(db, item_id, other),
          do: {:action, other}

    condition ++ text ++ actions
  end

  # the item is in the category because it is in one below it
  defp through(db, item_id, cat_id) do
    explicit = Database.explicit_categories(db, item_id)

    for child <- Database.descendants(db, cat_id),
        MapSet.member?(explicit, child),
        do: {:through, child}
  end
end
