defmodule Agenda.TUI.ItemColumnBox do
  @moduledoc """
  The Item Column Properties box (View ▸ Column ▸ Properties with the
  highlight on the item text; User's Guide 3-18 to 3-19, Help "Item
  Column Properties Box"): the section's item column (R55).

    * Section head: F3, SPACE or → picks another category for the section.
    * Set width: Automatically (as wide as the columns leave) or Manually.
      Manually starts at the width the item text has at that moment.
    * Width (Manually) or Minimum width (Automatically): → ← by one.
    * Link with other sections: a linked item column changes with the
      other linked ones; No makes it change alone, Yes takes their
      settings again.

  Each change applies at once and is one undo step, as in Column
  Properties. ESC or ENTER closes the box. Pure.
  """

  alias Agenda.Core
  alias Agenda.Core.View
  alias Agenda.Core.View.ItemColumn
  alias Agenda.TUI.{CategoryScreens, State, Template}

  @layout """
   Section head:             [head              ]
   Set width:                [set          ]
   Width:                    [width ]
   Minimum width:            [minimum ]
   Link with other sections: [linked]
  """

  @hint " SPACE/→ next choice · ← previous · F3 picks the head · ESC closes"

  @doc "Opens the box for the item column of section `sidx`."
  def open(state, sidx), do: State.push(state, %{type: :item_column, sidx: sidx, cursor: 0})

  defp item_column(state, mode), do: Enum.at(State.view(state).sections, mode.sidx).item_column

  # Width shows only when it is set by hand, Minimum width only when it is
  # automatic, so the cursor goes through the fields shown.
  defp fields(state, mode) do
    hidden = if item_column(state, mode).set == :auto, do: :width, else: :minimum
    List.delete(Template.fields(@layout), hidden)
  end

  defp field(state, mode), do: Enum.at(fields(state, mode), mode.cursor)

  def handle(state, mode, key) do
    last = length(fields(state, mode)) - 1
    field = field(state, mode)

    case key do
      k when k in [:esc, :enter] -> State.pop(state)
      :up -> State.put_mode(state, %{mode | cursor: max(mode.cursor - 1, 0)})
      :down -> State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, last)})
      {:f, 3} when field == :head -> pick_head(state, mode)
      k when k in [{:char, " "}, :right] -> change(state, mode, field, 1)
      :left -> change(state, mode, field, -1)
      _ -> state
    end
  end

  defp pick_head(state, mode),
    do: CategoryScreens.open_picker(state, {:change_section, mode.sidx}, nil)

  defp change(state, mode, :head, _step), do: pick_head(state, mode)

  # Manually starts at the width the item text has now, so nothing moves
  defp change(state, mode, :set, _step) do
    case item_column(state, mode) do
      %{set: :auto} -> set(state, mode, set: :manual, width: shown_width(state, mode))
      %{set: :manual} -> set(state, mode, set: :auto)
    end
  end

  defp change(state, mode, field, step) when field in [:width, :minimum],
    do: set(state, mode, [{field, Map.fetch!(item_column(state, mode), field) + step}])

  defp change(state, mode, :linked, _step) do
    linked = not item_column(state, mode).linked
    db = Core.set_item_column_linked(state.db, state.view_id, mode.sidx, linked)
    State.change_db(state, db)
  end

  defp set(state, mode, changes),
    do: State.change_db(state, Core.set_item_column(state.db, state.view_id, mode.sidx, changes))

  defp shown_width(state, mode) do
    view = State.view(state)
    ItemColumn.text_width(item_column(state, mode), View.columns(view, mode.sidx), state.width)
  end

  # --- drawing ---

  @doc "The box's lines, the highlighted setting selected."
  def content(state, mode) do
    items = item_column(state, mode)
    section = Enum.at(State.view(state).sections, mode.sidx)

    values = %{
      head: state.db.categories[section.category_id].name,
      set: if(items.set == :auto, do: "Automatically", else: "Manually"),
      # nil leaves the row out (`Template.render/3`)
      width: if(items.set == :manual, do: Integer.to_string(items.width)),
      minimum: if(items.set == :auto, do: Integer.to_string(items.minimum)),
      linked: if(items.linked, do: "Yes", else: "No")
    }

    Template.render(@layout, values, selected: field(state, mode)) ++ [[], [{:box, @hint}]]
  end
end
