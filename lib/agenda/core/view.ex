defmodule Agenda.Core.View do
  @moduledoc """
  A view is a saved arrangement of the database: a list of sections, each
  headed by a category, plus columns to the right of the item text.

  A section shows every item assigned (directly or by subsumption) to its
  head category. A column shows, for each item, the descendants of the
  column head category to which the item is assigned.

  A view's `filter` shows only items that are (or are not) assigned to
  some categories (R28), or whose date or number is in a range (R28a,
  `Agenda.Core.RangeFilter`); its `sort` keys order the items in every section
  (R36). `match` limits it to items whose text matches a search, as in
  the Show View (R37), or to a list of items (`{:items, ids}`, R43).
  `hide_dependent` hides items still waiting for a prerequisite (R43).
  `datebook` makes it a datebook view (R47, `Agenda.Core.Datebook`), whose
  sections are time slots worked out from its settings; its stored
  `sections` are not used. `section_sort` shows the sections in category
  order, alphabetically or numerically by name (`section_order`), instead
  of the order they were added in (User's Guide 15-20).

  Columns belong to sections (R55): each `Section` has its own. A datebook
  view keeps one set in `columns` for all its slots, as its sections are
  not stored; a standard view's `columns` is empty. `columns/2` reads
  either. How columns are added, linked and removed is
  `Agenda.Core.ViewColumns`.
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
              :text | {:category, Agenda.Core.Category.id()} | {:note, Agenda.Core.Category.id()},
            order: :asc | :desc,
            na: :bottom | :top,
            sequence: :hierarchy | :alpha,
            line: pos_integer
          }
    defstruct on: :text, order: :asc, na: :bottom, sequence: :hierarchy, line: 1
  end

  defmodule Section do
    @moduledoc """
    A view section headed by a category. `filter` narrows it further (R28);
    `sort` overrides the view's sort keys (`nil` = use the view's).
    `columns` are the columns it shows (R55).
    """
    @type t :: %__MODULE__{
            category_id: Agenda.Core.Category.id(),
            collapsed: boolean,
            filter: [{Agenda.Core.Category.id(), Agenda.Core.View.filter_term()}],
            sort: [SortKey.t()] | nil,
            columns: [Agenda.Core.View.Column.t()]
          }
    defstruct [:category_id, collapsed: false, filter: [], sort: nil, columns: []]
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
    """
    @type t :: %__MODULE__{
            category_id: Agenda.Core.Category.id(),
            width: pos_integer,
            number: Agenda.Core.NumberFormat.t(),
            date: Agenda.Core.DateFormat.t() | nil,
            link: pos_integer | nil
          }
    defstruct [
      :category_id,
      width: 12,
      number: %Agenda.Core.NumberFormat{},
      date: nil,
      link: nil
    ]
  end

  @typedoc "One filter criterion on a category (R28, R28a)."
  @type filter_term :: :assigned | :not_assigned | Agenda.Core.RangeFilter.term_()

  @type id :: pos_integer
  @type t :: %__MODULE__{
          id: id,
          name: String.t(),
          sections: [Section.t()],
          columns: [Column.t()],
          hide_done: boolean,
          hide_empty: boolean,
          hide_inherited: boolean,
          filter: [{Agenda.Core.Category.id(), Agenda.Core.View.filter_term()}],
          sort: [SortKey.t()],
          match: Agenda.Core.Search.t() | {:items, [Agenda.Core.Item.id()]} | nil,
          hide_dependent: boolean,
          section_sort: :none | :category | :alpha | :numeric,
          section_order: :asc | :desc,
          datebook: Agenda.Core.Datebook.t() | nil
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
  def columns(%__MODULE__{datebook: %Agenda.Core.Datebook{}} = view, _sidx), do: view.columns

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
    do: view |> Agenda.Core.ViewColumns.linked(at) |> Enum.any?(fn {s, _} -> s != sidx end)

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
