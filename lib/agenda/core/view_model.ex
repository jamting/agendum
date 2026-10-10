defmodule Agenda.Core.ViewModel do
  @moduledoc """
  Projects a view onto the database: which items appear in which section,
  and what each column shows for each item. This is a pure read model; the
  TUI renders it, and tests can assert on it without a terminal.
  """

  alias Agenda.Core.{Assign, Database, DateParser, View}
  alias Agenda.Core.View.SortKey

  defmodule Row do
    @moduledoc "One item as shown in a section."
    @type t :: %__MODULE__{item: Agenda.Core.Item.t(), cells: [String.t()], inherited: boolean}
    defstruct [:item, cells: [], inherited: false]
  end

  defmodule SectionModel do
    @moduledoc "A section of a built view."
    @type t :: %__MODULE__{
            category: Agenda.Core.Category.t(),
            rows: [Row.t()],
            collapsed: boolean
          }
    defstruct [:category, rows: [], collapsed: false]
  end

  @spec build(Database.t(), View.t()) :: [SectionModel.t()]
  def build(%Database{} = db, %View{} = view) do
    view.sections
    |> Enum.map(fn section ->
      category = db.categories[section.category_id]

      rows =
        db
        |> Database.items_in(category.id)
        |> Enum.reject(&(view.hide_done and &1.done != nil))
        |> Enum.filter(&Assign.criteria_met?(db, &1.id, view.filter ++ section.filter))
        |> Enum.filter(&(view.match == nil or Agenda.Core.Search.matches?(&1, view.match)))
        |> sort(db, section.sort || view.sort)
        |> Enum.map(fn item ->
          inherited = inherited?(db, item.id, category.id)

          %Row{
            item: item,
            inherited: inherited,
            cells: Enum.map(view.columns, &cell(db, item, &1.category_id, &1.width))
          }
        end)
        |> Enum.reject(&(view.hide_inherited and &1.inherited))

      %SectionModel{category: category, rows: rows, collapsed: section.collapsed}
    end)
    |> Enum.reject(&(view.hide_empty and &1.rows == []))
  end

  @doc """
  Orders items by sort keys (R36). The first key decides; the next breaks
  ties; items equal on every key keep their entry order (the sort is
  stable). Items without a value for a key go to its `na` end.
  """
  @spec sort([Agenda.Core.Item.t()], Database.t(), [SortKey.t()]) :: [Agenda.Core.Item.t()]
  def sort(items, _db, []), do: items

  def sort(items, db, keys) do
    Enum.sort(items, fn a, b -> compare(db, keys, a, b) != :gt end)
  end

  defp compare(_db, [], _a, _b), do: :eq

  defp compare(db, [key | rest], a, b) do
    case compare_key(key, sort_value(db, key, a), sort_value(db, key, b)) do
      :eq -> compare(db, rest, a, b)
      other -> other
    end
  end

  defp compare_key(_key, nil, nil), do: :eq
  defp compare_key(%SortKey{na: :bottom}, nil, _), do: :gt
  defp compare_key(%SortKey{na: :bottom}, _, nil), do: :lt
  defp compare_key(%SortKey{na: :top}, nil, _), do: :lt
  defp compare_key(%SortKey{na: :top}, _, nil), do: :gt

  defp compare_key(%SortKey{order: order}, x, y) do
    result =
      cond do
        x == y -> :eq
        less?(x, y) -> :lt
        true -> :gt
      end

    if order == :desc, do: flip(result), else: result
  end

  defp less?(%Date{} = x, %Date{} = y), do: Date.compare(x, y) == :lt
  defp less?(%NaiveDateTime{} = x, %NaiveDateTime{} = y), do: NaiveDateTime.compare(x, y) == :lt
  defp less?(x, y), do: x < y

  defp flip(:lt), do: :gt
  defp flip(:gt), do: :lt
  defp flip(:eq), do: :eq

  # The value an item sorts by for one key, or nil when it has none.
  defp sort_value(_db, %SortKey{on: :text}, item) do
    case String.trim(item.text) do
      "" -> nil
      text -> String.downcase(text)
    end
  end

  defp sort_value(db, %SortKey{on: {:category, head}} = key, item) do
    case Database.date_field(db, head) do
      nil ->
        children = db.categories[head].children

        case Enum.find_index(children, &Database.member?(db, item.id, &1)) do
          nil ->
            nil

          index when key.sequence == :alpha ->
            String.downcase(db.categories[Enum.at(children, index)].name)

          index ->
            index
        end

      :when ->
        if item.when, do: NaiveDateTime.new!(item.when, item.when_time || ~T[00:00:00])

      field ->
        Map.get(item, field)
    end
  end

  @doc """
  The text a column shows for an item: the item's date for a date column;
  `*` for a childless ("yes/no") column head the item belongs to; otherwise
  the names of the head's descendants the item is assigned to. When those
  names do not fit in `width`, categories with a short name show it
  instead (User's Guide 19-2).
  """
  @spec cell(Database.t(), Agenda.Core.Item.t(), Database.id(), pos_integer | nil) :: String.t()
  def cell(db, item, head_id, width \\ nil) do
    head = db.categories[head_id]

    cond do
      field = Database.date_field(db, head_id) ->
        if field == :when,
          do: DateParser.format_when(item.when, item.when_time),
          else: DateParser.format(Map.get(item, field))

      head.children == [] ->
        if Database.member?(db, item.id, head_id), do: "*", else: ""

      true ->
        categories = db |> column_entries(item.id, head_id) |> Enum.map(&db.categories[&1])
        full = Enum.map_join(categories, ", ", & &1.name)

        if width == nil or String.length(full) <= width,
          do: full,
          else: Enum.map_join(categories, ", ", &(&1.short_name || &1.name))
    end
  end

  @doc """
  A column head as shown above a column `width` characters wide: the
  category's name, or its short name when the name does not fit.
  """
  @spec column_label(Database.t(), Database.id(), pos_integer) :: String.t()
  def column_label(db, cat_id, width) do
    category = db.categories[cat_id]

    if String.length(category.name) <= width,
      do: category.name,
      else: category.short_name || category.name
  end

  @doc "Descendants of `head_id` the item is explicitly assigned to, in hierarchy order."
  @spec column_entries(Database.t(), Database.id(), Database.id()) :: [Database.id()]
  def column_entries(db, item_id, head_id) do
    explicit = Database.explicit_categories(db, item_id)
    db |> Database.descendants(head_id) |> Enum.filter(&MapSet.member?(explicit, &1))
  end

  # An item is "inherited" in a section when it is there only through
  # a descendant of the section head, not by a direct link.
  defp inherited?(db, item_id, cat_id) do
    cat_id != db.main_id and Database.date_field(db, cat_id) == nil and
      not Database.explicit?(db, item_id, cat_id)
  end
end
