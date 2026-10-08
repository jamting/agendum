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
        section -> Assign.assign(db, id, section)
      end

    {Assign.auto_assign(db, id, Keyword.get(opts, :adjacent, [])), id}
  end

  @doc "Changes an item's text and re-runs automatic assignment (it only adds assignments)."
  @spec edit_item(db, id, String.t(), [id]) :: db
  def edit_item(db, id, text, adjacent \\ []) do
    db
    |> Database.update_item(id, &%{&1 | text: String.trim(text)})
    |> Assign.auto_assign(id, adjacent)
  end

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
        db = if from == db.main_id, do: db, else: remove_from_category(db, item_id, from)
        if to == db.main_id, do: db, else: Assign.assign(db, item_id, to)
      end

    case opts[:after] do
      nil -> db
      ^item_id -> db
      after_id -> Database.reorder_item(db, item_id, after_id)
    end
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
      field -> Database.update_item(db, item_id, &Map.put(&1, field, nil))
    end
  end

  @doc "Assigns an item to a category (with mutual exclusion and category links)."
  @spec assign(db, id, id) :: db
  defdelegate assign(db, item_id, cat_id), to: Assign

  @doc """
  Toggles one explicit assignment, as in the assignment profile: an
  explicit link is removed (only that link, not the subtree); otherwise the
  item is assigned with the usual rules.
  """
  @spec toggle_assignment(db, id, id) :: db
  def toggle_assignment(db, item_id, cat_id) do
    if Database.explicit?(db, item_id, cat_id),
      do: Database.unlink(db, item_id, cat_id),
      else: Assign.assign(db, item_id, cat_id)
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
            {:ok, Database.update_item(db, item_id, &Map.put(&1, field, date)), :date}

          :error ->
            {:error, :invalid_date}
        end

      true ->
        case resolve_name(db, head_id, text) do
          {:ok, cat_id} ->
            {:ok, Assign.assign(db, item_id, cat_id), cat_id}

          :none ->
            {db, cat_id} = Database.insert_category(db, head_id, text)
            {:ok, Assign.assign(db, item_id, cat_id), cat_id}

          :ambiguous ->
            {:error, :ambiguous}
        end
    end
  end

  @doc "Sets or clears the date for a date category."
  @spec set_date(db, id, id, Date.t() | nil) :: db
  def set_date(db, item_id, cat_id, date) do
    field = Database.date_field(db, cat_id) || raise ArgumentError, "not a date category"
    Database.update_item(db, item_id, &Map.put(&1, field, date))
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
  defdelegate move_category(db, id, parent, after_id), to: Database
  defdelegate promote(db, id), to: Database
  defdelegate demote(db, id), to: Database

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
  (Agenda's F9 RECALC behaviour).
  """
  @spec reassign_all(db) :: db
  def reassign_all(db) do
    Enum.reduce(db.item_order, db, &Assign.auto_assign(&2, &1, []))
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

  @doc "Toggles a boolean view option such as `:hide_done`."
  @spec toggle_view_option(db, id, :hide_done | :hide_empty | :hide_inherited) :: db
  def toggle_view_option(db, view_id, option) do
    Database.update_view(db, view_id, &Map.update!(&1, option, fn value -> not value end))
  end
end
