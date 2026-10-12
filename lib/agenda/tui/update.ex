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
  alias Agenda.Core.{Database, DateFormat, ViewModel}

  alias Agenda.TUI.{
    CalendarBox,
    CategoryScreens,
    ColumnProperties,
    Completion,
    Draw,
    FileProperties,
    GoTo,
    History,
    ItemProperties,
    SearchBox,
    AlarmList,
    SortBox,
    Layout,
    LineEdit,
    Menu,
    NoteSearch,
    RangeFilterBox,
    State,
    TextEdit,
    ViewManager
  }

  @spec handle(State.t(), term) :: {State.t(), [term]}
  def handle(%State{} = state, key) do
    # the end of a macro run is not a keypress: what the run said stays
    message = if key == :macro_done, do: state.message
    state = %{state | message: message, effects: []}
    key = normalize(state, key)

    next =
      with :pass <- splash_key(state, key),
           :pass <- Agenda.TUI.Macros.key(state, key),
           :pass <- global_key(state, key),
           do: dispatch(state, State.mode(state), key)

    # Learn mode records the key after it has done its work (R50)
    next = Agenda.TUI.Macros.record(state, key, next)
    state = History.record(state, next)
    state = %{state | dirty: state.db != state.saved_db}

    state =
      if state.modes == [] or
           match?(%{type: t} when t in [:move_item, :searching, :browse], State.mode(state)),
         do: Layout.settle(state),
         else: state

    {%{state | effects: [], last_key: key}, state.effects}
  end

  # the splash screen goes at any key, which does nothing else (R52)
  defp splash_key(%State{modes: [%{type: :splash} | _]} = state, key) when key != :macro_done,
    do: Agenda.TUI.Splash.close(state)

  defp splash_key(_state, _key), do: :pass

  @doc """
  How the program starts (R52): the splash screen, and when no file was
  named (`ask_file`), under it the prompt for a file to open or create,
  with the last file used.
  """
  def start(state, ask_file) do
    state =
      if ask_file,
        do: prompt(state, "File to open or create:", :startup_open, state.prefs.last_file || ""),
        else: state

    Agenda.TUI.Splash.open(state)
  end

  # --- keyboard aliases -------------------------------------------------------
  #
  # Mac keyboards have no INS key, and terminals do not pass the Command key
  # to programs, so every command also has a CTRL key (which a terminal can
  # map ⌘ shortcuts to; see docs/KEYBOARD.md).

  # True while the user is typing text, when CTRL keys act as editing keys.
  defp typing?(state) do
    state.edit != nil or
      match?(%{type: t} when t in [:note, :note_search, :prompt], State.mode(state))
  end

  # the developer screen shows keys as decoded
  defp normalize(%State{modes: [%{type: :devtools} | _]}, key), do: key

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
      key == {:alt, "?"} and not typing?(state) and not match?(%{type: :devtools}, top) ->
        Agenda.TUI.DevTools.open(state)

      typing?(state) or match?(%{type: t} when t in [:confirm, :menu, :help, :devtools], top) ->
        :pass

      key == {:ctrl, "z"} ->
        if undoable?(top), do: History.undo(state), else: :pass

      key == {:ctrl, "y"} ->
        if undoable?(top), do: History.redo(state), else: :pass

      key == {:alt, "k"} ->
        State.toggle_key_map(state)

      key == {:ctrl, "s"} ->
        perform(state, :save)

      key == {:ctrl, "o"} ->
        perform(state, :retrieve)

      key == {:ctrl, "p"} and top == nil ->
        perform(state, :export)

      key in [{:ctrl, "q"}, {:ctrl, "c"}, {:alt, "q"}] ->
        perform(state, :quit)

      true ->
        :pass
    end
  end

  # Undo is offered where the screen does not depend on one particular item.
  defp undoable?(nil), do: true
  defp undoable?(%{type: t}), do: t in [:catmgr, :viewmgr]

  # --- the clock (R38) -----------------------------------------------------------

  @doc """
  Called by the shell with the current time on every pass of its loop:
  updates the clock, forgets the previous day's past alarms when the date
  changes, and rings alarms whose time has come (a message, a bell, and
  the alarm symbol in the title until the alarm list is shown). Ringing
  is not an undo step.
  """
  @spec tick(State.t(), NaiveDateTime.t()) :: {State.t(), [term]}
  def tick(%State{} = state, %NaiveDateTime{} = now) do
    today = NaiveDateTime.to_date(now)

    # a new day: forget yesterday's past alarms and re-check conditions,
    # whose relative dates ("this week") may now mean other days (R15a)
    db =
      if today != state.today,
        do:
          state.db
          |> Core.clear_old_alarms(today)
          |> Core.recheck_conditions(State.context(%{state | now: now})),
        else: state.db

    {db, rung} = Core.ring_alarms(db, now)
    state = %{state | now: now, today: today, db: db}

    # the splash screen's three seconds (R52)
    state =
      case state.modes do
        [%{type: :splash} = splash | _] ->
          if Agenda.TUI.Splash.over?(splash, now), do: Agenda.TUI.Splash.close(state), else: state

        _ ->
          state
      end

    state = %{state | dirty: state.db != state.saved_db}

    # calendars due to be read again (R45), one read at a time each
    state =
      db
      |> Core.calendars_due(now)
      |> Enum.reduce(%{state | effects: []}, &fetch_calendar(&2, &1.id, :auto))

    {state, fetches} = {%{state | effects: []}, state.effects}

    case rung do
      [] ->
        {state, fetches}

      ids ->
        texts = Enum.map_join(ids, " · ", &state.db.items[&1].text)
        {%{state | alarm_rang: true} |> State.info("Alarm: " <> texts), [:bell | fetches]}
    end
  end

  @doc """
  Asks the shell to read a calendar (`{:fetch_calendar, id, url}`), unless
  it is being read already; `kind` is `:manual` (from the Calendars box,
  which reports the result) or `:auto` (on schedule, quiet unless something
  changed).
  """
  def fetch_calendar(state, cal_id, kind) do
    cal = state.db.calendars[cal_id]

    if cal == nil or Map.has_key?(state.fetching, cal_id),
      do: state,
      else:
        %{state | fetching: Map.put(state.fetching, cal_id, kind)}
        |> State.effect({:fetch_calendar, cal_id, cal.url})
  end

  @doc """
  After the shell read a calendar: its events are mirrored into the file
  (one undo step), or the failure is remembered (R45).
  """
  def calendar_read(state, cal_id, result) do
    {kind, fetching} = Map.pop(state.fetching, cal_id)
    state = %{state | fetching: fetching}
    cal = state.db.calendars[cal_id]

    if cal == nil do
      state
    else
      next = read_into(state, cal, kind, result)
      next = %{History.record(state, next) | dirty: next.db != next.saved_db}
      if next.modes == [], do: Layout.settle(next), else: next
    end
  end

  defp read_into(state, cal, kind, {:ok, events}) do
    {:ok, db, counts} = Core.sync_calendar(state.db, cal.id, events, State.context(state))
    state = %{state | db: db}

    parts =
      [added: "new", updated: "changed", removed: "removed"]
      |> Enum.filter(fn {key, _} -> counts[key] > 0 end)
      |> Enum.map_join(", ", fn {key, word} -> "#{counts[key]} #{word}" end)

    cond do
      parts != "" -> State.info(state, "#{cal.name}: #{parts}")
      kind == :manual -> State.info(state, "#{cal.name}: no changes")
      true -> state
    end
  end

  defp read_into(state, cal, kind, {:error, message}) do
    state = %{state | db: Core.calendar_failed(state.db, cal.id, message, State.context(state))}
    if kind == :manual, do: State.error(state, "#{cal.name}: #{message}"), else: state
  end

  # --- results of effects -----------------------------------------------------

  @doc "After saving the person's preferences (R41b): only a failure is reported."
  def preferences_saved(state, :ok), do: state

  def preferences_saved(state, {:error, reason}),
    do: State.error(state, "Could not save your preferences: #{inspect(reason)}")

  def saved(state, path, :ok) do
    %{state | path: path, dirty: false, saved_db: state.db}
    |> remember(path)
    |> State.info("Saved #{Path.basename(path)}")
  end

  def saved(state, _path, {:error, reason}),
    do: State.error(state, "Could not save: #{inspect(reason)}")

  # the file offered when Agendum next starts without one (R52); the shell
  # saves the preferences when this changed them
  defp remember(state, path), do: %{state | prefs: %{state.prefs | last_file: path}}

  @doc """
  The startup prompt's file (R52): opened when it exists; otherwise a new
  file, saved there on the first save.
  """
  def opened(state, path, {:error, :enoent}) do
    state
    |> State.reopen(Core.new_file(), path)
    |> remember(path)
    |> State.info("New file #{Path.basename(path)} (saved there on the first save)")
    |> Layout.settle()
  end

  def opened(state, path, result), do: loaded(state, path, result)

  def loaded(state, path, {:ok, db}) do
    %State{
      State.reopen(state, db, path)
      | message: {:message, "Retrieved #{Path.basename(path)}"}
    }
    |> remember(path)
    |> Layout.settle()
  end

  def loaded(state, _path, {:error, :enoent}), do: State.error(state, "File not found")

  def loaded(state, _path, {:error, reason}),
    do: State.error(state, "Could not open: #{inspect(reason)}")

  @doc """
  After the shell read a JSON file to import (R44): the file opens as a
  new, untitled file, to be saved under a name; on an error the open file
  stays.
  """
  def imported(state, path, {:ok, text}) do
    case Core.import_json(text) do
      {:ok, db} ->
        %State{
          State.reopen(state, db, nil)
          | dirty: true,
            saved_db: nil,
            message: {:message, "Imported #{Path.basename(path)} (save it to keep it)"}
        }
        |> Layout.settle()

      {:error, reason} ->
        State.error(state, "Could not import #{Path.basename(path)}: #{reason}")
    end
  end

  def imported(state, _path, {:error, :enoent}), do: State.error(state, "File not found")

  def imported(state, _path, {:error, reason}),
    do: State.error(state, "Could not read: #{inspect(reason)}")

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
  defp dispatch(state, %{type: :devtools} = m, key), do: Agenda.TUI.DevTools.handle(state, m, key)
  defp dispatch(state, %{type: :move_item} = m, key), do: move_key(state, m, key)
  defp dispatch(state, %{type: :item_props} = m, key), do: ItemProperties.handle(state, m, key)
  defp dispatch(state, %{type: :scope} = m, key), do: scope_key(state, m, key)
  defp dispatch(state, %{type: :sort} = m, key), do: SortBox.handle(state, m, key)
  defp dispatch(state, %{type: :search_box} = m, key), do: SearchBox.handle(state, m, key)
  defp dispatch(state, %{type: :note_search} = m, key), do: NoteSearch.handle(state, m, key)

  defp dispatch(state, %{type: :calendar} = m, key), do: CalendarBox.handle(state, m, key)
  defp dispatch(state, %{type: :macros} = m, key), do: Agenda.TUI.Macros.handle(state, m, key)

  defp dispatch(state, %{type: :select_file} = m, key),
    do: Agenda.TUI.SelectFile.handle(state, m, key)

  defp dispatch(state, %{type: :macro_props} = m, key),
    do: Agenda.TUI.MacroProps.handle(state, m, key)

  defp dispatch(state, %{type: :browse} = m, key), do: Agenda.TUI.Browse.handle(state, m, key)

  defp dispatch(state, %{type: :schedule} = m, key),
    do: Agenda.TUI.ScheduleBox.handle(state, m, key)

  defp dispatch(state, %{type: :datebook_props} = m, key),
    do: Agenda.TUI.DatebookBox.handle(state, m, key)

  defp dispatch(state, %{type: type} = m, key)
       when type in [:file_props, :date_settings, :display_format],
       do: FileProperties.handle(state, m, key)

  defp dispatch(state, %{type: :calendars} = m, key),
    do: Agenda.TUI.CalendarsBox.handle(state, m, key)

  defp dispatch(state, %{type: :customize} = m, key),
    do: Agenda.TUI.CustomizeBox.handle(state, m, key)

  defp dispatch(state, %{type: :input_format} = m, key),
    do: Agenda.TUI.InputFormatBox.handle(state, m, key)

  defp dispatch(state, %{type: :category_match} = m, key),
    do: Agenda.TUI.CategoryMatchBox.handle(state, m, key)

  defp dispatch(state, %{type: :auto_assign} = m, key),
    do: Agenda.TUI.AutoAssignBox.handle(state, m, key)

  defp dispatch(state, %{type: :date_rule} = m, key),
    do: Agenda.TUI.DateRuleBox.handle(state, m, key)

  defp dispatch(state, %{type: :goto} = m, key), do: GoTo.handle(state, m, key)

  defp dispatch(state, %{type: :questions} = m, key),
    do: Agenda.TUI.QuestionsBox.handle(state, m, key)

  defp dispatch(state, %{type: :execute} = m, key),
    do: Agenda.TUI.ExecuteBox.handle(state, m, key)

  defp dispatch(state, %{type: :action_box} = m, key),
    do: Agenda.TUI.ActionBox.handle(state, m, key)

  defp dispatch(state, %{type: :range_filter} = m, key),
    do: RangeFilterBox.handle(state, m, key)

  defp dispatch(state, %{type: :column_props} = m, key),
    do: ColumnProperties.handle(state, m, key)

  defp dispatch(state, %{type: :date_column_props} = m, key),
    do: Agenda.TUI.DateColumnBox.handle(state, m, key)

  defp dispatch(state, %{type: :alarm_list} = m, key), do: AlarmList.handle(state, m, key)

  defp dispatch(state, %{type: :searching} = m, key),
    do: SearchBox.searching_key(state, m, key, &view_key/2)

  defp dispatch(state, mode, key), do: CategoryScreens.handle(state, mode, key)

  # --- the view ----------------------------------------------------------------

  defp view_key(%State{edit: edit} = state, key) when edit != nil, do: view_edit_key(state, key)

  # One branch per key, like Agenda's key chart.
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
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
      :delete -> if bulk?(state, row), do: scoped(state, :remove, row), else: delete(state, row)
      {:f, 1} -> perform(state, :help)
      {:f, 2} -> edit(state, row)
      {:f, 3} -> if bulk?(state, row), do: scoped(state, :profile, row), else: choices(state, row)
      {:f, 4} -> scoped(state, :done, row)
      {:f, 5} -> perform(state, :note)
      {:f, 6} -> props(state, row)
      {:f, 7} -> mark(state, row)
      {:alt_f, 7} -> perform(state, :unmark_all)
      {:alt, "j"} -> jump_to_marked(state, rows)
      {:alt, "m"} -> scoped(state, :make_assign, row)
      {:f, 8} -> perform(state, :view_manager)
      {:f, 9} -> perform(state, :category_manager)
      {:f, 10} -> perform(state, :menu)
      {:alt_f, 4} -> scoped(state, :discard, row)
      {:alt_f, 2} -> scoped(state, :when, row)
      {:ctrl, "d"} -> scoped(state, :discard, row)
      {:alt_f, 10} -> scoped(state, :move_item, row)
      {:alt, "d"} -> perform(state, :section_below)
      {:alt_f, 5} -> GoTo.open(state)
      {:alt, "n"} -> step_view(state, 1)
      {:alt, "p"} -> step_view(state, -1)
      {:alt, "w"} -> perform(state, :save)
      {:alt, "g"} -> perform(state, :retrieve)
      {:alt, "v"} -> perform(state, {:toggle_view, :hide_empty})
      {:alt, "i"} -> insert(state, row)
      {:alt, "o"} -> dependency(state, row)
      {:alt, "x"} -> Agenda.TUI.ExecuteBox.run(state, state.db.main_id, :all)
      {:alt, "e"} -> execute_category(state, row)
      {:alt_f, 6} -> SearchBox.open(state, :view)
      {:alt, "a"} -> perform(state, :alarm)
      {:alt, "c"} -> CalendarBox.open(state, nil)
      {:alt, "b"} -> Agenda.TUI.Browse.open(state)
      {:alt_f, 8} -> perform(state, :last_view)
      {:alt, "-"} -> collapse_sections(state, row, true)
      {:alt, "="} -> collapse_sections(state, row, false)
      {:alt, "u"} -> perform(state, :section_above)
      {:alt, "r"} -> perform(state, :column_right)
      {:alt, "l"} -> perform(state, :column_left)
      _ -> state
    end
  end

  # ALT-N / ALT-P: the next / previous view in the view manager's order.
  defp step_view(state, step) do
    order = state.db.view_order
    index = Enum.find_index(order, &(&1 == state.view_id)) || 0
    State.switch_view(state, Enum.at(order, Integer.mod(index + step, length(order))))
  end

  # ALT-- / ALT-= collapse or expand the current section; pressed twice,
  # every section in the view (User's Guide 5-5).
  defp collapse_sections(state, nil, _collapsed), do: state
  defp collapse_sections(state, %{slot: %{}}, _collapsed), do: datebook_sections(state)

  defp collapse_sections(state, row, collapsed) do
    twice = state.last_key == {:alt, if(collapsed, do: "-", else: "=")}

    db =
      if twice,
        do: Core.set_all_sections_collapsed(state.db, state.view_id, collapsed),
        else: Core.set_section_collapsed(state.db, state.view_id, row.sidx, collapsed)

    %{State.change_db(state, db) | cursor_key: {:section, row.sidx}}
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
    numeric = state.db.categories[head].kind == :numeric

    case Database.date_category?(state.db, head) do
      false when numeric ->
        text = number_text(Database.number(state.db, item_id, head))

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
        text = Agenda.Core.DateParser.format(Database.item_date(state.db, item_id, head))

        %{
          state
          | edit: %{target: {:column_entry, item_id, head, :replace}, line: LineEdit.new(text)}
        }
    end
  end

  defp edit(state, nil), do: state

  @doc "A number as offered for editing: in full, without formatting."
  def number_text(nil), do: ""

  def number_text(value) do
    if value == Float.round(value),
      do: value |> round() |> Integer.to_string(),
      else: :erlang.float_to_binary(value, [:short])
  end

  defp delete(state, %{kind: :section, slot: %{}}), do: datebook_sections(state)

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
      |> State.change_db(
        Core.remove_from_category(state.db, item.id, cat.id, State.context(state))
      )
      |> State.info("Removed from #{cat.name}")
    end
  end

  defp delete(state, %{kind: :item} = row) do
    {:column_entry, item_id, head, _} = column_target(state, row, :replace)
    State.change_db(state, clear_column(state.db, item_id, head, State.context(state)))
  end

  defp delete(state, nil), do: state

  defp clear_column(db, item_id, head, context) do
    case Database.date_category?(db, head) do
      false ->
        if db.categories[head].children == [],
          do: Core.remove_from_category(db, item_id, head, context),
          else:
            db
            |> ViewModel.column_entries(item_id, head)
            |> Enum.reduce(db, &Core.remove_from_category(&2, item_id, &1, context))

      true ->
        Core.remove_from_category(db, item_id, head, context)
    end
  end

  defp choices(state, %{kind: :item} = row) when state.col > 0 do
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

  defp choices(state, %{kind: :item, item: item}),
    do: CategoryScreens.open_profile(state, item.id)

  defp choices(state, %{kind: :section, slot: %{}}), do: datebook_sections(state)

  defp choices(state, %{kind: :section, sidx: sidx}),
    do: CategoryScreens.open_picker(state, {:change_section, sidx}, nil)

  defp choices(state, nil), do: state

  defp props(state, %{kind: :item, item: item}), do: ItemProperties.open(state, item.id)

  defp props(state, %{kind: :section, category: cat}),
    do: CategoryScreens.open_props(state, cat.id)

  defp props(state, nil), do: state

  # ALT-E: the conditions and actions of the highlighted section's category
  # (or the item's section) and its children, on all items (R15e).
  defp execute_category(state, nil), do: state

  defp execute_category(state, row),
    do: Agenda.TUI.ExecuteBox.run(state, row.category.id, :all)

  # ALT-O (User's Guide 13-12): make the item depend on the marked items,
  # or, with nothing marked, clear its dependencies.
  defp dependency(state, %{kind: :item, item: item}) do
    marked = Core.marked_items(state.db) -- [item.id]

    cond do
      marked != [] ->
        confirm(
          state,
          "Make this item depend on the #{Draw.count(length(marked), "marked item")}? (Y/N)",
          {:make_dependent, item.id, marked}
        )

      Core.prerequisites(state.db, item.id) != [] ->
        confirm(state, "Clear this item's dependencies? (Y/N)", {:clear_dependencies, item.id})

      true ->
        State.error(state, "Mark the items it depends on with F7, then ALT-O")
    end
  end

  defp dependency(state, _row), do: State.error(state, "Highlight an item first")

  # F4 DONE; for a recurring item, says when its next occurrence is (R14a).
  defp toggle_done(state, row) do
    next = on_item(state, row, &Core.toggle_done(&1, &2, State.context(state)))

    case next.db.item_order -- state.db.item_order do
      [copy] ->
        date = DateFormat.date(next.db.items[copy].when, next.db.date_format)
        State.info(next, "Done · the next one is on #{date}")

      _ ->
        next
    end
  end

  defp on_item(state, %{kind: :item, item: item}, fun),
    do: State.change_db(state, fun.(state.db, item.id))

  defp on_item(state, _row, _fun), do: state

  # --- inline editing in the view ---------------------------------------------

  defp view_edit_key(%State{edit: edit} = state, key) do
    completing = Completion.column_entry?(state)

    case key do
      :esc ->
        %{state | edit: nil}

      :enter ->
        commit(state)

      # automatic completion (R32): NEXTSEL / PREVSEL and NEWCAT
      k when completing and k in [{:f, 8}, {:alt, "n"}] ->
        Completion.cycle(state, 1)

      k when completing and k in [{:f, 7}, {:alt, "p"}] ->
        Completion.cycle(state, -1)

      k when completing and k in [:insert, {:f, 5}] ->
        commit_new_category(state)

      k when k in [:up, :down, :tab, :shift_tab] ->
        state |> commit() |> view_key(k)

      _ ->
        case LineEdit.handle(edit.line, key) do
          # typing starts the completion over at the first match
          {:ok, line} -> %{state | edit: edit |> Map.put(:line, line) |> Map.put(:choice, 0)}
          :unhandled -> state
        end
    end
  end

  # ENTER on a column entry takes the completion shown (R32); with no match
  # the typed name becomes a new category.
  @doc """
  Sets a column entry as if typed (replacing what is there), as the pop-up
  calendar does with the date it picked (R46).
  """
  def set_column_entry(state, item_id, head, text),
    do: commit(state, {:column_entry, item_id, head, :replace}, text)

  defp commit(%State{edit: %{target: {:column_entry, item_id, head, how}, line: line}} = state) do
    shown = Completion.shown(state)
    state = %{state | edit: nil}

    if shown do
      db =
        if how == :replace,
          do: clear_column(state.db, item_id, head, State.context(state)),
          else: state.db

      State.change_db(state, Core.assign(db, item_id, shown, State.context(state)))
    else
      commit(state, {:column_entry, item_id, head, how}, line.text)
    end
  end

  defp commit(%State{edit: %{target: target, line: line}} = state) do
    commit(%{state | edit: nil}, target, line.text)
  end

  # INS / F5 (NEWCAT): exactly the typed name, even if it begins an existing one.
  defp commit_new_category(
         %State{edit: %{target: {:column_entry, item_id, head, how}, line: line}} = state
       ) do
    state = %{state | edit: nil}

    db =
      if how == :replace and String.trim(line.text) != "",
        do: clear_column(state.db, item_id, head, State.context(state)),
        else: state.db

    case Core.assign_new_by_name(db, item_id, head, line.text) do
      {:ok, db, cat_id} ->
        state |> State.change_db(db) |> State.info("Assigned to #{db.categories[cat_id].name}")

      {:error, :empty} ->
        state
    end
  end

  defp commit(state, {:new_item, sidx, key}, text) do
    datebook = State.view(state).datebook

    cond do
      String.trim(text) == "" -> state
      datebook -> new_datebook_item(state, datebook, sidx, text)
      true -> new_item(state, sidx, key, text)
    end
  end

  defp commit(state, {:edit_item, id}, text) do
    if String.trim(text) == "" do
      State.error(state, "Item text cannot be empty (use ALT-F4 to discard)")
    else
      before = Database.explicit_categories(state.db, id)
      old_when = Core.when_at(state.db.items[id])

      state
      |> State.change_db(Core.edit_item(state.db, id, text, State.context(state)))
      |> report_auto_assignments(id, MapSet.to_list(before), old_when)
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
        do: clear_column(state.db, item_id, head, State.context(state)),
        else: state.db

    case Core.assign_by_name(db, item_id, head, text, State.context(state)) do
      {:ok, db, _} ->
        State.change_db(state, db)

      {:error, :empty} ->
        state

      {:error, :invalid_date} ->
        State.error(state, "Not a date: #{text}")

      {:error, :not_a_number} ->
        State.error(state, "Not a number: #{String.trim(text)}")

      {:error, :ambiguous} ->
        State.error(state, "\"#{text}\" matches several categories; type more or press F3")
    end
  end

  # typed into a datebook slot: filed under the Section category, dated at
  # the slot's start (R47)
  defp new_datebook_item(state, datebook, sidx, text) do
    slot =
      state
      |> Layout.rows()
      |> Enum.find(&(&1.kind == :section and &1.sidx == sidx))
      |> Map.get(:slot)

    section =
      if datebook.section_category == state.db.main_id, do: nil, else: datebook.section_category

    opts = Keyword.put(Agenda.Core.Datebook.entry(datebook, slot), :section, section)
    {db, id} = Core.add_item(state.db, text, State.context(state), opts)

    state
    |> State.change_db(db)
    |> Map.put(:cursor_key, {:item, sidx, id})
    |> report_auto_assignments(id, List.wrap(section))
  end

  defp new_item(state, sidx, key, text) do
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
      Core.add_item(state.db, text, State.context(state),
        section: section,
        after: after_id,
        adjacent: adjacent
      )

    # a filtered view or section gives new items what the filter needs (R28)
    required = Core.entry_categories(db, state.view_id, sidx)
    db = Enum.reduce(required, db, &Core.assign(&2, id, &1, State.context(state)))
    values = Core.entry_values(db, state.view_id, sidx, State.context(state))
    db = Core.apply_entry_values(db, id, values, State.context(state))

    state
    |> State.change_db(db)
    |> Map.put(:cursor_key, {:item, sidx, id})
    |> report_auto_assignments(id, List.wrap(section) ++ required)
  end

  defp predecessor(order, id) do
    case Enum.find_index(order, &(&1 == id)) do
      0 -> :first
      i -> Enum.at(order, i - 1)
    end
  end

  # Tells the user what Agenda did on its own: categories found in the text,
  # and a When date read from it (R14).
  defp report_auto_assignments(state, item_id, already),
    do: report_auto_assignments(state, item_id, already, nil)

  # A special action (R15b) may have discarded the item at once.
  defp report_auto_assignments(state, item_id, _already, _old_when)
       when not is_map_key(state.db.items, item_id),
       do: State.info(state, "The item was discarded by a special action")

  defp report_auto_assignments(state, item_id, already, old_when) do
    added =
      Database.explicit_categories(state.db, item_id)
      |> Enum.reject(&(&1 in already))
      |> Enum.map(&state.db.categories[&1].name)

    item = state.db.items[item_id]
    new_when = Core.when_at(item)

    parts =
      [
        added != [] && "Also assigned to: " <> Enum.join(added, ", "),
        new_when != old_when && new_when &&
          "When: " <>
            DateFormat.date_time(item.when, item.when_time, state.db.date_format),
        new_when != old_when && is_nil(new_when) && "When date removed"
      ]
      |> Enum.filter(& &1)

    if parts == [], do: state, else: State.info(state, Enum.join(parts, " · "))
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

  # --- marked items (User's Guide 13-1 to 13-4) ----------------------------------

  # F7 on an item marks or unmarks it; on a section head it marks every item
  # in the section, or unmarks them when all are marked already.
  defp mark(state, %{kind: :item} = row), do: on_item(state, row, &Core.toggle_mark/2)

  defp mark(state, %{kind: :section, sidx: sidx}) do
    ids = for %{kind: :item, sidx: ^sidx, item: item} <- Layout.rows(state), do: item.id
    all_marked = ids != [] and Enum.all?(ids, &state.db.items[&1].marked)
    State.change_db(state, Core.set_marked(state.db, ids, not all_marked))
  end

  defp mark(state, nil), do: state

  # ALT-J: the next marked item in the view, wrapping around.
  defp jump_to_marked(state, rows) do
    indexed = Enum.with_index(rows)
    {after_, before} = Enum.split_with(indexed, fn {_, i} -> i > state.cursor end)

    case Enum.find(after_ ++ before, fn {r, _} -> r.kind == :item and r.item.marked end) do
      nil -> State.error(state, "No marked items in this view")
      {_, index} -> Layout.move_to(state, index)
    end
  end

  defp bulk?(state, row),
    do: row != nil and row.kind == :item and state.col == 0 and Core.marked_items(state.db) != []

  # A command that can act on the marked items or the current item. With
  # marked items Agenda asks which (User's Guide 13-2); with none, or when
  # the highlight is not on an item, there is nothing to ask.
  defp scoped(state, action, row) do
    marked = Core.marked_items(state.db)
    on_item = row != nil and row.kind == :item

    cond do
      marked == [] or (on_item and state.col > 0 and action in [:done, :when, :make_assign]) ->
        single(state, action, row)

      not on_item and action in [:discard, :move_item, :remove, :profile] ->
        single(state, action, row)

      not on_item ->
        bulk(state, action, marked, row)

      true ->
        State.push(state, %{type: :scope, action: action, marked: marked, row: row, cursor: 0})
    end
  end

  defp scope_key(state, mode, key) do
    case key do
      k when k in [{:char, "m"}, {:char, "M"}] ->
        state |> State.pop() |> bulk(mode.action, mode.marked, mode.row)

      k when k in [{:char, "c"}, {:char, "C"}] ->
        state |> State.pop() |> single(mode.action, mode.row)

      :enter when mode.cursor == 0 ->
        state |> State.pop() |> bulk(mode.action, mode.marked, mode.row)

      :enter ->
        state |> State.pop() |> single(mode.action, mode.row)

      k when k in [:up, :down] ->
        State.put_mode(state, %{mode | cursor: 1 - mode.cursor})

      :esc ->
        State.pop(state)

      _ ->
        state
    end
  end

  # The command for the highlighted item (what it did before marks existed).
  defp single(state, :done, row), do: toggle_done(state, row)
  defp single(state, :remove, row), do: delete(state, row)
  defp single(state, :profile, row), do: choices(state, row)

  defp single(state, :make_assign, %{kind: :item, item: item}),
    do: CategoryScreens.open_picker(state, {:assign_items, [item.id]}, nil)

  defp single(state, :make_assign, _row), do: State.error(state, "Highlight an item first")
  defp single(state, action, _row), do: perform(state, action)

  # The command for every marked item.
  defp bulk(state, :done, ids, _row) do
    db = Enum.reduce(ids, state.db, &Core.mark_done(&2, &1, state.today))
    state |> State.change_db(db) |> State.info("#{Draw.count(length(ids), "marked item")} done")
  end

  defp bulk(state, :discard, ids, _row),
    do:
      confirm(
        state,
        "Discard #{Draw.count(length(ids), "marked item")} from the whole file? (Y/N)",
        {:discard_items, ids}
      )

  defp bulk(state, :remove, ids, %{category: cat}) do
    if cat.id == state.db.main_id do
      State.error(state, "Items cannot be removed from MAIN; use ALT-F4 to discard")
    else
      db =
        Enum.reduce(
          ids,
          state.db,
          &Core.remove_from_category(&2, &1, cat.id, State.context(state))
        )

      state
      |> State.change_db(db)
      |> State.info("Removed #{Draw.count(length(ids), "marked item")} from #{cat.name}")
    end
  end

  defp bulk(state, :when, ids, _row),
    do:
      prompt(
        state,
        "When date for #{Draw.count(length(ids), "marked item")}:",
        {:when_items, ids}
      )

  defp bulk(state, :move_item, ids, _row) do
    # each item leaves the first section of this view that holds it
    rows = Layout.rows(state)

    froms =
      for id <- ids,
          do:
            {id,
             Enum.find_value(rows, fn r ->
               r.kind == :item and r.item.id == id and r.category.id
             end)}

    start_move(state, froms)
  end

  defp bulk(state, :make_assign, ids, _row),
    do: CategoryScreens.open_picker(state, {:assign_items, ids}, nil)

  defp bulk(state, :profile, ids, _row), do: CategoryScreens.open_group_profile(state, ids)

  defp start_move(state, moves) do
    what =
      if length(moves) == 1,
        do: "Move to where?",
        else: "Move #{Draw.count(length(moves), "marked item")} to where?"

    state
    |> State.push(%{type: :move_item, moves: moves})
    |> State.info(what <> " Highlight the new position and press ENTER (ESC cancels)")
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

  # Moves the item(s) to the highlighted position, one after another so
  # marked items keep their order.
  defp drop_item(state, _move, %{slot: %{}}),
    do: State.error(state, "In a datebook view, change the item's date instead")

  defp drop_item(state, %{moves: moves}, row) do
    to = Enum.at(State.view(state).sections, row.sidx).category_id
    first_after = if row.kind == :item, do: row.item.id

    {db, _} =
      Enum.reduce(moves, {state.db, first_after}, fn {id, from}, {db, after_id} ->
        from = from || db.main_id
        {Core.move_item(db, id, from, to, after: after_id, clock: State.context(state)), id}
      end)

    {last_id, _} = List.last(moves)
    %{State.change_db(state, db) | cursor_key: {:item, row.sidx, last_id}}
  end

  # --- prompts and confirmations ------------------------------------------------

  @doc "A folder read for the Select File box (R51)."
  def dir_listed(state, dir, result), do: Agenda.TUI.SelectFile.listed(state, dir, result)

  @doc "Opens a one-line prompt; `action` is passed to `prompt_submitted/3`."
  def prompt(state, label, action, initial \\ "") do
    state
    |> State.push(%{type: :prompt, label: label, action: action})
    |> Map.put(:edit, %{line: LineEdit.new(initial)})
  end

  @doc "Converts a category to numeric (R29), reporting the result."
  def make_numeric(state, cat_id) do
    case Core.make_numeric(state.db, cat_id) do
      {:ok, db} ->
        state |> State.change_db(db) |> State.info("#{db.categories[cat_id].name} is now numeric")

      {:error, _} ->
        State.error(state, "#{state.db.categories[cat_id].name} cannot become numeric")
    end
  end

  @doc "Converts a category to a date category (R6a), reporting the result."
  def make_date(state, cat_id) do
    case Core.make_date(state.db, cat_id, State.context(state)) do
      {:ok, db} ->
        state
        |> State.change_db(db)
        |> State.info("#{db.categories[cat_id].name} is now a date category")

      {:error, _} ->
        State.error(state, "#{state.db.categories[cat_id].name} cannot become a date category")
    end
  end

  def confirm(state, question, action),
    do: State.push(state, %{type: :confirm, question: question, action: action})

  defp prompt_key(state, mode, key) do
    case key do
      :esc ->
        State.pop(state)

      # a file name can be picked from a list (R51)
      {:f, 3} ->
        if Agenda.TUI.SelectFile.file_prompt?(mode.action),
          do: Agenda.TUI.SelectFile.open(state, mode),
          else: state

      :enter ->
        state.edit.line.text |> then(&prompt_submitted(State.pop(state), mode.action, &1))

      _ ->
        case LineEdit.handle(state.edit.line, key) do
          {:ok, line} -> %{state | edit: %{line: line}}
          :unhandled -> state
        end
    end
  end

  # the pop-up calendar's F6: an empty time means none (R46)
  defp prompt_submitted(state, :calendar_time, text),
    do: CalendarBox.set_time(state, String.trim(text))

  defp prompt_submitted(state, action, text) do
    text = String.trim(text)

    if text == "", do: state, else: prompt_action(state, action, text)
  end

  defp prompt_action(state, :save_as, text) do
    path = Agenda.Store.normalize_path(text)
    State.effect(%{state | path: path}, {:save, path})
  end

  defp prompt_action(state, :save_as_then_quit, text) do
    path = Agenda.Store.normalize_path(text)
    state |> Map.put(:path, path) |> State.effect({:save, path}) |> State.effect(:quit)
  end

  defp prompt_action(state, {:save_as_then, command}, text) do
    path = Agenda.Store.normalize_path(text)
    state |> Map.put(:path, path) |> State.effect({:save, path}) |> replace_file(command)
  end

  defp prompt_action(state, :calendar_jump, text), do: CalendarBox.jump(state, text)

  # Calendars (R45): the address, then a name for its category
  defp prompt_action(state, :calendar_url, text),
    do: prompt(state, "Name of its category (its events go there):", {:calendar_name, text})

  defp prompt_action(state, {:calendar_name, url}, name) do
    case Core.subscribe_calendar(state.db, name, url) do
      {:ok, db, id} ->
        state
        |> State.change_db(db)
        |> State.info("Subscribed to #{name}")
        |> fetch_calendar(id, :manual)

      {:error, :bad_url} ->
        State.error(state, "A calendar needs an https:// or webcal:// address")

      {:error, :no_name} ->
        State.error(state, "A calendar needs a name")
    end
  end

  defp prompt_action(state, :startup_open, text),
    do: State.effect(state, {:open_or_create, Agenda.Store.normalize_path(text)})

  defp prompt_action(state, :retrieve, text),
    do: State.effect(state, {:load, Agenda.Store.normalize_path(text)})

  defp prompt_action(state, :new_file, text) do
    path = Agenda.Store.normalize_path(text)

    %{
      State.reopen(state, Core.new_file(), path)
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

  # a new view's name, then its type: Standard or Datebook (R47)
  defp prompt_action(state, :add_view, text),
    do: State.push(state, %{type: :choice, kind: :view_type, name: text, cursor: 0})

  defp prompt_action(state, {:datebook_time, view_id, row}, text),
    do: Agenda.TUI.DatebookBox.set_time(state, view_id, row, text)

  defp prompt_action(state, :browse_to, text), do: Agenda.TUI.Browse.go_to(state, text)
  defp prompt_action(state, :new_macro, text), do: Agenda.TUI.Macros.create(state, text)

  defp prompt_action(state, {:rename_macro, id}, text),
    do: Agenda.TUI.MacroProps.rename(state, id, text)

  defp prompt_action(state, {:attach_macro, id}, text),
    do: Agenda.TUI.MacroProps.attach(state, id, text)

  defp prompt_action(state, :schedule_date, text),
    do: Agenda.TUI.ScheduleBox.set_date(state, text)

  defp prompt_action(state, {:datebook_base, view_id}, text),
    do: Agenda.TUI.DatebookBox.set_base(state, view_id, text)

  defp prompt_action(state, {:when_items, ids}, text) do
    Enum.reduce_while(ids, {:ok, state.db}, fn id, {:ok, db} ->
      case Core.when_key(db, id, text, State.context(state)) do
        {:ok, db} -> {:cont, {:ok, db}}
        {:error, _} -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, db} ->
        state
        |> State.change_db(db)
        |> State.info("When date set for #{Draw.count(length(ids), "item")}")

      :error ->
        State.error(state, "Not a date: #{text} (try friday, next week, 12/24, December 24)")
    end
  end

  defp prompt_action(state, {:when, item_id}, text) do
    case Core.when_key(state.db, item_id, text, State.context(state)) do
      {:ok, db} ->
        state
        |> State.change_db(db)
        |> State.info("When: " <> DateFormat.date(db.items[item_id].when, db.date_format))

      {:error, :invalid_date} ->
        State.error(state, "Not a date: #{text} (try friday, next week, 12/24, December 24)")
    end
  end

  defp prompt_action(state, :rename_view, text) do
    State.change_db(state, Core.rename_view(state.db, state.view_id, text))
  end

  defp prompt_action(state, {:move_new_category, id, relocation}, text) do
    CategoryScreens.apply_move(state, id, relocation, {:new_category, text})
  end

  defp prompt_action(state, {:alarm, item_id}, text) do
    with {minutes, ""} <- Integer.parse(String.trim(text)),
         {:ok, db} <- Core.set_alarm(state.db, item_id, minutes) do
      at = Core.when_at(db.items[item_id]) |> NaiveDateTime.add(-minutes * 60)

      state
      |> State.change_db(db)
      |> State.info("Alarm set for " <> DateFormat.datetime(at, db.date_format))
    else
      _ -> State.error(state, "Type a number of minutes from 0 to 60")
    end
  end

  defp prompt_action(state, {:item_date, item_id, cat_id}, text) do
    case Core.assign_by_name(state.db, item_id, cat_id, text, State.context(state)) do
      {:ok, db, :date} ->
        State.change_db(state, db)

      {:error, :invalid_date} ->
        State.error(state, "Not a date: #{text} (try friday, next week, 12/24)")
    end
  end

  defp prompt_action(state, {:item_number, item_id, cat_id}, text) do
    case Core.assign_by_name(state.db, item_id, cat_id, text, State.context(state)) do
      {:ok, db, :number} ->
        State.change_db(state, db)

      {:error, :empty} ->
        State.change_db(state, Core.clear_number(state.db, item_id, cat_id, State.context(state)))

      {:error, :not_a_number} ->
        State.error(state, "Not a number: #{String.trim(text)}")
    end
  end

  defp prompt_action(state, {:exclusive_new_child, cat_id}, text) do
    CategoryScreens.apply_exclusive(state, cat_id, {:new_child, text})
  end

  defp prompt_action(state, :export_json, text),
    do: State.effect(state, {:write_text, Path.expand(text), Core.export_json(state.db)})

  defp prompt_action(state, :import_json, text),
    do: State.effect(state, {:import_json, Path.expand(text)})

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

  defp confirmed(state, {:make_numeric, id}, true), do: make_numeric(state, id)

  defp confirmed(state, {:delete_macro, id}, true),
    do: State.change_db(state, Core.delete_macro(state.db, id))

  defp confirmed(state, {:make_date, id}, true), do: make_date(state, id)

  defp confirmed(state, {:make_dependent, id, prerequisites}, true) do
    case Core.make_dependent(state.db, id, prerequisites) do
      {:ok, db} ->
        count = length(Core.prerequisites(db, id))
        state |> State.change_db(db) |> State.info("Depends on #{Draw.count(count, "item")}")

      {:error, :cycle} ->
        State.error(state, "Not done: the item would depend on itself (through the marked items)")
    end
  end

  defp confirmed(state, {:clear_dependencies, id}, true) do
    state
    |> State.change_db(Core.clear_dependencies(state.db, id))
    |> State.info("Dependencies cleared")
  end

  defp confirmed(state, {:sort_children, id}, true) do
    State.change_db(state, Core.sort_children(state.db, id))
  end

  defp confirmed(state, {:discard_items, ids}, true) do
    db = Enum.reduce(ids, state.db, &Core.discard_item(&2, &1))
    state |> State.change_db(db) |> State.info("#{Draw.count(length(ids), "item")} discarded")
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

  defp confirmed(state, {:unsubscribe_calendar, id}, discard) do
    name = state.db.calendars[id].name

    state
    |> State.change_db(Core.unsubscribe_calendar(state.db, id, discard))
    |> State.info("Unsubscribed from #{name}")
  end

  defp confirmed(state, {:leave_for, command}, true) do
    if state.path,
      do: state |> State.effect({:save, state.path}) |> replace_file(command),
      else: prompt(state, "Save file as:", {:save_as_then, command})
  end

  defp confirmed(state, {:leave_for, command}, false), do: replace_file(state, command)

  defp confirmed(state, :quit, true), do: perform(state, :save_and_quit)
  defp confirmed(state, :quit, false), do: State.effect(state, :quit)
  defp confirmed(state, _action, false), do: state

  # Asks which file replaces the open one (after any question about saving).
  defp replace_file(state, :retrieve), do: prompt(state, "File to retrieve:", :retrieve)
  defp replace_file(state, :new_file), do: prompt(state, "Name of new file:", :new_file)

  defp replace_file(state, :import_json),
    do: prompt(state, "JSON file to import (opens as a new file):", :import_json)

  # --- notes --------------------------------------------------------------------

  defp note_key(state, %{replacing: replacing} = mode, key) when replacing != nil,
    do: NoteSearch.confirm_key(state, mode, key)

  defp note_key(state, mode, key) do
    case key do
      {:alt_f, 6} ->
        NoteSearch.open(state)

      {:alt, "s"} ->
        NoteSearch.next(state, mode)

      k when k in [:esc, {:f, 5}, {:f, 4}] ->
        close_note(state, mode)

      {:alt, "d"} ->
        type_in_note(state, mode, DateFormat.date(state.today, state.db.date_format))

      {:alt, "t"} ->
        type_in_note(
          state,
          mode,
          DateFormat.time(NaiveDateTime.to_time(state.now), state.db.date_format)
        )

      {:alt, "n"} ->
        step_note(state, mode, 1)

      {:alt, "p"} ->
        step_note(state, mode, -1)

      {:alt, "q"} ->
        state |> close_note(mode) |> perform(:quit)

      {:alt, "k"} ->
        State.toggle_key_map(state)

      _ ->
        case TextEdit.handle(mode.edit, key) do
          {:ok, edit} -> State.put_mode(state, Map.merge(mode, %{edit: edit, match: nil}))
          :unhandled -> state
        end
    end
  end

  # Saves the note and closes it.
  defp close_note(state, mode) do
    text = TextEdit.text(mode.edit)

    db =
      case mode.target do
        {:item, id} -> Core.set_note(state.db, id, text, State.context(state))
        {:category, id} -> Core.set_category_note(state.db, id, text)
        {:macro, id} -> Core.set_macro_keys(state.db, id, text)
      end

    if db == state.db, do: State.pop(state), else: state |> State.pop() |> State.change_db(db)
  end

  defp type_in_note(state, mode, text) do
    {:ok, edit} = TextEdit.handle(mode.edit, {:char, text})
    State.put_mode(state, %{mode | edit: edit})
  end

  # ALT-N / ALT-P: save this note and show the note of the next / previous
  # item (or section) in the view, or category in the category manager.
  defp step_note(state, mode, step) do
    below = state.modes |> Enum.drop(1) |> List.first()

    case {below, next_note_target(state, below, mode.target, step)} do
      {_, :unsupported} ->
        State.error(
          state,
          "ALT-N / ALT-P work in notes opened from a view or the category manager"
        )

      {_, nil} ->
        state |> State.effect(:bell) |> State.error("No more notes in this direction")

      {nil, index} ->
        state |> close_note(mode) |> Layout.move_to(index) |> perform(:note)

      {%{type: :catmgr}, {index, id}} ->
        state = close_note(state, mode)

        state
        |> State.put_mode(%{State.mode(state) | cursor: index})
        |> CategoryScreens.open_note(id)
    end
  end

  defp next_note_target(state, nil, target, step) do
    kind = if match?({:item, _}, target), do: :item, else: :section
    rows = Layout.rows(state)

    candidates =
      if step > 0,
        do: (state.cursor + 1)..(length(rows) - 1)//1,
        else: (state.cursor - 1)..0//-1

    Enum.find(candidates, &(Enum.at(rows, &1).kind == kind))
  end

  defp next_note_target(state, %{type: :catmgr} = catmgr, {:category, _}, step) do
    rows = CategoryScreens.rows(state, catmgr)
    index = catmgr.cursor + step

    case Enum.at(rows, index) do
      {id, _} when index >= 0 -> {index, id}
      _ -> nil
    end
  end

  defp next_note_target(_state, _below, _target, _step), do: :unsupported

  # --- actions (shared by keys and menus) --------------------------------------

  @doc "Performs a named action. Used by key handlers and the menu."
  @spec perform(State.t(), atom | tuple) :: State.t()
  # a datebook view's sections are its time slots (R47)
  @section_commands [
    :section_below,
    :section_above,
    :remove_section,
    :collapse_section,
    :filter_section,
    :sort_section
  ]

  def perform(state, action) do
    if action in @section_commands and State.view(state).datebook,
      do: datebook_sections(state),
      else: do_perform(state, action, Layout.current_row(state))
  end

  defp datebook_sections(state),
    do: State.error(state, "A datebook view's sections are its dates; they follow its settings")

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

  # Commands that replace the open file ask first when it has unsaved changes.
  defp do_perform(%State{dirty: true} = state, command, _)
       when command in [:retrieve, :new_file, :import_json],
       do: confirm(state, "Save changes first? (Y/N, ESC to cancel)", {:leave_for, command})

  defp do_perform(state, command, _) when command in [:retrieve, :new_file, :import_json],
    do: replace_file(state, command)

  defp do_perform(state, :export_json, _) do
    name = if state.path, do: Path.rootname(state.path) <> ".json", else: "agendum.json"
    prompt(state, "Export to JSON file:", :export_json, name)
  end

  defp do_perform(state, :export, _),
    do: prompt(state, "Print view to text file:", :export, "agendum-view.txt")

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
    do: toggle_done(state, row)

  defp do_perform(state, :mark, row), do: mark(state, row)
  defp do_perform(state, :make_assign, row), do: scoped(state, :make_assign, row)

  defp do_perform(state, :when, %{kind: :item, item: item}) do
    current = if item.when, do: Agenda.Core.DateParser.format(item.when), else: ""
    prompt(state, "When date (overrides dates in the text):", {:when, item.id}, current)
  end

  defp do_perform(state, :file_props, _), do: FileProperties.open(state)
  defp do_perform(state, :customize, _), do: Agenda.TUI.CustomizeBox.open(state)
  defp do_perform(state, :calendars, _), do: Agenda.TUI.CalendarsBox.open(state)
  defp do_perform(state, :execute, _), do: Agenda.TUI.ExecuteBox.open(state)
  defp do_perform(state, :questions, _), do: Agenda.TUI.QuestionsBox.open(state)

  defp do_perform(state, :column_props, %{kind: :item}) when state.col > 0 do
    column = Enum.at(State.view(state).columns, state.col - 1)

    cond do
      state.db.categories[column.category_id].kind == :numeric ->
        ColumnProperties.open(state, state.col - 1)

      Database.date_category?(state.db, column.category_id) ->
        Agenda.TUI.DateColumnBox.open(state, state.col - 1)

      true ->
        State.error(state, "Column properties are for numeric and date columns only, so far")
    end
  end

  defp do_perform(state, :column_props, _),
    do: State.error(state, "Highlight a column entry of an item first")

  defp do_perform(state, :toggle_auto_date, _) do
    db = Core.toggle_auto_date(state.db)

    message =
      if Core.auto_dating?(db),
        do: "Dates in item text set When dates",
        else: "Dates in item text are ignored"

    state |> State.change_db(db) |> State.info(message)
  end

  defp do_perform(state, :item_props, %{kind: :item, item: item}),
    do: ItemProperties.open(state, item.id)

  defp do_perform(state, :assign, %{kind: :item, item: item}),
    do: CategoryScreens.open_profile(state, item.id)

  defp do_perform(state, :move_item, %{kind: :item, item: item, category: cat}) do
    start_move(state, [{item.id, cat.id}])
  end

  # ALT-A (Item Alarm): set an alarm, or cancel the one already set
  defp do_perform(state, :alarm, %{kind: :item, item: item}) do
    cond do
      item.alarm_minutes != nil ->
        state
        |> State.change_db(Core.cancel_alarm(state.db, item.id))
        |> State.info("Alarm cancelled")

      item.when == nil ->
        State.error(state, "Give the item a When date and time first (ALT-F2)")

      true ->
        prompt(state, "Alarm: minutes before the When time (0-60):", {:alarm, item.id}, "5")
    end
  end

  defp do_perform(state, :alarm_list, _), do: AlarmList.open(state)

  defp do_perform(state, :search_view, _), do: SearchBox.open(state, :view)
  defp do_perform(state, :search_file, _), do: SearchBox.open(state, :file)

  # Utilities Show Depends / Show Prereqs (User's Guide 13-15, R43)
  defp do_perform(state, {:show_related, direction, level}, row) do
    item_id =
      case row do
        %{kind: :item, item: item} -> item.id
        _ -> nil
      end

    if item_id == nil and level != :every do
      State.error(state, "Highlight an item first")
    else
      case Core.related_items(state.db, item_id, direction, level) do
        [] ->
          State.info(
            state,
            if(direction == :dependents,
              do: "No items depend on this one",
              else: "This item depends on no other items"
            )
          )

        ids ->
          {db, view_id} = Core.show_items(state.db, ids)
          noun = if direction == :dependents, do: "dependent", else: "prerequisite"

          state
          |> State.change_db(db)
          |> State.switch_view(view_id)
          |> State.info(
            "#{Draw.count(length(ids), noun <> " item")} · ALT-F8 returns to the last view"
          )
      end
    end
  end

  # ALT-F8 (LAST VW): back to the view shown before this one.
  defp do_perform(state, :last_view, _) do
    if state.last_view_id && Map.has_key?(state.db.views, state.last_view_id),
      do: State.switch_view(state, state.last_view_id),
      else: State.error(state, "No previous view")
  end

  defp do_perform(state, :filter_view, _),
    do: CategoryScreens.open_picker(state, {:filter, :view}, nil)

  defp do_perform(state, :sort_view, _), do: SortBox.open(state, :view)

  defp do_perform(state, :filter_section, %{sidx: sidx}),
    do: CategoryScreens.open_picker(state, {:filter, {:section, sidx}}, nil)

  defp do_perform(state, :sort_section, %{sidx: sidx}), do: SortBox.open(state, {:section, sidx})

  defp do_perform(state, :unmark_all, _) do
    state |> State.change_db(Core.unmark_all(state.db)) |> State.info("All items unmarked")
  end

  defp do_perform(state, :add_category, _),
    do: prompt(state, "New category name (under MAIN):", :add_category)

  defp do_perform(state, :recalc, _) do
    state
    |> State.change_db(Core.reassign_all(state.db, State.context(state)))
    |> State.info("Automatic assignments recalculated")
  end

  defp do_perform(state, :add_view, _), do: prompt(state, "Name of new view:", :add_view)

  defp do_perform(state, :browse, _), do: Agenda.TUI.Browse.open(state)
  defp do_perform(state, :show_schedule, _), do: Agenda.TUI.ScheduleBox.open(state)

  defp do_perform(state, :view_props, _) do
    if State.view(state).datebook,
      do: Agenda.TUI.DatebookBox.open(state, state.view_id),
      else: State.error(state, "A standard view's settings are in View ▸ Hide, Filter and Order")
  end

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

  defp do_perform(state, :fit_column, _) do
    if state.col == 0,
      do: State.error(state, "Highlight a column first (use → or TAB)"),
      else:
        State.change_db(
          state,
          Core.fit_column(state.db, state.view_id, state.col - 1, State.context(state))
        )
  end

  defp do_perform(state, {:toggle_view, option}, _),
    do: State.change_db(state, Core.toggle_view_option(state.db, state.view_id, option))

  defp do_perform(state, _action, _row), do: State.error(state, "Highlight an item first")

  defp section_index(state, nil), do: length(State.view(state).sections) - 1
  defp section_index(_state, row), do: row.sidx
end
