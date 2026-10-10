defmodule Agenda.Core.Database do
  @moduledoc """
  The complete state of one Agenda file, as an immutable value.

  Objects (items, categories, views) share a single id space, mirroring the
  single object file (`.AGA`) described in the patent. Item/category
  assignments are stored as independent links (`Agenda.Core.Links`), which
  mirror the link-structure file (`.AGB`).

  This module provides primitive operations and queries. Assignment rules
  (subsumption, mutual exclusion, automatic assignment) live in
  `Agenda.Core.Assign`; user-level operations are in `Agenda.Core`.

  Every function is pure: it takes a database and returns a new one.
  """

  alias Agenda.Core.{Category, DateFormat, Item, Links, View}
  alias Agenda.Core.View.{Column, Section}

  @type id :: pos_integer
  @type t :: %__MODULE__{
          items: %{optional(id) => Item.t()},
          item_order: [id],
          categories: %{optional(id) => Category.t()},
          views: %{optional(id) => View.t()},
          view_order: [id],
          links: Links.t(),
          next_id: id,
          main_id: id,
          special: %{entry: id, when: id, done: id},
          auto_date: boolean,
          conditional: MapSet.t({id, id}),
          date_format: DateFormat.t()
        }

  defstruct items: %{},
            item_order: [],
            categories: %{},
            views: %{},
            view_order: [],
            links: Links.new(),
            next_id: 1,
            main_id: nil,
            special: %{},
            auto_date: true,
            conditional: MapSet.new(),
            date_format: %DateFormat{}

  @date_fields %{entry: :entry, when: :when, done: :done}

  # ---------------------------------------------------------------------------
  # Construction
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new, empty file: the MAIN category with the Entry, When and Done
  date categories, an "Initial Section" category, and an "Initial View" that
  shows it with a When column.
  """
  @spec new(keyword) :: t
  def new(opts \\ []) do
    view_name = Keyword.get(opts, :view_name, "Initial View")
    section_name = Keyword.get(opts, :section_name, "Initial Section")

    db = %__MODULE__{}
    {db, main} = put_new_category(db, %Category{name: "MAIN", match_name: false})
    db = %{db | main_id: main}

    {db, entry} = insert_category(db, main, "Entry", kind: :date, match_name: false)
    {db, when_id} = insert_category(db, main, "When", kind: :date, match_name: false)
    {db, done} = insert_category(db, main, "Done", kind: :date, match_name: false)
    db = %{db | special: %{entry: entry, when: when_id, done: done}}

    {db, section} = insert_category(db, main, section_name, match_name: false)

    {db, _view} =
      insert_view(db, view_name,
        sections: [section],
        columns: [%Column{category_id: when_id, width: 16}]
      )

    db
  end

  # ---------------------------------------------------------------------------
  # Items
  # ---------------------------------------------------------------------------

  @spec item(t, id) :: Item.t() | nil
  def item(%__MODULE__{items: items}, id), do: Map.get(items, id)

  @doc "All items in entry order."
  @spec items(t) :: [Item.t()]
  def items(%__MODULE__{} = db), do: Enum.map(db.item_order, &db.items[&1])

  @doc """
  Inserts a new item and returns `{db, id}`.

  Options: `:after` places the item directly after the given item in the
  global item order (which is the order items appear in sections).
  """
  @spec insert_item(t, String.t(), Date.t(), keyword) :: {t, id}
  def insert_item(%__MODULE__{} = db, text, %Date{} = today, opts \\ []) do
    {db, id} = take_id(db)
    item = %Item{id: id, text: text, entry: today}
    order = insert_after(db.item_order, id, Keyword.get(opts, :after))
    {%{db | items: Map.put(db.items, id, item), item_order: order}, id}
  end

  @spec update_item(t, id, (Item.t() -> Item.t())) :: t
  def update_item(%__MODULE__{} = db, id, fun) do
    %{db | items: Map.update!(db.items, id, fun)}
  end

  @doc "Removes an item from the file entirely (Agenda's DISCARD)."
  @spec delete_item(t, id) :: t
  def delete_item(%__MODULE__{} = db, id) do
    %{
      db
      | items: Map.delete(db.items, id),
        item_order: List.delete(db.item_order, id),
        links: Links.drop_left(db.links, id),
        conditional: MapSet.reject(db.conditional, &(elem(&1, 0) == id))
    }
  end

  @doc "Moves an item to directly after `after_id` (or first, if nil)."
  @spec reorder_item(t, id, id | nil) :: t
  def reorder_item(%__MODULE__{} = db, id, after_id) do
    order = db.item_order |> List.delete(id) |> insert_after(id, after_id)
    %{db | item_order: order}
  end

  # ---------------------------------------------------------------------------
  # Categories and the hierarchy
  # ---------------------------------------------------------------------------

  @spec category(t, id) :: Category.t() | nil
  def category(%__MODULE__{categories: cats}, id), do: Map.get(cats, id)

  @spec main(t) :: Category.t()
  def main(%__MODULE__{} = db), do: db.categories[db.main_id]

  @doc """
  Inserts a category under `parent_id` and returns `{db, id}`.

  Options: `:after` (a sibling id to insert after; `:first` to insert first),
  `:kind`, `:exclusive`, `:match_name`, `:short_name`.
  """
  @spec insert_category(t, id, String.t(), keyword) :: {t, id}
  def insert_category(%__MODULE__{} = db, parent_id, name, opts \\ []) do
    fields = Keyword.take(opts, [:kind, :exclusive, :match_name, :short_name])
    category = struct!(Category, [name: name, parent_id: parent_id] ++ fields)
    {db, id} = put_new_category(db, category)
    {attach_child(db, parent_id, id, Keyword.get(opts, :after)), id}
  end

  @spec update_category(t, id, (Category.t() -> Category.t())) :: t
  def update_category(%__MODULE__{} = db, id, fun) do
    %{db | categories: Map.update!(db.categories, id, fun)}
  end

  @spec rename_category(t, id, String.t()) :: t
  def rename_category(db, id, name), do: update_category(db, id, &%{&1 | name: name})

  @doc "True for MAIN and the Entry/When/Done date categories."
  @spec protected?(t, id) :: boolean
  def protected?(%__MODULE__{} = db, id) do
    id == db.main_id or id in Map.values(db.special)
  end

  @doc """
  Deletes a category together with all its descendants. Links to the
  deleted categories are dropped, which automatically removes items from
  any parent categories they belonged to only by subsumption (the side
  effect the patent describes for deleting C5).
  """
  @spec delete_category(t, id) :: {:ok, t} | {:error, :protected}
  def delete_category(%__MODULE__{} = db, id) do
    if protected?(db, id) do
      {:error, :protected}
    else
      doomed = subtree(db, id)
      doomed_set = MapSet.new(doomed)
      parent = db.categories[id].parent_id

      db = detach_child(db, parent, id)
      links = Enum.reduce(doomed, db.links, &Links.drop_right(&2, &1))
      conditional = MapSet.reject(db.conditional, &(elem(&1, 1) in doomed_set))

      categories =
        db.categories
        |> Map.drop(doomed)
        |> Map.new(fn {cid, c} ->
          {cid,
           %{
             c
             | also_assign: Enum.reject(c.also_assign, &(&1 in doomed_set)),
               conditions: Enum.reject(c.conditions, &(elem(&1, 0) in doomed_set))
           }}
        end)

      views =
        Map.new(db.views, fn {vid, v} ->
          {vid,
           %{
             v
             | sections:
                 v.sections
                 |> Enum.reject(&(&1.category_id in doomed_set))
                 |> Enum.map(
                   &%{
                     &1
                     | filter: drop_filters(&1.filter, doomed_set),
                       sort: drop_keys(&1.sort, doomed_set)
                   }
                 ),
               columns: Enum.reject(v.columns, &(&1.category_id in doomed_set)),
               filter: drop_filters(v.filter, doomed_set),
               sort: drop_keys(v.sort, doomed_set)
           }}
        end)

      {:ok, %{db | links: links, conditional: conditional, categories: categories, views: views}}
    end
  end

  @doc """
  Moves a category to become a child of `new_parent`, after sibling
  `after_id` (`nil` appends, `:first` prepends). Refuses to create cycles.
  """
  @spec move_category(t, id, id, id | :first | nil) :: {:ok, t} | {:error, atom}
  def move_category(%__MODULE__{} = db, id, new_parent, after_id \\ nil) do
    cond do
      protected?(db, id) ->
        {:error, :protected}

      new_parent == id or new_parent in descendants(db, id) ->
        {:error, :cycle}

      true ->
        {:ok,
         db
         |> detach_child(db.categories[id].parent_id, id)
         |> attach_child(new_parent, id, after_id)}
    end
  end

  @doc """
  Moves a category up one level, right after its old parent. Its following
  siblings become its children (after its own), as in an outline (R7d).
  """
  @spec promote(t, id) :: {:ok, t} | {:error, atom}
  def promote(%__MODULE__{} = db, id) do
    with {:ok, parent, after_id} <- promote_target(db, id) do
      # Outline-style (SPEC R7d): the following siblings become children of
      # the promoted category, after its own, so the outline order holds.
      followers = db.categories[after_id].children |> Enum.drop_while(&(&1 != id)) |> tl()

      with {:ok, db} <- move_category(db, id, parent, after_id) do
        {:ok, Enum.reduce(followers, db, &adopt(&2, &1, id))}
      end
    end
  end

  defp adopt(db, child, new_parent) do
    db
    |> detach_child(db.categories[child].parent_id, child)
    |> attach_child(new_parent, child, nil)
  end

  @doc "Where `promote/2` would move a category: `{:ok, new_parent, after_id}`."
  @spec promote_target(t, id) :: {:ok, id, id} | {:error, :top_level}
  def promote_target(%__MODULE__{} = db, id) do
    with parent when parent != nil <- db.categories[id].parent_id,
         grandparent when grandparent != nil <- db.categories[parent].parent_id do
      {:ok, grandparent, parent}
    else
      nil -> {:error, :top_level}
    end
  end

  @doc "Moves a category down one level, making it the last child of its previous sibling."
  @spec demote(t, id) :: {:ok, t} | {:error, atom}
  def demote(%__MODULE__{} = db, id) do
    with {:ok, parent, after_id} <- demote_target(db, id),
         do: move_category(db, id, parent, after_id)
  end

  @doc "Where `demote/2` would move a category: `{:ok, new_parent, nil}` (appended)."
  @spec demote_target(t, id) :: {:ok, id, nil} | {:error, :no_previous_sibling}
  def demote_target(%__MODULE__{} = db, id) do
    case previous_sibling(db, id) do
      nil -> {:error, :no_previous_sibling}
      sibling -> {:ok, sibling, nil}
    end
  end

  @spec previous_sibling(t, id) :: id | nil
  def previous_sibling(db, id), do: sibling_at(db, id, -1)

  @spec next_sibling(t, id) :: id | nil
  def next_sibling(db, id), do: sibling_at(db, id, 1)

  @doc "Ancestors of a category, nearest first (excluding itself)."
  @spec ancestors(t, id) :: [id]
  def ancestors(%__MODULE__{} = db, id) do
    case db.categories[id].parent_id do
      nil -> []
      parent -> [parent | ancestors(db, parent)]
    end
  end

  @doc "All descendants of a category in pre-order (excluding itself)."
  @spec descendants(t, id) :: [id]
  def descendants(%__MODULE__{} = db, id) do
    Enum.flat_map(db.categories[id].children, &[&1 | descendants(db, &1)])
  end

  @doc "The category and all its descendants, in pre-order."
  @spec subtree(t, id) :: [id]
  def subtree(db, id), do: [id | descendants(db, id)]

  @doc "Depth below MAIN (MAIN is 0)."
  @spec depth(t, id) :: non_neg_integer
  def depth(db, id), do: length(ancestors(db, id))

  @doc "The whole hierarchy in pre-order, as `{id, depth}` pairs."
  @spec hierarchy(t) :: [{id, non_neg_integer}]
  def hierarchy(%__MODULE__{} = db) do
    Enum.map(subtree(db, db.main_id), &{&1, depth(db, &1)})
  end

  @doc "Finds categories (within the subtree of `root`) whose name equals `name`, ignoring case."
  @spec find_categories(t, String.t(), id | nil) :: [id]
  def find_categories(%__MODULE__{} = db, name, root \\ nil) do
    wanted = normalize(name)

    db
    |> subtree(root || db.main_id)
    |> Enum.filter(fn id ->
      c = db.categories[id]
      normalize(c.name) == wanted or (c.short_name && normalize(c.short_name) == wanted)
    end)
  end

  # ---------------------------------------------------------------------------
  # Links and membership
  # ---------------------------------------------------------------------------

  @spec link(t, id, id) :: t
  def link(db, item_id, cat_id), do: %{db | links: Links.link(db.links, item_id, cat_id)}

  @spec unlink(t, id, id) :: t
  def unlink(db, item_id, cat_id) do
    %{
      db
      | links: Links.unlink(db.links, item_id, cat_id),
        conditional: MapSet.delete(db.conditional, {item_id, cat_id})
    }
  end

  @doc """
  Whether a link was made by a category's assignment conditions (R15), so
  it is broken again when the conditions stop holding. Links the user makes
  are never conditional.
  """
  @spec conditional?(t, id, id) :: boolean
  def conditional?(db, item_id, cat_id), do: MapSet.member?(db.conditional, {item_id, cat_id})

  @spec mark_conditional(t, id, id) :: t
  def mark_conditional(db, item_id, cat_id),
    do: %{db | conditional: MapSet.put(db.conditional, {item_id, cat_id})}

  @spec unmark_conditional(t, id, id) :: t
  def unmark_conditional(db, item_id, cat_id),
    do: %{db | conditional: MapSet.delete(db.conditional, {item_id, cat_id})}

  @doc "Categories an item is explicitly linked to."
  @spec explicit_categories(t, id) :: MapSet.t(id)
  def explicit_categories(db, item_id), do: Links.rights(db.links, item_id)

  @spec explicit?(t, id, id) :: boolean
  def explicit?(db, item_id, cat_id), do: Links.linked?(db.links, item_id, cat_id)

  @doc "The date field backing a date category, or nil for standard categories."
  @spec date_field(t, id) :: :entry | :when | :done | nil
  def date_field(%__MODULE__{special: special}, cat_id) do
    Enum.find_value(special, fn {key, id} -> if id == cat_id, do: @date_fields[key] end)
  end

  @doc """
  Whether an item belongs to a category, directly or by subsumption: an item
  linked to a category is also a member of every ancestor of that category.
  Every item is a member of MAIN; date categories derive membership from the
  item's date fields.
  """
  @spec member?(t, id, id) :: boolean
  def member?(%__MODULE__{} = db, item_id, cat_id) do
    cond do
      cat_id == db.main_id ->
        true

      field = date_field(db, cat_id) ->
        Map.get(db.items[item_id], field) != nil

      true ->
        explicit = explicit_categories(db, item_id)
        Enum.any?(subtree(db, cat_id), &MapSet.member?(explicit, &1))
    end
  end

  @doc "Items that are members of a category, in item order."
  @spec items_in(t, id) :: [Item.t()]
  def items_in(%__MODULE__{} = db, cat_id) do
    cond do
      cat_id == db.main_id ->
        items(db)

      field = date_field(db, cat_id) ->
        db |> items() |> Enum.filter(&(Map.get(&1, field) != nil))

      true ->
        ids =
          db
          |> subtree(cat_id)
          |> Enum.reduce(MapSet.new(), &MapSet.union(&2, Links.lefts(db.links, &1)))

        db.item_order |> Enum.filter(&MapSet.member?(ids, &1)) |> Enum.map(&db.items[&1])
    end
  end

  # ---------------------------------------------------------------------------
  # Views
  # ---------------------------------------------------------------------------

  @spec view(t, id) :: View.t() | nil
  def view(%__MODULE__{views: views}, id), do: Map.get(views, id)

  @doc "All views in view-manager order."
  @spec views(t) :: [View.t()]
  def views(%__MODULE__{} = db), do: Enum.map(db.view_order, &db.views[&1])

  @doc "Inserts a view. Options: `:sections` (category ids), `:columns` (`Column` structs)."
  @spec insert_view(t, String.t(), keyword) :: {t, id}
  def insert_view(%__MODULE__{} = db, name, opts \\ []) do
    {db, id} = take_id(db)
    sections = opts |> Keyword.get(:sections, []) |> Enum.map(&%Section{category_id: &1})
    view = %View{id: id, name: name, sections: sections, columns: Keyword.get(opts, :columns, [])}
    {%{db | views: Map.put(db.views, id, view), view_order: db.view_order ++ [id]}, id}
  end

  @spec update_view(t, id, (View.t() -> View.t())) :: t
  def update_view(db, id, fun), do: %{db | views: Map.update!(db.views, id, fun)}

  @spec delete_view(t, id) :: {:ok, t} | {:error, :last_view}
  def delete_view(%__MODULE__{view_order: [_]}, _id), do: {:error, :last_view}

  def delete_view(%__MODULE__{} = db, id) do
    {:ok, %{db | views: Map.delete(db.views, id), view_order: List.delete(db.view_order, id)}}
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  @doc false
  def normalize(name),
    do: name |> String.trim() |> String.downcase() |> String.replace(~r/\s+/u, " ")

  defp take_id(%__MODULE__{next_id: id} = db), do: {%{db | next_id: id + 1}, id}

  # Filters and sort keys that name deleted categories go with them.
  defp drop_filters(filter, doomed), do: Enum.reject(filter, &(elem(&1, 0) in doomed))
  defp drop_keys(nil, _doomed), do: nil

  defp drop_keys(keys, doomed) do
    Enum.reject(keys, fn
      %{on: {:category, id}} -> MapSet.member?(doomed, id)
      _ -> false
    end)
  end

  defp put_new_category(db, category) do
    {db, id} = take_id(db)
    {%{db | categories: Map.put(db.categories, id, %{category | id: id})}, id}
  end

  defp attach_child(db, parent_id, id, after_id) do
    db = update_category(db, id, &%{&1 | parent_id: parent_id})
    update_category(db, parent_id, &%{&1 | children: insert_after(&1.children, id, after_id)})
  end

  defp detach_child(db, parent_id, id) do
    update_category(db, parent_id, &%{&1 | children: List.delete(&1.children, id)})
  end

  defp sibling_at(db, id, offset) do
    case db.categories[id].parent_id do
      nil ->
        nil

      parent ->
        siblings = db.categories[parent].children
        index = Enum.find_index(siblings, &(&1 == id)) + offset
        if index >= 0, do: Enum.at(siblings, index)
    end
  end

  # Inserts `id` after `after_id`; `nil` appends, `:first` prepends.
  # An unknown `after_id` also appends.
  defp insert_after(list, id, nil), do: list ++ [id]
  defp insert_after(list, id, :first), do: [id | list]

  defp insert_after(list, id, after_id) do
    case Enum.find_index(list, &(&1 == after_id)) do
      nil -> list ++ [id]
      index -> List.insert_at(list, index + 1, id)
    end
  end
end
