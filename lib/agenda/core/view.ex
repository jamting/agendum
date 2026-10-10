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
  the Show View (R37).
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
    """
    @type t :: %__MODULE__{
            category_id: Agenda.Core.Category.id(),
            collapsed: boolean,
            filter: [{Agenda.Core.Category.id(), Agenda.Core.View.filter_term()}],
            sort: [SortKey.t()] | nil
          }
    defstruct [:category_id, collapsed: false, filter: [], sort: nil]
  end

  defmodule Column do
    @moduledoc """
    A view column headed by a category. `number` is how a numeric column
    shows its numbers and calculations (R29); other columns ignore it.
    """
    @type t :: %__MODULE__{
            category_id: Agenda.Core.Category.id(),
            width: pos_integer,
            number: Agenda.Core.NumberFormat.t()
          }
    defstruct [:category_id, width: 12, number: %Agenda.Core.NumberFormat{}]
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
          match: Agenda.Core.Search.t() | nil
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
    match: nil
  ]
end
