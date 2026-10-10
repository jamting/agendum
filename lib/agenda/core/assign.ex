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

  alias Agenda.Core.{Database, RangeFilter}

  @type db :: Database.t()
  @type id :: Database.id()

  @doc """
  Assigns an item to a category, applying mutual exclusion, the
  ancestor/descendant rule and category links. Assigning to MAIN or to a
  date category is a no-op here (dates are set with `Agenda.Core.set_date/4`).

  An item is never directly assigned to both a category and one of its
  ancestors (R7c): assigning to an ancestor breaks the item's assignments to
  its descendants, as Agenda does, and assigning to a descendant replaces a
  direct assignment to an ancestor (the item still belongs to the ancestor
  through inheritance).
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
        db =
          db
          |> clear_exclusive_siblings(item_id, cat_id)
          |> clear_lineage(item_id, cat_id)
          |> Database.link(item_id, cat_id)

        visited = MapSet.put(visited, cat_id)

        # A link to a category the item already belongs to (e.g. an ancestor)
        # adds nothing, and assigning it would break the more specific link.
        Enum.reduce(db.categories[cat_id].also_assign, db, fn target, acc ->
          if Map.has_key?(acc.categories, target) and not Database.member?(acc, item_id, target),
            do: do_assign(acc, item_id, target, visited),
            else: acc
        end)
    end
  end

  # Removes the item's direct links to the category's ancestors and
  # descendants, so that linking the category keeps R7c.
  defp clear_lineage(db, item_id, cat_id) do
    (Database.ancestors(db, cat_id) ++ Database.descendants(db, cat_id))
    |> Enum.reduce(db, &Database.unlink(&2, item_id, &1))
  end

  @doc """
  Applies the file's assignment conditions to one item (R15), until nothing
  changes: a category whose conditions the item meets assigns it (marked
  conditional), and a conditional assignment whose conditions no longer
  hold is broken. Assignments the user made are left alone. Contradictory
  conditions (A if not B, B if not A) stop after a bounded number of rounds.
  """
  @spec apply_conditions(db, id) :: db
  def apply_conditions(db, item_id) do
    with_conditions = for {id, %{conditions: [_ | _]}} <- db.categories, do: id
    settle_conditions(db, item_id, Enum.sort(with_conditions), length(with_conditions) + 2)
  end

  defp settle_conditions(db, _item_id, [], _rounds), do: db
  defp settle_conditions(db, _item_id, _cats, 0), do: db

  defp settle_conditions(db, item_id, cats, rounds) do
    next =
      Enum.reduce(cats, db, fn cat_id, acc ->
        met = conditions_met?(acc, item_id, cat_id)

        cond do
          met and not Database.member?(acc, item_id, cat_id) ->
            acc |> assign(item_id, cat_id) |> Database.mark_conditional(item_id, cat_id)

          not met and Database.conditional?(acc, item_id, cat_id) ->
            Database.unlink(acc, item_id, cat_id)

          true ->
            acc
        end
      end)

    if next == db, do: db, else: settle_conditions(next, item_id, cats, rounds - 1)
  end

  @doc """
  Whether an item meets a category's assignment conditions: every
  condition must hold, except that "assigned" conditions naming mutually
  exclusive categories are alternatives (High or Low), as in Agenda.
  """
  @spec conditions_met?(db, id, id) :: boolean
  def conditions_met?(db, item_id, cat_id) do
    conditions = Enum.reject(db.categories[cat_id].conditions, &(elem(&1, 0) == cat_id))
    conditions != [] and criteria_met?(db, item_id, conditions)
  end

  @doc """
  Whether an item meets a list of `{category, :assigned | :not_assigned}`
  criteria, as used by conditions (R15) and filters (R28): every criterion
  must hold, except that `:assigned` criteria naming mutually exclusive
  categories are alternatives. Filters can also hold date and numeric
  ranges (`Agenda.Core.RangeFilter`, R28a), read against the clock `today`
  (a date or an `Agenda.Core.Context`). An empty
  list is always met.
  """
  @spec criteria_met?(db, id, [{id, term}], Agenda.Core.Context.clock() | nil) :: boolean
  def criteria_met?(db, item_id, criteria, today \\ nil) do
    {ranges, criteria} = Enum.split_with(criteria, &match?({_, {:range, _, _, _}}, &1))

    Enum.all?(ranges, fn {cat, range} -> RangeFilter.met?(db, item_id, cat, range, today) end) and
      plain_criteria_met?(db, item_id, criteria)
  end

  defp plain_criteria_met?(db, item_id, criteria) do
    {positive, negative} = Enum.split_with(criteria, &(elem(&1, 1) == :assigned))

    Enum.all?(negative, fn {target, _} -> not Database.member?(db, item_id, target) end) and
      positive
      |> Enum.map(&elem(&1, 0))
      |> exclusive_groups(db)
      |> Enum.all?(fn group -> Enum.any?(group, &Database.member?(db, item_id, &1)) end)
  end

  # Groups categories that cannot hold together (mutually exclusive), so that
  # each group is satisfied by any one of its members.
  defp exclusive_groups(targets, db) do
    Enum.reduce(targets, [], fn target, groups ->
      case Enum.split_with(groups, fn group -> Enum.any?(group, &conflict?(db, target, &1)) end) do
        {[], rest} -> [[target] | rest]
        {joined, rest} -> [Enum.concat([[target] | joined]) | rest]
      end
    end)
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
  Every way an item breaks Agenda's assignment rules: an exclusive family
  it is in more than once (`{:exclusive, family}`, R7), or a direct link to
  both a category and its ancestor (`{:lineage, category, ancestor}`, R7c).
  """
  @spec violations(db, id) :: [{:exclusive, id} | {:lineage, id, id}]
  def violations(db, item_id) do
    explicit = Database.explicit_categories(db, item_id)

    exclusive =
      for {id, %{exclusive: true}} <- db.categories,
          length(branches(db, item_id, id)) > 1,
          do: {:exclusive, id}

    lineage =
      for c <- explicit,
          a <- Database.ancestors(db, c),
          MapSet.member?(explicit, a),
          do: {:lineage, c, a}

    Enum.sort(exclusive) ++ Enum.sort(lineage)
  end

  @doc """
  After a category has been moved, promoted or demoted, the items in its
  (new) subtree that now break an assignment rule (see `violations/2`).
  """
  @spec placement_conflicts(db, id) :: [id]
  def placement_conflicts(db, cat_id) do
    db
    |> Database.items_in(cat_id)
    |> Enum.map(& &1.id)
    |> Enum.filter(&(violations(db, &1) != []))
  end

  @doc """
  Where a new category for conflicting items belongs: the category the
  conflicts hinge on (an exclusive family, or the ancestor in a
  category/ancestor pair), preferring the moved category itself and then
  its nearest ancestor.
  """
  @spec conflicting_family(db, id, [id]) :: id | nil
  def conflicting_family(db, cat_id, items) do
    anchors =
      for item <- items, v <- violations(db, item), uniq: true do
        case v do
          {:exclusive, family} -> family
          {:lineage, _child, ancestor} -> ancestor
        end
      end

    Enum.find([cat_id | Database.ancestors(db, cat_id)], &(&1 in anchors)) || List.first(anchors)
  end

  @doc """
  Resolves one item that a move put in conflict, as Agenda 2.0's "Process
  conflicting item(s) by" box does. `moved` is the moved category's subtree
  as it was before the move (so siblings adopted by a promote are "other").

    * `:remove_moved` – keep the item's other assignments; links in the
      moved category give way
    * `:remove_other` – keep the item's links in the moved category; the
      other assignments give way
    * `{:category, target}` – drop every link involved in a conflict and
      assign the item to `target`

  When several links on the same side clash, the one closest to the top of
  the outline wins.
  """
  @spec resolve_placement(db, MapSet.t(id), id, :remove_moved | :remove_other | {:category, id}) ::
          db
  def resolve_placement(db, _moved, item_id, {:category, target}) do
    db
    |> involved(item_id)
    |> Enum.reduce(db, &Database.unlink(&2, item_id, &1))
    |> assign(item_id, target)
  end

  def resolve_placement(db, moved, item_id, rule) do
    {inside, outside} =
      db
      |> Database.explicit_categories(item_id)
      |> Enum.sort_by(&outline_position(db, &1), :desc)
      |> Enum.split_with(&MapSet.member?(moved, &1))

    # reassert the losing side first and the winning side last; within a
    # side the bottom of the outline goes first, so the top wins
    order = if rule == :remove_moved, do: inside ++ outside, else: outside ++ inside
    Enum.reduce(order, db, &reassert(&2, item_id, &1))
  end

  # Links that take part in one of the item's conflicts.
  defp involved(db, item_id) do
    explicit = Database.explicit_categories(db, item_id)

    db
    |> violations(item_id)
    |> Enum.flat_map(fn
      {:exclusive, family} ->
        Enum.filter(Database.descendants(db, family), &MapSet.member?(explicit, &1))

      {:lineage, child, ancestor} ->
        [child, ancestor]
    end)
    |> Enum.uniq()
  end

  # Re-links a category, removing whatever conflicts with it (without
  # following category links, which already ran when it was assigned).
  defp reassert(db, item_id, cat_id) do
    db
    |> clear_exclusive_siblings(item_id, cat_id)
    |> clear_lineage(item_id, cat_id)
    |> Database.link(item_id, cat_id)
  end

  defp outline_position(db, cat_id) do
    Enum.find_index(Database.subtree(db, db.main_id), &(&1 == cat_id))
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

    accepted =
      db
      |> matching_categories(text)
      # already a member (directly, or through a more specific category)
      |> Enum.reject(&Database.member?(db, item_id, &1))
      |> Enum.reject(fn cand -> Enum.any?(explicit, &conflict?(db, cand, &1)) end)
      |> Enum.sort_by(&preference(db, &1, adjacent))
      |> Enum.reduce([], fn cand, accepted ->
        if Enum.any?(accepted, &conflict?(db, cand, &1)), do: accepted, else: [cand | accepted]
      end)
      |> Enum.reverse()

    # when a category and its ancestor both match, keep the specific one (R7c)
    accepted
    |> Enum.reject(fn cand -> Enum.any?(accepted, &(cand in Database.ancestors(db, &1))) end)
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
