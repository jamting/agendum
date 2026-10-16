defmodule Agendum.Core.View do
  @moduledoc """
  A view is a saved arrangement of the database: a list of sections, each
  headed by a category, plus columns to the right of the item text.

  A section shows every item assigned (directly or by subsumption) to its
  head category. A column shows, for each item, the descendants of the
  column head category to which the item is assigned.

  A view's `filter` shows only items that are (or are not) assigned to
  some categories (R28), or whose date or number is in a range (R28a,
  `Agendum.Core.RangeFilter`); its `sort` keys order the items in every section
  (R36). `match` limits it to items whose text matches a search, as in
  the Show View (R37), or to a list of items (`{:items, ids}`, R43).
  `hide_dependent` hides items still waiting for a prerequisite (R43).
  `hide_column_heads` shows column heads only on the first section head
  on the screen (R57); how a front end draws it is its own.
  `section_separators` draws each section head as a line across, in place
  of the blank line between sections (R58).
  `datebook` makes it a datebook view (R47, `Agendum.Core.Datebook`), whose
  sections are time slots worked out from its settings; its stored
  `sections` are not used. `section_sort` shows the sections in category
  order, alphabetically or numerically by name (`section_order`), instead
  of the order they were added in (User's Guide 15-20).

  Columns belong to sections (R55): each `Section` has its own. A datebook
  view keeps one set in `columns` for all its slots, as its sections are
  not stored; a standard view's `columns` is empty. `columns/2` reads
  either. How columns are added, linked and removed is
  `Agendum.Core.ViewColumns`.
  """

  defmodule SortKey do
    @moduledoc """
    One way to order items (User's Guide chapter 15): by item text, by
    the children of a category (`{:category, id}`; by date for a date
    category, by number for a numeric one), or by line `line` of the note
    of the child an item is in (`{:note, id}`, e.g. a town on line 2 of
    each person's note). `order` is `:asc` or `:desc`; `na` puts items
    without a value at the `:bottom` or `:top`; `sequence` orders a
    category's children as in the `:hierarchy` or alphabetically (`:alpha`).
    """
    @type t :: %__MODULE__{
            on:
              :text
              | {:category, Agendum.Core.Category.id()}
              | {:note, Agendum.Core.Category.id()},
            order: :asc | :desc,
            na: :bottom | :top,
            sequence: :hierarchy | :alpha,
            line: pos_integer
          }
    defstruct on: :text, order: :asc, na: :bottom, sequence: :hierarchy, line: 1
  end

  defmodule ItemColumn do
    @moduledoc """
    A section's item column, the one with the items (R55; User's Guide 3-18
    to 3-19, Help "Item Column Properties Box"). `set` is how its width is
    found: `:auto`, as wide as the section's columns leave but at least
    `minimum`, or `:manual`, `width` wide whatever the columns. `linked`
    item columns are one: a change to one is made to all the linked ones
    of the view (`Agendum.Core.ViewColumns.update_items/3`). `position` is
    its place among the section's columns: how many are left of it
    (User's Guide 5-20); it is the section's own, linked or not.
    """
    @type t :: %__MODULE__{
            set: :auto | :manual,
            width: pos_integer,
            minimum: pos_integer,
            linked: boolean,
            position: non_neg_integer
          }
    defstruct set: :auto, width: 40, minimum: 10, linked: true, position: 0

    @doc """
    How wide the item text is in a screen `screen` wide, beside `columns`:
    3 go to the bullet and the margin, and each column takes its width
    and a space.
    """
    @spec text_width(t, [Agendum.Core.View.Column.t()], pos_integer) :: pos_integer
    def text_width(%__MODULE__{set: :manual, width: width}, _columns, _screen), do: width

    def text_width(%__MODULE__{minimum: minimum}, columns, screen) do
      used = columns |> Enum.map(&(Agendum.Core.View.Column.shown_width(&1) + 1)) |> Enum.sum()
      max(screen - 3 - used, minimum)
    end
  end

  defmodule Section do
    @moduledoc """
    A view section headed by a category. `filter` narrows it further (R28);
    `sort` overrides the view's sort keys (`nil` = use the view's).
    `columns` are the columns it shows (R55), and `item_column` how wide
    its item text is.
    """
    @type t :: %__MODULE__{
            category_id: Agendum.Core.Category.id(),
            collapsed: boolean,
            filter: [{Agendum.Core.Category.id(), Agendum.Core.View.filter_term()}],
            sort: [SortKey.t()] | nil,
            columns: [Agendum.Core.View.Column.t()],
            item_column: ItemColumn.t()
          }
    defstruct [
      :category_id,
      collapsed: false,
      filter: [],
      sort: nil,
      columns: [],
      item_column: %ItemColumn{}
    ]
  end

  defmodule Column do
    @moduledoc """
    A view column headed by a category. `number` is how a numeric column
    shows its numbers and calculations (R29); `date` how a date column
    shows its dates, `nil` for the file's (global defaults, R41a). Other
    columns ignore them.

    `link` (Column Properties ▸ Link with other sections, R55): columns
    of a view with the same `link` are one column shown in several
    sections, so a change to one is made to all of them; `nil` for a
    column in one section only. Each column added to all sections gets a
    link of its own, numbered within the view, so two columns with the
    same head stay two columns, as in Agenda.

    `format` is how a standard column shows an item's assignments (User's
    Guide 5-26 to 5-37): `:name` (Name only, the names of the categories
    under the head it is in), `:parent` (Parent:Category), `:ancestor` (the
    head's child they are under), `:star` (* when the item is in the head),
    `:yes_no` (Y or N), `:zettel` (ours: the item's Zettel id, R73a, for
    every item, whatever the head) or `:note` (Category note: line `note_line` of those
    categories' notes, headed by `title` instead of the head's name).
    Date and numeric columns ignore it.
    """
    @type format :: :name | :parent | :ancestor | :star | :yes_no | :note | :zettel
    @type t :: %__MODULE__{
            category_id: Agendum.Core.Category.id(),
            width: pos_integer,
            number: Agendum.Core.NumberFormat.t(),
            date: Agendum.Core.DateFormat.t() | nil,
            link: pos_integer | nil,
            format: format,
            note_line: pos_integer,
            title: String.t() | nil
          }
    defstruct [
      :category_id,
      width: 12,
      number: %Agendum.Core.NumberFormat{},
      date: nil,
      link: nil,
      format: :name,
      note_line: 1,
      title: nil
    ]

    @doc "The formats a standard column can have, in the order Agenda offers them."
    @spec formats() :: [format]
    def formats, do: [:name, :parent, :ancestor, :star, :yes_no, :note, :zettel]

    @doc """
    How wide the column is on the screen: its width, and 6 more for a
    numeric column's "% tot" beside it (a space and 5).
    """
    @spec shown_width(t) :: pos_integer
    def shown_width(%__MODULE__{width: width, number: %{percent: true}}), do: width + 6
    def shown_width(%__MODULE__{width: width}), do: width
  end

  @typedoc "One filter criterion on a category (R28, R28a)."
  @type filter_term :: :assigned | :not_assigned | Agendum.Core.RangeFilter.term_()

  @type id :: pos_integer
  @type t :: %__MODULE__{
          id: id,
          name: String.t(),
          sections: [Section.t()],
          columns: [Column.t()],
          hide_done: boolean,
          hide_empty: boolean,
          hide_inherited: boolean,
          filter: [{Agendum.Core.Category.id(), Agendum.Core.View.filter_term()}],
          sort: [SortKey.t()],
          match: Agendum.Core.Search.t() | {:items, [Agendum.Core.Item.id()]} | nil,
          hide_dependent: boolean,
          hide_column_heads: boolean,
          section_separators: boolean,
          section_sort: :none | :category | :alpha | :numeric,
          section_order: :asc | :desc,
          datebook: Agendum.Core.Datebook.t() | nil
        }

  defstruct [
    :id,
    :name,
    sections: [],
    columns: [],
    hide_done: false,
    hide_empty: false,
    hide_inherited: false,
    filter: [],
    sort: [],
    match: nil,
    hide_dependent: false,
    hide_column_heads: false,
    section_separators: false,
    section_sort: :none,
    section_order: :asc,
    datebook: nil
  ]

  @typedoc "Where a column is: `{section index, column index}` (R55)."
  @type at :: {non_neg_integer, non_neg_integer}

  @doc """
  The columns of the section at `sidx`; for a datebook view, the columns
  all its slots share, whatever `sidx` is.
  """
  @spec columns(t, non_neg_integer) :: [Column.t()]
  def columns(%__MODULE__{datebook: %Agendum.Core.Datebook{}} = view, _sidx), do: view.columns

  def columns(%__MODULE__{} = view, sidx) do
    # `Enum.at/2` gives nil past the end, and `nil.columns` would raise, so
    # a section index the view does not have reads as no columns
    case Enum.at(view.sections, sidx) do
      nil -> []
      section -> section.columns
    end
  end

  @doc """
  Whether the column at `at` is linked to a column in another section, so
  removing it asks "All sections in view" or "Current section only".
  """
  @spec in_other_sections?(t, at) :: boolean
  def in_other_sections?(%__MODULE__{} = view, {sidx, _} = at),
    do: view |> Agendum.Core.ViewColumns.linked(at) |> Enum.any?(fn {s, _} -> s != sidx end)

  @doc """
  A standard view whose columns are stored in `columns`, as files from
  before columns per section were (R55), gets them in every section,
  linked: each column one link. Other views are returned as they are.
  """
  @spec columns_into_sections(t) :: t
  def columns_into_sections(%__MODULE__{datebook: nil, columns: [_ | _] = columns} = view) do
    columns = numbered_links(columns)

    %{
      view
      | sections: Enum.map(view.sections, &%{&1 | columns: &1.columns ++ columns}),
        columns: []
    }
  end

  def columns_into_sections(%__MODULE__{} = view), do: view

  @doc """
  Columns each linked to every section: link 1, 2, 3 … in order.
  """
  @spec numbered_links([Column.t()]) :: [Column.t()]
  def numbered_links(columns) do
    # with_index(1) numbers from 1, as links are positive
    columns |> Enum.with_index(1) |> Enum.map(fn {c, n} -> %{c | link: n} end)
  end

  @doc """
  Files from formats 25 and 26 (and JSON with `linked`) marked columns
  only as linked or not, and linked columns of a head were one column.
  Now each column is its own: in every section the first linked column
  of a head gets one link, the second another, and so on. `linked` holds
  the places (`{section, column}`) that were linked.
  """
  @spec link_by_head(t, MapSet.t(at)) :: t
  def link_by_head(%__MODULE__{} = view, linked) do
    # {head, n}: the nth linked column of that head in a section
    keys =
      for {section, s} <- Enum.with_index(view.sections) do
        section.columns
        |> Enum.with_index()
        # map_reduce: walks the columns with a count per head (`seen`)
        |> Enum.map_reduce(%{}, fn {c, i}, seen ->
          if MapSet.member?(linked, {s, i}) do
            n = Map.get(seen, c.category_id, 0)
            {{c.category_id, n}, Map.put(seen, c.category_id, n + 1)}
          else
            {nil, seen}
          end
        end)
        |> elem(0)
      end

    numbers =
      keys
      |> List.flatten()
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.with_index(1)
      |> Map.new()

    sections =
      Enum.zip_with(view.sections, keys, fn section, section_keys ->
        columns =
          Enum.zip_with(section.columns, section_keys, &%{&1 | link: numbers[&2]})

        %{section | columns: columns}
      end)

    %{view | sections: sections}
  end
end
