defmodule Agendum.Core.ViewModel do
  @moduledoc """
  Projects a view onto the database: which items appear in which section,
  and what each column shows for each item. This is a pure read model; the
  TUI renders it, and tests can assert on it without a terminal.
  """

  alias Agendum.Core.{Assign, Context, Database, Datebook, DateFormat, NumberFormat, View}
  alias Agendum.Core.View.SortKey

  defmodule Row do
    @moduledoc """
    One item as shown in a section: a cell per column, and per column its
    "% tot" ("12%", "" without a number) or nil when the column shows none
    (Display % of total, R29). `values` holds what each cell shows as
    data, for a front end that formats or sorts it itself (a web page):
    see `Agendum.Core.ViewModel.value/3`. `number` is the item's place
    among the items its section shows, from 1, when the view numbers its
    items (Number items, R79); nil when it does not.
    """
    @type t :: %__MODULE__{
            item: Agendum.Core.Item.t(),
            cells: [String.t()],
            values: [Agendum.Core.ViewModel.value()],
            percents: [String.t() | nil],
            inherited: boolean,
            number: pos_integer | nil
          }
    defstruct [:item, :number, cells: [], values: [], percents: [], inherited: false]
  end

  defmodule SectionModel do
    @moduledoc """
    A section of a built view. `calcs` are the calculation lines shown at
    its bottom (R29): `{calculation, [cell per column]}`, with "" for
    columns that do not show that calculation. In a datebook view (R47)
    `slot` is the time slot it shows; nil in a standard view. `columns`
    are the columns it shows (R55), `item_column` how wide its item text
    is (a datebook slot's is the default), `index` its place among the view's
    stored sections (it may be shown elsewhere when sections are sorted;
    nil for a datebook slot).
    """
    @type t :: %__MODULE__{
            category: Agendum.Core.Category.t(),
            rows: [Row.t()],
            collapsed: boolean,
            calcs: [{NumberFormat.calc(), [String.t()]}],
            slot: Datebook.Slot.t() | nil,
            columns: [View.Column.t()],
            item_column: View.ItemColumn.t(),
            index: non_neg_integer | nil
          }
    defstruct [
      :category,
      :index,
      rows: [],
      collapsed: false,
      calcs: [],
      slot: nil,
      columns: [],
      item_column: %View.ItemColumn{}
    ]
  end

  @doc """
  Builds a view. `today` (a date or an `Agendum.Core.Context`, which also
  gives the date languages) is needed by date filters with relative dates
  (R28a); without it only ISO dates in filters can be read.
  """
  @spec build(Database.t(), View.t(), Agendum.Core.Context.clock() | nil) :: [SectionModel.t()]
  def build(db, view, today \\ nil)

  # A datebook view (R47): a section per slot, each with the items of the
  # Section category dated in it, by date and time unless the view sorts.
  # Its slots need the clock; without one it has none.
  def build(%Database{}, %View{datebook: %Datebook{}}, nil), do: []

  def build(%Database{} = db, %View{datebook: %Datebook{} = d} = view, today) do
    category = db.categories[d.section_category]

    # date words in the filter ("yesterday") are read once, not per item
    filter = Assign.resolve_ranges(db, view.filter, today)

    items =
      db
      |> Database.items_in(category.id)
      |> Enum.reject(&(view.hide_done and &1.done != nil))
      |> Enum.filter(&(Assign.criteria_met?(db, &1.id, filter, today) and shown?(&1, view.match)))
      |> Enum.reject(&(view.hide_dependent and Database.waiting?(db, &1.id)))
      |> Enum.map(&{&1, dated(db, &1.id, d.date_category), dated(db, &1.id, d.end_category)})
      |> Enum.reject(&(elem(&1, 1) == nil))

    d
    |> Datebook.slots(db.date_settings, today)
    |> Enum.map(fn slot ->
      shown =
        for {item, start, stop} <- items, Datebook.in_slot?(slot, start, stop), do: {item, start}

      rows =
        shown
        |> order(db, view.sort)
        |> Enum.map(fn item ->
          %Row{
            item: item,
            cells:
              Enum.map(
                view.columns,
                &cell(db, item, &1.category_id, &1.width, &1.number, cell_opts(&1, today))
              ),
            values: Enum.map(view.columns, &value(db, item, &1.category_id))
          }
        end)

      %SectionModel{
        category: category,
        rows: rows |> percents(db, view.columns) |> numbered(view),
        slot: slot,
        columns: view.columns,
        calcs: calcs(db, view.columns, rows, Context.number_opts(today))
      }
    end)
    |> Enum.reject(&(view.hide_empty and &1.rows == []))
  end

  def build(%Database{} = db, %View{} = view, today) do
    view.sections
    # each section with its index, kept through the sorting
    |> Enum.with_index()
    |> sort_sections(db, view, Context.number_opts(today))
    |> Enum.map(fn {section, index} ->
      category = db.categories[section.category_id]
      # date words in the filters ("yesterday") are read once, not per item
      filter = Assign.resolve_ranges(db, view.filter ++ section.filter, today)

      rows =
        db
        |> Database.items_in(category.id)
        |> Enum.reject(&(view.hide_done and &1.done != nil))
        |> Enum.filter(
          &(Assign.criteria_met?(db, &1.id, filter, today) and shown?(&1, view.match))
        )
        |> Enum.reject(&(view.hide_dependent and Database.waiting?(db, &1.id)))
        |> sort(db, section.sort || view.sort)
        |> Enum.map(fn item ->
          inherited = inherited?(db, item.id, category.id)

          %Row{
            item: item,
            inherited: inherited,
            cells:
              Enum.map(
                section.columns,
                &cell(db, item, &1.category_id, &1.width, &1.number, cell_opts(&1, today))
              ),
            values: Enum.map(section.columns, &value(db, item, &1.category_id))
          }
        end)
        |> Enum.reject(&(view.hide_inherited and &1.inherited))

      %SectionModel{
        category: category,
        index: index,
        rows: rows |> percents(db, section.columns) |> numbered(view),
        collapsed: section.collapsed,
        columns: section.columns,
        item_column: section.item_column,
        calcs: calcs(db, section.columns, rows, Context.number_opts(today))
      }
    end)
    |> Enum.reject(&(view.hide_empty and &1.rows == []))
  end

  # an item's date and time in a date category, or nil
  defp dated(_db, _item_id, nil), do: nil

  defp dated(db, item_id, cat_id) do
    case Database.item_date(db, item_id, cat_id) do
      nil -> nil
      date -> {date, Database.item_time(db, item_id, cat_id)}
    end
  end

  # by date and time (untimed first), then entry order; or by the view's sort
  defp order(shown, _db, []) do
    shown
    |> Enum.sort_by(fn {_item, {date, time}} -> {Date.to_gregorian_days(date), seconds(time)} end)
    |> Enum.map(&elem(&1, 0))
  end

  defp order(shown, db, keys), do: shown |> Enum.map(&elem(&1, 0)) |> sort(db, keys)

  defp seconds(nil), do: -1
  defp seconds(time), do: time |> Time.to_seconds_after_midnight() |> elem(0)

  # The calculation lines of a section: every calculation some numeric
  # column asks for, in Agenda's order.
  # what `cell/6` needs from a column besides its head, width and numbers
  defp cell_opts(column, today),
    do: [today: today, date: column.date, format: column.format, note_line: column.note_line]

  # Number items (R79): each row's place in its section, counting only the
  # rows shown (a hidden done item leaves no gap, as in Agenda).
  # `Enum.with_index/3` with a start of 1 hands each row its number.
  defp numbered(rows, %View{number_items: true}),
    do: rows |> Enum.with_index(1) |> Enum.map(fn {row, n} -> %{row | number: n} end)

  defp numbered(rows, _view), do: rows

  # Each row's "% tot" per column: its number's share of the section's
  # total in a column that shows % of total, nil in the others.
  defp percents(rows, db, columns) do
    totals =
      Enum.map(columns, fn column ->
        if column.number.percent and db.categories[column.category_id].kind == :numeric,
          do:
            rows
            |> Enum.map(&(Database.number(db, &1.item.id, column.category_id) || 0))
            |> Enum.sum()
      end)

    Enum.map(rows, fn row ->
      percents =
        Enum.zip_with(columns, totals, fn
          _column, nil ->
            nil

          column, total ->
            NumberFormat.percent_of(Database.number(db, row.item.id, column.category_id), total)
        end)

      %{row | percents: percents}
    end)
  end

  defp calcs(db, columns, rows, opts) do
    numeric = Enum.filter(columns, &(db.categories[&1.category_id].kind == :numeric))

    wanted =
      NumberFormat.calcs() |> Enum.filter(fn c -> Enum.any?(numeric, &(c in &1.number.calcs)) end)

    for calc <- wanted do
      cells =
        Enum.map(columns, fn column ->
          if column in numeric and calc in column.number.calcs,
            do: calc_cell(db, calc, column, rows, opts),
            else: ""
        end)

      {calc, cells}
    end
  end

  defp calc_cell(db, calc, column, rows, opts) do
    values =
      for row <- rows,
          value = Database.number(db, row.item.id, column.category_id),
          value != nil,
          do: value

    case NumberFormat.calculate(calc, values) do
      nil -> ""
      count when calc == :count -> count |> round() |> Integer.to_string()
      value -> NumberFormat.format(value, column.number, [width: column.width] ++ opts)
    end
  end

  defp shown?(_item, nil), do: true
  defp shown?(item, {:items, ids}), do: item.id in ids
  defp shown?(item, search), do: Agendum.Core.Search.matches?(item, search)

  # Section heads in category order, by name, or by name as a number with
  # the other names last (User's Guide 15-20). The sort is stable.
  defp sort_sections(sections, _db, %View{section_sort: :none}, _opts), do: sections

  defp sort_sections(sections, db, %View{section_sort: :numeric, section_order: order}, opts) do
    {numbers, others} =
      sections
      |> Enum.map(fn {section, _} = pair ->
        {pair, NumberFormat.parse(db.categories[section.category_id].name, opts)}
      end)
      |> Enum.split_with(&match?({_, {:ok, _}}, &1))

    numbers
    |> Enum.sort_by(fn {_, {:ok, n}} -> n end, order)
    |> Enum.concat(others)
    |> Enum.map(&elem(&1, 0))
  end

  defp sort_sections(sections, db, %View{section_sort: :category, section_order: order}, _opts) do
    position =
      db |> Database.hierarchy() |> Enum.with_index() |> Map.new(fn {{id, _}, i} -> {id, i} end)

    Enum.sort_by(sections, fn {section, _} -> position[section.category_id] end, order)
  end

  defp sort_sections(sections, db, %View{section_sort: :alpha, section_order: order}, _opts),
    do:
      Enum.sort_by(
        sections,
        fn {section, _} -> String.downcase(db.categories[section.category_id].name) end,
        order
      )

  @doc """
  Orders items by sort keys (R36). The first key decides; the next breaks
  ties; items equal on every key keep their entry order (the sort is
  stable). Items without a value for a key go to its `na` end.
  """
  @spec sort([Agendum.Core.Item.t()], Database.t(), [SortKey.t()]) :: [Agendum.Core.Item.t()]
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

    date = Database.date_category?(db, head)

    cond do
      numeric ->
        Database.number(db, item.id, head)

      date ->
        case Database.item_date(db, item.id, head) do
          nil ->
            nil

          day ->
            NaiveDateTime.new!(day, Database.item_time(db, item.id, head) || ~T[00:00:00])
        end

      true ->
        children = db.categories[head].children

        case Enum.find_index(children, &Database.member?(db, item.id, &1)) do
          nil ->
            nil

          index when key.sequence == :alpha ->
            String.downcase(db.categories[Enum.at(children, index)].name)

          index ->
            index
        end
    end
  end

  @typedoc """
  What a cell shows, as data (`value/3`): a number (or nil) in a numeric
  column, `{date, time or nil}` (or nil) in a date column, whether the item
  is in a childless head (a Star or Yes/No column, true or false), else the
  ids of the head's categories the cell shows, in its order.
  """
  @type value :: float | nil | {Date.t(), Time.t() | nil} | boolean | [Database.id()]

  @doc """
  What `cell/6` shows for an item in the column headed by `head_id`, as
  data rather than text (`t:value/0`): the same for every format, so a
  front end can format, sort or edit it itself.
  """
  @spec value(Database.t(), Agendum.Core.Item.t(), Database.id()) :: value
  def value(db, item, head_id) do
    head = db.categories[head_id]

    cond do
      head.kind == :numeric ->
        Database.number(db, item.id, head_id)

      Database.date_category?(db, head_id) ->
        case Database.item_date(db, item.id, head_id) do
          nil -> nil
          date -> {date, Database.item_time(db, item.id, head_id)}
        end

      head.children == [] ->
        Database.member?(db, item.id, head_id)

      true ->
        column_entries(db, item.id, head_id)
    end
  end

  @doc """
  The text a column shows for an item: the item's date for a date column,
  in the column's own format (`date:`) or the file's, relative dates
  counted from `today:` (R41a);
  its number in `number`'s format for a numeric column (R29); for a
  standard column, its assignments in the column's `format:` (Name only by
  default: the names of the head's descendants the item is assigned to, or
  `*` for a childless head the item belongs to; `View.Column`, with
  `note_line:` for Category note). When the names do not fit in `width`,
  categories with a short name show it instead (User's Guide 19-2).
  """
  @spec cell(
          Database.t(),
          Agendum.Core.Item.t(),
          Database.id(),
          pos_integer | nil,
          NumberFormat.t(),
          keyword
        ) :: String.t()
  def cell(db, item, head_id, width \\ nil, number \\ %NumberFormat{}, opts \\ []) do
    head = db.categories[head_id]

    cond do
      head.kind == :numeric ->
        case Database.number(db, item.id, head_id) do
          nil ->
            ""

          value ->
            NumberFormat.format(
              value,
              number,
              [width: width] ++ Context.number_opts(opts[:today])
            )
        end

      Database.date_category?(db, head_id) ->
        DateFormat.date_time(
          Database.item_date(db, item.id, head_id),
          Database.item_time(db, item.id, head_id),
          opts[:date] || db.date_format,
          today: opts[:today] && Agendum.Core.Context.today(opts[:today]),
          global: db.date_format
        )

      true ->
        standard_cell(db, item.id, head, width, opts[:format] || :name, opts[:note_line] || 1)
    end
  end

  # A standard column in its Format (User's Guide 5-26 to 5-37).
  # Ours: a Zettel id column shows the item's id, whatever the head (R73a)
  defp standard_cell(db, item_id, _head, _width, :zettel, _line),
    do: Agendum.Core.Facade.Extras.Zettels.zettel(db.items[item_id]) || ""

  defp standard_cell(db, item_id, head, _width, :star, _line),
    do: if(Database.member?(db, item_id, head.id), do: "*", else: "")

  defp standard_cell(db, item_id, head, _width, :yes_no, _line),
    do: if(Database.member?(db, item_id, head.id), do: "Y", else: "N")

  # a childless head has no names to show: * when the item is in it
  defp standard_cell(db, item_id, %{children: []} = head, width, format, line)
       when format != :note,
       do: standard_cell(db, item_id, head, width, :star, line)

  defp standard_cell(db, item_id, head, _width, :note, line) do
    db
    |> column_entries(item_id, head.id)
    |> Enum.map(&note_line(db.categories[&1].note, line))
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(", ")
  end

  defp standard_cell(db, item_id, head, width, format, _line) do
    entries = entries_as(db, column_entries(db, item_id, head.id), head.id, format)
    full = Enum.map_join(entries, ", ", &label(&1, :name))

    if width == nil or String.length(full) <= width,
      do: full,
      else: Enum.map_join(entries, ", ", &label(&1, :short))
  end

  # The categories a column shows, each as the categories its label is
  # made of: itself (Name only), its parent and itself (Parent:Category),
  # or the head's child it is under, once each (Ancestor).
  defp entries_as(db, ids, _head_id, :name), do: Enum.map(ids, &[db.categories[&1]])

  defp entries_as(db, ids, _head_id, :parent) do
    Enum.map(ids, fn id ->
      cat = db.categories[id]
      [db.categories[cat.parent_id], cat]
    end)
  end

  defp entries_as(db, ids, head_id, :ancestor) do
    ids
    |> Enum.map(fn id ->
      # the ancestors, nearest first, end at MAIN; the one just under the
      # head is the last before the head (or the category itself)
      chain = [id | Database.ancestors(db, id)]
      chain |> Enum.take_while(&(&1 != head_id)) |> List.last()
    end)
    |> Enum.uniq()
    |> Enum.map(&[db.categories[&1]])
  end

  defp label(categories, :name), do: Enum.map_join(categories, ":", & &1.name)
  defp label(categories, :short), do: Enum.map_join(categories, ":", &(&1.short_name || &1.name))

  @doc """
  Line `n` of a note as a Category note column shows it: without the
  label before a colon ("Telephone: 555-1234" shows "555-1234"), trimmed;
  "" when the note has no such line (User's Guide 5-36).
  """
  @spec note_line(String.t(), pos_integer) :: String.t()
  def note_line(note, n) do
    line = note |> String.split("\n") |> Enum.at(n - 1, "")

    case String.split(line, ":", parts: 2) do
      [_label, value] -> String.trim(value)
      [text] -> String.trim(text)
    end
  end

  @doc """
  A column's head as shown above it: a Category note column's title, if
  it has one; otherwise the head category's name, or its short name when
  the name does not fit (`column_label/3`).
  """
  @spec column_head(Database.t(), View.Column.t()) :: String.t()
  def column_head(_db, %View.Column{format: format, title: title})
      when format in [:note, :zettel] and is_binary(title),
      do: title

  def column_head(_db, %View.Column{format: :zettel, width: width}),
    do: String.slice("Zettel id", 0, width)

  def column_head(db, column), do: column_label(db, column.category_id, column.width)

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

  @doc """
  The category an item's entry in `column` stands for, whose note the
  note symbol and NOTE (F5) are about (User's Guide 12-2): the first
  category the entry shows, or the head itself for an item assigned to
  the head (a Star or Yes/No entry, or a childless head's `*`). A date or
  a number is no category: nil, as for an empty entry.
  """
  @spec entry_category(Database.t(), Database.id(), View.Column.t()) :: Database.id() | nil
  def entry_category(db, item_id, %View.Column{category_id: head_id}) do
    if db.categories[head_id].kind == :numeric or Database.date_category?(db, head_id) do
      nil
    else
      case column_entries(db, item_id, head_id) do
        # `[first | _]` matches a list with at least one element
        [first | _] -> first
        # an `if` without `else` gives nil when its test fails
        [] -> if Database.explicit?(db, item_id, head_id), do: head_id
      end
    end
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
    cat_id != db.main_id and not Database.date_category?(db, cat_id) and
      not Database.explicit?(db, item_id, cat_id)
  end
end
