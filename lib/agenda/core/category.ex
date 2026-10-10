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
  * `actions` – actions run when an item joins the category (R15b):
    `{category, :remove}` breaks an assignment; on a date or numeric
    category `{category, {:set, value}}` sets the date (an expression read
    when it runs) or number and `:clear` removes it.
  * `special` – `:done` or `:discard`: the special action (R15b).
  * `also_assign` – category-to-category links (patent FIG. 6): items
    assigned here are also assigned to these categories.
  * `excludes` – negative links (R9, patent FIG. 6; not in Agenda 2.0):
    categories that may not share an item with this one. Kept on both
    categories of a pair.
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
          excludes: [id],
          conditions: [{id, :assigned | :not_assigned | Agenda.Core.RangeFilter.term_()}],
          also_match: String.t(),
          actions: [{id, :remove | :clear | {:set, String.t() | float}}],
          special: :done | :discard | nil,
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
    excludes: [],
    conditions: [],
    also_match: "",
    actions: [],
    special: nil,
    note: ""
  ]
end
