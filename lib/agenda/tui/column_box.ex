defmodule Agenda.TUI.ColumnBox do
  @moduledoc """
  The Column Properties box of a standard column (View ▸ Column ▸
  Properties; User's Guide 3-18 to 3-19, screenshot 127): its head, width,
  category type, and Link with other sections (R55). Numeric and date
  columns have boxes of their own so far (`Agenda.TUI.ColumnProperties`,
  `Agenda.TUI.DateColumnBox`).

  The box is drawn from `@layout` (`Agenda.TUI.Template`), Agenda's two
  columns; the cursor goes through its fields in reading order. → and ←
  change the width by one; SPACE, → or ← flip the link. Each change applies
  at once to the column and the columns linked to it, and is one undo
  step. The head and the type are shown, not changed here. ESC or ENTER
  closes the box. Pure.
  """

  alias Agenda.Core
  alias Agenda.Core.{Database, View}
  alias Agenda.TUI.{State, Template}

  @layout """
   Column head: [head          ]  Category type:            [type    ]
   Width:       [width ]          Link with other sections: [linked  ]

   SPACE/→ next choice · ← previous · ESC closes
  """
  @rows Template.fields(@layout)

  @doc "Opens the box for the column at `at` (`{section, column}`)."
  def open(state, at),
    do: State.push(state, %{type: :standard_column_props, column: at, cursor: 0})

  @doc "The column the box is for."
  def column(state, %{column: {sidx, index}}),
    do: state |> State.view() |> View.columns(sidx) |> Enum.at(index)

  def handle(state, mode, key) do
    row = Enum.at(@rows, mode.cursor)

    case key do
      k when k in [:esc, :enter] -> State.pop(state)
      :up -> State.put_mode(state, %{mode | cursor: max(mode.cursor - 1, 0)})
      :down -> State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, length(@rows) - 1)})
      k when k in [{:char, " "}, :right] -> change(state, mode, row, 1)
      :left -> change(state, mode, row, -1)
      _ -> state
    end
  end

  defp change(state, mode, :width, step),
    do: State.change_db(state, Core.resize_column(state.db, state.view_id, mode.column, step))

  defp change(state, mode, :linked, _step) do
    linked = not column(state, mode).linked
    State.change_db(state, Core.set_column_linked(state.db, state.view_id, mode.column, linked))
  end

  defp change(state, _mode, :head, _step),
    do: State.error(state, "To show another category, remove the column and add one (ALT-R)")

  defp change(state, _mode, :type, _step),
    do: State.error(state, "A category's type is changed in its Category Properties")

  @doc "The box's lines, the highlighted setting selected."
  def content(state, mode) do
    column = column(state, mode)

    values = %{
      head: state.db.categories[column.category_id].name,
      type: type(state.db, column.category_id),
      width: Integer.to_string(column.width),
      linked: if(column.linked, do: "Yes", else: "No")
    }

    Template.render(@layout, values, selected: Enum.at(@rows, mode.cursor))
  end

  defp type(db, cat_id) do
    cond do
      db.categories[cat_id].kind == :numeric -> "Numeric"
      Database.date_category?(db, cat_id) -> "Date"
      true -> "Standard"
    end
  end
end
