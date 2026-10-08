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
  The children of `cat_id` whose subtree holds one of the item's explicit
  links, in hierarchy order. An item belongs to several *branches* of a
  family when this has more than one element.
  """
  @spec branches(db, id, id) :: [id]
  def branches(db, item_id, cat_id) do
    explicit = Database.explicit_categories(db, item_id)

    Enum.filter(db.categories[cat_id].children, fn child ->
      db |> Database.subtree(child) |> Enum.any?(&MapSet.member?(explicit, &1))
    end)
  end

  @doc """
  Items that would break mutual exclusion if `cat_id`'s children were made
  exclusive, i.e. items in more than one branch of the family.
  """
  @spec exclusive_conflicts(db, id) :: [id]
  def exclusive_conflicts(db, cat_id) do
    db
    |> Database.items_in(cat_id)
    |> Enum.map(& &1.id)
    |> Enum.filter(&(length(branches(db, &1, cat_id)) > 1))
  end

  @doc """
  Resolves one conflicting item before `cat_id` becomes exclusive, the way
  Agenda 2.0 offers it:

    * `:parent` – leave every child branch and assign the item to `cat_id`
    * `:first_child` – keep only the branch closest to the top of the family
    * `{:category, id}` – leave every child branch and assign to `id`
  """
  @spec resolve_exclusive(db, id, id, :parent | :first_child | {:category, id}) :: db
  def resolve_exclusive(db, cat_id, item_id, :first_child) do
    [_keep | drop] = branches(db, item_id, cat_id)
    Enum.reduce(drop, db, &unassign(&2, item_id, &1))
  end

  def resolve_exclusive(db, cat_id, item_id, target) do
    target = if target == :parent, do: cat_id, else: elem(target, 1)

    db
    |> then(
      &Enum.reduce(db.categories[cat_id].children, &1, fn child, acc ->
        unassign(acc, item_id, child)
      end)
    )
    |> assign(item_id, target)
  end

  @doc """
  After a category has been moved, the items in its subtree that are now
  in more than one branch of an exclusive family above it.
  """
  @spec placement_conflicts(db, id) :: [id]
  def placement_conflicts(db, cat_id) do
    exclusive = Enum.filter(Database.ancestors(db, cat_id), &db.categories[&1].exclusive)

    db
    |> Database.items_in(cat_id)
    |> Enum.map(& &1.id)
    |> Enum.filter(fn item -> Enum.any?(exclusive, &(length(branches(db, item, &1)) > 1)) end)
  end

  @doc """
  The nearest exclusive ancestor of a moved category where any of the
  given items is in more than one branch.
  """
  @spec conflicting_family(db, id, [id]) :: id | nil
  def conflicting_family(db, cat_id, items) do
    db
    |> Database.ancestors(cat_id)
    |> Enum.find(fn a ->
      db.categories[a].exclusive and Enum.any?(items, &(length(branches(db, &1, a)) > 1))
    end)
  end

  @doc """
  Resolves one item that a category move put in two exclusive branches, as
  Agenda 2.0's "Process conflicting item(s) by" box does:

    * `:remove_moved` – remove the item from the moved category (subtree)
    * `:remove_other` – remove it from the branches it now clashes with
    * `{:category, family, target}` – leave every branch of the exclusive
      `family` and assign the item to `target`
  """
  @spec resolve_placement(db, id, id, :remove_moved | :remove_other | {:category, id, id}) :: db
  def resolve_placement(db, cat_id, item_id, :remove_moved), do: unassign(db, item_id, cat_id)

  def resolve_placement(db, cat_id, item_id, :remove_other),
    do: clear_exclusive_siblings(db, item_id, cat_id)

  def resolve_placement(db, _cat_id, item_id, {:category, family, target}) do
    db.categories[family].children
    |> Enum.reduce(db, &unassign(&2, item_id, &1))
    |> assign(item_id, target)
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
