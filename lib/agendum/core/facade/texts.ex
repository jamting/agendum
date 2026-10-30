# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Facade.Texts do
  @moduledoc """
  Unindexed categories (R29b; User's Guide 3-10 to 3-11, 3-23 to 3-26): a
  category that gives each item assigned to it one text value, such as a
  phone number or an address; giving items their texts, and converting a
  category to an unindexed one. The text is not a category: it is not
  matched against item text, and nothing is assigned from it.

  Called through `Agendum.Core`.
  """

  alias Agendum.Core.Database
  alias Agendum.Core.Facade.{Assignments, Changes}

  @typep db :: Agendum.Core.db()
  @typep id :: Agendum.Core.id()
  @typep clock :: Agendum.Core.clock()

  @doc """
  Gives an item a text in an unindexed category, assigning it there (with
  the usual assignment rules); an empty text takes it out, as an empty
  number would.
  """
  @spec set_text(db, id, id, String.t(), clock | nil) :: {:ok, db} | {:error, :not_unindexed}
  def set_text(db, item_id, cat_id, text, clock \\ nil) do
    text = String.trim(text)

    cond do
      db.categories[cat_id].kind != :unindexed ->
        {:error, :not_unindexed}

      text == "" ->
        {:ok, clear_text(db, item_id, cat_id, clock)}

      true ->
        db =
          db
          |> Changes.user_assign(item_id, cat_id)
          |> Database.put_text(item_id, cat_id, text)
          |> Changes.settle(db, item_id, clock)

        {:ok, db}
    end
  end

  @doc "Removes an item's text, and so its assignment to the unindexed category."
  @spec clear_text(db, id, id, clock | nil) :: db
  def clear_text(db, item_id, cat_id, clock \\ nil),
    do: Assignments.remove_from_category(db, item_id, cat_id, clock)

  @doc """
  Converts a standard category to an unindexed one (User's Guide 3-23 to
  3-24). Its children, if any, become texts: an item in a child gets the
  child's name as its text, an item in the category itself an empty one,
  as a numeric conversion gives numbers (`Agendum.Core.Facade.Numbers`;
  what Agenda does with the children is unchecked). A category with
  grandchildren cannot be converted. Unindexed categories do not match
  item text.
  """
  @spec make_unindexed(db, id, clock | nil) ::
          {:ok, db} | {:error, :not_standard | :protected | :too_deep}
  def make_unindexed(db, cat_id, _clock \\ nil) do
    cat = db.categories[cat_id]

    cond do
      cat.kind != :standard ->
        {:error, :not_standard}

      Database.protected?(db, cat_id) ->
        {:error, :protected}

      Enum.any?(cat.children, &(db.categories[&1].children != [])) ->
        {:error, :too_deep}

      true ->
        values =
          for(item <- Changes.direct_items(db, cat_id), do: {item, ""}) ++
            for child <- cat.children,
                name = db.categories[child].name,
                item <- Database.items_in(db, child),
                do: {item.id, name}

        db =
          Enum.reduce(cat.children, db, fn child, db ->
            {:ok, db} = Database.delete_category(db, child)
            db
          end)

        db =
          db
          |> Changes.drop_excludes(cat_id)
          |> Database.update_category(
            cat_id,
            &%{&1 | kind: :unindexed, match_name: false, exclusive: false}
          )

        {:ok,
         Enum.reduce(values, db, fn {item, t}, db -> Database.put_text(db, item, cat_id, t) end)}
    end
  end
end
