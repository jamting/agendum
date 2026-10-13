defmodule Agenda.Core.Facade.Numbers do
  @moduledoc """
  Numbers (R29): giving items numbers in numeric categories, and
  converting a category to a numeric one.

  Called through `Agenda.Core`.
  """

  alias Agenda.Core.{Context, Database, NumberFormat}
  alias Agenda.Core.Facade.{Assignments, Changes}

  @typep db :: Agenda.Core.db()
  @typep id :: Agenda.Core.id()
  @typep clock :: Agenda.Core.clock()

  # --- numbers (R29) ----------------------------------------------------------

  @doc """
  Gives an item a number in a numeric category, assigning it there (with
  the usual assignment rules).
  """
  @spec set_number(db, id, id, number, clock | nil) :: {:ok, db} | {:error, :not_numeric}
  def set_number(db, item_id, cat_id, value, clock \\ nil) do
    if db.categories[cat_id].kind == :numeric do
      db =
        db
        |> Changes.user_assign(item_id, cat_id)
        |> Database.put_number(item_id, cat_id, value)
        |> Changes.settle(db, item_id, clock)

      {:ok, db}
    else
      {:error, :not_numeric}
    end
  end

  @doc "Removes an item's number, and so its assignment to the numeric category."
  @spec clear_number(db, id, id, clock | nil) :: db
  def clear_number(db, item_id, cat_id, clock \\ nil),
    do: Assignments.remove_from_category(db, item_id, cat_id, clock)

  @doc """
  What converting a standard category to numeric would do to its children
  (User's Guide 8-11): they are removed, and their items get the child's
  name as their number, or 0 for the names listed in `non_numeric`; the
  `assigned` items assigned to the category itself get 0. Names are read
  as numbers with the person's separators, from `clock` (R54).
  """
  @spec numeric_conversion(db, id, clock | nil) :: %{
          children: non_neg_integer,
          non_numeric: [String.t()],
          assigned: non_neg_integer
        }
  def numeric_conversion(db, cat_id, clock \\ nil) do
    children = Enum.map(db.categories[cat_id].children, &db.categories[&1])
    opts = Context.number_opts(clock)

    %{
      children: length(children),
      non_numeric: for(c <- children, NumberFormat.parse(c.name, opts) == :error, do: c.name),
      assigned: db |> Changes.direct_items(cat_id) |> length()
    }
  end

  @doc """
  Converts a standard category to a numeric one (User's Guide 8-11 to
  8-12). Its children, if any, become numbers (see `numeric_conversion/3`);
  a category with grandchildren cannot be converted. Numeric categories do
  not match item text.
  """
  @spec make_numeric(db, id, clock | nil) ::
          {:ok, db} | {:error, :not_standard | :protected | :too_deep}
  def make_numeric(db, cat_id, clock \\ nil) do
    cat = db.categories[cat_id]

    cond do
      cat.kind != :standard ->
        {:error, :not_standard}

      Database.protected?(db, cat_id) ->
        {:error, :protected}

      Enum.any?(cat.children, &(db.categories[&1].children != [])) ->
        {:error, :too_deep}

      true ->
        values =
          for(item <- Changes.direct_items(db, cat_id), do: {item, 0.0}) ++
            for child <- cat.children,
                value = child_value(db.categories[child].name, clock),
                item <- Database.items_in(db, child),
                do: {item.id, value}

        db =
          Enum.reduce(cat.children, db, fn child, db ->
            {:ok, db} = Database.delete_category(db, child)
            db
          end)

        db =
          db
          |> Changes.drop_excludes(cat_id)
          |> Database.update_category(
            cat_id,
            &%{&1 | kind: :numeric, match_name: false, exclusive: false}
          )

        {:ok,
         Enum.reduce(values, db, fn {item, v}, db -> Database.put_number(db, item, cat_id, v) end)}
    end
  end

  defp child_value(name, clock) do
    case NumberFormat.parse(name, Context.number_opts(clock)) do
      {:ok, value} -> value
      :error -> 0.0
    end
  end
end
