defmodule Agendum.Core.Assign do
  @moduledoc """
  Assignment rules: how items get linked to categories.

  * **Explicit assignment** links an item to a category. Membership of every
    ancestor follows by subsumption (see `Database.member?/3`), so it is never
    stored.
  * **Mutual exclusion.** If a category's parent has `exclusive: true`,
    assigning an item to one child removes it from that child's siblings and
    their subtrees. The same applies at every exclusive level above it.
  * **Negative links** (R9). A category's `excludes` list names categories
    that may not share an item with it: assigning an item to the category
    (or below it) removes it from those and their subtrees.
  * **Category links.** A category's `also_assign` list sends its items on to
    other categories (patent FIG. 6).
  * **Automatic assignment.** An item whose text contains a category's name
    (its words, ignoring case, by the file's matching settings,
    `Agendum.Core.TextMatch`) is assigned to it. If two matches cannot
    both hold because they are mutually exclusive, the tie is broken the way
    the patent (claim 7) describes: prefer the category that the adjacent
    item in the view belongs to, then the one created first. Existing
    explicit assignments always win over new automatic ones.
  """

  alias Agendum.Core.{Database, RangeFilter, TextCondition, TextMatch}
  alias Agendum.Core.Extras.ZettelLinks

  @type db :: Database.t()
  @type id :: Database.id()

  @doc """
  Assigns an item to a category, applying mutual exclusion, the
  ancestor/descendant rule and category links. Assigning to MAIN or to a
  date category is a no-op here (dates are set with `Agendum.Core.set_date/4`).

  An item is never directly assigned to both a category and one of its
  ancestors (R7c): assigning to an ancestor breaks the item's assignments to
  its descendants, as Agenda does, and assigning to a descendant replaces a
  direct assignment to an ancestor (the item still belongs to the ancestor
  through inheritance).
  """
  @spec assign(db, id, id) :: db
  def assign(db, item_id, cat_id), do: do_assign(db, item_id, cat_id, [])

  # `visited`: the categories already assigned through category links, so
  # that cycles stop.
  defp do_assign(db, item_id, cat_id, visited) do
    cond do
      cat_id in visited ->
        db

      cat_id == db.main_id or Database.date_category?(db, cat_id) ->
        db

      true ->
        db =
          db
          |> clear_exclusive_siblings(item_id, cat_id)
          |> clear_excluded(item_id, cat_id)
          |> clear_lineage(item_id, cat_id)
          |> Database.link(item_id, cat_id)

        visited = [cat_id | visited]

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
  Date conditions with relative dates (R15a) are read against `clock` (a
  date or an `Agendum.Core.Context`); without one, only ISO dates are read.
  """
  @spec apply_conditions(db, id, Agendum.Core.Context.clock() | nil, MapSet.t(id) | nil) :: db
  def apply_conditions(db, item_id, clock \\ nil, only \\ nil) do
    {with_conditions, conditions} = condition_set(db, clock, only)
    rounds = length(with_conditions) + 2
    settle_conditions(db, item_id, with_conditions, rounds, {conditions, clock})
  end

  @doc """
  The items whose conditions have not settled, in item order: one more
  round of them would change something. Such an item is caught in a
  circular reference (User's Guide 20-21: conditions that keep assigning
  it and taking it out again, which `apply_conditions/4` stops after a
  bounded number of rounds).
  """
  @spec unsettled(db, Agendum.Core.Context.clock() | nil) :: [id]
  def unsettled(db, clock \\ nil) do
    case condition_set(db, clock, nil) do
      # no conditions, nothing to keep flipping
      {[], _} ->
        []

      {with_conditions, conditions} ->
        for id <- db.item_order,
            settle_conditions(db, id, with_conditions, 1, {conditions, clock}) != db,
            do: id
    end
  end

  # the categories whose conditions assign, sorted, and every category's
  # conditions with their date words read
  defp condition_set(db, clock, only) do
    # Only a standard category's conditions assign. A category made a date
    # or numeric category keeps its conditions, but they do nothing, as in
    # Agenda (its box shows them "Only if Type is Standard"; checked in
    # Agenda 2.0, 2026-10-16).
    with_conditions =
      for {id, %{conditions: [_ | _], kind: :standard}} <- db.categories,
          only == nil or MapSet.member?(only, id),
          do: id

    # every category's conditions, with their date words ("yesterday")
    # read once here rather than in each round for each category: reading
    # a date runs every rule of the date languages. Conditions do not
    # change while they settle, and neither does the clock.
    conditions =
      for {id, %{conditions: [_ | _], kind: :standard}} <- db.categories,
          into: %{},
          do: {id, resolve_ranges(db, own_conditions(db, id), clock)}

    {Enum.sort(with_conditions), conditions}
  end

  defp settle_conditions(db, _item_id, _cats, 0, _conditions), do: db

  # Categories with conditions may pull the item in; any conditional link
  # (from conditions or from text, R15c) breaks when neither holds.
  # `conditions` is {category id => its read conditions, clock}.
  defp settle_conditions(db, item_id, with_conditions, rounds, {read, clock} = conditions) do
    conditional =
      for cat <- Database.explicit_categories(db, item_id),
          Database.conditional?(db, item_id, cat),
          do: cat

    next =
      Enum.reduce(Enum.uniq(with_conditions ++ Enum.sort(conditional)), db, fn cat_id, acc ->
        cat_conditions = Map.get(read, cat_id, [])
        met = cat_conditions != [] and criteria_met?(acc, item_id, cat_conditions, clock)

        cond do
          met and not Database.member?(acc, item_id, cat_id) ->
            assign_conditionally(acc, item_id, cat_id)

          not met and Database.conditional?(acc, item_id, cat_id) and
              not text_matches?(acc, item_id, cat_id) ->
            Database.unlink(acc, item_id, cat_id)

          true ->
            acc
        end
      end)

    if next == db,
      do: db,
      else: settle_conditions(next, item_id, with_conditions, rounds - 1, conditions)
  end

  # Assigns and marks the link as made by conditions. `assign/3` links
  # nothing to MAIN or a date category (a category with conditions can be
  # made a date category later, and keeps them), and then there is no link
  # to mark (DATA_MODEL invariant 10).
  defp assign_conditionally(db, item_id, cat_id) do
    db = assign(db, item_id, cat_id)

    if Database.explicit?(db, item_id, cat_id),
      do: Database.mark_conditional(db, item_id, cat_id),
      else: db
  end

  @doc """
  Whether an item meets a category's assignment conditions: every
  condition must hold, except that "assigned" conditions naming mutually
  exclusive categories are alternatives (High or Low), as in Agenda.
  """
  @spec conditions_met?(db, id, id, Agendum.Core.Context.clock() | nil) :: boolean
  def conditions_met?(db, item_id, cat_id, clock \\ nil) do
    conditions = own_conditions(db, cat_id)
    conditions != [] and criteria_met?(db, item_id, conditions, clock)
  end

  # A category's conditions, less any on itself (which could never hold
  # before it is assigned).
  defp own_conditions(db, cat_id),
    do: Enum.reject(db.categories[cat_id].conditions, &(elem(&1, 0) == cat_id))

  @doc """
  Whether an item meets a list of `{category, :assigned | :not_assigned}`
  criteria, as used by conditions (R15) and filters (R28): every criterion
  must hold, except that `:assigned` criteria naming mutually exclusive
  categories are alternatives. Filters can also hold date and numeric
  ranges (`Agendum.Core.RangeFilter`, R28a), read against the clock `today`
  (a date or an `Agendum.Core.Context`). An empty
  list is always met.
  """
  @spec criteria_met?(db, id, [{id, term}], Agendum.Core.Context.clock() | nil) :: boolean
  def criteria_met?(db, item_id, criteria, today \\ nil) do
    {ranges, criteria} = Enum.split_with(criteria, &match?({_, {:range, _, _, _}}, &1))

    Enum.all?(ranges, fn {cat, range} -> RangeFilter.met?(db, item_id, cat, range, today) end) and
      plain_criteria_met?(db, item_id, criteria)
  end

  @doc """
  The criteria with the date ranges read against the clock once
  (`RangeFilter.resolve_bounds/3`), for testing many items with
  `criteria_met?/4`: a view does this before it filters its items.
  """
  @spec resolve_ranges(db, [{id, term}], Agendum.Core.Context.clock() | nil) :: [{id, term}]
  def resolve_ranges(db, criteria, today) do
    Enum.map(criteria, fn
      {cat, {:range, _, _, _} = range} -> {cat, RangeFilter.resolve_bounds(db, range, today)}
      criterion -> criterion
    end)
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
  different children of a mutually exclusive ancestor, or because a
  negative link joins them or their ancestors (R9).
  """
  @spec conflict?(db, id, id) :: boolean
  def conflict?(db, a, b) do
    path_a = [a | Database.ancestors(db, a)]
    path_b = [b | Database.ancestors(db, b)]
    excluded?(db, path_a, path_b) or exclusive_conflict?(db, path_a, path_b)
  end

  defp excluded?(db, path_a, path_b),
    do: Enum.any?(path_a, fn x -> Enum.any?(db.categories[x].excludes, &(&1 in path_b)) end)

  defp exclusive_conflict?(db, path_a, path_b) do
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
  @spec auto_assign(db, id, [id], MapSet.t(id) | nil) :: db
  def auto_assign(db, item_id, adjacent \\ [], only \\ nil) do
    levels = db |> item_match_levels(db.items[item_id]) |> Map.new()
    explicit = Database.explicit_categories(db, item_id)

    accepted =
      levels
      |> Map.keys()
      |> Enum.sort()
      |> Enum.filter(&(only == nil or MapSet.member?(only, &1)))
      # not already a member (directly, or through a more specific category),
      # and not in conflict with an assignment the item has
      |> Enum.reject(fn cand ->
        Database.member?(db, item_id, cand) or Enum.any?(explicit, &conflict?(db, cand, &1))
      end)
      |> Enum.sort_by(&preference(db, &1, adjacent))
      |> Enum.reduce([], fn cand, accepted ->
        if Enum.any?(accepted, &conflict?(db, cand, &1)), do: accepted, else: [cand | accepted]
      end)
      |> Enum.reverse()

    # when a category and its ancestor both match, keep the specific one (R7c)
    accepted =
      Enum.reject(accepted, fn cand ->
        Enum.any?(accepted, &(cand in Database.ancestors(db, &1)))
      end)

    # suggested, to be confirmed with Utilities Questions (R16): every
    # match with Always, partial ones with Sometimes (R16a)
    {suggested, made} =
      Enum.split_with(accepted, fn cand ->
        case confirm_mode(db, cand) do
          :always -> true
          :sometimes -> levels[cand] == :partial
          :never -> false
        end
      end)

    suggestions =
      if suggested == [],
        do: Map.delete(db.suggestions, item_id),
        else: Map.put(db.suggestions, item_id, suggested)

    # text matches are conditional: they break when the text changes (R15c)
    Enum.reduce(made, %{db | suggestions: suggestions}, fn cand, db ->
      db |> assign(item_id, cand) |> Database.mark_conditional(item_id, cand)
    end)
  end

  @doc """
  The text an item is matched on (Match on, R16a): its text, its note, or
  both.
  """
  @spec match_text(Agendum.Core.Item.t(), :item | :note | :both) :: String.t()
  def match_text(item, :item), do: item.text
  def match_text(item, :note), do: item.note
  def match_text(item, :both), do: item.text <> "\n" <> item.note

  @doc """
  A category's text matching settings: the file's, with those it sets for
  itself (R16b).
  """
  @spec match_settings(db, id) :: TextMatch.t()
  def match_settings(db, cat_id) do
    overrides = Map.delete(db.categories[cat_id].match_overrides, :confirm)
    struct(db.match_settings, overrides)
  end

  @doc "A category's Confirm assignments: its own or the file's (R16, R16b)."
  @spec confirm_mode(db, id) :: :never | :always | :sometimes
  def confirm_mode(db, cat_id),
    do: Map.get(db.categories[cat_id].match_overrides, :confirm, db.confirm_assignments)

  @doc """
  Categories whose name or short name (when they match names) or text
  conditions ("Also match", R15d) match `text`, by the file's matching
  settings (R16a).
  """
  @spec matching_categories(db, String.t()) :: [id]
  def matching_categories(db, text), do: db |> match_levels(text) |> Enum.map(&elem(&1, 0))

  @doc """
  The categories `text` matches, each with how well: `:full`, or
  `:partial` when only enough words for the required strength are there.
  """
  @spec match_levels(db, String.t()) :: [{id, :full | :partial}]
  def match_levels(db, text), do: levels(db, fn _match_on -> text end)

  # The same for an item, each category matching the text it says (R16b).
  defp item_match_levels(db, item), do: levels(db, &match_text(item, &1))

  defp levels(db, text_for) do
    db.categories
    |> Map.values()
    |> Enum.filter(&(&1.kind == :standard and not Database.protected?(db, &1.id)))
    |> Enum.map_reduce(%{}, fn cat, prepared ->
      settings = match_settings(db, cat.id)
      key = {settings.match_on, settings.ignore_accents}

      prepared =
        Map.put_new_lazy(prepared, key, fn ->
          TextMatch.prepare(ZettelLinks.strip(text_for.(settings.match_on)), settings)
        end)

      level = if settings.enabled, do: category_level(cat, prepared[key], settings), else: :none
      {{cat.id, level}, prepared}
    end)
    |> elem(0)
    |> Enum.reject(&(elem(&1, 1) == :none))
    |> Enum.sort()
  end

  @doc "Whether an item's text matches a category (see `matching_categories/2`)."
  @spec text_matches?(db, id, id) :: boolean
  def text_matches?(db, item_id, cat_id) do
    settings = match_settings(db, cat_id)
    text = ZettelLinks.strip(match_text(db.items[item_id], settings.match_on))
    prepared = TextMatch.prepare(text, settings)
    settings.enabled and category_level(db.categories[cat_id], prepared, settings) != :none
  end

  defp category_level(cat, prepared, settings) do
    names = if cat.match_name, do: Enum.reject([cat.name, cat.short_name], &is_nil/1), else: []

    levels =
      Enum.map(names, &name_level(&1, prepared, settings)) ++
        [TextCondition.level(cat.also_match, prepared, settings)]

    cond do
      :full in levels -> :full
      :partial in levels -> :partial
      true -> :none
    end
  end

  # A name of words matches by the settings; one with other characters
  # ("C++") as written.
  defp name_level(name, prepared, settings) do
    cond do
      Regex.match?(~r/^[\p{L}\p{N}'’_\-.\s]+$/u, name) ->
        TextMatch.level(name, prepared, settings, name: true)

      name_in_text?(name, prepared.text) ->
        :full

      true ->
        :none
    end
  end

  @doc "Whole-word, case-insensitive match of a name in text, its words in order."
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

  # R9: out of every category this one, or an ancestor, excludes.
  defp clear_excluded(db, item_id, cat_id) do
    [cat_id | Database.ancestors(db, cat_id)]
    |> Enum.flat_map(&db.categories[&1].excludes)
    |> Enum.reduce(db, &unassign(&2, item_id, &1))
  end

  @doc """
  Whether some negative link joins a category to one of its ancestors
  (which would leave the descendant no items), e.g. after a move (R9).
  """
  @spec excluded_lineage?(db) :: boolean
  def excluded_lineage?(db) do
    Enum.any?(db.categories, fn {id, cat} ->
      Enum.any?(cat.excludes, &(&1 in Database.ancestors(db, id)))
    end)
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
