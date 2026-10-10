defmodule Agenda.Core.ViewModel do
  @moduledoc """
  Projects a view onto the database: which items appear in which section,
  and what each column shows for each item. This is a pure read model; the
  TUI renders it, and tests can assert on it without a terminal.
  """

  alias Agenda.Core.{Assign, Database, DateFormat, NumberFormat, View}
  alias Agenda.Core.View.SortKey

  defmodule Row do
    @moduledoc "One item as shown in a section."
    @type t :: %__MODULE__{item: Agenda.Core.Item.t(), cells: [String.t()], inherited: boolean}
    defstruct [:item, cells: [], inherited: false]
  end

  defmodule SectionModel do
    @moduledoc """
    A section of a built view. `calcs` are the calculation lines shown at
    its bottom (R29): `{calculation, [cell per column]}`, with "" for
    columns that do not show that calculation.
    """
    @type t :: %__MODULE__{
            category: Agenda.Core.Category.t(),
            rows: [Row.t()],
            collapsed: boolean,
            calcs: [{NumberFormat.calc(), [String.t()]}]
          }
    defstruct [:category, rows: [], collapsed: false, calcs: []]
  end

  @doc """
  Builds a view. `today` is needed by date filters with relative dates
  (R28a); without it only ISO dates in filters can be read.
  """
  @spec build(Database.t(), View.t(), Date.t() | nil) :: [SectionModel.t()]
  def build(%Database{} = db, %View{} = view, today \\ nil) do
    view.sections
    |> sort_sections(db, view)
    |> Enum.map(fn section ->
      category = db.categories[section.category_id]

      rows =
        db
        |> Database.items_in(category.id)
        |> Enum.reject(&(view.hide_done and &1.done != nil))
        |> Enum.filter(&Assign.criteria_met?(db, &1.id, view.filter ++ section.filter, today))
        |> Enum.filter(&(view.match == nil or Agenda.Core.Search.matches?(&1, view.match)))
        |> sort(db, section.sort || view.sort)
        |> Enum.map(fn item ->
          inherited = inherited?(db, item.id, category.id)

          %Row{
            item: item,
            inherited: inherited,
            cells: Enum.map(view.columns, &cell(db, item, &1.category_id, &1.width, &1.number))
          }
        end)
        |> Enum.reject(&(view.hide_inherited and &1.inherited))

      %SectionModel{
        category: category,
        rows: rows,
        collapsed: section.collapsed,
        calcs: calcs(db, view.columns, rows)
      }
    end)
    |> Enum.reject(&(view.hide_empty and &1.rows == []))
  end

  # The calculation lines of a section: every calculation some numeric
  # column asks for, in Agenda's order.
  defp calcs(db, columns, rows) do
    numeric = Enum.filter(columns, &(db.categories[&1.category_id].kind == :numeric))

    wanted =
      NumberFormat.calcs() |> Enum.filter(fn c -> Enum.any?(numeric, &(c in &1.number.calcs)) end)

    for calc <- wanted do
      cells =
        Enum.map(columns, fn column ->
          if column in numeric and calc in column.number.calcs,
            do: calc_cell(db, calc, column, rows),
            else: ""
        end)

      {calc, cells}
    end
  end

  defp calc_cell(db, calc, column, rows) do
    values =
      for row <- rows,
          value = Database.number(db, row.item.id, column.category_id),
          value != nil,
          do: value

    case NumberFormat.calculate(calc, values) do
      nil -> ""
      count when calc == :count -> count |> round() |> Integer.to_string()
      value -> NumberFormat.format(value, column.number, width: column.width)
    end
  end

  # Section heads in category order, by name, or by name as a number with
  # the other names last (User's Guide 15-20). The sort is stable.
  defp sort_sections(sections, _db, %View{section_sort: :none}), do: sections

  defp sort_sections(sections, db, %View{section_sort: :numeric, section_order: order}) do
    {numbers, others} =
      sections
      |> Enum.map(&{&1, NumberFormat.parse(db.categories[&1.category_id].name)})
      |> Enum.split_with(&match?({_, {:ok, _}}, &1))

    numbers
    |> Enum.sort_by(fn {_, {:ok, n}} -> n end, order)
    |> Enum.concat(others)
    |> Enum.map(&elem(&1, 0))
  end

  defp sort_sections(sections, db, %View{section_sort: :category, section_order: order}) do
    position =
      db |> Database.hierarchy() |> Enum.with_index() |> Map.new(fn {{id, _}, i} -> {id, i} end)

    Enum.sort_by(sections, &position[&1.category_id], order)
  end

  defp sort_sections(sections, db, %View{section_sort: :alpha, section_order: order}),
    do: Enum.sort_by(sections, &String.downcase(db.categories[&1.category_id].name), order)

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

  # Line `line` of the note on the first child of `head` the item is in.
  defp sort_value(db, %SortKey{on: {:note, head}, line: line}, item) do
    with child when child != nil <-
           Enum.find(db.categories[head].children, &Database.member?(db, item.id, &1)),
         text when is_binary(text) <-
           db.categories[child].note |> String.split("\n") |> Enum.at(line - 1),
         text when text != "" <- String.trim(text) do
      String.downcase(text)
    else
      _ -> nil
    end
  end

  defp sort_value(db, %SortKey{on: {:category, head}} = key, item) do
    numeric = db.categories[head].kind == :numeric

    case Database.date_field(db, head) do
      nil when numeric ->
        Database.number(db, item.id, head)

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
  its number in `number`'s format for a numeric column (R29); `*` for a
  childless ("yes/no") column head the item belongs to; otherwise the names
  of the head's descendants the item is assigned to. When those names do
  not fit in `width`, categories with a short name show it instead (User's
  Guide 19-2).
  """
  @spec cell(
          Database.t(),
          Agenda.Core.Item.t(),
          Database.id(),
          pos_integer | nil,
          NumberFormat.t()
        ) :: String.t()
  def cell(db, item, head_id, width \\ nil, number \\ %NumberFormat{}) do
    head = db.categories[head_id]

    cond do
      head.kind == :numeric ->
        case Database.number(db, item.id, head_id) do
          nil -> ""
          value -> NumberFormat.format(value, number, width: width)
        end

      field = Database.date_field(db, head_id) ->
        if field == :when,
          do: DateFormat.date_time(item.when, item.when_time, db.date_format),
          else: DateFormat.date(Map.get(item, field), db.date_format)

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
