defmodule Agenda.Core.View do
  @moduledoc """
  A view is a saved arrangement of the database: a list of sections, each
  headed by a category, plus columns to the right of the item text.

  A section shows every item assigned (directly or by subsumption) to its
  head category. A column shows, for each item, the descendants of the
  column head category to which the item is assigned.
  """

  defmodule Section do
    @moduledoc "A view section headed by a category."
    @type t :: %__MODULE__{category_id: Agenda.Core.Category.id(), collapsed: boolean}
    defstruct [:category_id, collapsed: false]
  end

  defmodule Column do
    @moduledoc "A view column headed by a category."
    @type t :: %__MODULE__{category_id: Agenda.Core.Category.id(), width: pos_integer}
    defstruct [:category_id, width: 12]
  end

  @type id :: pos_integer
  @type t :: %__MODULE__{
          id: id,
          name: String.t(),
          sections: [Section.t()],
          columns: [Column.t()],
          hide_done: boolean,
          hide_empty: boolean,
          hide_inherited: boolean
        }

  defstruct [
    :id,
    :name,
    sections: [],
    columns: [],
    hide_done: false,
    hide_empty: false,
    hide_inherited: false
  ]
end
