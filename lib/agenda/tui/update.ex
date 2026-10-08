defmodule Agenda.TUI.Update do
  @moduledoc """
  The UI state machine: `handle/2` maps a key to a new state plus a list of
  side effects for the shell to perform. Pure.

  Effects:
    * `{:save, path}` – write `state.db` to `path`, then call `saved/3`
    * `{:load, path}` – read a file, then call `loaded/3`
    * `{:write_text, path, text}` – export text, then call `written/3`
    * `:quit`
  """

  alias Agenda.Core
  alias Agenda.Core.{Database, ViewModel}

  alias Agenda.TUI.{
    CategoryScreens,
    History,
    Layout,
    LineEdit,
    Menu,
    State,
    TextEdit,
    ViewManager
  }

  @spec handle(State.t(), term) :: {State.t(), [term]}
  def handle(%State{} = state, key) do
    state = %{state | message: nil, effects: []}
    key = normalize(state, key)

    next =
      case global_key(state, key) do
        :pass -> dispatch(state, State.mode(state), key)
        handled -> handled
      end

    state = History.record(state, next)
    state = %{state | dirty: state.db != state.saved_db}

    state =
      if state.modes == [] or match?(%{type: :move_item}, State.mode(state)),
        do: Layout.settle(state),
        else: state

    {%{state | effects: []}, state.effects}
  end

  # --- keyboard aliases -------------------------------------------------------
  #
  # Mac keyboards have no INS key, and terminals do not pass the Command key
  # to programs, so every command also has a CTRL key (which a terminal can
  # map ⌘ shortcuts to; see docs/KEYBOARD.md).

  # True while the user is typing text, when CTRL keys act as editing keys.
  defp typing?(state) do
    state.edit != nil or match?(%{type: t} when t in [:note, :prompt], State.mode(state))
  end

  defp normalize(state, key) do
    case key do
      {:ctrl, "n"} -> :insert
      {:ctrl, "e"} -> if typing?(state), do: key, else: {:f, 2}
      {:ctrl, "k"} -> if typing?(state), do: key, else: {:f, 4}
      {:alt, :up} -> if State.mode(state) == nil, do: :ctrl_pgup, else: key
      {:alt, :down} -> if State.mode(state) == nil, do: :ctrl_pgdn, else: key
      _ -> key
    end
  end

  # Commands that work the same on every screen. Returns :pass when the key
  # is not one of them, or when the user is typing or answering a question.
  defp global_key(state, key) do
    top = State.mode(state)

    cond do
      typing?(state) or match?(%{type: t} when t in [:confirm, :menu, :help], top) -> :pass
      key == {:ctrl, "z"} -> if undoable?(top), do: History.undo(state), else: :pass
      key == {:ctrl, "y"} -> if undoable?(top), do: History.redo(state), else: :pass
      key == {:ctrl, "s"} -> perform(state, :save)
      key == {:ctrl, "o"} -> perform(state, :retrieve)
      key == {:ctrl, "p"} and top == nil -> perform(state, :export)
      key in [{:ctrl, "q"}, {:ctrl, "c"}] -> perform(state, :quit)
      true -> :pass
    end
  end

  # Undo is offered where the screen does not depend on one particular item.
  defp undoable?(nil), do: true
  defp undoable?(%{type: t}), do: t in [:catmgr, :viewmgr]

  # --- results of effects -----------------------------------------------------

  def saved(state, path, :ok) do
    %{state | path: path, dirty: false, saved_db: state.db}
    |> State.info("Saved #{Path.basename(path)}")
  end

  def saved(state, _path, {:error, reason}),
    do: State.error(state, "Could not save: #{inspect(reason)}")

  def loaded(state, path, {:ok, db}) do
    %State{
      State.new(db, path: path, today: state.today, width: state.width, height: state.height)
      | message: {:message, "Retrieved #{Path.basename(path)}"}
    }
    |> Layout.settle()
  end

  def loaded(state, _path, {:error, :enoent}), do: State.error(state, "File not found")

  def loaded(state, _path, {:error, reason}),
    do: State.error(state, "Could not open: #{inspect(reason)}")

  def written(state, path, :ok), do: State.info(state, "Wrote #{path}")

  def written(state, _path, {:error, reason}),
    do: State.error(state, "Could not write: #{inspect(reason)}")

  # --- dispatch --------------------------------------------------------------

  defp dispatch(state, nil, key), do: view_key(state, key)
  defp dispatch(state, %{type: :menu} = m, key), do: Menu.handle(state, m, key)
  defp dispatch(state, %{type: :viewmgr} = m, key), do: ViewManager.handle(state, m, key)
  defp dispatch(state, %{type: :prompt} = m, key), do: prompt_key(state, m, key)
  defp dispatch(state, %{type: :confirm} = m, key), do: confirm_key(state, m, key)
  defp dispatch(state, %{type: :note} = m, key), do: note_key(state, m, key)
  defp dispatch(state, %{type: :help} = m, key), do: help_key(state, m, key)
  defp dispatch(state, %{type: :move_item} = m, key), do: move_key(state, m, key)
  defp dispatch(state, mode, key), do: CategoryScreens.handle(state, mode, key)

  # --- the view ----------------------------------------------------------------

  defp view_key(%State{edit: edit} = state, key) when edit != nil, do: view_edit_key(state, key)

  defp view_key(state, key) do
    row = Layout.current_row(state)
    rows = Layout.rows(state)
    ncols = length(State.view(state).columns)

    case key do
      :up -> Layout.move_to(state, state.cursor - 1)
      :down -> Layout.move_to(state, state.cursor + 1)
      :enter -> Layout.move_to(state, state.cursor + 1)
      :pgup -> Layout.move_to(state, state.cursor - State.body_height(state))
      :pgdn -> Layout.move_to(state, state.cursor + State.body_height(state))
      :home -> Layout.move_to(state, 0)
      :end -> Layout.move_to(state, length(rows) - 1)
      :ctrl_home -> Layout.move_to(state, 0)
      :ctrl_end -> Layout.move_to(state, length(rows) - 1)
      :ctrl_pgup -> Layout.move_to(state, section_head_index(rows, state.cursor, -1))
      :ctrl_pgdn -> Layout.move_to(state, section_head_index(rows, state.cursor, 1))
      k when k in [:right, :tab] -> %{state | col: min(state.col + 1, ncols)}
      k when k in [:left, :shift_tab] -> %{state | col: max(state.col - 1, 0)}
      {:char, "/"} -> perform(state, :menu)
      {:char, c} -> start_typing(state, row, c)
      :insert -> insert(state, row)
      :delete -> delete(state, row)
      {:f, 1} -> perform(state, :help)
      {:f, 2} -> edit(state, row)
      {:f, 3} -> choices(state, row)
      {:f, 4} -> on_item(state, row, &Core.toggle_done(&1, &2, state.today))
      {:f, 5} -> perform(state, :note)
      {:f, 6} -> props(state, row)
      {:f, 7} -> on_item(state, row, &Core.toggle_mark/2)
      {:f, 8} -> perform(state, :view_manager)
      {:f, 9} -> perform(state, :category_manager)
      {:f, 10} -> perform(state, :menu)
      {:alt_f, 4} -> perform(state, :discard)
      {:ctrl, "d"} -> perform(state, :discard)
      {:alt_f, 10} -> perform(state, :move_item)
      {:alt, "d"} -> perform(state, :section_below)
      {:alt, "u"} -> perform(state, :section_above)
      {:alt, "r"} -> perform(state, :column_right)
      {:alt, "l"} -> perform(state, :column_left)
      _ -> state
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

  defp start_typing(state, %{kind: :item} = row, c) when state.col > 0 do
    %{state | edit: %{target: column_target(state, row, :replace), line: LineEdit.new(c)}}
  end

  defp start_typing(state, row, c) when row != nil, do: begin_new_item(state, row, c)
  defp start_typing(state, nil, _c), do: State.error(state, "Add a section first (ALT-D)")

  defp insert(state, nil), do: perform(state, :section_below)

  defp insert(state, %{kind: :item} = row) when state.col > 0 do
    target = column_target(state, row, :add)
    %{state | edit: %{target: target, line: LineEdit.new()}}
  end

  defp insert(state, row), do: begin_new_item(state, row, "")

  defp begin_new_item(state, row, text) do
    %{state | col: 0, edit: %{target: {:new_item, row.sidx, row.key}, line: LineEdit.new(text)}}
  end

  defp column_target(state, row, how) do
    column = Enum.at(State.view(state).columns, state.col - 1)
    {:column_entry, row.item.id, column.category_id, how}
  end

  defp edit(state, %{kind: :section, category: cat}) do
    if Database.protected?(state.db, cat.id),
      do: State.error(state, "#{cat.name} cannot be renamed"),
      else: %{state | edit: %{target: {:rename_category, cat.id}, line: LineEdit.new(cat.name)}}
  end

  defp edit(state, %{kind: :item, item: item}) when state.col == 0 do
    %{state | edit: %{target: {:edit_item, item.id}, line: LineEdit.new(item.text)}}
  end

  defp edit(state, %{kind: :item} = row) do
    {:column_entry, item_id, head, _} = column_target(state, row, :replace)

    case Database.date_field(state.db, head) do
      nil ->
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

      field ->
        text = Agenda.Core.DateParser.format(Map.get(state.db.items[item_id], field))

        %{
          state
          | edit: %{target: {:column_entry, item_id, head, :replace}, line: LineEdit.new(text)}
        }
    end
  end

  defp edit(state, nil), do: state

  defp delete(state, %{kind: :section, sidx: sidx}) do
    state
    |> State.change_db(Core.remove_section(state.db, state.view_id, sidx))
    |> State.info("Section removed from view (category kept)")
  end

  defp delete(state, %{kind: :item, item: item, category: cat}) when state.col == 0 do
    if cat.id == state.db.main_id do
      State.error(state, "Items cannot be removed from MAIN; use ALT-F4 to discard")
    else
      state
      |> State.change_db(Core.remove_from_category(state.db, item.id, cat.id))
      |> State.info("Removed from #{cat.name}")
    end
  end

  defp delete(state, %{kind: :item} = row) do
    {:column_entry, item_id, head, _} = column_target(state, row, :replace)
    State.change_db(state, clear_column(state.db, item_id, head))
  end

  defp delete(state, nil), do: state

  defp clear_column(db, item_id, head) do
    case Database.date_field(db, head) do
      nil ->
        if db.categories[head].children == [],
          do: Core.remove_from_category(db, item_id, head),
          else:
            db
            |> ViewModel.column_entries(item_id, head)
            |> Enum.reduce(db, &Core.remove_from_category(&2, item_id, &1))

      _ ->
        Core.remove_from_category(db, item_id, head)
    end
  end

  defp choices(state, %{kind: :item} = row) when state.col > 0 do
    {:column_entry, item_id, head, _} = column_target(state, row, :replace)

    if Database.date_field(state.db, head),
      do: State.error(state, "Type a date, e.g. tomorrow, friday, 2026-12-24"),
      else: CategoryScreens.open_picker(state, {:assign_column, item_id, head}, head)
  end

  defp choices(state, %{kind: :item, item: item}),
    do: CategoryScreens.open_profile(state, item.id)

  defp choices(state, %{kind: :section, sidx: sidx}),
    do: CategoryScreens.open_picker(state, {:change_section, sidx}, nil)

  defp choices(state, nil), do: state

  defp props(state, %{kind: :item, item: item}), do: CategoryScreens.open_profile(state, item.id)

  defp props(state, %{kind: :section, category: cat}),
    do: CategoryScreens.open_props(state, cat.id)

  defp props(state, nil), do: state

  defp on_item(state, %{kind: :item, item: item}, fun),
    do: State.change_db(state, fun.(state.db, item.id))

  defp on_item(state, _row, _fun), do: state

  # --- inline editing in the view ---------------------------------------------

  defp view_edit_key(%State{edit: edit} = state, key) do
    case key do
      :esc ->
        %{state | edit: nil}

      :enter ->
        commit(state)

      k when k in [:up, :down, :tab, :shift_tab] ->
        state |> commit() |> view_key(k)

      _ ->
        case LineEdit.handle(edit.line, key) do
          {:ok, line} -> %{state | edit: %{edit | line: line}}
          :unhandled -> state
        end
    end
  end

  defp commit(%State{edit: %{target: target, line: line}} = state) do
    commit(%{state | edit: nil}, target, line.text)
  end

  defp commit(state, {:new_item, sidx, key}, text) do
    if String.trim(text) == "" do
      state
    else
      rows = Layout.rows(state)
      section_rows = Enum.filter(rows, &(&1.kind == :item and &1.sidx == sidx))
      section_cat = Enum.at(State.view(state).sections, sidx).category_id

      {after_id, adjacent} =
        case key do
          {:item, _, id} ->
            next = section_rows |> Enum.drop_while(&(&1.item.id != id)) |> Enum.at(1)
            {id, [id | List.wrap(next && next.item.id)]}

          {:section, _} ->
            case section_rows do
              [] -> {nil, []}
              [first | _] -> {predecessor(state.db.item_order, first.item.id), [first.item.id]}
            end
        end

      section = if section_cat == state.db.main_id, do: nil, else: section_cat

      {db, id} =
        Core.add_item(state.db, text, state.today,
          section: section,
          after: after_id,
          adjacent: adjacent
        )

      state
      |> State.change_db(db)
      |> Map.put(:cursor_key, {:item, sidx, id})
      |> report_auto_assignments(id, List.wrap(section))
    end
  end

  defp commit(state, {:edit_item, id}, text) do
    if String.trim(text) == "" do
      State.error(state, "Item text cannot be empty (use ALT-F4 to discard)")
    else
      before = Database.explicit_categories(state.db, id)

      state
      |> State.change_db(Core.edit_item(state.db, id, text))
      |> report_auto_assignments(id, MapSet.to_list(before))
    end
  end

  defp commit(state, {:rename_category, id}, text) do
    case Core.rename_category(state.db, id, text) do
      {:ok, db} -> State.change_db(state, db)
      {:error, :empty} -> State.error(state, "A category needs a name")
      {:error, :protected} -> State.error(state, "This category cannot be renamed")
    end
  end

  defp commit(state, {:column_entry, item_id, head, how}, text) do
    db =
      if how == :replace and String.trim(text) != "",
        do: clear_column(state.db, item_id, head),
        else: state.db

    case Core.assign_by_name(db, item_id, head, text, state.today) do
      {:ok, db, _} ->
        State.change_db(state, db)

      {:error, :empty} ->
        state

      {:error, :invalid_date} ->
        State.error(state, "Not a date: #{text}")

      {:error, :ambiguous} ->
        State.error(state, "\"#{text}\" matches several categories; type more or press F3")
    end
  end

  defp predecessor(order, id) do
    case Enum.find_index(order, &(&1 == id)) do
      0 -> :first
      i -> Enum.at(order, i - 1)
    end
  end

  defp report_auto_assignments(state, item_id, already) do
    added =
      Database.explicit_categories(state.db, item_id)
      |> Enum.reject(&(&1 in already))
      |> Enum.map(&state.db.categories[&1].name)

    if added == [],
      do: state,
      else: State.info(state, "Also assigned to: " <> Enum.join(added, ", "))
  end

  # --- help -------------------------------------------------------------------

  defp help_key(state, mode, key) do
    page = State.body_height(state)
    last = max(Agenda.TUI.Render.help_line_count() - page, 0)

    top =
      case key do
        :up -> mode.top - 1
        :down -> mode.top + 1
        :pgup -> mode.top - page
        k when k in [:pgdn, {:char, " "}] -> mode.top + page
        _ -> :close
      end

    if top == :close,
      do: State.pop(state),
      else: State.put_mode(state, %{mode | top: top |> min(last) |> max(0)})
  end

  # --- moving an item between sections (ALT-F10) --------------------------------

  defp move_key(state, mode, key) do
    case key do
      :esc ->
        State.pop(state)

      :enter ->
        state |> State.pop() |> drop_item(mode, Layout.current_row(state))

      k when k in [:up, :down, :pgup, :pgdn, :home, :end, :ctrl_pgup, :ctrl_pgdn] ->
        view_key(state, k)

      _ ->
        state
    end
  end

  defp drop_item(state, %{item_id: id, from: from}, row) do
    to = Enum.at(State.view(state).sections, row.sidx).category_id
    after_id = if row.kind == :item, do: row.item.id
    db = Core.move_item(state.db, id, from, to, after: after_id)
    %{State.change_db(state, db) | cursor_key: {:item, row.sidx, id}}
  end

  # --- prompts and confirmations ------------------------------------------------

  @doc "Opens a one-line prompt; `action` is passed to `prompt_submitted/3`."
  def prompt(state, label, action, initial \\ "") do
    state
    |> State.push(%{type: :prompt, label: label, action: action})
    |> Map.put(:edit, %{line: LineEdit.new(initial)})
  end

  def confirm(state, question, action),
    do: State.push(state, %{type: :confirm, question: question, action: action})

  defp prompt_key(state, mode, key) do
    case key do
      :esc ->
        State.pop(state)

      :enter ->
        state.edit.line.text |> then(&prompt_submitted(State.pop(state), mode.action, &1))

      _ ->
        case LineEdit.handle(state.edit.line, key) do
          {:ok, line} -> %{state | edit: %{line: line}}
          :unhandled -> state
        end
    end
  end

  defp prompt_submitted(state, action, text) do
    text = String.trim(text)

    cond do
      text == "" -> state
      true -> prompt_action(state, action, text)
    end
  end

  defp prompt_action(state, :save_as, text) do
    path = Agenda.Store.normalize_path(text)
    State.effect(%{state | path: path}, {:save, path})
  end

  defp prompt_action(state, :save_as_then_quit, text) do
    path = Agenda.Store.normalize_path(text)
    state |> Map.put(:path, path) |> State.effect({:save, path}) |> State.effect(:quit)
  end

  defp prompt_action(state, :retrieve, text),
    do: State.effect(state, {:load, Agenda.Store.normalize_path(text)})

  defp prompt_action(state, :new_file, text) do
    path = Agenda.Store.normalize_path(text)

    %{
      State.new(Core.new_file(),
        path: path,
        today: state.today,
        width: state.width,
        height: state.height
      )
      | dirty: true,
        saved_db: nil
    }
    |> State.info("New file #{Path.basename(path)} (not saved yet)")
  end

  defp prompt_action(state, :add_category, text) do
    case Core.add_category(state.db, state.db.main_id, text) do
      {:ok, db, _} -> state |> State.change_db(db) |> State.info("Added #{text} under MAIN")
      {:error, :duplicate} -> State.error(state, "#{text} already exists")
    end
  end

  defp prompt_action(state, :add_view, text) do
    CategoryScreens.open_picker(state, {:new_view, text}, nil)
  end

  defp prompt_action(state, :rename_view, text) do
    State.change_db(state, Core.rename_view(state.db, state.view_id, text))
  end

  defp prompt_action(state, :export, text) do
    path = Path.expand(text)
    State.effect(state, {:write_text, path, Agenda.TUI.Render.export_text(state)})
  end

  defp confirm_key(state, mode, key) do
    case key do
      {:char, c} when c in ["y", "Y"] -> state |> State.pop() |> confirmed(mode.action, true)
      {:char, c} when c in ["n", "N"] -> state |> State.pop() |> confirmed(mode.action, false)
      :esc -> State.pop(state)
      _ -> state
    end
  end

  defp confirmed(state, {:discard_item, id}, true) do
    state |> State.change_db(Core.discard_item(state.db, id)) |> State.info("Item discarded")
  end

  defp confirmed(state, {:discard_category, id}, true) do
    case Core.discard_category(state.db, id) do
      {:ok, db} -> state |> State.change_db(db) |> State.info("Category discarded")
      {:error, :protected} -> State.error(state, "This category cannot be discarded")
    end
  end

  defp confirmed(state, {:discard_view, id}, true) do
    case Core.discard_view(state.db, id) do
      {:ok, db} ->
        view_id = if state.view_id == id, do: hd(db.view_order), else: state.view_id
        %{State.change_db(state, db) | view_id: view_id, cursor: 0, cursor_key: nil}

      {:error, :last_view} ->
        State.error(state, "A file must have at least one view")
    end
  end

  defp confirmed(state, :quit, true), do: perform(state, :save_and_quit)
  defp confirmed(state, :quit, false), do: State.effect(state, :quit)
  defp confirmed(state, _action, false), do: state

  # --- notes --------------------------------------------------------------------

  defp note_key(state, mode, key) do
    case key do
      k when k in [:esc, {:f, 5}, {:f, 4}] ->
        text = TextEdit.text(mode.edit)

        db =
          case mode.target do
            {:item, id} -> Core.set_note(state.db, id, text)
            {:category, id} -> Core.set_category_note(state.db, id, text)
          end

        if db == state.db, do: State.pop(state), else: state |> State.pop() |> State.change_db(db)

      _ ->
        case TextEdit.handle(mode.edit, key) do
          {:ok, edit} -> State.put_mode(state, %{mode | edit: edit})
          :unhandled -> state
        end
    end
  end

  # --- actions (shared by keys and menus) --------------------------------------

  @doc "Performs a named action. Used by key handlers and the menu."
  @spec perform(State.t(), atom) :: State.t()
  def perform(state, action) do
    do_perform(state, action, Layout.current_row(state))
  end

  defp do_perform(state, :menu, _row), do: Menu.open(state)
  defp do_perform(state, :view_manager, _), do: ViewManager.open(state)
  defp do_perform(state, :category_manager, _), do: CategoryScreens.open_catmgr(state)
  defp do_perform(state, :help, _), do: State.push(state, %{type: :help, top: 0})
  defp do_perform(state, :undo, _), do: History.undo(state)
  defp do_perform(state, :redo, _), do: History.redo(state)

  defp do_perform(state, :save, _) do
    if state.path,
      do: State.effect(state, {:save, state.path}),
      else: prompt(state, "Save file as:", :save_as)
  end

  defp do_perform(state, :save_as, _),
    do: prompt(state, "Save file as:", :save_as, state.path || "")

  defp do_perform(state, :retrieve, _), do: prompt(state, "File to retrieve:", :retrieve)
  defp do_perform(state, :new_file, _), do: prompt(state, "Name of new file:", :new_file)

  defp do_perform(state, :export, _),
    do: prompt(state, "Print view to text file:", :export, "agenda-view.txt")

  defp do_perform(state, :quit, _) do
    if state.dirty,
      do: confirm(state, "Save changes before quitting? (Y/N, ESC to cancel)", :quit),
      else: State.effect(state, :quit)
  end

  defp do_perform(state, :save_and_quit, _) do
    if state.path,
      do: state |> State.effect({:save, state.path}) |> State.effect(:quit),
      else: prompt(state, "Save file as:", :save_as_then_quit)
  end

  defp do_perform(state, :note, %{kind: :item, item: item}) do
    State.push(state, %{
      type: :note,
      target: {:item, item.id},
      title: item.text,
      edit: TextEdit.new(item.note)
    })
  end

  defp do_perform(state, :note, %{kind: :section, category: cat}) do
    State.push(state, %{
      type: :note,
      target: {:category, cat.id},
      title: cat.name,
      edit: TextEdit.new(cat.note)
    })
  end

  defp do_perform(state, :discard, %{kind: :item, item: item}) do
    confirm(state, "Discard this item from the whole file? (Y/N)", {:discard_item, item.id})
  end

  defp do_perform(state, :discard, %{kind: :section, category: cat}) do
    if Database.protected?(state.db, cat.id),
      do: State.error(state, "#{cat.name} cannot be discarded"),
      else:
        confirm(
          state,
          "Discard category #{cat.name} and its children? (Y/N)",
          {:discard_category, cat.id}
        )
  end

  defp do_perform(state, :done, row),
    do: on_item(state, row, &Core.toggle_done(&1, &2, state.today))

  defp do_perform(state, :mark, row), do: on_item(state, row, &Core.toggle_mark/2)

  defp do_perform(state, :assign, %{kind: :item, item: item}),
    do: CategoryScreens.open_profile(state, item.id)

  defp do_perform(state, :move_item, %{kind: :item, item: item, category: cat}) do
    state
    |> State.push(%{type: :move_item, item_id: item.id, from: cat.id})
    |> State.info("Move to where? Highlight the new position and press ENTER (ESC cancels)")
  end

  defp do_perform(state, :add_category, _),
    do: prompt(state, "New category name (under MAIN):", :add_category)

  defp do_perform(state, :recalc, _) do
    state
    |> State.change_db(Core.reassign_all(state.db))
    |> State.info("Automatic assignments recalculated")
  end

  defp do_perform(state, :add_view, _), do: prompt(state, "Name of new view:", :add_view)

  defp do_perform(state, :rename_view, _),
    do: prompt(state, "Rename view to:", :rename_view, State.view(state).name)

  defp do_perform(state, :discard_view, _) do
    confirm(
      state,
      "Discard view #{State.view(state).name}? Items and categories are kept. (Y/N)",
      {:discard_view, state.view_id}
    )
  end

  defp do_perform(state, :section_below, row),
    do: CategoryScreens.open_picker(state, {:add_section, section_index(state, row) + 1}, nil)

  defp do_perform(state, :section_above, row),
    do: CategoryScreens.open_picker(state, {:add_section, max(section_index(state, row), 0)}, nil)

  defp do_perform(state, :remove_section, %{sidx: sidx}) do
    State.change_db(state, Core.remove_section(state.db, state.view_id, sidx))
  end

  defp do_perform(state, :collapse_section, %{sidx: sidx}) do
    %{
      State.change_db(state, Core.toggle_section_collapsed(state.db, state.view_id, sidx))
      | cursor_key: {:section, sidx}
    }
  end

  defp do_perform(state, :column_right, _),
    do: CategoryScreens.open_picker(state, {:add_column, state.col}, nil)

  defp do_perform(state, :column_left, _),
    do: CategoryScreens.open_picker(state, {:add_column, max(state.col - 1, 0)}, nil)

  defp do_perform(state, :remove_column, _) do
    if state.col == 0,
      do: State.error(state, "Highlight a column first (use → or TAB)"),
      else: %{
        State.change_db(state, Core.remove_column(state.db, state.view_id, state.col - 1))
        | col: state.col - 1
      }
  end

  defp do_perform(state, action, _) when action in [:wider, :narrower] do
    if state.col == 0,
      do: State.error(state, "Highlight a column first (use → or TAB)"),
      else:
        State.change_db(
          state,
          Core.resize_column(
            state.db,
            state.view_id,
            state.col - 1,
            if(action == :wider, do: 2, else: -2)
          )
        )
  end

  defp do_perform(state, {:toggle_view, option}, _),
    do: State.change_db(state, Core.toggle_view_option(state.db, state.view_id, option))

  defp do_perform(state, _action, _row), do: State.error(state, "Highlight an item first")

  defp section_index(state, nil), do: length(State.view(state).sections) - 1
  defp section_index(_state, row), do: row.sidx
end
