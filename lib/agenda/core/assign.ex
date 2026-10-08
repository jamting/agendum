defmodule Agenda.Core.Assign do
  @moduledoc """
  Assignment rules: how items get linked to categories.

  * **Explicit assignment** links an item to a category. Membership of every
    ancestor follows by subsumption (see `Database.member?/3`), so it is never
    stored.
  * **Mutual exclusion.** If a category's parent has `exclusive: true`,
    assigning an item to one child removes it from that child's siblings and
    their subtrees. The same applies at every exclusive level above it.
  * **Category links.** A category's `also_assign` list sends its items on to
    other categories (patent FIG. 6).
  * **Automatic assignment.** An item whose text contains a category's name
    (whole words, ignoring case) is assigned to it. If two matches cannot
    both hold because they are mutually exclusive, the tie is broken the way
    the patent (claim 7) describes: prefer the category that the adjacent
    item in the view belongs to, then the one created first. Existing
    explicit assignments always win over new automatic ones.
  """

  alias Agenda.Core.Database

  @type db :: Database.t()
  @type id :: Database.id()

  @doc """
  Assigns an item to a category, applying mutual exclusion and category
  links. Assigning to MAIN or to a date category is a no-op here (dates are
  set with `Agenda.Core.set_date/4`).
  """
  @spec assign(db, id, id) :: db
  def assign(db, item_id, cat_id), do: do_assign(db, item_id, cat_id, MapSet.new())

  defp do_assign(db, item_id, cat_id, visited) do
    cond do
      MapSet.member?(visited, cat_id) ->
        db

      cat_id == db.main_id or Database.date_field(db, cat_id) ->
        db

      true ->
        db = db |> clear_exclusive_siblings(item_id, cat_id) |> Database.link(item_id, cat_id)
        visited = MapSet.put(visited, cat_id)

        Enum.reduce(db.categories[cat_id].also_assign, db, fn target, acc ->
          if Map.has_key?(acc.categories, target),
            do: do_assign(acc, item_id, target, visited),
            else: acc
        end)
    end
  end

  @doc "Removes an item from a category and everything below it."
  @spec unassign(db, id, id) :: db
  def unassign(db, item_id, cat_id) do
    db
    |> Database.subtree(cat_id)
    |> Enum.reduce(db, &Database.unlink(&2, item_id, &1))
  end

  @doc """
  True if an item cannot be in both categories because they sit under
  different children of a mutually exclusive ancestor.
  """
  @spec conflict?(db, id, id) :: boolean
  def conflict?(db, a, b) do
    path_a = [a | Database.ancestors(db, a)]
    path_b = [b | Database.ancestors(db, b)]

    Enum.any?(Enum.zip(path_a, tl(path_a)), fn {child_a, parent} ->
      db.categories[parent].exclusive and
        case child_toward(path_b, parent) do
          nil -> false
          child_b -> child_b != child_a
        end
    end)
  end

  # The element of `path` (a leaf-to-root list) directly beneath `ancestor`.
  defp child_toward(path, ancestor) do
    path
    |> Enum.zip(tl(path))
    |> Enum.find_value(fn {child, parent} -> if parent == ancestor, do: child end)
  end

  @doc """
  Runs automatic assignment for an item based on its text.

  `adjacent` lists ids of neighbouring items in the view, nearest first
  (previous item, then next item), and is used to resolve ambiguity.
  """
  @spec auto_assign(db, id, [id]) :: db
  def auto_assign(db, item_id, adjacent \\ []) do
    text = db.items[item_id].text
    explicit = Database.explicit_categories(db, item_id)

    db
    |> matching_categories(text)
    |> Enum.reject(&MapSet.member?(explicit, &1))
    |> Enum.reject(fn cand -> Enum.any?(explicit, &conflict?(db, cand, &1)) end)
    |> Enum.sort_by(&preference(db, &1, adjacent))
    |> Enum.reduce([], fn cand, accepted ->
      if Enum.any?(accepted, &conflict?(db, cand, &1)), do: accepted, else: [cand | accepted]
    end)
    |> Enum.reverse()
    |> Enum.reduce(db, &assign(&2, item_id, &1))
  end

  @doc "Categories whose name or short name occurs in `text` as whole words."
  @spec matching_categories(db, String.t()) :: [id]
  def matching_categories(db, text) do
    db.categories
    |> Map.values()
    |> Enum.filter(
      &(&1.match_name and &1.kind == :standard and not Database.protected?(db, &1.id))
    )
    |> Enum.filter(fn c -> Enum.any?([c.name, c.short_name], &name_in_text?(&1, text)) end)
    |> Enum.map(& &1.id)
    |> Enum.sort()
  end

  @doc "Whole-word, case-insensitive match of a category name in text."
  @spec name_in_text?(String.t() | nil, String.t()) :: boolean
  def name_in_text?(nil, _text), do: false

  def name_in_text?(name, text) do
    words = name |> String.trim() |> String.split(~r/\s+/u, trim: true)

    if String.length(Enum.join(words, " ")) < 2 do
      false
    else
      pattern = Enum.map_join(words, "\\s+", &Regex.escape/1)
      Regex.match?(~r/(?<![\p{L}\p{N}])#{pattern}(?![\p{L}\p{N}])/iu, text)
    end
  end

  # Lower sorts first: categories held by the nearest adjacent item win,
  # then the category that was created first (lowest id).
  defp preference(db, cand, adjacent) do
    rank = Enum.find_index(adjacent, &Database.member?(db, &1, cand)) || length(adjacent)
    {rank, cand}
  end

  defp clear_exclusive_siblings(db, item_id, cat_id) do
    path = [cat_id | Database.ancestors(db, cat_id)]

    path
    |> Enum.zip(tl(path))
    |> Enum.filter(fn {_child, parent} -> db.categories[parent].exclusive end)
    |> Enum.reduce(db, fn {child, parent}, acc ->
      acc.categories[parent].children
      |> Enum.reject(&(&1 == child))
      |> Enum.reduce(acc, &unassign(&2, item_id, &1))
    end)
  end
end
