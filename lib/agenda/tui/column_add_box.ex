defmodule Agenda.TUI.ColumnAddBox do
  @moduledoc """
  The Column Add box (View ▸ Column ▸ Add; User's Guide 3-15 to 3-18):
  the settings of a column before it is added.

    * Column head: typing a name gives the category of that name, or a
      new one (`Agenda.TUI.FieldTyping`); F3, SPACE or → opens the picker
      (the whole hierarchy, where INS makes a new category); ENTER without
      a head does too.
    * Category type (User's Guide 3-17): Standard, Date or Numeric. A
      standard head (or none yet) can be given another type, which it gets
      when the column is added, after the same question Category
      Properties asks when children or items would change; a date or
      numeric head keeps its type, as in Agenda.
    * Width: → ← by one; until changed, the core's default for the type
      (16 for a date category, 2 for a Star or Yes/No column, 12 for
      others).
    * Format, for a standard column (R56): Name only, Parent:Category,
      Ancestor, Star, Yes/No or Category note, which adds Line number and
      a typed Column title.
    * Position: Right of current column (Agenda's default) or Left.
    * Insert in: All sections or Current section, starting at the file's
      Insert new columns in, which it overrides for this column (R55).

  The settings live in the box's mode until ENTER adds the column, so the
  whole box is one database change and one undo step. ALT-R and ALT-L
  skip the box: they open the picker and use the file's setting. Pure.
  """

  alias Agenda.Core
  alias Agenda.Core.View
  alias Agenda.TUI.{CategoryScreens, ColumnBox, FieldTyping, State, Template}
  alias Agenda.TUI.CategoryScreens.Properties
  alias Agenda.TUI.Update.Prompts

  # Format shows for a standard column, Line number and Column title for
  # Category note (R56); a row whose value is nil is left out
  @layout """
   Column head:  [head          ]  Category type: [type    ]
   Width:        [width ]
   Format:       [format              ]
   Line number:  [note_line ]
   Column title: [title                        ]
   Position:     [position              ]
   Insert in:    [insert_in      ]
  """

  @hint " SPACE/→ next choice · ← previous · F3 picks the head · ENTER adds"

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
      kind: :standard,
      format: :name,
      note_line: 1,
      title: nil,
      width: nil,
      position: :right,
      insert_in: state.db.insert_columns,
      cursor: 0
    })
  end

  @doc """
  The picker chose the head (`Picker.pick/3`). A standard one keeps the
  type chosen; a date or numeric one brings its own.
  """
  def set_head(state, id) do
    kind = state.db.categories[id].kind
    update(state, &%{&1 | head: id, kind: if(kind == :standard, do: &1.kind, else: kind)})
  end

  # the box may not be on top (the picker just closed above it), so it is
  # found by its type, as `ScheduleBox` does
  defp update(state, fun) do
    case Enum.find_index(state.modes, &(&1.type == :column_add)) do
      nil -> state
      i -> %{state | modes: List.update_at(state.modes, i, fun)}
    end
  end

  def handle(state, mode, key) do
    if FieldTyping.typing?(mode),
      do: FieldTyping.key(state, mode, key, &typed/3),
      else: settings_key(state, mode, key)
  end

  # a typed head: a new category is kept at once (one undo step), and the
  # box takes it as the head
  defp typed(state, :head, name),
    do:
      FieldTyping.head_named(state, name, fn state, db, id ->
        state |> State.change_db(db) |> set_head(id)
      end)

  # a Category note column's title, kept with the box until ENTER
  defp typed(state, :title, text), do: update(state, &%{&1 | title: text})

  # The fields shown, in the cursor's order: no Format for a date or
  # numeric column, and Line number and Column title only for Category note.
  defp fields(mode) do
    hidden =
      cond do
        mode.kind != :standard -> [:format, :note_line, :title]
        mode.format != :note -> [:note_line, :title]
        true -> []
      end

    Template.fields(@layout) -- hidden
  end

  defp settings_key(state, mode, key) do
    last = length(fields(mode)) - 1
    field = Enum.at(fields(mode), min(mode.cursor, last))

    case key do
      :esc ->
        State.pop(state)

      :enter when mode.head == nil ->
        pick_head(state)

      :enter ->
        add(state, mode)

      :up ->
        State.put_mode(state, %{mode | cursor: max(mode.cursor - 1, 0)})

      :down ->
        State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, last)})

      {:f, 3} when field == :head ->
        pick_head(state)

      {:char, c} when field in [:head, :title] and c != " " ->
        FieldTyping.start(state, mode, field, c)

      k when k in [{:char, " "}, :right] ->
        change(state, mode, field, 1)

      :left ->
        change(state, mode, field, -1)

      _ ->
        state
    end
  end

  defp pick_head(state), do: CategoryScreens.open_picker(state, :column_add, nil)

  defp change(state, _mode, :head, _step), do: pick_head(state)

  @kinds [:standard, :date, :numeric]

  defp change(state, mode, :type, step) do
    if mode.head && state.db.categories[mode.head].kind != :standard do
      State.error(state, "#{name(state, mode.head)} stays a #{kind_name(mode.kind)} category")
    else
      index = Enum.find_index(@kinds, &(&1 == mode.kind))
      State.put_mode(state, %{mode | kind: Enum.at(@kinds, Integer.mod(index + step, 3))})
    end
  end

  defp change(state, mode, :width, step),
    do: State.put_mode(state, %{mode | width: max(1, width(state, mode) + step)})

  # Agenda's formats, in its order (R56)
  defp change(state, mode, :format, step) do
    formats = View.Column.formats()
    index = Enum.find_index(formats, &(&1 == mode.format))

    State.put_mode(state, %{
      mode
      | format: Enum.at(formats, Integer.mod(index + step, length(formats)))
    })
  end

  defp change(state, mode, :note_line, step),
    do: State.put_mode(state, %{mode | note_line: (mode.note_line + step) |> max(1) |> min(999)})

  defp change(state, _mode, :title, _step), do: State.error(state, "Type the column's title")

  # two choices each, so any step flips them
  defp change(state, mode, :position, _step),
    do: State.put_mode(state, %{mode | position: flip(mode.position, :right, :left)})

  defp change(state, mode, :insert_in, _step),
    do: State.put_mode(state, %{mode | insert_in: flip(mode.insert_in, :all, :section)})

  # the other of `a` and `b`: a variable named twice in a pattern must be
  # the same value both times, so the first clause matches `value == a`
  defp flip(a, a, b), do: b
  defp flip(_value, a, _b), do: a

  # A head about to change type is asked about first, when its children or
  # items would change (Y comes back to `add_now/1`).
  defp add(state, mode) do
    case question(state, mode) do
      nil -> add_now(state)
      question -> Prompts.confirm(state, question, :column_add)
    end
  end

  defp question(state, %{head: head, kind: kind}) do
    cat = state.db.categories[head]
    clock = State.context(state)

    case {cat.kind, kind} do
      {:standard, :date} ->
        Properties.date_question(cat, Core.date_conversion(state.db, head, clock))

      {:standard, :numeric} ->
        Properties.numeric_question(cat, Core.numeric_conversion(state.db, head, clock))

      _ ->
        nil
    end
  end

  @doc """
  Adds the column the box (on top) describes, with its head made the type
  chosen: one change, one undo step. It goes right or left of the
  highlighted column or of the item text (R55), and the highlight ends on
  it: columns are counted from 0, the cursor from 1 (0 is the item text).
  """
  def add_now(state) do
    mode = State.mode(state)
    side = if mode.position == :right, do: :right_of, else: :left_of
    place = {side, if(mode.col == 0, do: :items, else: mode.col - 1)}
    index = Agenda.Core.ViewColumns.insert_index(State.view(state), mode.sidx, place)

    opts = [
      width: mode.width,
      insert_in: mode.insert_in,
      clock: State.context(state),
      format: mode.format,
      note_line: mode.note_line,
      title: mode.title
    ]

    case Core.add_column_as(
           state.db,
           state.view_id,
           mode.head,
           mode.kind,
           {mode.sidx, place},
           opts
         ) do
      {:ok, db} -> %{State.change_db(State.pop(state), db) | col: index + 1}
      {:error, _} -> State.error(state, "#{name(state, mode.head)} cannot change type")
    end
  end

  defp name(state, id), do: state.db.categories[id].name

  # the width chosen, or the core's default for the type and Format
  defp width(_state, %{width: width}) when width != nil, do: width

  defp width(state, mode),
    do: Core.default_column_width(state.db, mode.head, mode.kind, mode.format)

  # --- drawing ---

  @doc "The box's lines, the highlighted setting selected."
  def content(state, mode) do
    values = %{
      head: if(mode.head, do: state.db.categories[mode.head].name, else: "(F3 to pick)"),
      type: kind_name(mode.kind) |> String.capitalize(),
      width: Integer.to_string(width(state, mode)),
      position:
        if(mode.position == :right, do: "Right of current column", else: "Left of current column"),
      insert_in: if(mode.insert_in == :all, do: "All sections", else: "Current section")
    }

    # the rows not shown get nil, which leaves them out
    shown = fields(mode)

    values =
      Map.merge(values, %{
        format: if(:format in shown, do: ColumnBox.format_name(mode.format)),
        note_line: if(:note_line in shown, do: Integer.to_string(mode.note_line)),
        title: if(:title in shown, do: mode.title || "")
      })

    field = Enum.at(shown, min(mode.cursor, length(shown) - 1))
    opts = [selected: field] ++ FieldTyping.editing(mode)

    Template.render(@layout, values, opts) ++
      [[], [{:box, @hint}]]
  end

  defp kind_name(kind), do: Atom.to_string(kind)

  @doc "The highlighted field, for its help in the control panel (`Agenda.TUI.FieldHelp`)."
  def field(_state, mode), do: Enum.at(fields(mode), min(mode.cursor, length(fields(mode)) - 1))
end
