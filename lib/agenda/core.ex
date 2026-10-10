defmodule Agenda.Core do
  @moduledoc """
  The functional core: user-level operations on an Agenda database.

  This is the API the TUI (and any other shell) uses. Every function is
  pure; anything that depends on the outside world, such as today's date,
  is passed in as an argument.

  Following the patent, all modification happens "through a view": adding
  an item under a section assigns it to the section's category, typing a
  name into a column assigns (or creates) a subcategory of the column head,
  and so on.
  """

  alias Agenda.Core.{Assign, Database, DateParser, View}
  alias Agenda.Core.View.{Column, Section}

  @type db :: Database.t()
  @type id :: Database.id()

  defdelegate new_file(opts \\ []), to: Database, as: :new

  # ---------------------------------------------------------------------------
  # Items
  # ---------------------------------------------------------------------------

  @doc """
  Adds an item, assigns it to `:section` (a category id) and runs automatic
  assignment.

  Options:
    * `:section` – category the item was typed under
    * `:after` – item to place the new item after
    * `:adjacent` – neighbouring item ids, nearest first, for resolving
      ambiguous automatic assignments
  """
  @spec add_item(db, String.t(), Date.t(), keyword) :: {db, id}
  def add_item(db, text, today, opts \\ []) do
    {db, id} = Database.insert_item(db, String.trim(text), today, after: opts[:after])

    db =
      case opts[:section] do
        nil -> db
        section -> user_assign(db, id, section)
      end

    db =
      db
      |> Assign.auto_assign(id, Keyword.get(opts, :adjacent, []))
      |> date_from_text(id, nil, today)
      |> Assign.apply_conditions(id)

    {db, id}
  end

  @doc """
  Changes an item's text, re-runs automatic assignment (it only adds
  assignments) and updates a When date read from the text (R14).
  """
  @spec edit_item(db, id, String.t(), Date.t(), [id]) :: db
  def edit_item(db, id, text, today, adjacent \\ []) do
    old_text = db.items[id].text

    db
    |> Database.update_item(id, &%{&1 | text: String.trim(text)})
    |> Assign.auto_assign(id, adjacent)
    |> date_from_text(id, old_text, today)
    |> Assign.apply_conditions(id)
  end

  # An assignment the user asked for: never treated as conditional (R15).
  defp user_assign(db, item_id, cat_id) do
    db |> Assign.assign(item_id, cat_id) |> Database.unmark_conditional(item_id, cat_id)
  end

  # SPEC R14: the first date in an item's text is its When date, unless the
  # user set one explicitly or turned automatic dating off. Relative dates
  # are read once: after an edit the date is only re-read when the date
  # words themselves changed (so "tomorrow" keeps meaning the day it was
  # typed). Removing the date words clears a When date they gave.
  defp date_from_text(db, id, old_text, today) do
    item = db.items[id]

    if not db.auto_date or item.when_explicit do
      db
    else
      old = if old_text, do: DateParser.extract(old_text, today), else: :none

      case {old, DateParser.extract(item.text, today)} do
        {{:ok, _, phrase}, {:ok, _, phrase}} -> db
        {_, {:ok, date, _}} -> Database.update_item(db, id, &%{&1 | when: date})
        {{:ok, _, _}, :none} -> Database.update_item(db, id, &%{&1 | when: nil})
        {:none, :none} -> db
      end
    end
  end

  @doc "Turns reading When dates from item text on or off for the file (R14)."
  @spec toggle_auto_date(db) :: db
  def toggle_auto_date(db), do: %{db | auto_date: not db.auto_date}

  @spec set_note(db, id, String.t()) :: db
  def set_note(db, id, note), do: Database.update_item(db, id, &%{&1 | note: note})

  @doc """
  Moves an item from one section's category to another (ALT-F10). The item
  leaves `from` and joins `to` (MAIN is never left or joined explicitly).
  With `after: item_id`, it is also placed after that item in item order.
  """
  @spec move_item(db, id, id, id, keyword) :: db
  def move_item(db, item_id, from, to, opts \\ []) do
    db =
      if to == from do
        db
      else
        db = if from == db.main_id, do: db, else: Assign.unassign(db, item_id, from)
        if to == db.main_id, do: db, else: user_assign(db, item_id, to)
      end

    db =
      case opts[:after] do
        nil -> db
        ^item_id -> db
        after_id -> Database.reorder_item(db, item_id, after_id)
      end

    Assign.apply_conditions(db, item_id)
  end

  @doc "Marks an item done today, or clears its done date (F4 DONE)."
  @spec toggle_done(db, id, Date.t()) :: db
  def toggle_done(db, id, today) do
    Database.update_item(db, id, fn item ->
      %{item | done: if(item.done, do: nil, else: today)}
    end)
  end

  @doc "Toggles the mark used to select several items (F7 MARK)."
  @spec toggle_mark(db, id) :: db
  def toggle_mark(db, id), do: Database.update_item(db, id, &%{&1 | marked: not &1.marked})

  @doc "Marks an item done today unless it already has a done date (bulk F4 DONE)."
  @spec mark_done(db, id, Date.t()) :: db
  def mark_done(db, id, today) do
    Database.update_item(db, id, fn item ->
      if item.done, do: item, else: %{item | done: today}
    end)
  end

  @doc "Marked items, in item order (the group bulk commands act on)."
  @spec marked_items(db) :: [id]
  def marked_items(db), do: for(item <- Database.items(db), item.marked, do: item.id)

  @doc "Marks (true) or unmarks (false) a group of items (F7 on a section head)."
  @spec set_marked(db, [id], boolean) :: db
  def set_marked(db, ids, marked),
    do: Enum.reduce(ids, db, &Database.update_item(&2, &1, fn i -> %{i | marked: marked} end))

  @doc "Unmarks every item in the file (ALT-F7 UNMKALL)."
  @spec unmark_all(db) :: db
  def unmark_all(db), do: set_marked(db, marked_items(db), false)

  @doc "Deletes an item from the whole file (ALT-F4 DISCARD)."
  @spec discard_item(db, id) :: db
  defdelegate discard_item(db, id), to: Database, as: :delete_item

  @doc """
  Removes an item from a category and its descendants (DEL on an item in a
  section, or on a column entry). For a date category, clears the date.
  """
  @spec remove_from_category(db, id, id) :: db
  def remove_from_category(db, item_id, cat_id) do
    case Database.date_field(db, cat_id) do
      nil -> Assign.unassign(db, item_id, cat_id)
      field -> put_date(db, item_id, field, nil)
    end
    |> Assign.apply_conditions(item_id)
  end

  @doc """
  Assigns an item to a category (with mutual exclusion, the
  ancestor/descendant rule and category links), then re-checks the file's
  assignment conditions for the item (R15).
  """
  @spec assign(db, id, id) :: db
  def assign(db, item_id, cat_id),
    do: db |> user_assign(item_id, cat_id) |> Assign.apply_conditions(item_id)

  @doc """
  Toggles one explicit assignment, as in the assignment profile: an
  explicit link is removed (only that link, not the subtree); otherwise the
  item is assigned with the usual rules.
  """
  @spec toggle_assignment(db, id, id) :: db
  def toggle_assignment(db, item_id, cat_id) do
    if Database.explicit?(db, item_id, cat_id),
      do: Database.unlink(db, item_id, cat_id),
      else:
        user_assign(db, item_id, cat_id)
        |> Assign.apply_conditions(item_id)
  end

  @doc """
  Handles text typed into a column cell for an item (claims 3 and 6 of the
  patent). For a date column the text is parsed as a date. Otherwise the
  text names a descendant of the column head: an exact name match is used
  first, then a unique prefix match; if nothing matches, a new child of the
  column head is created. Returns the category assigned.
  """
  @spec assign_by_name(db, id, id, String.t(), Date.t()) ::
          {:ok, db, id | :date} | {:error, :invalid_date | :ambiguous | :empty}
  def assign_by_name(db, item_id, head_id, text, today) do
    text = String.trim(text)

    cond do
      text == "" ->
        {:error, :empty}

      field = Database.date_field(db, head_id) ->
        case DateParser.parse(text, today) do
          {:ok, date} ->
            {:ok, put_date(db, item_id, field, date), :date}

          :error ->
            {:error, :invalid_date}
        end

      true ->
        case resolve_name(db, head_id, text) do
          {:ok, cat_id} ->
            {:ok, assign(db, item_id, cat_id), cat_id}

          :none ->
            {db, cat_id} = Database.insert_category(db, head_id, text)
            {:ok, assign(db, item_id, cat_id), cat_id}

          :ambiguous ->
            {:error, :ambiguous}
        end
    end
  end

  @doc "Sets or clears the date for a date category."
  @spec set_date(db, id, id, Date.t() | nil) :: db
  def set_date(db, item_id, cat_id, date) do
    field = Database.date_field(db, cat_id) || raise ArgumentError, "not a date category"
    put_date(db, item_id, field, date)
  end

  # A When date set or cleared by the user: set is explicit and overrides
  # the text; cleared hands the When date back to the text (R14).
  defp put_date(db, item_id, :when, date) do
    Database.update_item(db, item_id, &%{&1 | when: date, when_explicit: date != nil})
  end

  defp put_date(db, item_id, field, date),
    do: Database.update_item(db, item_id, &Map.put(&1, field, date))

  @doc """
  Everything an item is assigned to, in hierarchy order, as the Item
  Properties box lists it: date categories with the item's date (`:date`),
  and links the user made (`:explicit`) or a condition made
  (`:conditional`). Membership through subcategories is not listed.
  """
  @spec item_assignments(db, id) :: [
          %{category: id, kind: :date | :explicit | :conditional, date: Date.t() | nil}
        ]
  def item_assignments(db, item_id) do
    item = db.items[item_id]

    db
    |> Database.hierarchy()
    |> Enum.flat_map(fn {id, _depth} ->
      cond do
        field = Database.date_field(db, id) ->
          case Map.get(item, field) do
            nil -> []
            date -> [%{category: id, kind: :date, date: date}]
          end

        Database.explicit?(db, item_id, id) ->
          kind = if Database.conditional?(db, item_id, id), do: :conditional, else: :explicit
          [%{category: id, kind: kind, date: nil}]

        true ->
          []
      end
    end)
  end

  @doc """
  Automatic completion (R32): the subcategories of `head_id` whose names
  begin with `text`, ignoring case and accents, in hierarchy order with an
  exact name first. The first one is what Agenda shows as you type; the
  others are reached with NEXTSEL / PREVSEL.
  """
  @spec completions(db, id, String.t()) :: [id]
  def completions(db, head_id, text) do
    case fold(text) do
      "" ->
        []

      wanted ->
        matches =
          db
          |> Database.descendants(head_id)
          |> Enum.filter(&String.starts_with?(fold(db.categories[&1].name), wanted))

        {exact, prefix} = Enum.split_with(matches, &(fold(db.categories[&1].name) == wanted))
        exact ++ prefix
    end
  end

  @doc """
  Assigns an item to a new child of `head_id` named exactly `text`,
  overriding automatic completion (Agenda's NEWCAT / INS): typing "Low"
  creates Low even when Lowest exists. If a child with that name already
  exists, that one is used.
  """
  @spec assign_new_by_name(db, id, id, String.t()) :: {:ok, db, id} | {:error, :empty}
  def assign_new_by_name(db, item_id, head_id, text) do
    case add_category(db, head_id, text) do
      {:ok, db, cat_id} ->
        {:ok, assign(db, item_id, cat_id), cat_id}

      {:error, :duplicate} ->
        wanted = Database.normalize(text)

        cat_id =
          Enum.find(
            db.categories[head_id].children,
            &(Database.normalize(db.categories[&1].name) == wanted)
          )

        {:ok, assign(db, item_id, cat_id), cat_id}

      {:error, :empty} ->
        {:error, :empty}
    end
  end

  # Case- and accent-insensitive form used for completion ("éc" ~ "ec").
  defp fold(text) do
    text
    |> String.trim()
    |> :unicode.characters_to_nfd_binary()
    |> String.replace(~r/\p{Mn}/u, "")
    |> String.downcase()
  end

  # Exact (case-insensitive) match among descendants of `root`, else a
  # unique prefix match.
  defp resolve_name(db, root, text) do
    wanted = Database.normalize(text)
    candidates = Database.descendants(db, root)

    case Database.find_categories(db, text, root) -- [root] do
      [id | _] ->
        {:ok, id}

      [] ->
        prefixed =
          Enum.filter(
            candidates,
            &String.starts_with?(Database.normalize(db.categories[&1].name), wanted)
          )

        case prefixed do
          [] -> :none
          [id] -> {:ok, id}
          _ -> :ambiguous
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Categories
  # ---------------------------------------------------------------------------

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
  # --- moving categories (SPEC R7b, R7c, R7d) ---

  @typedoc "A change to a category's place in the hierarchy."
  @type relocation :: :promote | :demote | {:move, id, id | :first | nil}

  @typedoc "How items that a move puts in conflict are resolved."
  @type move_resolution :: :remove_moved | :remove_other | {:new_category, String.t()}

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
  @spec relocate(db, id, relocation, move_resolution) :: {:ok, db} | {:error, atom}
  def relocate(db, id, relocation, resolution \\ :remove_moved) do
    with {:ok, moved_db} <- do_relocate(db, id, relocation) do
      original = MapSet.new(Database.subtree(db, id))
      resolve_move(moved_db, id, original, Assign.placement_conflicts(moved_db, id), resolution)
    end
  end

  defp do_relocate(db, id, :promote), do: Database.promote(db, id)
  defp do_relocate(db, id, :demote), do: Database.demote(db, id)

  defp do_relocate(db, id, {:move, parent, after_id}),
    do: Database.move_category(db, id, parent, after_id)

  defp resolve_move(db, _id, _original, [], _resolution), do: {:ok, db}

  defp resolve_move(db, id, original, items, {:new_category, name}) do
    family = Assign.conflicting_family(db, id, items)

    with {:ok, db, target} <- add_category(db, family, name) do
      {:ok,
       Enum.reduce(items, db, &Assign.resolve_placement(&2, original, &1, {:category, target}))}
    end
  end

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

  @doc "Adds `target` to a category's `also_assign` links, or removes it if present."
  @spec toggle_also_assign(db, id, id) :: db
  def toggle_also_assign(db, cat_id, target) do
    Database.update_category(db, cat_id, fn c ->
      if target in c.also_assign,
        do: %{c | also_assign: List.delete(c.also_assign, target)},
        else: %{c | also_assign: c.also_assign ++ [target]}
    end)
  end

  @doc """
  Re-runs automatic assignment for every item, e.g. after adding a category
  (Agenda's F9 RECALC behaviour), and gives a When date to items whose text
  has a date but that have none yet.
  """
  @spec reassign_all(db, Date.t()) :: db
  def reassign_all(db, today) do
    Enum.reduce(db.item_order, db, fn id, db ->
      db = Assign.auto_assign(db, id, [])
      db = if db.items[id].when, do: db, else: date_from_text(db, id, nil, today)
      Assign.apply_conditions(db, id)
    end)
  end

  # --- assignment conditions (R15) ---

  @doc """
  Adds an assignment condition to a category: items `:assigned` (or
  `:not_assigned`) to `target` are assigned to it. Like Agenda, a new
  condition applies to items as they are added or changed; Recalc
  (`reassign_all/2`) applies it to all existing items.
  """
  @spec add_condition(db, id, id, :assigned | :not_assigned) ::
          {:ok, db} | {:error, :self | :duplicate}
  def add_condition(db, cat_id, target, kind) when kind in [:assigned, :not_assigned] do
    cond do
      cat_id == target ->
        {:error, :self}

      List.keymember?(db.categories[cat_id].conditions, target, 0) ->
        {:error, :duplicate}

      true ->
        {:ok,
         Database.update_category(
           db,
           cat_id,
           &%{&1 | conditions: &1.conditions ++ [{target, kind}]}
         )}
    end
  end

  @spec remove_condition(db, id, id) :: db
  def remove_condition(db, cat_id, target) do
    Database.update_category(
      db,
      cat_id,
      &%{&1 | conditions: List.keydelete(&1.conditions, target, 0)}
    )
  end

  @doc """
  Cycles the condition on `target` the way the category properties box
  does: none → assigned → not assigned → none.
  """
  @spec cycle_condition(db, id, id) :: {:ok, db} | {:error, :self}
  def cycle_condition(db, cat_id, target) do
    case List.keyfind(db.categories[cat_id].conditions, target, 0) do
      nil ->
        add_condition(db, cat_id, target, :assigned)

      {_, :assigned} ->
        {:ok,
         Database.update_category(
           db,
           cat_id,
           &%{&1 | conditions: List.keyreplace(&1.conditions, target, 0, {target, :not_assigned})}
         )}

      {_, :not_assigned} ->
        {:ok, remove_condition(db, cat_id, target)}
    end
  end

  # ---------------------------------------------------------------------------
  # Views
  # ---------------------------------------------------------------------------

  @spec add_view(db, String.t(), [id]) :: {db, id}
  def add_view(db, name, section_ids),
    do: Database.insert_view(db, String.trim(name), sections: section_ids)

  @spec rename_view(db, id, String.t()) :: db
  def rename_view(db, view_id, name),
    do: Database.update_view(db, view_id, &%{&1 | name: String.trim(name)})

  defdelegate discard_view(db, view_id), to: Database, as: :delete_view

  @doc "Moves a view to position `index` in the view manager (clamped)."
  @spec move_view(db, id, integer) :: db
  def move_view(db, view_id, index) do
    rest = List.delete(db.view_order, view_id)
    index = index |> max(0) |> min(length(rest))
    %{db | view_order: List.insert_at(rest, index, view_id)}
  end

  @doc "Changes the category heading the section at `index`."
  @spec set_section_category(db, id, non_neg_integer, id) :: db
  def set_section_category(db, view_id, index, cat_id) do
    Database.update_view(db, view_id, fn v ->
      %{v | sections: List.update_at(v.sections, index, &%{&1 | category_id: cat_id})}
    end)
  end

  @doc "Inserts a section headed by `cat_id` at `index` in the view."
  @spec add_section(db, id, id, non_neg_integer) :: db
  def add_section(db, view_id, cat_id, index) do
    Database.update_view(db, view_id, fn %View{} = v ->
      %{v | sections: List.insert_at(v.sections, index, %Section{category_id: cat_id})}
    end)
  end

  @spec remove_section(db, id, non_neg_integer) :: db
  def remove_section(db, view_id, index) do
    Database.update_view(db, view_id, &%{&1 | sections: List.delete_at(&1.sections, index)})
  end

  @doc "Collapses (true) or expands (false) the section at `index`."
  @spec set_section_collapsed(db, id, non_neg_integer, boolean) :: db
  def set_section_collapsed(db, view_id, index, collapsed) do
    Database.update_view(db, view_id, fn v ->
      %{v | sections: List.update_at(v.sections, index, &%{&1 | collapsed: collapsed})}
    end)
  end

  @doc "Collapses or expands every section of a view."
  @spec set_all_sections_collapsed(db, id, boolean) :: db
  def set_all_sections_collapsed(db, view_id, collapsed) do
    Database.update_view(db, view_id, fn v ->
      %{v | sections: Enum.map(v.sections, &%{&1 | collapsed: collapsed})}
    end)
  end

  @spec toggle_section_collapsed(db, id, non_neg_integer) :: db
  def toggle_section_collapsed(db, view_id, index) do
    Database.update_view(db, view_id, fn v ->
      %{v | sections: List.update_at(v.sections, index, &%{&1 | collapsed: not &1.collapsed})}
    end)
  end

  @doc "Inserts a column headed by `cat_id` at `index` in the view."
  @spec add_column(db, id, id, non_neg_integer, pos_integer) :: db
  def add_column(db, view_id, cat_id, index, width \\ 12) do
    Database.update_view(db, view_id, fn v ->
      %{v | columns: List.insert_at(v.columns, index, %Column{category_id: cat_id, width: width})}
    end)
  end

  @spec remove_column(db, id, non_neg_integer) :: db
  def remove_column(db, view_id, index) do
    Database.update_view(db, view_id, &%{&1 | columns: List.delete_at(&1.columns, index)})
  end

  @spec resize_column(db, id, non_neg_integer, integer) :: db
  def resize_column(db, view_id, index, delta) do
    Database.update_view(db, view_id, fn v ->
      %{v | columns: List.update_at(v.columns, index, &%{&1 | width: max(3, &1.width + delta)})}
    end)
  end

  # --- filters (R28) and sorting (R36) ---

  @doc """
  Cycles the filter on `cat_id` for a view (`:view`) or one of its sections
  (`{:section, index}`): none → assigned → not assigned → none. A filtered
  view shows only items meeting all its criteria (mutually exclusive
  categories count as alternatives).
  """
  @spec cycle_filter(db, id, :view | {:section, non_neg_integer}, id) :: {:ok, db}
  def cycle_filter(db, view_id, scope, cat_id) do
    filter = get_scoped(db, view_id, scope, :filter)

    filter =
      case List.keyfind(filter, cat_id, 0) do
        nil -> filter ++ [{cat_id, :assigned}]
        {_, :assigned} -> List.keyreplace(filter, cat_id, 0, {cat_id, :not_assigned})
        {_, :not_assigned} -> List.keydelete(filter, cat_id, 0)
      end

    {:ok, put_scoped(db, view_id, scope, :filter, filter)}
  end

  @doc """
  Sets the sort keys (`[View.SortKey.t()]`, at most two are used) for a view
  or a section; a section's `nil` means "as the view".
  """
  @spec set_sort(db, id, :view | {:section, non_neg_integer}, [View.SortKey.t()] | nil) :: db
  def set_sort(db, view_id, scope, keys),
    do: put_scoped(db, view_id, scope, :sort, keys && Enum.take(keys, 2))

  @doc """
  The categories a new item typed into section `index` must have to pass
  the view's and the section's filters (User's Guide 11-4). Of mutually
  exclusive alternatives, the first is used.
  """
  @spec entry_categories(db, id, non_neg_integer) :: [id]
  def entry_categories(db, view_id, index) do
    view = Database.view(db, view_id)
    section = Enum.at(view.sections, index)

    (view.filter ++ section.filter)
    |> Enum.filter(&(elem(&1, 1) == :assigned))
    |> Enum.map(&elem(&1, 0))
    |> Enum.reduce([], fn cat, chosen ->
      if Enum.any?(chosen, &Assign.conflict?(db, cat, &1)), do: chosen, else: chosen ++ [cat]
    end)
  end

  @doc "Sorts a category's children alphabetically (ALT-F5 in the category manager)."
  @spec sort_children(db, id) :: db
  def sort_children(db, parent_id) do
    Database.update_category(db, parent_id, fn c ->
      %{c | children: Enum.sort_by(c.children, &String.downcase(db.categories[&1].name))}
    end)
  end

  @doc "Sorts the views alphabetically (ALT-F5 in the view manager)."
  @spec sort_views(db) :: db
  def sort_views(db),
    do: %{db | view_order: Enum.sort_by(db.view_order, &String.downcase(db.views[&1].name))}

  defp get_scoped(db, view_id, :view, field), do: Map.fetch!(Database.view(db, view_id), field)

  defp get_scoped(db, view_id, {:section, index}, field),
    do:
      db |> Database.view(view_id) |> Map.fetch!(:sections) |> Enum.at(index) |> Map.fetch!(field)

  defp put_scoped(db, view_id, :view, field, value),
    do: Database.update_view(db, view_id, &Map.put(&1, field, value))

  defp put_scoped(db, view_id, {:section, index}, field, value) do
    Database.update_view(db, view_id, fn v ->
      %{v | sections: List.update_at(v.sections, index, &Map.put(&1, field, value))}
    end)
  end

  @doc "Toggles a boolean view option such as `:hide_done`."
  @spec toggle_view_option(db, id, :hide_done | :hide_empty | :hide_inherited) :: db
  def toggle_view_option(db, view_id, option) do
    Database.update_view(db, view_id, &Map.update!(&1, option, fn value -> not value end))
  end
end
