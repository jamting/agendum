defmodule Agendum.Core.Database do
  @moduledoc """
  The complete state of one Agendum file, as an immutable value.

  Objects (items, categories, views) share a single id space, mirroring the
  single object file (`.AGA`) described in the patent. Item/category
  assignments are stored as independent links (`Agendum.Core.Links`), which
  mirror the link-structure file (`.AGB`).

  This module provides primitive operations and queries. Assignment rules
  (subsumption, mutual exclusion, automatic assignment) live in
  `Agendum.Core.Assign`; user-level operations are in `Agendum.Core`.

  Every function is pure: it takes a database and returns a new one.
  """

  alias Agendum.Core.{Category, DateFormat, DateRule, DateSettings, Item, Links, TextMatch, View}
  alias Agendum.Core.View.{Column, Section}

  @type id :: pos_integer
  @type t :: %__MODULE__{
          items: %{optional(id) => Item.t()},
          item_order: [id],
          categories: %{optional(id) => Category.t()},
          views: %{optional(id) => View.t()},
          view_order: [id],
          links: Links.t(),
          next_id: id,
          next_zettel: pos_integer,
          main_id: id,
          special: %{entry: id, when: id, done: id},
          conditional: MapSet.t({id, id}),
          date_format: DateFormat.t(),
          date_settings: DateSettings.t(),
          numbers: %{optional({id, id}) => float},
          texts: %{optional({id, id}) => String.t()},
          dates: %{optional({id, id}) => {Date.t(), Time.t() | nil, boolean}},
          dependencies: Links.t(),
          confirm_assignments: :never | :always | :sometimes,
          match_settings: TextMatch.t(),
          suggestions: %{optional(id) => [id]},
          calendars: %{optional(id) => Agendum.Core.Extras.Calendar.t()},
          feeds: %{optional(id) => Agendum.Core.Extras.Feed.t()},
          macros: %{optional(id) => Agendum.Core.Macro.t()},
          macro_order: [id],
          insert_columns: :all | :section,
          tab_size: pos_integer,
          description: String.t(),
          backup_on_open: boolean,
          password: String.t() | nil,
          blog: Agendum.Core.Extras.Blog.t()
        }

  defstruct items: %{},
            item_order: [],
            categories: %{},
            views: %{},
            view_order: [],
            links: Links.new(),
            next_id: 1,
            # the next Zettel id's number (R73): a counter of its own
            next_zettel: 1,
            main_id: nil,
            special: %{},
            conditional: MapSet.new(),
            date_format: %DateFormat{},
            date_settings: %DateSettings{},
            numbers: %{},
            # an item's text in an unindexed category (R29b)
            texts: %{},
            dates: %{},
            dependencies: Links.new(),
            confirm_assignments: :never,
            match_settings: %TextMatch{},
            suggestions: %{},
            calendars: %{},
            # feed subscriptions (R75)
            feeds: %{},
            macros: %{},
            macro_order: [],
            # File Properties ▸ Insert new columns in (R55)
            insert_columns: :all,
            # File Properties ▸ Tab size: the note editor's tab stops (R64e)
            tab_size: 5,
            # File Properties ▸ File description and Make backup on open (R82)
            description: "",
            backup_on_open: false,
            # the file's password while it is open (ADR 0046): never written,
            # the file is encrypted with it instead
            password: nil,
            # the micro-blog (R74)
            blog: %Agendum.Core.Extras.Blog{}

  @date_fields %{entry: :entry, when: :when, done: :done}

  # ---------------------------------------------------------------------------
  # Construction
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new, empty file: the MAIN category with the Entry, When and Done
  date categories, an "Initial Section" category, and an "Initial View" that
  shows it with a When column; dates in Agenda's default format (R41).
  """
  @spec new(keyword) :: t
  def new(opts \\ []) do
    view_name = Keyword.get(opts, :view_name, "Initial View")
    section_name = Keyword.get(opts, :section_name, "Initial Section")

    # A new file shows dates as Agenda's did (R41). The struct's own default
    # stays ISO 8601: an old file saved before dates had a format (format 7)
    # gets it when loaded, so it shows its dates as it always did.
    db = %__MODULE__{date_format: DateFormat.agenda()}
    {db, main} = put_new_category(db, %Category{name: "MAIN", match_name: false})
    db = %{db | main_id: main}

    date = &[kind: :date, match_name: false, date_rule: DateRule.builtin(&1)]
    {db, entry} = insert_category(db, main, "Entry", date.(:entry))
    {db, when_id} = insert_category(db, main, "When", date.(:when))
    {db, done} = insert_category(db, main, "Done", date.(:done))
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
        conditional: MapSet.reject(db.conditional, &(elem(&1, 0) == id)),
        numbers: Map.reject(db.numbers, fn {{item, _}, _} -> item == id end),
        texts: Map.reject(db.texts, fn {{item, _}, _} -> item == id end),
        dates: Map.reject(db.dates, fn {{item, _}, _} -> item == id end),
        dependencies: db.dependencies |> Links.drop_left(id) |> Links.drop_right(id),
        suggestions: Map.delete(db.suggestions, id),
        # a Show View listing items no longer lists this one
        views: Map.new(db.views, fn {vid, v} -> {vid, without_item(v, id)} end)
    }
  end

  defp without_item(%View{match: {kind, ids}} = view, id) when kind in [:items, :circular],
    do: %{view | match: {kind, List.delete(ids, id)}}

  defp without_item(view, _id), do: view

  @doc "Moves an item to directly after `after_id` (first with `:first`, last with nil)."
  @spec reorder_item(t, id, id | :first | nil) :: t
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
    fields = Keyword.take(opts, [:kind, :exclusive, :match_name, :short_name, :date_rule])
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
               excludes: Enum.reject(c.excludes, &(&1 in doomed_set)),
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
                       sort: drop_keys(&1.sort, doomed_set),
                       columns: Enum.reject(&1.columns, fn c -> c.category_id in doomed_set end)
                   }
                 ),
               columns: Enum.reject(v.columns, &(&1.category_id in doomed_set)),
               filter: drop_filters(v.filter, doomed_set),
               sort: drop_keys(v.sort, doomed_set),
               datebook: datebook_without(v.datebook, doomed_set, db.special.when)
           }}
        end)

      # an alarm on a date category that is gone rings before When again
      items =
        Map.new(db.items, fn
          {iid, %{alarm_category: cat} = item} when cat != nil ->
            {iid, if(cat in doomed_set, do: %{item | alarm_category: nil}, else: item)}

          pair ->
            pair
        end)

      numbers = Map.reject(db.numbers, fn {{_, cat}, _} -> cat in doomed_set end)
      texts = Map.reject(db.texts, fn {{_, cat}, _} -> cat in doomed_set end)
      dates = Map.reject(db.dates, fn {{_, cat}, _} -> cat in doomed_set end)

      suggestions =
        db.suggestions
        |> Map.new(fn {item, cats} -> {item, Enum.reject(cats, &(&1 in doomed_set))} end)
        |> Map.reject(fn {_, cats} -> cats == [] end)

      {:ok,
       %{
         db
         | links: links,
           conditional: conditional,
           categories: categories,
           items: items,
           views: views,
           numbers: numbers,
           texts: texts,
           dates: dates,
           suggestions: suggestions,
           # a calendar whose category is gone is no longer read (R45)
           calendars: Map.reject(db.calendars, fn {_, c} -> c.category_id in doomed_set end),
           # and a feed (R75)
           feeds: Map.reject(db.feeds, fn {_, f} -> f.category_id in doomed_set end),
           # the blog forgets a posts or drafts category that is gone (R74)
           blog: %{
             db.blog
             | posts: if(db.blog.posts in doomed_set, do: nil, else: db.blog.posts),
               drafts: if(db.blog.drafts in doomed_set, do: nil, else: db.blog.drafts)
           }
       }}
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
        conditional: MapSet.delete(db.conditional, {item_id, cat_id}),
        numbers: Map.delete(db.numbers, {item_id, cat_id}),
        texts: Map.delete(db.texts, {item_id, cat_id})
    }
  end

  @doc """
  The items an item depends on (its prerequisites, R43), in item order.
  `dependencies` links a dependent item (left) to each prerequisite (right).
  """
  @spec prerequisites(t, id) :: [id]
  def prerequisites(db, item_id),
    do: in_item_order(db, Links.rights(db.dependencies, item_id))

  @doc "The items that depend on an item, in item order."
  @spec dependents(t, id) :: [id]
  def dependents(db, item_id), do: in_item_order(db, Links.lefts(db.dependencies, item_id))

  @doc "Whether an item still waits for a prerequisite that is not done."
  @spec waiting?(t, id) :: boolean
  # straight from the links, not `prerequisites/2`: the order does not
  # matter here, and sorting walks every item, once for each item shown
  def waiting?(db, item_id),
    do: db.dependencies |> Links.rights(item_id) |> Enum.any?(&(db.items[&1].done == nil))

  defp in_item_order(db, ids), do: Enum.filter(db.item_order, &MapSet.member?(ids, &1))

  @doc "An item's number in a numeric category (R29), or nil."
  @spec number(t, id, id) :: float | nil
  def number(%__MODULE__{numbers: numbers}, item_id, cat_id),
    do: Map.get(numbers, {item_id, cat_id})

  @doc "Assigns an item to a numeric category with a number."
  @spec put_number(t, id, id, number) :: t
  def put_number(db, item_id, cat_id, value) do
    db = link(db, item_id, cat_id)
    %{db | numbers: Map.put(db.numbers, {item_id, cat_id}, value * 1.0)}
  end

  @doc "An item's text in an unindexed category (R29b), or nil."
  @spec text(t, id, id) :: String.t() | nil
  def text(%__MODULE__{texts: texts}, item_id, cat_id), do: Map.get(texts, {item_id, cat_id})

  @doc "Assigns an item to an unindexed category with a text."
  @spec put_text(t, id, id, String.t()) :: t
  def put_text(db, item_id, cat_id, text) do
    db = link(db, item_id, cat_id)
    %{db | texts: Map.put(db.texts, {item_id, cat_id}, text)}
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

  @doc """
  The item field backing a built-in date category (Entry, When, Done), or
  nil for every other category, including date categories the user made
  (R6a), whose dates are in `dates`. Use `date_category?/2` and
  `item_date/3` to treat all date categories alike.
  """
  @spec date_field(t, id) :: :entry | :when | :done | nil
  def date_field(%__MODULE__{special: special}, cat_id) do
    Enum.find_value(special, fn {key, id} -> if id == cat_id, do: @date_fields[key] end)
  end

  @doc "Whether a category is a date category: Entry, When, Done or one the user made (R6a)."
  @spec date_category?(t, id) :: boolean
  def date_category?(db, cat_id), do: match?(%{kind: :date}, db.categories[cat_id])

  @doc "An item's date in a date category, or nil."
  @spec item_date(t, id, id) :: Date.t() | nil
  def item_date(db, item_id, cat_id) do
    case date_field(db, cat_id) do
      nil ->
        case Map.get(db.dates, {item_id, cat_id}) do
          {date, _time, _explicit} -> date
          nil -> nil
        end

      field ->
        Map.get(db.items[item_id], field)
    end
  end

  @doc "The time of day of an item's date in a date category (When or one the user made), or nil."
  @spec item_time(t, id, id) :: Time.t() | nil
  def item_time(db, item_id, cat_id) do
    case date_field(db, cat_id) do
      :when -> db.items[item_id].when_time
      nil -> with {_date, time, _explicit} <- Map.get(db.dates, {item_id, cat_id}), do: time
      _entry_or_done -> nil
    end
  end

  @doc """
  Whether the user set an item's date in a date category by hand, so that
  dates in the text leave it alone (When's `when_explicit`, R14, R6b).
  """
  @spec date_explicit?(t, id, id) :: boolean
  def date_explicit?(db, item_id, cat_id) do
    case date_field(db, cat_id) do
      :when -> db.items[item_id].when_explicit
      nil -> match?({_, _, true}, Map.get(db.dates, {item_id, cat_id}))
      _entry_or_done -> false
    end
  end

  @doc """
  Sets (or, with a nil date, clears) an item's date in a date category the
  user made; `explicit` when the user set it by hand.
  """
  @spec put_item_date(t, id, id, Date.t() | nil, Time.t() | nil, boolean) :: t
  def put_item_date(db, item_id, cat_id, date, time, explicit \\ false)

  def put_item_date(db, item_id, cat_id, nil, _time, _explicit),
    do: %{db | dates: Map.delete(db.dates, {item_id, cat_id})}

  def put_item_date(db, item_id, cat_id, %Date{} = date, time, explicit),
    do: %{db | dates: Map.put(db.dates, {item_id, cat_id}, {date, time, explicit})}

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

      date_category?(db, cat_id) ->
        item_date(db, item_id, cat_id) != nil

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

      date_category?(db, cat_id) ->
        db |> items() |> Enum.filter(&(item_date(db, &1.id, cat_id) != nil))

      true ->
        ids = linked_ids(db, cat_id)
        db.item_order |> Enum.filter(&MapSet.member?(ids, &1)) |> Enum.map(&db.items[&1])
    end
  end

  @doc """
  Each item's place in item order, from 0: read once by a caller that asks
  `items_in/3` for many categories (a view with a section per feed).
  """
  @spec item_positions(t) :: %{id => non_neg_integer}
  def item_positions(%__MODULE__{} = db),
    do: db.item_order |> Enum.with_index() |> Map.new()

  @doc """
  `items_in/2`, faster for a category with few items: its members are put
  in item order by their `positions` (`item_positions/1`), rather than by
  walking the whole item order once per category.
  """
  @spec items_in(t, id, %{id => non_neg_integer}) :: [Item.t()]
  def items_in(%__MODULE__{} = db, cat_id, positions) do
    if cat_id == db.main_id or date_category?(db, cat_id) do
      items_in(db, cat_id)
    else
      # `Map.has_key?/2` keeps out a link to an item no longer in the file,
      # as the walk through the item order did
      db
      |> linked_ids(cat_id)
      |> Enum.filter(&Map.has_key?(positions, &1))
      |> Enum.sort_by(&Map.fetch!(positions, &1))
      |> Enum.map(&db.items[&1])
    end
  end

  # The items linked to a category or to any category below it.
  defp linked_ids(db, cat_id) do
    db
    |> subtree(cat_id)
    |> Enum.reduce(MapSet.new(), &MapSet.union(&2, Links.lefts(db.links, &1)))
  end

  # ---------------------------------------------------------------------------
  # Views
  # ---------------------------------------------------------------------------

  @spec view(t, id) :: View.t() | nil
  def view(%__MODULE__{views: views}, id), do: Map.get(views, id)

  @doc "All views in view-manager order."
  @spec views(t) :: [View.t()]
  def views(%__MODULE__{} = db), do: Enum.map(db.view_order, &db.views[&1])

  @doc """
  How much of the file uses a category (Category Properties ▸ Statistics,
  Agenda's Category Statistics box): the items in it, its children, the
  sections it heads (a datebook's Section heads all its slots: one), the
  views filtered on it (the view or one of its sections), and the
  categories whose conditions or actions name it.
  """
  @spec category_statistics(t, id) :: %{atom => non_neg_integer}
  def category_statistics(%__MODULE__{} = db, cat_id) do
    views = views(db)
    others = Map.values(db.categories)
    # `List.keymember?/3`: a {category, _} pair for this category in the list
    names? = &List.keymember?(&1, cat_id, 0)

    %{
      items: length(items_in(db, cat_id)),
      children: length(db.categories[cat_id].children),
      section_heads:
        Enum.sum_by(views, fn
          # a datebook's stored sections are not shown: its slots are (R47)
          %{datebook: %{section_category: head}} -> if head == cat_id, do: 1, else: 0
          view -> Enum.count(view.sections, &(&1.category_id == cat_id))
        end),
      view_filters:
        Enum.count(views, fn view ->
          names?.(view.filter) or Enum.any?(view.sections, &names?.(&1.filter))
        end),
      conditions: Enum.count(others, &names?.(&1.conditions)),
      actions: Enum.count(others, &(cat_id in &1.also_assign or names?.(&1.actions)))
    }
  end

  @doc """
  The file's statistics (File ▸ Properties ▸ File statistics, Agenda's File
  Statistics box): its items, those with a note, its categories (MAIN
  too), and the average number of items per category and categories per
  item. As Agenda, the averages count the assignments stored with the
  items (not those through a subcategory) and are whole numbers, rounded
  down; Agenda's other counts (unused space, items in the trash) have no
  counterpart here.
  """
  @spec file_statistics(t) :: %{atom => non_neg_integer}
  def file_statistics(%__MODULE__{} = db) do
    items = map_size(db.items)
    categories = map_size(db.categories)
    assignments = Links.size(db.links)

    %{
      items: items,
      items_with_notes: Enum.count(Map.values(db.items), &(&1.note != "")),
      categories: categories,
      # `max(_, 1)`: no division by zero in an empty file
      items_per_category: div(assignments, max(categories, 1)),
      categories_per_item: div(assignments, max(items, 1))
    }
  end

  # a datebook view whose categories go falls back to When (R47)
  defp datebook_without(nil, _doomed, _when), do: nil

  defp datebook_without(d, doomed, when_id) do
    date = if d.date_category in doomed, do: when_id, else: d.date_category

    %{
      d
      | date_category: date,
        section_category: if(d.section_category in doomed, do: date, else: d.section_category),
        end_category: if(d.end_category in doomed, do: nil, else: d.end_category)
    }
  end

  @doc """
  Inserts a view. Options: `:sections` (category ids), `:columns` (`Column`
  structs, which every section gets, linked: R55).
  """
  @spec insert_view(t, String.t(), keyword) :: {t, id}
  def insert_view(%__MODULE__{} = db, name, opts \\ []) do
    {db, id} = take_id(db)
    columns = opts |> Keyword.get(:columns, []) |> View.numbered_links()

    sections =
      opts
      |> Keyword.get(:sections, [])
      |> Enum.map(&%Section{category_id: &1, columns: columns})

    view = %View{id: id, name: name, sections: sections}
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
  # Calendar subscriptions (R45)
  # ---------------------------------------------------------------------------

  @doc "Adds a calendar subscription, giving it a new id."
  @spec add_calendar(t, Agendum.Core.Extras.Calendar.t()) :: {t, id}
  def add_calendar(%__MODULE__{} = db, calendar) do
    {db, id} = take_id(db)
    {%{db | calendars: Map.put(db.calendars, id, %{calendar | id: id})}, id}
  end

  @doc "Changes a calendar subscription."
  @spec update_calendar(t, id, (Agendum.Core.Extras.Calendar.t() ->
                                  Agendum.Core.Extras.Calendar.t())) :: t
  def update_calendar(%__MODULE__{} = db, id, fun),
    do: %{db | calendars: Map.update!(db.calendars, id, fun)}

  @doc "Removes a calendar subscription (its items stay)."
  @spec delete_calendar(t, id) :: t
  def delete_calendar(%__MODULE__{} = db, id), do: %{db | calendars: Map.delete(db.calendars, id)}

  @doc "The calendar subscriptions, in the order they were made."
  @spec calendars(t) :: [Agendum.Core.Extras.Calendar.t()]
  def calendars(%__MODULE__{} = db), do: db.calendars |> Map.values() |> Enum.sort_by(& &1.id)

  # ---------------------------------------------------------------------------
  # Feed subscriptions (R75)
  # ---------------------------------------------------------------------------

  @doc "Adds a feed subscription, giving it a new id."
  @spec add_feed(t, Agendum.Core.Extras.Feed.t()) :: {t, id}
  def add_feed(%__MODULE__{} = db, feed) do
    {db, id} = take_id(db)
    {%{db | feeds: Map.put(db.feeds, id, %{feed | id: id})}, id}
  end

  @doc "Changes a feed subscription."
  @spec update_feed(t, id, (Agendum.Core.Extras.Feed.t() -> Agendum.Core.Extras.Feed.t())) :: t
  def update_feed(%__MODULE__{} = db, id, fun), do: %{db | feeds: Map.update!(db.feeds, id, fun)}

  @doc "Removes a feed subscription (its items stay)."
  @spec delete_feed(t, id) :: t
  def delete_feed(%__MODULE__{} = db, id), do: %{db | feeds: Map.delete(db.feeds, id)}

  @doc "The feed subscriptions, in the order they were made."
  @spec feeds(t) :: [Agendum.Core.Extras.Feed.t()]
  def feeds(%__MODULE__{} = db), do: db.feeds |> Map.values() |> Enum.sort_by(& &1.id)

  @doc "Adds a macro (R50) at the end of the list, giving it an id."
  @spec add_macro(t, Agendum.Core.Macro.t()) :: {t, id}
  def add_macro(%__MODULE__{} = db, macro) do
    {db, id} = take_id(db)

    {%{
       db
       | macros: Map.put(db.macros, id, %{macro | id: id}),
         macro_order: db.macro_order ++ [id]
     }, id}
  end

  @doc "Changes a macro."
  @spec update_macro(t, id, (Agendum.Core.Macro.t() -> Agendum.Core.Macro.t())) :: t
  def update_macro(%__MODULE__{} = db, id, fun),
    do: %{db | macros: Map.update!(db.macros, id, fun)}

  @doc "Removes a macro."
  @spec delete_macro(t, id) :: t
  def delete_macro(%__MODULE__{} = db, id),
    do: %{db | macros: Map.delete(db.macros, id), macro_order: List.delete(db.macro_order, id)}

  @doc "The macros, in the macro manager's order."
  @spec macros(t) :: [Agendum.Core.Macro.t()]
  def macros(%__MODULE__{} = db), do: Enum.map(db.macro_order, &db.macros[&1])

  @doc "The macro of a name, case aside, or nil."
  @spec find_macro(t, String.t()) :: Agendum.Core.Macro.t() | nil
  def find_macro(%__MODULE__{} = db, name) do
    wanted = name |> String.trim() |> String.downcase()
    Enum.find(macros(db), &(String.downcase(&1.name) == wanted))
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  @doc false
  @spec normalize(String.t()) :: String.t()
  def normalize(name),
    do: name |> String.trim() |> String.downcase() |> String.replace(~r/\s+/u, " ")

  defp take_id(%__MODULE__{next_id: id} = db), do: {%{db | next_id: id + 1}, id}

  # Filters and sort keys that name deleted categories go with them.
  defp drop_filters(filter, doomed), do: Enum.reject(filter, &(elem(&1, 0) in doomed))
  defp drop_keys(nil, _doomed), do: nil

  defp drop_keys(keys, doomed) do
    Enum.reject(keys, fn
      %{on: {kind, id}} when kind in [:category, :note] -> MapSet.member?(doomed, id)
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
