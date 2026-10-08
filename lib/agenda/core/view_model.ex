defmodule Agenda.Core.ViewModel do
  @moduledoc """
  Projects a view onto the database: which items appear in which section,
  and what each column shows for each item. This is a pure read model; the
  TUI renders it, and tests can assert on it without a terminal.
  """

  alias Agenda.Core.{Database, DateParser, View}

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
        |> Enum.map(fn item ->
          inherited = inherited?(db, item.id, category.id)

          %Row{
            item: item,
            inherited: inherited,
            cells: Enum.map(view.columns, &cell(db, item, &1.category_id))
          }
        end)
        |> Enum.reject(&(view.hide_inherited and &1.inherited))

      %SectionModel{category: category, rows: rows, collapsed: section.collapsed}
    end)
    |> Enum.reject(&(view.hide_empty and &1.rows == []))
  end

  @doc """
  The text a column shows for an item: the item's date for a date column;
  `*` for a childless ("yes/no") column head the item belongs to; otherwise
  the names of the head's descendants the item is assigned to.
  """
  @spec cell(Database.t(), Agenda.Core.Item.t(), Database.id()) :: String.t()
  def cell(db, item, head_id) do
    head = db.categories[head_id]

    cond do
      field = Database.date_field(db, head_id) ->
        DateParser.format(Map.get(item, field))

      head.children == [] ->
        if Database.member?(db, item.id, head_id), do: "*", else: ""

      true ->
        db
        |> column_entries(item.id, head_id)
        |> Enum.map_join(", ", &db.categories[&1].name)
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
    cat_id != db.main_id and Database.date_field(db, cat_id) == nil and
      not Database.explicit?(db, item_id, cat_id)
  end
end
