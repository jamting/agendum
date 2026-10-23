defmodule Agendum.TUI.Update.ViewKeys do
  @moduledoc """
  Keys in the view itself (no box open): a key runs the command the
  view's keymap binds it to (`Agendum.TUI.Keymap`, ADR 0033), and `run/2`
  runs the view's commands (`Agendum.TUI.Commands`): moving the highlight,
  collapsing sections, the commands on the highlighted row (F2, F3, F4,
  F6, DEL, ALT-O, ALT-E …). An unbound character starts typing an item or
  a column entry. Pure.
  """

  alias Agendum.Core
  alias Agendum.Core.{Database, DateFormat, ViewModel}

  alias Agendum.TUI.{
    Boxes.CalendarBox,
    CategoryScreens,
    Terminal.Draw,
    Boxes.GoTo,
    Boxes.ItemProperties,
    Commands,
    Keymap,
    Layout,
    Typing.LineEdit,
    Boxes.SearchBox,
    State
  }

  alias Agendum.TUI.Update.{Actions, Editing, Prompts}

  # the key chart in view_key/2 stays one line per key
  import Agendum.TUI.Update.Marked, only: [bulk?: 2, jump_to_marked: 2, mark: 2, scoped: 3]

  @doc "F1's text in a view (R65)."
  @spec about() :: String.t()
  def about do
    """
    A view shows your items in sections. Each section is a category: an
    item in a section is assigned to it. The highlight is on an item, a
    section head, or a column beside them.

    Type to add an item to the highlighted section, or to fill in the
    highlighted column. An item is assigned to the section it is typed in,
    and to any category whose name appears in its text; the first date in
    the text ("call Bob next Friday") becomes its When date.

    F2 edits what is highlighted, F3 shows its choices, F5 its note and F6
    its properties. F7 marks items, for the commands that work on many at
    once. F8 lists the views, F9 the categories; F10 or / opens the menu.
    CTRL-Z undoes.

    ALT-1 … ALT-9 before a move give a count: ALT-1 ALT-0 ↓ goes ten rows
    down.

    On a Mac, hold fn for the function keys; ALT is ⌥ with "Use Option as
    Meta key". Press a for every key.
    """
  end

  # --- the view ----------------------------------------------------------------

  @doc "A key in the view: moving, a command on the highlighted row, or inline editing."
  # While a line is being edited, every key goes to the editor: this
  # clause comes first and matches only then (the guard).
  def view_key(%State{edit: edit} = state, key) when edit != nil,
    do: Editing.view_edit_key(state, key)

  # view commands that take a count themselves (`step/4`)
  @own [:up, :down, :page_up, :page_down, :previous_section, :next_section] ++
         [:next_column, :previous_column]

  # view commands that are the menu's named actions as they are
  @actions [
    :unmark_all,
    :section_below,
    :section_above,
    :column_right,
    :column_left,
    :alarm,
    :last_view,
    :view_manager,
    :category_manager,
    :menu,
    :help,
    :save,
    :retrieve
  ]

  # A key runs the command the view's keymap binds it to (ADR 0033), with
  # the count typed before it; an unbound character starts typing an item
  # or a column entry. ALT-digits build the count (R65).
  def view_key(state, {:alt, d} = key) when d in ~w(0 1 2 3 4 5 6 7 8 9),
    do: add_digit(state, String.to_integer(d), Keymap.lookup(:view, key))

  # `case` on a tuple of two values matches both at once. Domain: a key is
  # first looked up in the view's keymap (ADR 0033): bound, it runs its
  # command (an atom such as `:down` or `:save`); unbound, a printable
  # character starts a new item or column entry, and anything else does
  # nothing.
  def view_key(state, key) do
    case {Keymap.lookup(:view, key), key} do
      {nil, {:char, c}} -> start_typing(state, Layout.current_row(state), c)
      {nil, _} -> state
      {id, _} -> run(state, id, state.count || 1)
    end
  end

  @max_count 999

  # a leading 0 starts nothing (ALT-0 ALT-5 is 5); `Update.handle/2`
  # forgets the count after any other key
  defp add_digit(state, 0, _bound) when state.count == nil, do: state

  defp add_digit(state, d, _bound) do
    count = min((state.count || 0) * 10 + d, @max_count)
    State.info(%{state | count: count}, "Count: #{count}")
  end

  @doc """
  Runs a view command (`Agendum.TUI.Commands`) on the highlighted row,
  `n` times for a count (R65): a command that takes one moves n rows at
  once (`:own`) or runs again until n, stopping as soon as a run changes
  nothing or reports an error (`:repeat`); the others run once. Where the
  highlight is decides what some do (F3, F5, DEL …), as in Agenda.
  """
  # A head without a body: when a function with a default argument has
  # several clauses, the default is declared once, here, and the clauses
  # below leave it out.
  @spec run(State.t(), atom, pos_integer) :: State.t()
  def run(state, id, n \\ 1)

  def run(state, id, n) when n > 1 do
    case Commands.get(:view, id).count do
      :own -> step(state, id, Layout.current_row(state), n)
      :repeat -> repeat(state, id, n)
      :none -> run(state, id, 1)
    end
  end

  def run(state, id, _n), do: command(state, id, Layout.current_row(state))

  # the commands that can be unable to run (`unavailable/1`)
  @checked [:edit, :choices, :note, :properties, :mark, :remove, :discard, :move, :copy] ++
             [:yank, :hop, :alarm, :dependency, :done, :when, :make_assign, :collapse] ++
             [:expand, :execute_category, :unmark_all, :next_marked, :last_view] ++
             [:next_view, :previous_view, :follow_link, :linked_from, :open_link]

  @no_rows "Nothing is highlighted: this view shows no rows"

  @doc """
  The view's commands that cannot run on the highlighted row now, each
  with why (R65a): F1 `c` greys them and says why. Only the commands
  that would do nothing, or only report an error, are here; one that
  asks something first (Discard on an item) can run. The reasons are
  the ones running them reports, where it reports one.
  """
  @spec unavailable(State.t()) :: %{atom => String.t()}
  def unavailable(state) do
    row = Layout.current_row(state)
    marked = Core.marked_items(state.db)

    @checked
    |> Enum.map(&{&1, why_not(state, &1, row, marked)})
    |> Enum.filter(fn {_id, reason} -> is_binary(reason) end)
    |> Map.new()
  end

  # why a command cannot run on `row` (nil: it can): first those that do
  # not depend on the row, then those that need one, then an item
  defp why_not(state, :yank, row, _marked) do
    id = state.last.removed

    cond do
      id == nil or not Map.has_key?(state.db.items, id) -> "No removed item to yank back"
      row == nil -> @no_rows
      true -> nil
    end
  end

  defp why_not(_state, :unmark_all, _row, []), do: "No items are marked"
  defp why_not(_state, :unmark_all, _row, _marked), do: nil

  defp why_not(state, :next_marked, _row, _marked) do
    unless Enum.any?(Layout.rows(state), &(&1.kind == :item and &1.item.marked)),
      do: "No marked items in this view"
  end

  defp why_not(state, :last_view, _row, _marked) do
    unless state.last.view && Map.has_key?(state.db.views, state.last.view),
      do: "No previous view"
  end

  defp why_not(state, id, _row, _marked) when id in [:next_view, :previous_view] do
    if length(state.db.view_order) == 1, do: "This file has only one view"
  end

  # with items marked, these work on them wherever the highlight is
  defp why_not(_state, id, nil, marked) when id in [:done, :when, :make_assign] and marked != [],
    do: nil

  defp why_not(_state, _id, nil, _marked), do: @no_rows

  # a section head of MAIN (or another category that cannot change)
  defp why_not(state, id, %{kind: :section, category: cat}, _marked)
       when id in [:edit, :discard] and state.col == 0 do
    if Database.protected?(state.db, cat.id),
      do: "#{cat.name} cannot be #{if id == :edit, do: "renamed", else: "discarded"}"
  end

  defp why_not(_state, :alarm, %{kind: :item, item: item}, _marked) do
    if item.alarm_minutes == nil and item.when == nil,
      do: "Give the item a When date and time first (ALT-F2)"
  end

  defp why_not(state, :dependency, %{kind: :item, item: item}, marked) do
    if marked -- [item.id] == [] and Core.prerequisites(state.db, item.id) == [],
      do: "Mark the items it depends on with F7, then ALT-O"
  end

  defp why_not(state, :follow_link, %{kind: :item, item: item}, _marked) do
    if Core.link_targets(state.db, item.id) == [], do: "This item has no links to other items"
  end

  defp why_not(_state, :open_link, %{kind: :item, item: item}, _marked) do
    unless Regex.match?(~r{https?://}i, item.note <> "\n" <> item.text),
      do: "The item has no web address in its note or text"
  end

  defp why_not(state, :linked_from, %{kind: :item, item: item}, _marked) do
    cond do
      item.zettel == nil -> "The item has no Zettel id, so nothing can link to it"
      Core.linked_from(state.db, item.id) == [] -> "No item links to this one"
      true -> nil
    end
  end

  defp why_not(_state, _id, %{kind: :item}, _marked), do: nil
  defp why_not(_state, :copy, _row, _marked), do: "Highlight an item to copy"
  defp why_not(_state, :hop, _row, _marked), do: "Highlight an item to hop to its next occurrence"

  defp why_not(_state, id, _row, _marked)
       when id in [:alarm, :dependency, :follow_link, :linked_from, :open_link],
       do: "Highlight an item first"

  defp why_not(_state, id, _row, []) when id in [:done, :when, :make_assign],
    do: "Highlight an item, or mark some with F7"

  defp why_not(_state, _id, _row, _marked), do: nil

  defp repeat(state, _id, 0), do: state

  defp repeat(state, id, n) do
    next = run(state, id, 1)

    if next == state or match?({:error, _}, next.message),
      do: next,
      else: repeat(next, id, n - 1)
  end

  # the commands that use a count themselves: one build of the view for
  # all n steps
  defp step(state, :up, _row, n), do: Layout.move_to(state, state.cursor - n)
  defp step(state, :down, _row, n), do: Layout.move_to(state, state.cursor + n)

  defp step(state, :page_up, _row, n),
    do: Layout.move_to(state, state.cursor - n * State.body_height(state))

  defp step(state, :page_down, _row, n),
    do: Layout.move_to(state, state.cursor + n * State.body_height(state))

  defp step(state, :previous_section, _row, n),
    do: Layout.move_to(state, section_heads(Layout.rows(state), state.cursor, -1, n))

  defp step(state, :next_section, _row, n),
    do: Layout.move_to(state, section_heads(Layout.rows(state), state.cursor, 1, n))

  defp step(state, :next_column, row, n), do: Layout.step_col(state, row, n)
  defp step(state, :previous_column, row, n), do: Layout.step_col(state, row, -n)

  defp command(state, :top, _row), do: Layout.move_to(state, 0)
  defp command(state, :bottom, _row), do: Layout.move_to(state, length(Layout.rows(state)) - 1)

  defp command(state, id, row) when id in @own, do: step(state, id, row, 1)
  defp command(state, :insert, row), do: insert(state, row)

  defp command(state, :remove, row),
    do: if(bulk?(state, row), do: scoped(state, :remove, row), else: delete(state, row))

  defp command(state, :edit, row), do: edit(state, row)

  defp command(state, :choices, row),
    do: if(bulk?(state, row), do: scoped(state, :profile, row), else: choices(state, row))

  defp command(state, :done, row), do: scoped(state, :done, row)

  # in a column, the note of the column head or of the entry's category
  defp command(state, :note, _row) when state.col > 0, do: column_note(state)
  defp command(state, :note, _row), do: Actions.perform(state, :note)
  defp command(state, :properties, row), do: props(state, row)
  defp command(state, :mark, row), do: mark(state, row)
  defp command(state, :next_marked, _row), do: jump_to_marked(state, Layout.rows(state))
  defp command(state, :make_assign, row), do: scoped(state, :make_assign, row)
  defp command(state, :discard, row), do: scoped(state, :discard, row)
  defp command(state, :when, row), do: scoped(state, :when, row)
  defp command(state, :attach_zettel, row), do: scoped(state, :attach_zettel, row)

  defp command(state, id, _row) when id in [:follow_link, :linked_from, :open_link],
    do: Actions.perform(state, id)

  # on a column head (a section head line) the column moves, as in
  # Agenda (User's Guide 5-20); on a section head the section (5-8);
  # elsewhere the item(s)
  defp command(state, :move, %{kind: :section}) when state.col > 0,
    do: Actions.perform(state, :column_move)

  defp command(state, :move, %{kind: :section}), do: Actions.perform(state, :section_move)
  defp command(state, :move, row), do: scoped(state, :move_item, row)
  defp command(state, :copy, row), do: scoped(state, :copy_item, row)
  defp command(state, :yank, row), do: yank(state, row)
  defp command(state, :hop, row), do: hop(state, row)
  defp command(state, :dependency, row), do: dependency(state, row)
  defp command(state, :collapse, row), do: collapse_sections(state, row, true)
  defp command(state, :expand, row), do: collapse_sections(state, row, false)

  defp command(state, :toggle_empty, _row),
    do: Actions.perform(state, {:toggle_view, :hide_empty})

  defp command(state, :go_to, _row), do: GoTo.open(state)
  defp command(state, :search, _row), do: SearchBox.open(state, :view)
  defp command(state, :browse, _row), do: Agendum.TUI.Moves.Browse.open(state)
  defp command(state, :calendar, _row), do: CalendarBox.open(state, nil)

  defp command(state, :execute_all, _row),
    do: Agendum.TUI.Boxes.ExecuteBox.execute(state, state.db.main_id, :all)

  defp command(state, :execute_category, row), do: execute_category(state, row)
  defp command(state, :next_view, _row), do: step_view(state, 1)
  defp command(state, :previous_view, _row), do: step_view(state, -1)

  # the rest are named actions shared with the menu
  defp command(state, id, _row) when id in @actions, do: Actions.perform(state, id)

  # ALT-N / ALT-P: the next / previous view in the view manager's order.
  defp step_view(state, step) do
    order = state.db.view_order
    index = Enum.find_index(order, &(&1 == state.view_id)) || 0
    State.switch_view(state, Enum.at(order, Integer.mod(index + step, length(order))))
  end

  # ALT-- / ALT-= collapse or expand the current section; pressed twice,
  # every section in the view (User's Guide 5-5).
  defp collapse_sections(state, nil, _collapsed), do: state
  defp collapse_sections(state, %{slot: %{}}, _collapsed), do: Actions.datebook_sections(state)

  defp collapse_sections(state, row, collapsed) do
    twice = state.last_key.key == {:alt, if(collapsed, do: "-", else: "=")}

    command =
      if twice,
        do: {:set_all_sections_collapsed, state.view_id, collapsed},
        else: {:set_section_collapsed, state.view_id, row.sidx, collapsed}

    %{State.run(state, command) | cursor_key: {:section, row.sidx}}
  end

  # the nth section head above or below; stops at the last one there is
  defp section_heads(_rows, from, _direction, 0), do: from

  defp section_heads(rows, from, direction, n) do
    case section_head_index(rows, from, direction) do
      ^from -> from
      next -> section_heads(rows, next, direction, n - 1)
    end
  end

  defp section_head_index(rows, from, direction) do
    indexed = Enum.with_index(rows)

    candidates =
      if direction < 0,
        do: indexed |> Enum.take(from) |> Enum.reverse(),
        else: Enum.drop(indexed, from + 1)

    Enum.find_value(candidates, from, fn {r, i} -> if r.kind == :section, do: i end)
  end

  # In a standard column the Format decides (R56; User's Guide 5-31 to
  # 5-37): SPACE stars, Y and N answer, a Category note line is typed;
  # otherwise the letter starts a column entry.
  defp start_typing(state, %{kind: :item} = row, c) when state.col > 0 do
    case {standard_format(state), c} do
      {:star, " "} -> star(state, row)
      {:yes_no, y} when y in ["y", "Y"] -> set_in_column(state, row, true)
      {:yes_no, n} when n in ["n", "N"] -> set_in_column(state, row, false)
      {:note, _} -> %{state | edit: %{target: note_target(state, row), line: LineEdit.new(c)}}
      {:zettel, _} -> zettel_column(state)
      _ -> %{state | edit: %{target: column_target(state, row, :replace), line: LineEdit.new(c)}}
    end
  end

  defp start_typing(state, row, c) when row != nil, do: begin_new_item(state, row, c)
  defp start_typing(state, nil, _c), do: State.error(state, "Add a section first (ALT-D)")

  defp insert(state, nil), do: Actions.perform(state, :section_below)

  defp insert(state, %{kind: :item} = row) when state.col > 0 do
    target = column_target(state, row, :add)
    %{state | edit: %{target: target, line: LineEdit.new()}}
  end

  defp insert(state, row), do: begin_new_item(state, row, "")

  defp begin_new_item(state, row, text) do
    %{state | col: 0, edit: %{target: {:new_item, row.sidx, row.key}, line: LineEdit.new(text)}}
  end

  # the highlighted column's Format, for a standard column; nil otherwise
  defp standard_format(state) do
    {column, _at} = Layout.current_column(state)
    if state.db.categories[column.category_id].kind == :standard, do: column.format
  end

  defp star(state, row) do
    {:column_entry, item_id, head, _} = column_target(state, row, :replace)
    set_in_column(state, row, not Database.member?(state.db, item_id, head))
  end

  defp set_in_column(state, row, in?) do
    {:column_entry, item_id, head, _} = column_target(state, row, :replace)
    State.run(state, {:set_in_column, item_id, head, in?})
  end

  # what a Category note column's cell types into: that line of the note
  defp note_target(state, row) do
    {column, _at} = Layout.current_column(state)
    {:note_line, row.item.id, column.category_id, column.note_line}
  end

  # NOTE (F5) in a column opens the note of the category highlighted there
  # (User's Guide 12-4: "Highlight the item or category")
  defp column_note(state) do
    case Layout.note_target(state) do
      {:category, id} -> CategoryScreens.open_note(state, id)
      _ -> State.error(state, "No category here to have a note")
    end
  end

  defp column_target(state, row, how) do
    {column, _at} = Layout.current_column(state)
    {:column_entry, row.item.id, column.category_id, how}
  end

  # on a column head (ours; the manual does not say): the head's category
  defp edit(state, %{kind: :section}) when state.col > 0 do
    {column, _at} = Layout.current_column(state)
    rename(state, state.db.categories[column.category_id])
  end

  defp edit(state, %{kind: :section, category: cat}), do: rename(state, cat)

  defp edit(state, %{kind: :item, item: item}) when state.col == 0 do
    %{state | edit: %{target: {:edit_item, item.id}, line: LineEdit.new(item.text)}}
  end

  # F2 in a Category note column: what its line says now (R56)
  defp edit(state, %{kind: :item} = row) when state.col > 0 do
    if standard_format(state) == :note,
      do: edit_note(state, row),
      else: edit_entry(state, row)
  end

  defp edit(state, nil), do: state

  defp edit_note(state, row) do
    {:note_line, item_id, head, n} = target = note_target(state, row)

    text =
      case ViewModel.column_entries(state.db, item_id, head) do
        [] -> ""
        [cat_id | _] -> ViewModel.note_line(state.db.categories[cat_id].note, n)
      end

    %{state | edit: %{target: target, line: LineEdit.new(text)}}
  end

  defp edit_entry(state, row) do
    {:column_entry, item_id, head, _} = column_target(state, row, :replace)
    numeric = state.db.categories[head].kind == :numeric

    case Database.date_category?(state.db, head) do
      false when numeric ->
        text =
          Editing.number_text(Database.number(state.db, item_id, head), State.number_opts(state))

        %{
          state
          | edit: %{target: {:column_entry, item_id, head, :replace}, line: LineEdit.new(text)}
        }

      false ->
        case ViewModel.column_entries(state.db, item_id, head) do
          [] ->
            %{
              state
              | edit: %{target: {:column_entry, item_id, head, :replace}, line: LineEdit.new()}
            }

          [cat_id | _] ->
            %{
              state
              | edit: %{
                  target: {:rename_category, cat_id},
                  line: LineEdit.new(state.db.categories[cat_id].name)
                }
            }
        end

      true ->
        # When offers a recurring date's rule, so ENTER keeps it (R14a)
        text =
          if head == state.db.special.when,
            do: Agendum.Core.when_text(state.db, item_id, State.context(state)),
            else: Agendum.Core.DateParser.format(Database.item_date(state.db, item_id, head))

        %{
          state
          | edit: %{target: {:column_entry, item_id, head, :replace}, line: LineEdit.new(text)}
        }
    end
  end

  defp rename(state, cat) do
    if Database.protected?(state.db, cat.id),
      do: State.error(state, "#{cat.name} cannot be renamed"),
      else: %{state | edit: %{target: {:rename_category, cat.id}, line: LineEdit.new(cat.name)}}
  end

  @doc """
  DEL on the highlighted row: removes the column (on its head), the section
  from the view, the item from the section's category, or the column entry.
  """
  def delete(state, %{kind: :section}) when state.col > 0,
    do: Actions.perform(state, :remove_column)

  def delete(state, %{kind: :section, slot: %{}}), do: Actions.datebook_sections(state)

  def delete(state, %{kind: :section, sidx: sidx}) do
    State.run(
      state,
      {:remove_section, state.view_id, sidx},
      "Section removed from view (category kept)"
    )
  end

  def delete(state, %{kind: :item, item: item, category: cat}) when state.col == 0 do
    if cat.id == state.db.main_id do
      State.error(state, "Items cannot be removed from MAIN; use ALT-F4 to discard")
    else
      state
      |> State.run({:remove_from_category, item.id, cat.id}, "Removed from #{cat.name}")
      |> then(&%{&1 | last: %{&1.last | removed: item.id}})
    end
  end

  # DEL in a column: a Category note line is emptied, a Star or Yes/No
  # column takes the item out of the head (R56), others lose their entries
  def delete(state, %{kind: :item} = row) do
    case standard_format(state) do
      :note ->
        Editing.set_note_line(state, note_target(state, row), "")

      format when format in [:star, :yes_no] ->
        set_in_column(state, row, false)

      :zettel ->
        zettel_column(state)

      _ ->
        {:column_entry, item_id, head, _} = column_target(state, row, :replace)

        State.run(state, {:clear_column, item_id, head})
    end
  end

  def delete(state, nil), do: state

  # a Zettel id is given, never typed or taken away (R73a)
  defp zettel_column(state),
    do: State.error(state, "A Zettel id is given by Item ▸ Zettel ▸ Attach; it cannot be typed")

  # ALT-H (User's Guide 13-9): the highlighted item's next occurrence,
  # further down this view, else in the next view that shows it (in the
  # view manager's order, round to this view's top). Moves the highlight
  # only.
  defp hop(state, %{kind: :item, item: item}) do
    here = for {r, i} <- Enum.with_index(Layout.rows(state)), i > state.cursor, do: {r, i}

    case Enum.find(here, fn {r, _} -> occurrence?(r, item.id) end) do
      {_, index} -> Layout.move_to(state, index)
      nil -> hop_views(state, item.id)
    end
  end

  defp hop(state, _row), do: State.error(state, "Highlight an item to hop to its next occurrence")

  defp hop_views(state, id) do
    {before, [current | rest]} = Enum.split_while(state.db.view_order, &(&1 != state.view_id))

    Enum.find_value(rest ++ before ++ [current], fn view_id ->
      shown = state |> State.switch_view(view_id) |> Layout.settle()
      index = Enum.find_index(Layout.rows(shown), &occurrence?(&1, id))

      cond do
        index == nil -> nil
        # round to this view again: its first occurrence, if not this one
        view_id == state.view_id and index == state.cursor -> nil
        view_id == state.view_id -> Layout.move_to(state, index)
        true -> shown |> Layout.move_to(index) |> State.info("In view #{shown_name(shown)}")
      end
    end) || State.error(state, "No other occurrence of this item")
  end

  defp occurrence?(row, id), do: row.kind == :item and row.item.id == id
  defp shown_name(state), do: State.view(state).name

  # ALT-Y (User's Guide 4-10): the item DEL last removed goes into the
  # highlighted item's section, below it (on a section head, in its usual
  # place), assigned to the section's head. One at a time, as in Agenda.
  defp yank(state, row) do
    id = state.last.removed

    cond do
      id == nil or not Map.has_key?(state.db.items, id) ->
        State.error(state, "No removed item to yank back")

      row == nil ->
        state

      # every row has a slot; only a datebook's rows have one that is a map
      match?(%{slot: %{}}, row) ->
        Actions.datebook_sections(state)

      Database.member?(state.db, id, row.category.id) ->
        State.error(state, "#{state.db.items[id].text} is already in #{row.category.name}")

      true ->
        after_id = if row.kind == :item, do: row.item.id

        state =
          State.run(state, {:move_item, id, state.db.main_id, row.category.id, after: after_id})

        %{state | last: %{state.last | removed: nil}, cursor_key: {:item, row.sidx, id}}
        |> State.info("Yanked back into #{row.category.name}")
    end
  end

  @doc """
  F3 (CHOICES) on the highlighted row: the column's choices or calendar,
  the item's assignment profile, or the categories for the section or
  column head (User's Guide 5-25).
  """
  def choices(state, %{kind: :item} = row) when state.col > 0 do
    {:column_entry, item_id, head, _} = column_target(state, row, :replace)

    cond do
      Database.date_category?(state.db, head) ->
        CalendarBox.open(state, {item_id, head})

      state.db.categories[head].kind == :numeric ->
        State.error(state, "Type a number, e.g. 120 or 1,234.50")

      true ->
        CategoryScreens.open_picker(state, {:assign_column, item_id, head}, head)
    end
  end

  def choices(state, %{kind: :item, item: item}),
    do: CategoryScreens.open_profile(state, item.id)

  def choices(state, %{kind: :section}) when state.col > 0 do
    {_column, at} = Layout.current_column(state)
    CategoryScreens.open_picker(state, {:column_head, at}, nil)
  end

  def choices(state, %{kind: :section, slot: %{}}), do: Actions.datebook_sections(state)

  def choices(state, %{kind: :section, sidx: sidx}),
    do: CategoryScreens.open_picker(state, {:change_section, sidx}, nil)

  def choices(state, nil), do: state

  defp props(state, %{kind: :section}) when state.col > 0,
    do: Actions.perform(state, :column_props)

  defp props(state, %{kind: :item, item: item}), do: ItemProperties.open(state, item.id)

  # Agenda's PROPS on a section head: Section Properties, whose head field
  # opens the category's properties with F6 again
  defp props(state, %{kind: :section}), do: Actions.perform(state, :section_props)

  defp props(state, nil), do: state

  # ALT-E: the conditions and actions of the highlighted section's category
  # (or the item's section) and its children, on all items (R15e).
  defp execute_category(state, nil), do: state

  defp execute_category(state, row),
    do: Agendum.TUI.Boxes.ExecuteBox.execute(state, row.category.id, :all)

  # ALT-O (User's Guide 13-12): make the item depend on the marked items,
  # or, with nothing marked, clear its dependencies.
  defp dependency(state, %{kind: :item, item: item}) do
    marked = Core.marked_items(state.db) -- [item.id]

    cond do
      marked != [] ->
        Prompts.confirm(
          state,
          "Make this item depend on the #{Draw.count(length(marked), "marked item")}?",
          {:make_dependent, item.id, marked}
        )

      Core.prerequisites(state.db, item.id) != [] ->
        Prompts.confirm(
          state,
          "Clear this item's dependencies?",
          {:clear_dependencies, item.id}
        )

      true ->
        State.error(state, "Mark the items it depends on with F7, then ALT-O")
    end
  end

  defp dependency(state, _row), do: State.error(state, "Highlight an item first")

  @doc "F4 DONE; for a recurring item, says when its next occurrence is (R14a)."
  def toggle_done(state, %{kind: :item, item: item}) do
    # what changed tells whether a recurring item got its next occurrence
    case State.run_with_changes(state, {:toggle_done, item.id}) do
      {next, %{items: %{added: [copy]}}} ->
        date = DateFormat.date(next.db.items[copy].when, next.db.date_format)
        State.info(next, "Done · the next one is on #{date}")

      {next, _changes} ->
        next
    end
  end

  def toggle_done(state, _row), do: state
end
