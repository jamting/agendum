defmodule Agendum.Core.Facade.Assignments do
  @moduledoc """
  Assigning items to categories by hand: assign, unassign (R24) and
  toggle, text typed into a column (R23; claims 3 and 6 of the patent),
  automatic completion (R32), and what an item is assigned to (Item
  Properties, R34).

  Called through `Agendum.Core`.
  """

  alias Agendum.Core.{Assign, Context, Database, DateParser, NumberFormat}
  alias Agendum.Core.Facade.{Categories, Changes, Numbers}

  @typep db :: Agendum.Core.db()
  @typep id :: Agendum.Core.id()
  @typep clock :: Agendum.Core.clock()

  @doc """
  Removes an item from a category and its descendants (DEL on an item in a
  section, or on a column entry). For a date category, clears the date.
  """
  @spec remove_from_category(db, id, id, clock | nil) :: db
  def remove_from_category(db, item_id, cat_id, clock \\ nil) do
    # `if c, do: a, else: b` is the keyword form of `if ... do ... else ...
    # end` (the block form is sugar for it). `if` is an expression: its
    # value is the function's result.
    if Database.date_category?(db, cat_id),
      do: Changes.put_date(db, item_id, cat_id, nil),
      else:
        Assign.unassign(db, item_id, cat_id)
        |> Changes.settle(db, item_id, clock)
  end

  @doc """
  Assigns an item to a category (with mutual exclusion, the
  ancestor/descendant rule and category links), then re-checks the file's
  assignment conditions for the item (R15), read against `clock` for date
  conditions (R15a).
  """
  @spec assign(db, id, id, clock | nil) :: db
  def assign(db, item_id, cat_id, clock \\ nil),
    do: db |> Changes.user_assign(item_id, cat_id) |> Changes.settle(db, item_id, clock)

  @doc """
  Toggles one explicit assignment, as in the assignment profile: an
  explicit link is removed (only that link, not the subtree); otherwise the
  item is assigned with the usual rules.
  """
  @spec toggle_assignment(db, id, id, clock | nil) :: db
  def toggle_assignment(db, item_id, cat_id, clock \\ nil) do
    if Database.explicit?(db, item_id, cat_id),
      do: db |> Database.unlink(item_id, cat_id) |> Changes.settle(db, item_id, clock),
      else:
        Changes.user_assign(db, item_id, cat_id)
        |> Changes.settle(db, item_id, clock)
  end

  @doc """
  Handles text typed into a column cell for an item (claims 3 and 6 of the
  patent). For a date column the text is parsed as a date, for a numeric
  column as a number (R29), for an unindexed column as its text (R29b).
  Otherwise the
  text names a descendant of the column head: an exact name match is used
  first, then a unique prefix match; if nothing matches, a new child of the
  column head is created. Returns the category assigned.
  """
  @spec assign_by_name(db, id, id, String.t(), clock) ::
          {:ok, db, id | :date | :number | :text}
          | {:error, :invalid_date | :not_a_number | :ambiguous | :empty}
  def assign_by_name(db, item_id, head_id, text, today) do
    text = String.trim(text)
    before = db

    cond do
      text == "" ->
        {:error, :empty}

      db.categories[head_id].kind == :numeric ->
        # `with` chains steps that may fail: each `pattern <- expr` must
        # match to go on; the first that doesn't falls to `else` (here any
        # error becomes `:not_a_number`). It replaces nested `case`s.
        with {:ok, value} <- NumberFormat.parse(text, Context.number_opts(today)),
             {:ok, db} <- Numbers.set_number(db, item_id, head_id, value, today) do
          {:ok, db, :number}
        else
          _ -> {:error, :not_a_number}
        end

      # the text is the item's value, not a category (R29b)
      db.categories[head_id].kind == :unindexed ->
        {:ok, db} = Agendum.Core.Facade.Texts.set_text(db, item_id, head_id, text, today)
        {:ok, db, :text}

      Database.date_category?(db, head_id) ->
        case DateParser.parse_recurring(
               text,
               Changes.now_of(today),
               Context.parser_opts(today, db.date_settings)
             ) do
          {:ok, date, time, rule} ->
            db = Changes.put_date_time(db, item_id, head_id, date, time, rule)
            {:ok, Changes.settle(db, before, item_id, today), :date}

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

  @doc """
  Everything an item is assigned to, in hierarchy order, as the Item
  Properties box lists it: date categories with the item's date (`:date`),
  numeric categories with its number (`:numeric`, R29), and links the
  user made (`:explicit`) or a condition made
  (`:conditional`). Membership through subcategories is not listed.
  """
  @spec item_assignments(db, id) :: [
          %{
            required(:category) => id,
            required(:kind) => :date | :numeric | :explicit | :conditional,
            required(:date) => Date.t() | nil,
            optional(:number) => float
          }
        ]
  def item_assignments(db, item_id) do
    item = db.items[item_id]

    db
    |> Database.hierarchy()
    # `flat_map` with `[]` or `[x]` per element: filter and map in one pass.
    # `{id, _depth}` takes each 2-tuple apart right in the function's head.
    |> Enum.flat_map(fn {id, _depth} ->
      cond do
        Database.date_category?(db, id) ->
          case Database.item_date(db, item.id, id) do
            nil -> []
            date -> [%{category: id, kind: :date, date: date}]
          end

        # a `cond` condition can bind: the branch runs when `number` is
        # truthy (not nil or false) and can use it
        number = Database.number(db, item_id, id) ->
          [%{category: id, kind: :numeric, date: nil, number: number}]

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
    case Categories.add_category(db, head_id, text) do
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
    # `:unicode` is an Erlang module, called directly (Erlang modules are
    # atoms). NFD splits "é" into "e" plus a combining accent, which the
    # regex (`~r/.../u`, a Unicode regex sigil) then removes.
    |> :unicode.characters_to_nfd_binary()
    |> String.replace(~r/\p{Mn}/u, "")
    |> String.downcase()
  end

  # Exact (case-insensitive) match among descendants of `root`, else a
  # unique prefix match.
  defp resolve_name(db, root, text) do
    wanted = Database.normalize(text)
    candidates = Database.descendants(db, root)

    # `--` removes elements from a list; `[id | _]` matches a non-empty list
    # and binds its head (first element), `[]` the empty one, `[id]` exactly one.
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
end
