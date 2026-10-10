defmodule Agenda.Core.Category do
  @moduledoc """
  A node in the category hierarchy.

  `kind` is `:standard` for ordinary categories, `:date` for date categories
  (Entry, When, Done), whose membership derives from an item's date fields,
  or `:numeric` for categories that hold a number for each item assigned
  to them (R29; the numbers are in `Database.numbers`).

  * `exclusive` – the children of this category are mutually exclusive: an
    item can be assigned to at most one of them.
  * `match_name` – the category takes part in automatic assignment: an item
    whose text contains the category name (or `short_name`) is assigned to it.
  * `conditions` – assignment conditions (R15): `{category_id, :assigned}`
    or `{category_id, :not_assigned}`, or a date or numeric range on a date
    or numeric category (R15a, as in `Agenda.Core.RangeFilter`). Items that
    meet all of them (either of those naming mutually exclusive categories)
    are assigned here.
  * `also_match` – text conditions (R15d, `Agenda.Core.TextCondition`):
    items whose text meets them are assigned here, like the name does.
  * `also_assign` – category-to-category links (patent FIG. 6): items
    assigned here are also assigned to these categories.
  """

  @type id :: pos_integer
  @type kind :: :standard | :date | :numeric
  @type t :: %__MODULE__{
          id: id,
          name: String.t(),
          short_name: String.t() | nil,
          parent_id: id | nil,
          children: [id],
          kind: kind,
          exclusive: boolean,
          match_name: boolean,
          also_assign: [id],
          conditions: [{id, :assigned | :not_assigned | Agenda.Core.RangeFilter.term_()}],
          also_match: String.t(),
          note: String.t()
        }

  defstruct [
    :id,
    :name,
    short_name: nil,
    parent_id: nil,
    children: [],
    kind: :standard,
    exclusive: false,
    match_name: true,
    also_assign: [],
    conditions: [],
    also_match: "",
    note: ""
  ]
end
