defmodule Agenda.TUI.ColumnAddBox do
  @moduledoc """
  The Column Add box (View ▸ Column ▸ Add; User's Guide 3-15 to 3-18):
  the settings of a column before it is added.

    * Column head: F3, SPACE or → opens the picker (the whole hierarchy,
      where INS makes a new category); ENTER without a head does too.
    * Category type: the head's, shown (a category's type is changed in
      its Category Properties).
    * Width: → ← by one; until changed, the core's default for the head
      (16 for a date category, 12 for others).
    * Position: Right of current column (Agenda's default) or Left.
    * Insert in: All sections or Current section, starting at the file's
      Insert new columns in, which it overrides for this column (R55).

  The settings live in the box's mode until ENTER adds the column, so the
  whole box is one database change and one undo step. ALT-R and ALT-L
  skip the box: they open the picker and use the file's setting. Pure.
  """

  alias Agenda.Core
  alias Agenda.Core.Database
  alias Agenda.TUI.{CategoryScreens, State, Template}

  @layout """
   Column head: [head          ]  Category type: [type    ]
   Width:       [width ]
   Position:    [position              ]
   Insert in:   [insert_in      ]
  """

  @hint " SPACE/→ next choice · ← previous · F3 picks the head · ENTER adds"
  @fields Template.fields(@layout)

  @doc """
  Opens the box for a column beside the highlighted one: `sidx` is its
  section, `col` the view's column cursor (0 on the item text).
  """
  def open(state, sidx, col) do
    State.push(state, %{
      type: :column_add,
      sidx: sidx,
      col: col,
      head: nil,
      width: nil,
      position: :right,
      insert_in: state.db.insert_columns,
      cursor: 0
    })
  end

  @doc "The picker chose the head (`Picker.pick/3`)."
  def set_head(state, id), do: update(state, &%{&1 | head: id})

  # the box may not be on top (the picker just closed above it), so it is
  # found by its type, as `ScheduleBox` does
  defp update(state, fun) do
    case Enum.find_index(state.modes, &(&1.type == :column_add)) do
      nil -> state
      i -> %{state | modes: List.update_at(state.modes, i, fun)}
    end
  end

  def handle(state, mode, key) do
    last = length(@fields) - 1
    field = Enum.at(@fields, mode.cursor)

    case key do
      :esc -> State.pop(state)
      :enter when mode.head == nil -> pick_head(state)
      :enter -> add(state, mode)
      :up -> State.put_mode(state, %{mode | cursor: max(mode.cursor - 1, 0)})
      :down -> State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, last)})
      {:f, 3} when field == :head -> pick_head(state)
      k when k in [{:char, " "}, :right] -> change(state, mode, field, 1)
      :left -> change(state, mode, field, -1)
      _ -> state
    end
  end

  defp pick_head(state), do: CategoryScreens.open_picker(state, :column_add, nil)

  defp change(state, _mode, :head, _step), do: pick_head(state)

  defp change(state, _mode, :type, _step),
    do: State.error(state, "A category's type is changed in its Category Properties")

  defp change(state, mode, :width, step),
    do: State.put_mode(state, %{mode | width: max(3, width(state, mode) + step)})

  # two choices each, so any step flips them
  defp change(state, mode, :position, _step),
    do: State.put_mode(state, %{mode | position: flip(mode.position, :right, :left)})

  defp change(state, mode, :insert_in, _step),
    do: State.put_mode(state, %{mode | insert_in: flip(mode.insert_in, :all, :section)})

  # the other of `a` and `b`: a variable named twice in a pattern must be
  # the same value both times, so the first clause matches `value == a`
  defp flip(a, a, b), do: b
  defp flip(_value, a, _b), do: a

  # The column goes right or left of the highlighted column or of the item
  # text (R55). The highlight ends on the new column: columns are counted
  # from 0, the cursor from 1 (0 is the item text).
  defp add(state, mode) do
    side = if mode.position == :right, do: :right_of, else: :left_of
    place = {side, if(mode.col == 0, do: :items, else: mode.col - 1)}
    index = Agenda.Core.ViewColumns.insert_index(State.view(state), mode.sidx, place)

    db =
      Core.add_column(
        state.db,
        state.view_id,
        mode.head,
        {mode.sidx, place},
        mode.width,
        mode.insert_in
      )

    %{State.change_db(State.pop(state), db) | col: index + 1}
  end

  # the width chosen, or the core's default for the head
  defp width(_state, %{width: width}) when width != nil, do: width
  defp width(state, mode), do: Core.default_column_width(state.db, mode.head)

  # --- drawing ---

  @doc "The box's lines, the highlighted setting selected."
  def content(state, mode) do
    values = %{
      head: if(mode.head, do: state.db.categories[mode.head].name, else: "(F3 to pick)"),
      type: type(state, mode.head),
      width: Integer.to_string(width(state, mode)),
      position:
        if(mode.position == :right, do: "Right of current column", else: "Left of current column"),
      insert_in: if(mode.insert_in == :all, do: "All sections", else: "Current section")
    }

    Template.render(@layout, values, selected: Enum.at(@fields, mode.cursor)) ++
      [[], [{:box, @hint}]]
  end

  defp type(_state, nil), do: ""

  defp type(state, id) do
    cond do
      state.db.categories[id].kind == :numeric -> "Numeric"
      Database.date_category?(state.db, id) -> "Date"
      true -> "Standard"
    end
  end
end
