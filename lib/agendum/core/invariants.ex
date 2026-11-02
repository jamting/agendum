# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Invariants do
  @moduledoc """
  The data model's invariants as one pure check (docs/DATA_MODEL.md,
  "Invariants"): `violations/1` lists, in sentences, every one a database
  breaks; a sound database gives `[]`.

  The core keeps these through its own operations; the check is how tests
  make sure of it. The fuzz walks (`Agendum.TUI.Fuzz`) run it after every
  key, so any key sequence that leaves the file inconsistent fails there,
  not later in someone's file. Every file opened is checked with it too
  (`Agendum.Core.FileCheck`, ADR 0052).

  The numbers in the sentences are those of the list in DATA_MODEL.md.
  """

  alias Agendum.Core.{Database, Links}

  @protected [main: "MAIN", entry: "Entry", when: "When", done: "Done"]

  @doc "Every invariant the database breaks, as sentences; `[]` when none."
  @spec violations(Database.t()) :: [String.t()]
  def violations(%Database{} = db) do
    tree = tree(db)

    # The checks below walk up the tree (ancestors, subsumption); on a
    # broken tree they could loop for ever, so only the tree is reported.
    if tree == [] do
      ids(db) ++
        links(db) ++
        exclusive(db) ++
        live_references(db) ++
        orders(db) ++
        protected(db) ++
        lineage(db) ++
        conditional(db) ++
        zettels(db) ++ blog(db) ++ feeds(db) ++ trash(db)
    else
      tree
    end
  end

  # --- 1. The tree ---------------------------------------------------------

  defp tree(db) do
    cats = db.categories

    # `for` with several generators and a filter is a comprehension: one
    # result for each combination that passes the filter.
    parents =
      for {id, cat} <- cats,
          id != db.main_id,
          parent = cats[cat.parent_id],
          parent == nil or Enum.count(parent.children, &(&1 == id)) != 1,
          do: "1. tree: category #{id} is not listed once by its parent #{inspect(cat.parent_id)}"

    children =
      for {id, cat} <- cats,
          child <- cat.children,
          match?(%{parent_id: p} when p != id, cats[child]) or cats[child] == nil,
          do: "1. tree: category #{id} lists #{child}, which is not its child"

    main =
      if match?(%{parent_id: nil}, cats[db.main_id]),
        do: [],
        else: ["1. tree: MAIN has a parent"]

    # every category reachable from MAIN, each once: no cycles, no orphans
    reached = reach(cats, [db.main_id], %{})

    unreached =
      if Enum.sort(Map.keys(reached)) == Enum.sort(Map.keys(cats)),
        do: [],
        else: ["1. tree: not every category is reachable from MAIN, or there is a cycle"]

    parents ++ children ++ main ++ unreached
  end

  # A walk down from MAIN that never visits a category twice, so it ends
  # even on a cycle. `seen` is a map used as a set (id => true).
  defp reach(_cats, [], seen), do: seen

  defp reach(cats, [id | rest], seen) do
    if Map.has_key?(seen, id) or not Map.has_key?(cats, id),
      do: reach(cats, rest, seen),
      else: reach(cats, cats[id].children ++ rest, Map.put(seen, id, true))
  end

  # --- Ids -----------------------------------------------------------------

  defp ids(db) do
    kinds = [items: db.items, categories: db.categories, views: db.views, macros: db.macros]
    kinds = kinds ++ [calendars: db.calendars, feeds: db.feeds]
    all = Enum.flat_map(kinds, fn {_kind, map} -> Map.keys(map) end)

    own =
      for {kind, map} <- kinds,
          {id, object} <- map,
          object.id != id,
          do: "ids: #{kind} #{id} is not under its own id (#{inspect(object.id)})"

    shared =
      if length(all) == length(Enum.uniq(all)),
        do: [],
        else: ["ids: one id is used by two objects, though they share one id space"]

    below =
      for id <- all, id >= db.next_id, do: "ids: #{id} is not below next_id #{db.next_id}"

    own ++ shared ++ below
  end

  # --- 14. The trash ------------------------------------------------------

  # A discarded item is out of the file (R24a): its id is in neither the
  # items nor the order, used once, below next_id, and it has no dates or
  # alarm left to come back with.
  defp trash(db) do
    ids = Enum.map(db.trash.items, & &1.id)

    in_file =
      for id <- ids,
          Map.has_key?(db.items, id),
          do: "14. trash: item #{id} is both in the trash and in the file"

    twice = if ids == Enum.uniq(ids), do: [], else: ["14. trash: an item is in it twice"]
    below = for id <- ids, id >= db.next_id, do: "14. trash: #{id} is not below next_id"

    bare =
      for i <- db.trash.items,
          i.when != nil or i.done != nil or i.alarm_minutes != nil,
          do: "14. trash: item #{i.id} kept a date or an alarm"

    day =
      if db.trash.items == [] == (db.trash.day == nil),
        do: [],
        else: ["14. trash: its day is set exactly when it has items"]

    in_file ++ twice ++ below ++ bare ++ day
  end

  # --- 2, 3, 4. Links ------------------------------------------------------

  defp links(db) do
    symmetric(db.links, "links") ++
      symmetric(db.dependencies, "dependencies") ++
      live_links(db) ++ no_main_or_date(db)
  end

  defp symmetric(%Links{by_left: left, by_right: right}, name) do
    pairs = fn map, flip ->
      for {a, set} <- map, b <- set, into: MapSet.new(), do: if(flip, do: {b, a}, else: {a, b})
    end

    asym =
      if MapSet.equal?(pairs.(left, false), pairs.(right, true)),
        do: [],
        else: ["2. #{name} are not symmetric: by_left and by_right disagree"]

    empty =
      if Enum.any?(Map.values(left) ++ Map.values(right), &(MapSet.size(&1) == 0)),
        do: ["2. #{name} store an empty set"],
        else: []

    asym ++ empty
  end

  defp live_links(db) do
    links =
      for {item, cats} <- db.links.by_left,
          cat <- cats,
          not Map.has_key?(db.items, item) or not Map.has_key?(db.categories, cat),
          do: "3. a link #{item}–#{cat} does not join a live item and a live category"

    dependencies =
      for {a, bs} <- db.dependencies.by_left,
          b <- bs,
          not Map.has_key?(db.items, a) or not Map.has_key?(db.items, b),
          do: "3. a dependency #{a}–#{b} does not join two live items"

    links ++ dependencies
  end

  defp no_main_or_date(db) do
    for {item, cats} <- db.links.by_left,
        cat <- cats,
        cat == db.main_id or Database.date_category?(db, cat),
        do: "4. item #{item} is linked to MAIN or a date category (#{cat})"
  end

  # --- 5. Exclusive families -----------------------------------------------

  # For each item, the branches it is in below each exclusive parent: the
  # child of that parent on the way up from each category it is linked to.
  defp exclusive(db) do
    for {item, cats} <- db.links.by_left,
        Map.has_key?(db.items, item),
        {parent, children} <- branches(db, cats),
        MapSet.size(children) > 1,
        do: "5. item #{item} is in #{MapSet.size(children)} branches of exclusive #{parent}"
  end

  defp branches(db, cats) do
    cats
    |> Enum.filter(&Map.has_key?(db.categories, &1))
    |> Enum.flat_map(fn cat ->
      # [cat | ancestors] paired with the next one up: {child, parent}
      path = [cat | Database.ancestors(db, cat)]
      Enum.zip(path, tl(path))
    end)
    |> Enum.filter(fn {_child, parent} -> db.categories[parent].exclusive end)
    |> Enum.group_by(fn {_child, parent} -> parent end, fn {child, _parent} -> child end)
    |> Enum.map(fn {parent, children} -> {parent, MapSet.new(children)} end)
  end

  # --- 6. References to categories -----------------------------------------

  defp live_references(db) do
    gone = fn id -> id != nil and not Map.has_key?(db.categories, id) end

    in_views =
      for {view_id, view} <- db.views,
          {where, id} <- view_references(view),
          gone.(id),
          do: "6. view #{view_id}: #{where} names category #{id}, which is gone"

    in_categories =
      for {cat_id, cat} <- db.categories,
          {where, ids} <- [
            also_assign: cat.also_assign,
            excludes: cat.excludes,
            conditions: Enum.map(cat.conditions, &elem(&1, 0)),
            actions: Enum.map(cat.actions, &elem(&1, 0))
          ],
          id <- ids,
          gone.(id),
          do: "6. category #{cat_id}: #{where} names category #{id}, which is gone"

    in_calendars =
      for {cal_id, cal} <- db.calendars,
          gone.(cal.category_id),
          do: "6. calendar #{cal_id} files into category #{cal.category_id}, which is gone"

    # a Show View listing items (Show Prereqs, Show Circular …) lists live
    # ones: a discarded item leaves it (found 2026-10-26)
    listed =
      for {view_id, %{match: {kind, ids}}} <- db.views,
          kind in [:items, :circular],
          id <- ids,
          not Map.has_key?(db.items, id),
          do: "6. view #{view_id} lists item #{id}, which is gone"

    in_views ++ in_categories ++ in_calendars ++ listed
  end

  # Every category a view names, with where it names it.
  defp view_references(view) do
    sections =
      Enum.flat_map(view.sections, fn s ->
        [{:section, s.category_id}] ++
          columns(s.columns) ++ filters(s.filter) ++ sort_keys(s.sort || [])
      end)

    datebook =
      case view.datebook do
        nil -> []
        d -> [datebook: d.date_category, datebook: d.end_category, datebook: d.section_category]
      end

    sections ++ columns(view.columns) ++ filters(view.filter) ++ sort_keys(view.sort) ++ datebook
  end

  defp columns(columns), do: Enum.map(columns, &{:column, &1.category_id})
  defp filters(filter), do: Enum.map(filter, fn {id, _term} -> {:filter, id} end)

  defp sort_keys(keys) do
    for %{on: {_by, id}} <- keys, do: {:sort, id}
  end

  # --- 7. Order lists ------------------------------------------------------

  defp orders(db) do
    [
      order(db.item_order, db.items, "item_order", "items"),
      order(db.view_order, db.views, "view_order", "views"),
      order(db.macro_order, db.macros, "macro_order", "macros"),
      if(db.views == %{}, do: ["7. the file has no view"], else: [])
    ]
    |> List.flatten()
  end

  defp order(list, map, list_name, map_name) do
    if length(list) == length(Enum.uniq(list)) and
         MapSet.equal?(MapSet.new(list), MapSet.new(Map.keys(map))),
       do: [],
       else: ["7. #{list_name} does not hold exactly the ids of #{map_name}"]
  end

  # --- 8. Protected categories ---------------------------------------------

  defp protected(db) do
    ids = Map.put(db.special, :main, db.main_id)

    for {key, name} <- @protected,
        cat = db.categories[ids[key]],
        cat == nil or cat.name != name or
          (key != :main and cat.parent_id != db.main_id),
        do: "8. the protected category #{name} is missing, renamed or moved"
  end

  # --- 9. No direct link to a category and its ancestor (R7c) --------------

  defp lineage(db) do
    for {item, cats} <- db.links.by_left,
        cat <- cats,
        Map.has_key?(db.categories, cat),
        ancestor <- Database.ancestors(db, cat),
        MapSet.member?(cats, ancestor),
        do: "9. item #{item} is linked to #{cat} and to its ancestor #{ancestor}"
  end

  # --- 10. Conditional marks are links -------------------------------------

  defp conditional(db) do
    for {item, cat} <- db.conditional,
        not Links.linked?(db.links, item, cat),
        do: "10. the conditional mark #{item}–#{cat} has no link"
  end

  # --- 11. Zettel ids ------------------------------------------------------

  # Each number belongs to one item and is below the counter, so the next
  # one given is new (R73)
  defp zettels(db) do
    numbers = for {_id, %{zettel: n}} <- db.items, n != nil, do: n

    twice =
      for {n, count} <- Enum.frequencies(numbers),
          count > 1,
          do: "11. zettel ids: #{n} is given to #{count} items"

    above =
      for n <- numbers,
          not (is_integer(n) and n >= 0 and n < db.next_zettel),
          do: "11. zettel ids: #{inspect(n)} is not below next_zettel #{db.next_zettel}"

    twice ++ above
  end

  # --- 12. The blog's categories -------------------------------------------

  defp blog(db) do
    for id <- [db.blog.posts, db.blog.drafts, db.blog.pages],
        id != nil,
        not Map.has_key?(db.categories, id),
        do: "12. blog: category #{id} does not exist"
  end

  # --- 13. Feeds -------------------------------------------------------------

  defp feeds(db) do
    for {id, feed} <- db.feeds,
        not Map.has_key?(db.categories, feed.category_id),
        do: "13. feeds: feed #{id}'s category #{feed.category_id} does not exist"
  end
end
