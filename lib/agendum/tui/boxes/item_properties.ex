# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Boxes.ItemProperties do
  @moduledoc """
  The Item Properties box (F6 on an item; User's Guide 4-13 to 4-15): the
  item's text, note, statistics, the items it depends on ("Depends on")
  and those depending on it ("Needed by", R43), and every category it is
  assigned to.

    * F2 on the text edits it; SPACE (or F2) on the note opens it
    * on a dependency: SPACE opens that item's properties (ESC comes
      back); DEL removes that one dependency
    * on an assignment: DEL breaks it; F4 changes a date or a
      number
    * typing anywhere in the assignments assigns a category, with automatic
      completion over all categories (ENTER accepts, F8/F7 cycle, INS
      creates exactly what was typed under MAIN); a date category asks for
      its date
    * F3 opens the assignment profile; ENTER or F6 closes the box, ESC
      closes it and cancels its changes (`Agendum.TUI.Boxes.BoxCancel`)

  The text, note and statistics are drawn from `@layout`
  (`Agendum.TUI.Boxes.Template`), the dependencies and assignments listed below
  them. Pure, like the rest of the TUI state machine.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, cancels: true

  alias Agendum.Core
  alias Agendum.Core.{DateFormat, NumberFormat, Recurrence}
  alias Agendum.TUI.Boxes.{Box, BoxNav, Template}
  alias Agendum.TUI.{CategoryScreens, Typing.Completion, Typing.LineEdit, State}
  alias Agendum.TUI.Render.View
  alias Agendum.TUI.Terminal.Draw
  alias Agendum.TUI.Update.{Editing, Prompts}

  @layout """
   Item text:        [text                                  ]
   Note:             [note                                  ]
   Item statistics:  [stats                                 ]
  """

  @help %{
    text: "The item's text. F2 edits it.",
    note: "The item's note. SPACE (or F2) opens it.",
    stats: "Its Zettel id, if it has one (R73), its categories and when it was entered.",
    prerequisite: "An item this one depends on. SPACE shows it, DEL removes the dependency.",
    dependent: "An item that depends on this one. SPACE shows it, DEL removes the dependency.",
    linked_from: "An item whose text or note links to this one (R73b). SPACE shows it.",
    assigned:
      "A category the item is assigned to. DEL breaks the assignment; F4 " <>
        "changes a date or number.",
    add:
      "Type a category name to assign the item to it. ENTER accepts, INS makes a new one, " <>
        "F3 shows the profile."
  }

  def open(state, item_id),
    do: State.push(state, %Agendum.TUI.Modes.ItemProps{item_id: item_id, cursor: 0})

  @doc "The rows of the box, top to bottom."
  @spec rows(State.t(), map) :: [term]
  def rows(state, mode) do
    [:text, :note, :stats] ++
      Enum.map(Core.prerequisites(state.db, mode.item_id), &{:prerequisite, &1}) ++
      Enum.map(Core.dependents(state.db, mode.item_id), &{:dependent, &1}) ++
      Enum.map(Core.linked_from(state.db, mode.item_id), &{:linked_from, &1}) ++
      Enum.map(Core.item_assignments(state.db, mode.item_id), &{:assigned, &1}) ++ [:add]
  end

  @impl Box
  def about(_state, _mode) do
    """
    The item's properties: its text, its note, some figures, and every
    category it is assigned to.

    F2 edits the text, or opens the note. In the assignments, type a
    category's name to assign the item to it (ENTER takes the one shown);
    DEL takes the item out of the highlighted one; F4 changes a date or a
    number. F3 shows the whole assignment profile.

    ENTER or F6 closes the box, keeping what you changed; ESC puts it back.
    """
  end

  # --- keys ---------------------------------------------------------------------

  @impl Box
  def handle(%State{edit: edit} = state, mode, key) when edit != nil,
    do: edit_key(state, mode, key)

  # typing a letter in the assignments assigns a category
  def handle(state, mode, {:char, c}) do
    {state, _mode, row} = clamped(state, mode)
    if assigning?(row), do: start_assign(state, c), else: state
  end

  def handle(state, _mode, _key), do: state

  defp assigning?(row) when row in [:stats, :add], do: true
  defp assigning?({:assigned, _}), do: true
  defp assigning?(_row), do: false

  # the cursor kept on a row (undo can take rows away), and that row
  defp clamped(state, mode) do
    rows = rows(state, mode)
    mode = %{mode | cursor: mode.cursor |> min(length(rows) - 1) |> max(0)}
    {State.put_mode(state, mode), mode, Enum.at(rows, mode.cursor)}
  end

  # what every settings box does: the moves, done and cancel
  @settings [:up, :down, :left, :right, :next, :previous, :first, :last, :done, :close]

  # the settings box's keys and the row's (R65)
  @impl Box
  def keymap(_mode) do
    Box.settings_keymap(%{
      {:f, 6} => :done,
      {:f, 2} => :edit,
      {:f, 3} => :profile,
      {:f, 4} => :set_value,
      :delete => :remove,
      :insert => :assign
    })
  end

  # the key bar's slots, in Agenda's words (checked in Agenda 2.0,
  # 2026-10-25): F3 opens the profile, Agenda's CHOICES; F6 closes the box,
  # Agenda's PROPS going back
  @impl Box
  def labels(_mode), do: %{profile: "Choices", set_value: "Values", done: "Props"}

  # F4 VALUES only on an assignment, as Agenda's bar has it there alone
  @impl Box
  def idle_keys(state, mode), do: if(field(state, mode) == :assigned, do: [], else: [{:f, 4}])

  @impl Box
  def commands(_mode) do
    Box.settings_commands([
      {:edit, "Edit", "Edit the text, or open the note"},
      {:profile, "Profile", "The item's assignment profile"},
      {:set_value, "Date or number", "Change the date or the number"},
      {:remove, "Remove", "Remove the assignment or dependency"},
      {:assign, "Assign", "Assign to a category"}
    ])
  end

  # ENTER is done (ESC cancels: `Agendum.TUI.Boxes.BoxCancel`)
  @impl Box
  def run(state, mode, id) do
    {state, mode, row} = clamped(state, mode)
    command(state, mode, id, row)
  end

  defp command(state, mode, :profile, _row), do: CategoryScreens.open_profile(state, mode.item_id)
  defp command(state, mode, :edit, :text), do: edit_text(state, mode)
  defp command(state, mode, id, :note) when id in [:edit, :change], do: open_note(state, mode)

  defp command(state, _mode, :change, {kind, id})
       when kind in [:prerequisite, :dependent, :linked_from],
       do: open(state, id)

  defp command(state, mode, :remove, {:prerequisite, id}),
    do: State.run(state, {:remove_dependency, mode.item_id, id})

  defp command(state, mode, :remove, {:dependent, id}),
    do: State.run(state, {:remove_dependency, id, mode.item_id})

  defp command(state, _mode, :remove, {:linked_from, _id}),
    do: State.error(state, "A link goes when the text that has it is changed")

  defp command(state, mode, :set_value, {:assigned, %{kind: :date} = a}),
    do: ask_date(state, mode, a.category)

  defp command(state, mode, :set_value, {:assigned, %{kind: :numeric} = a}),
    do: ask_number(state, mode, a)

  # F4 VALUES on an unindexed assignment: its text (R29b)
  defp command(state, mode, :set_value, {:assigned, %{kind: :text} = a}),
    do:
      Prompts.prompt(
        state,
        "#{state.db.categories[a.category].name}:",
        {:item_text, mode.item_id, a.category},
        a.text
      )

  defp command(state, mode, :remove, {:assigned, a}), do: remove(state, mode, a)

  defp command(state, _mode, :assign, row) when row not in [:text, :note],
    do: start_assign(state, "")

  # SPACE in the assignments starts typing, as any letter does
  defp command(state, _mode, :change, row) do
    if assigning?(row), do: start_assign(state, " "), else: state
  end

  defp command(state, mode, id, _row) when id in @settings,
    do: Box.run_settings(state, mode, BoxNav.column(rows(state, mode)), id)

  defp command(state, _mode, _id, _row), do: state

  defp edit_text(state, mode) do
    %{
      state
      | edit: %{
          target: {:item_text, mode.item_id},
          line: LineEdit.new(state.db.items[mode.item_id].text)
        }
    }
  end

  defp open_note(state, mode) do
    item = state.db.items[mode.item_id]

    Agendum.TUI.Update.Notes.open(state, {:item, item.id}, item.text, item.note)
  end

  defp start_assign(state, text) do
    mode = State.mode(state)

    %{
      state
      | edit: %{target: {:assign_category, mode.item_id}, line: LineEdit.new(text), choice: 0}
    }
  end

  defp remove(state, mode, %{category: cat_id, kind: kind}) do
    cond do
      cat_id == state.db.special.entry ->
        State.error(state, "The Entry date cannot be removed")

      kind == :date ->
        State.run(state, {:remove_from_category, mode.item_id, cat_id})

      true ->
        State.run(state, {:toggle_assignment, mode.item_id, cat_id})
    end
  end

  # Prompts for a date for a date category (When, Done, Entry); see
  # `Update.Prompts` (`prompt_action/3`) for {:item_date, item, category}.
  defp ask_date(state, mode, cat_id) do
    db = state.db

    current =
      Agendum.Core.DateParser.format(Agendum.Core.Database.item_date(db, mode.item_id, cat_id))

    Prompts.prompt(
      state,
      "#{db.categories[cat_id].name} date:",
      {:item_date, mode.item_id, cat_id},
      current
    )
  end

  # Prompts for the number in a numeric category (R29); see
  # `Update.Prompts` (`prompt_action/3`) for {:item_number, item, category}.
  defp ask_number(state, mode, %{category: cat_id, number: number}) do
    Prompts.prompt(
      state,
      "#{state.db.categories[cat_id].name}:",
      {:item_number, mode.item_id, cat_id},
      Editing.number_text(number, State.number_opts(state))
    )
  end

  # --- editing inside the box ----------------------------------------------------

  defp edit_key(%State{edit: edit} = state, mode, key) do
    assigning = match?({:assign_category, _}, edit.target)

    case key do
      :esc ->
        %{state | edit: nil}

      :enter ->
        commit(%{state | edit: nil}, mode, edit, Completion.shown(state))

      k when assigning and k in [{:f, 8}, {:alt, "n"}] ->
        Completion.cycle(state, 1)

      k when assigning and k in [{:f, 7}, {:alt, "p"}] ->
        Completion.cycle(state, -1)

      k when assigning and k in [:insert, {:f, 5}] ->
        new_category(%{state | edit: nil}, mode, edit.line.text)

      _ ->
        case LineEdit.handle(edit.line, key) do
          {:ok, line} -> %{state | edit: edit |> Map.put(:line, line) |> Map.put(:choice, 0)}
          :unhandled -> state
        end
    end
  end

  # an emptied text is taken, the item staying blank, as Agenda's (R21)
  defp commit(state, _mode, %{target: {:item_text, item_id}, line: line}, _shown),
    do: State.run(state, {:edit_item, item_id, line.text})

  defp commit(state, mode, %{target: {:assign_category, item_id}, line: line}, shown) do
    cond do
      shown && Agendum.Core.Database.date_category?(state.db, shown) ->
        ask_date(state, mode, shown)

      shown && state.db.categories[shown].kind == :numeric ->
        ask_number(state, mode, %{category: shown, number: nil})

      shown ->
        State.run(state, {:assign, item_id, shown})

      String.trim(line.text) == "" ->
        state

      true ->
        new_category(state, mode, line.text)
    end
  end

  # INS / F5 (NEWCAT): exactly the typed name, as a new category under MAIN.
  defp new_category(state, mode, text) do
    case State.command(state, {:assign_new_by_name, mode.item_id, state.db.main_id, text}) do
      {:ok, state, %{new: cat_id}} ->
        State.info(state, "Assigned to #{state.db.categories[cat_id].name}")

      {:error, :empty} ->
        state
    end
  end

  # --- the box -------------------------------------------------------------------

  @impl Box
  def title(_state, _mode), do: "Item Properties"

  @impl Box
  def content(state, mode, inner, max_rows) do
    item = state.db.items[mode.item_id]
    rows = rows(state, mode)
    cursor = min(mode.cursor, length(rows) - 1)
    row = Enum.at(rows, cursor)
    value_width = inner - 20
    assignments = Core.item_assignments(state.db, item.id)
    entered = DateFormat.date(item.entry, state.db.date_format)

    values = %{
      text: item.text,
      note: if(item.note == "", do: "(none)", else: item.note |> String.split("\n") |> hd()),
      stats:
        zettel_stat(item) <>
          "#{Draw.count(length(assignments), "category", "categories")} · entered #{entered}"
    }

    editing =
      case state.edit do
        %{target: {:item_text, _}, line: line} -> [editing: {:text, line}]
        _ -> []
      end

    head = Template.render(@layout, values, [selected: row] ++ editing)

    # the dependencies and assignments, each row labelled as the first of its kind
    list =
      rows
      |> Enum.with_index()
      |> Enum.drop(3)
      |> Enum.map(fn {row, i} ->
        list_row(state, item, rows, assignments, row, i == cursor, value_width)
      end)

    # the rows that fit above the hint and the blank line before it, the
    # highlighted one among them (each row is one line)
    room = max(max_rows - 2, 1)
    top = max(cursor - room + 1, 0)

    (head ++ list)
    |> Enum.drop(top)
    |> Enum.take(room)
    |> Kernel.++([[], hint(state, mode, inner)])
  end

  defp list_row(state, item, rows, assignments, row, selected, value_width) do
    # the name being typed shows on the highlighted assignment or the add row
    assign_row = row == :add or (selected and is_tuple(row))

    {label, value} =
      case row do
        {kind, id} when kind in [:prerequisite, :dependent, :linked_from] ->
          {dependency_label(rows, row), dependency_text(state.db, id)}

        {:assigned, a} ->
          {if(a == hd(assignments), do: "Assigned to", else: ""), assignment_text(state, a, item)}

        :add ->
          {if(assignments == [], do: "Assigned to", else: ""), "(type a category name to add)"}
      end

    value_part =
      case state.edit do
        %{target: {:assign_category, _}} when assign_row ->
          View.completion_field(state, state.edit.line, value_width)

        _ ->
          [{if(selected, do: :box_selected, else: :box), String.slice(value, 0, value_width)}]
      end

    # Agenda's "Label:" with the values in a column after it
    label = if label == "", do: "", else: label <> ":"
    [{:box, " " <> Draw.pad(label, 18)}] ++ value_part
  end

  # One assignment in the Item Properties box: "When (2026-10-13)",
  # "Anna Lasky (c)" for a conditional one.
  defp assignment_text(%{db: db}, %{category: id}, item) when id == db.special.when do
    db.categories[id].name <>
      " (#{DateFormat.date_time(item.when, item.when_time, db.date_format)})" <>
      recurrence_note(item) <> alarm_note(item)
  end

  defp assignment_text(state, a, _item), do: assignment_text(state, a)

  # the item's Zettel id first, when it has one (R73)
  defp zettel_stat(item) do
    case Core.zettel(item) do
      nil -> ""
      word -> "#{word} · "
    end
  end

  # R43: the first row of each kind is labelled
  defp dependency_label(rows, {kind, _} = row) do
    cond do
      Enum.find(rows, &match?({^kind, _}, &1)) != row -> ""
      kind == :prerequisite -> "Depends on"
      kind == :linked_from -> "Linked from"
      true -> "Needed by"
    end
  end

  defp dependency_text(db, id) do
    item = db.items[id]
    if item.done, do: "‼ " <> item.text, else: item.text
  end

  defp recurrence_note(%{recurrence: nil}), do: ""
  defp recurrence_note(%{recurrence: rule}), do: " · " <> Recurrence.describe(rule)

  defp alarm_note(%{alarm_minutes: nil}), do: ""
  defp alarm_note(%{alarm_minutes: m}), do: " · alarm #{m} min before"

  defp assignment_text(state, %{category: id, kind: :text, text: text}),
    do: "#{state.db.categories[id].name} (#{text})"

  defp assignment_text(state, %{category: id, kind: :numeric, number: number}) do
    number =
      NumberFormat.format(
        number,
        %NumberFormat{},
        State.number_opts(state)
      )

    "#{state.db.categories[id].name} (#{number})"
  end

  defp assignment_text(%{db: db}, %{category: id, kind: kind, date: date}) do
    name = db.categories[id].name

    case kind do
      :date -> "#{name} (#{DateFormat.date(date, db.date_format)})"
      :conditional -> name <> " (c)"
      :explicit -> name
    end
  end

  # while a category name is typed: what ENTER will do; else the box's keys
  defp hint(state, mode, inner) do
    case state.edit do
      %{target: {:assign_category, _}} ->
        n = length(Completion.matches(state))
        text = String.trim(state.edit.line.text)

        text =
          cond do
            text == "" -> "Type a category name"
            n == 0 -> "New category: #{text} · ENTER creates it"
            true -> "#{n} match · ENTER accepts · F8/F7 cycle · INS new"
          end

        [{:box, " " <> text}]

      _ ->
        Box.hint(keys(state, mode), inner)
    end
  end

  @impl Box
  def keys(_state, _mode),
    do: [
      {"F2", "Edit", "Edit the text"},
      {"DEL", "Remove", "Remove the assignment"},
      {"type", "To assign", "Assign to a category"},
      {"F4", "Date", "Set the date"},
      {"F3", "Profile", "Assignment profile"},
      {"ENTER", "Done"},
      {"ESC", "Cancel"}
    ]

  @impl Box
  def help, do: @help

  @impl Box
  def field(state, mode) do
    rows = rows(state, mode)

    case Enum.at(rows, mode.cursor |> min(length(rows) - 1) |> max(0)) do
      # a dependency or an assignment: the kind of row, not which one
      {kind, _id} -> kind
      row -> row
    end
  end
end
