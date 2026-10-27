defmodule Agendum.Core.Facade.Categories do
  @moduledoc """
  Categories (R2, R7–R9): adding, finding and renaming categories, moving
  them in the hierarchy (R7b, R7c, R7d), mutually exclusive children (R7a),
  their properties, negative links (R9) and category links (R8), and
  sorting children.

  Called through `Agendum.Core`.
  """

  alias Agendum.Core.{Assign, Database}

  @typep db :: Agendum.Core.db()
  @typep id :: Agendum.Core.id()
  @typep relocation :: Agendum.Core.relocation()
  @typep move_resolution :: Agendum.Core.move_resolution()

  @doc """
  A category named `name` (case and surrounding spaces aside), or a new
  one under MAIN when none is, as typing a column head does (User's Guide
  3-17: "the name of a new or existing category"). A name more than one
  category has is `{:error, :ambiguous}` (names are unique only among
  siblings): the picker chooses among them.
  """
  @spec find_or_add_category(db, String.t()) ::
          {:ok, db, id} | {:error, :ambiguous | :empty}
  def find_or_add_category(db, name) do
    wanted = name |> String.trim() |> String.downcase()

    found =
      for {id, cat} <- db.categories, String.downcase(cat.name) == wanted, do: id

    case found do
      _ when wanted == "" -> {:error, :empty}
      [id] -> {:ok, db, id}
      [] -> add_category(db, db.main_id, String.trim(name))
      _several -> {:error, :ambiguous}
    end
  end

  @doc """
  Adds a category under `parent_id`. Names must be unique among siblings.
  Accepts the same options as `Database.insert_category/4`.
  """
  @spec add_category(db, id, String.t(), keyword) :: {:ok, db, id} | {:error, :duplicate | :empty}
  def add_category(db, parent_id, name, opts \\ []) do
    name = String.trim(name)
    siblings = db.categories[parent_id].children
    wanted = Database.normalize(name)

    cond do
      name == "" ->
        {:error, :empty}

      Enum.any?(siblings, &(Database.normalize(db.categories[&1].name) == wanted)) ->
        {:error, :duplicate}

      true ->
        {db, id} = Database.insert_category(db, parent_id, name, opts)
        {:ok, db, id}
    end
  end

  @doc """
  Adds a category as the person inserts one: in the category manager, or
  as a new name typed in a column (User's Guide 16-11, R42). It is
  `add_category/4`, and each view whose sections hold all the other
  children of `parent_id` gets a section for it as well
  (`Agendum.Core.Facade.Views.add_family_sections/2`). As in Agenda, the
  Category Add box and moving a category into the family do not (they
  use `add_category/4` and `relocate`).
  """
  @spec insert_category(db, id, String.t(), keyword) ::
          {:ok, db, id} | {:error, :duplicate | :empty}
  def insert_category(db, parent_id, name, opts \\ []) do
    # `with` runs the step and goes on only when it matches; an
    # `{:error, _}` from `add_category/4` falls through as it is
    with {:ok, db, id} <- add_category(db, parent_id, name, opts),
         do: {:ok, Agendum.Core.Facade.Views.add_family_sections(db, id), id}
  end

  @doc "Finds a category anywhere by name, or creates it under MAIN."
  @spec find_or_create_category(db, String.t()) :: {db, id}
  def find_or_create_category(db, name) do
    case Database.find_categories(db, name) do
      [id | _] -> {db, id}
      [] -> Database.insert_category(db, db.main_id, String.trim(name))
    end
  end

  @spec rename_category(db, id, String.t()) :: {:ok, db} | {:error, :empty | :protected}
  def rename_category(db, id, name) do
    name = String.trim(name)

    cond do
      name == "" -> {:error, :empty}
      Database.protected?(db, id) -> {:error, :protected}
      true -> {:ok, Database.rename_category(db, id, name)}
    end
  end

  defdelegate discard_category(db, id), to: Database, as: :delete_category

  @doc """
  The child of `parent` with that name (case and accents aside), or a new
  one without name matching: where an extra keeps its categories (a feed's
  under Feeds, a calendar's under Calendars; R75a).
  """
  @spec child_named(db, id, String.t()) :: {db, id}
  def child_named(db, parent, name) do
    wanted = Database.normalize(name)

    case Enum.find(
           db.categories[parent].children,
           &(Database.normalize(db.categories[&1].name) == wanted)
         ) do
      nil ->
        {:ok, db, id} = add_category(db, parent, name, match_name: false)
        {db, id}

      id ->
        {db, id}
    end
  end

  # --- moving categories (SPEC R7b, R7c, R7d) ---

  @doc """
  Items that a relocation would put in conflict with the assignment rules
  (an exclusive family twice, R7b; a category and its ancestor, R7c).
  Returns the relocation's error if it is invalid.
  """
  @spec relocation_conflicts(db, id, relocation) :: {:ok, [id]} | {:error, atom}
  def relocation_conflicts(db, id, relocation) do
    with {:ok, moved} <- do_relocate(db, id, relocation) do
      {:ok, Assign.placement_conflicts(moved, id)}
    end
  end

  @doc """
  Promotes, demotes or moves a category, resolving the items this puts in
  conflict, as Agenda 2.0 does:

    * `:remove_moved` (default) – the items keep their other assignments and
      lose the conflicting ones in the moved category
    * `:remove_other` – they keep the moved category's assignments and lose
      the other, conflicting ones
    * `{:new_category, name}` – create `name` under the category the
      conflict hinges on and move the items there (only when there are
      conflicts)
  """
  # Domain: membership is inherited (an item in Europe is in Sales too), so
  # moving a category moves its items with it, and that can break the rules
  # (R7b, R7c). E.g. with an exclusive Priority (High | Low), moving
  # Urgent (a category of its own) under High puts items that were in
  # both Urgent and Low into High and Low at once. The move is done first, on a copy; the items it
  # put in conflict are found by comparing with the category's `original`
  # subtree, and the user's chosen resolution decides which assignment goes.
  @spec relocate(db, id, relocation, move_resolution) :: {:ok, db} | {:error, atom}
  def relocate(db, id, relocation, resolution \\ :remove_moved) do
    with {:ok, moved_db} <- do_relocate(db, id, relocation) do
      original = MapSet.new(Database.subtree(db, id))
      resolve_move(moved_db, id, original, Assign.placement_conflicts(moved_db, id), resolution)
    end
  end

  # A move may not put a category under one it excludes (R9).
  defp do_relocate(db, id, relocation) do
    with {:ok, moved} <- move(db, id, relocation) do
      if Assign.excluded_lineage?(moved), do: {:error, :excluded_lineage}, else: {:ok, moved}
    end
  end

  # The relocation is a tagged value (`:promote`, `:demote` or
  # `{:move, parent, after_id}`): one clause per shape, the way Elixir does
  # what other languages do with a sum type or a small class hierarchy.
  defp move(db, id, :promote), do: Database.promote(db, id)
  defp move(db, id, :demote), do: Database.demote(db, id)

  defp move(db, id, {:move, parent, after_id}),
    do: Database.move_category(db, id, parent, after_id)

  # `[]` in the head: no conflicting items, nothing to resolve.
  defp resolve_move(db, _id, _original, [], _resolution), do: {:ok, db}

  defp resolve_move(db, id, original, items, {:new_category, name}) do
    family = Assign.conflicting_family(db, id, items)

    with {:ok, db, target} <- add_category(db, family, name) do
      {:ok,
       Enum.reduce(items, db, &Assign.resolve_placement(&2, original, &1, {:category, target}))}
    end
  end

  # A guard (`when ...`) adds a condition to a clause. Only a few
  # side-effect-free expressions are allowed in guards (comparisons, `in`
  # with a literal list, `is_integer/1` …), so they stay cheap and safe.
  defp resolve_move(db, _id, original, items, rule) when rule in [:remove_moved, :remove_other] do
    {:ok, Enum.reduce(items, db, &Assign.resolve_placement(&2, original, &1, rule))}
  end

  @doc "Moves a category under `parent` (ALT-F10); see `relocate/4`."
  @spec move_category(db, id, id, id | :first | nil, move_resolution) ::
          {:ok, db} | {:error, atom}
  def move_category(db, id, parent, after_id, resolution \\ :remove_moved),
    do: relocate(db, id, {:move, parent, after_id}, resolution)

  @doc "Moves a category up one level, adopting its following siblings (F7, R7d); see `relocate/4`."
  @spec promote(db, id, move_resolution) :: {:ok, db} | {:error, atom}
  def promote(db, id, resolution \\ :remove_moved), do: relocate(db, id, :promote, resolution)

  @doc "Moves a category down one level, under its previous sibling (F8); see `relocate/4`."
  @spec demote(db, id, move_resolution) :: {:ok, db} | {:error, atom}
  def demote(db, id, resolution \\ :remove_moved), do: relocate(db, id, :demote, resolution)

  @spec move_conflicts(db, id, id, id | :first | nil) :: {:ok, [id]} | {:error, atom}
  def move_conflicts(db, id, parent, after_id),
    do: relocation_conflicts(db, id, {:move, parent, after_id})

  @spec promote_conflicts(db, id) :: {:ok, [id]} | {:error, atom}
  def promote_conflicts(db, id), do: relocation_conflicts(db, id, :promote)

  @spec demote_conflicts(db, id) :: {:ok, [id]} | {:error, atom}
  def demote_conflicts(db, id), do: relocation_conflicts(db, id, :demote)

  @doc "Items assigned to more than one child of `id` (see `make_exclusive/3`)."
  @spec exclusive_conflicts(db, id) :: [id]
  defdelegate exclusive_conflicts(db, id), to: Assign

  @doc """
  Makes the children of a category mutually exclusive (SPEC R7a). Items
  already assigned to several children are resolved first, as in Agenda
  2.0's "Assign conflicting item(s) to" box:

    * `:parent` (default) – assign them to the category itself instead
    * `:first_child` – keep the child closest to the top of the family
    * `{:new_child, name}` – create a new child and assign them to it
      (only created when there are conflicts)
  """
  @spec make_exclusive(db, id, :parent | :first_child | {:new_child, String.t()}) ::
          {:ok, db} | {:error, :protected | :empty | :duplicate}
  def make_exclusive(db, id, resolution \\ :parent) do
    conflicts = Assign.exclusive_conflicts(db, id)

    # A `with` step can be any expression: here a plain check written as
    # `:ok` or an error, so it chains like the steps that return data.
    with :ok <- if(Database.protected?(db, id), do: {:error, :protected}, else: :ok),
         {:ok, db, rule} <- exclusive_rule(db, id, resolution, conflicts) do
      db = Enum.reduce(conflicts, db, &Assign.resolve_exclusive(&2, id, &1, rule))
      {:ok, Database.update_category(db, id, &%{&1 | exclusive: true})}
    end
  end

  defp exclusive_rule(db, _id, _resolution, []), do: {:ok, db, :parent}

  defp exclusive_rule(db, id, {:new_child, name}, _conflicts) do
    with {:ok, db, child} <- add_category(db, id, name), do: {:ok, db, {:category, child}}
  end

  defp exclusive_rule(db, _id, rule, _conflicts) when rule in [:parent, :first_child],
    do: {:ok, db, rule}

  @doc "Lets the children of a category be combined again. Assignments are kept."
  @spec make_unexclusive(db, id) :: db
  def make_unexclusive(db, id), do: Database.update_category(db, id, &%{&1 | exclusive: false})

  @doc "Toggles whether a category takes part in automatic assignment."
  @spec toggle_match_name(db, id) :: db
  def toggle_match_name(db, id),
    do: Database.update_category(db, id, &%{&1 | match_name: not &1.match_name})

  @doc "Sets a category's short name (an alias for matching); blank clears it."
  @spec set_short_name(db, id, String.t()) :: db
  def set_short_name(db, id, text) do
    short = if String.trim(text) == "", do: nil, else: String.trim(text)
    Database.update_category(db, id, &%{&1 | short_name: short})
  end

  @spec set_category_note(db, id, String.t()) :: db
  def set_category_note(db, id, note), do: Database.update_category(db, id, &%{&1 | note: note})

  @doc """
  Adds a negative link between two categories, or removes it if there is
  one (R9; not in Agenda 2.0): no item may then be in both, or in their
  subcategories. Refused for a category and itself (`:self`), its
  ancestors or descendants (`:lineage`), MAIN and date categories
  (`:not_allowed`), and while items are in both (`{:shared, items}`).
  """
  @spec toggle_exclude(db, id, id) ::
          {:ok, db} | {:error, :self | :lineage | :not_allowed | {:shared, [id]}}
  def toggle_exclude(db, a, b) do
    linked? = b in db.categories[a].excludes

    shared =
      Enum.filter(db.item_order, &(Database.member?(db, &1, a) and Database.member?(db, &1, b)))

    cond do
      a == b ->
        {:error, :self}

      linked? ->
        # Functions are values: the same `set_exclude/4` adds or removes,
        # depending on the function passed in (`&List.delete/2` or the
        # append below).
        {:ok, set_exclude(db, a, b, &List.delete/2)}

      Enum.any?([a, b], &(&1 == db.main_id or db.categories[&1].kind != :standard)) ->
        {:error, :not_allowed}

      a in Database.ancestors(db, b) or b in Database.ancestors(db, a) ->
        {:error, :lineage}

      shared != [] ->
        {:error, {:shared, shared}}

      true ->
        {:ok, set_exclude(db, a, b, &(&1 ++ [&2]))}
    end
  end

  defp set_exclude(db, a, b, change) do
    db
    |> Database.update_category(a, &%{&1 | excludes: change.(&1.excludes, b)})
    |> Database.update_category(b, &%{&1 | excludes: change.(&1.excludes, a)})
  end

  @doc "Adds `target` to a category's `also_assign` links, or removes it if present."
  @spec toggle_also_assign(db, id, id) :: db
  def toggle_also_assign(db, cat_id, target) do
    Database.update_category(db, cat_id, fn c ->
      if target in c.also_assign,
        do: %{c | also_assign: List.delete(c.also_assign, target)},
        else: %{c | also_assign: c.also_assign ++ [target]}
    end)
  end

  @doc "Sorts a category's children alphabetically (ALT-F5 in the category manager)."
  @spec sort_children(db, id) :: db
  def sort_children(db, parent_id) do
    Database.update_category(db, parent_id, fn c ->
      %{c | children: Enum.sort_by(c.children, &String.downcase(db.categories[&1].name))}
    end)
  end
end
