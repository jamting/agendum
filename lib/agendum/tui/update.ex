defmodule Agendum.TUI.Update do
  @moduledoc """
  The UI state machine: `handle/2` maps a key to a new state plus a list of
  side effects for the shell to perform. Pure.

  `Update` keeps the keys that work everywhere, the clock (`tick/2`), the
  results of effects, the dispatch to the screen on top, and the help
  screen's keys. The rest lives in modules of its own under
  `Agendum.TUI.Update`: `ViewKeys` (the view), `Editing` (typing in the
  view), `Marked` (marked items and moving items), `Prompts` (prompts and
  Y/N questions), `Notes` and `Actions` (`perform/2`, the named actions
  shared with the menu).

  Effects:
    * `{:save, path}` – write `state.db` to `path`, then call `saved/3`
    * `{:load, path}` – read a file, then call `loaded/3`
    * `{:write_text, path, text}` – export text, then call `written/3`
    * `:quit`
  """

  alias Agendum.Core

  alias Agendum.TUI.{
    CategoryScreens,
    History,
    Layout,
    Menu,
    Boxes.SearchBox,
    State,
    Boxes.ViewManager
  }

  alias Agendum.TUI.{Boxes.BoxCancel, Boxes.BoxChoices}
  alias Agendum.TUI.Update.{Actions, Marked, Notes, Prompts, ViewKeys}

  @spec handle(State.t(), term) :: {State.t(), [term]}
  def handle(%State{} = state, key) do
    # the end of a macro run is not a keypress: what the run said stays
    message = if key == :macro_done, do: state.message
    state = %{state | message: message, effects: []}
    key = normalize(state, key)

    next =
      with :pass <- splash_key(state, key),
           :pass <- Agendum.TUI.Macros.key(state, key),
           :pass <- global_key(state, key),
           :pass <- BoxCancel.cancel(state, key),
           :pass <- BoxChoices.key(state, key),
           do: dispatch(state, State.mode(state), key)

    # a settings box keeps how things were when it opened, for ESC
    next = BoxCancel.track(state, next)

    # a box opened from the menu goes back to it on ESC (Agenda's menus)
    next = Menu.resumed(next, key)

    # Learn mode records the key after it has done its work (R50)
    next = Agendum.TUI.Macros.record(state, key, next)
    state = History.record(state, next)
    state = %{state | dirty: state.db != state.saved_db}

    state =
      if state.modes == [] or
           match?(%{type: t} when t in [:move_item, :searching, :browse], State.mode(state)),
         do: Layout.settle(state),
         else: state

    {%{state | effects: [], last_key: %{key: key, at: state.now}}, state.effects}
  end

  # the splash screen goes at any key, which does nothing else (R52)
  defp splash_key(%State{modes: [%{type: :splash} | _]} = state, key) when key != :macro_done,
    do: Agendum.TUI.Splash.close(state)

  defp splash_key(_state, _key), do: :pass

  @doc """
  How the program starts (R52): the splash screen, and when no file was
  named (`ask_file`), under it the prompt for a file to open or create,
  with the last file used.
  """
  def start(state, ask_file) do
    state =
      if ask_file,
        do:
          Prompts.prompt(
            state,
            "File to open or create:",
            :startup_open,
            state.prefs.last_file || ""
          ),
        else: state

    Agendum.TUI.Splash.open(state)
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
        Agendum.TUI.DevTools.open(state)

      typing?(state) or match?(%{type: t} when t in [:confirm, :menu, :help, :devtools], top) ->
        :pass

      key == {:ctrl, "z"} ->
        if undoable?(top), do: History.undo(state), else: :pass

      key == {:ctrl, "y"} ->
        if undoable?(top), do: History.redo(state), else: :pass

      key == {:alt, "k"} ->
        State.toggle_key_map(state)

      key == {:ctrl, "s"} ->
        Actions.perform(state, :save)

      key == {:ctrl, "o"} ->
        Actions.perform(state, :retrieve)

      key == {:ctrl, "p"} and top == nil ->
        Actions.perform(state, :export)

      key in [{:ctrl, "q"}, {:ctrl, "c"}, {:alt, "q"}] ->
        Actions.perform(state, :quit)

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
          if Agendum.TUI.Splash.over?(splash, now),
            do: Agendum.TUI.Splash.close(state),
            else: state

        _ ->
          state
      end

    state = %{state | dirty: state.db != state.saved_db}
    {state, save} = auto_save(state, now)

    # calendars due to be read again (R45), one read at a time each
    state =
      db
      |> Core.calendars_due(now)
      |> Enum.reduce(%{state | effects: []}, &fetch_calendar(&2, &1.id, :auto))

    {state, fetches} = {%{state | effects: []}, save ++ state.effects}

    case rung do
      [] ->
        {state, fetches}

      ids ->
        texts = Enum.map_join(ids, " · ", &state.db.items[&1].text)
        {%{state | alarm_rang: true} |> State.info("Alarm: " <> texts), [:bell | fetches]}
    end
  end

  # Auto-save (R54): a named file with unsaved changes is saved once no key
  # has come for the person's interval; trying restarts the idle time, so
  # a save that fails is tried again an interval later, not every second
  defp auto_save(%State{prefs: %{auto_save: minutes}, dirty: true, path: path} = state, now)
       when minutes > 0 and path != nil do
    idle_since = state.last_key.at || now

    if NaiveDateTime.diff(now, idle_since) >= minutes * 60,
      do: {%{state | last_key: %{state.last_key | at: now}}, [{:save, path}]},
      else: {state, []}
  end

  defp auto_save(state, _now), do: {state, []}

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

  @doc "A folder read for the Select File box (R51)."
  def dir_listed(state, dir, result), do: Agendum.TUI.Boxes.SelectFile.listed(state, dir, result)

  # --- dispatch --------------------------------------------------------------

  @boxes Agendum.TUI.Boxes.Box.registry()

  @doc """
  A key for the box on top alone, without what `handle/2` does around it
  (undo, macros): `Agendum.TUI.Boxes.BoxChoices` tries SPACE with it.
  """
  @spec box_key(State.t(), term) :: State.t()
  def box_key(state, key), do: dispatch(state, State.mode(state), key)

  defp dispatch(state, nil, key), do: ViewKeys.view_key(state, key)

  # a box with a module of its own (`Agendum.TUI.Boxes.Box`)
  defp dispatch(state, %{type: type} = m, key) when is_map_key(@boxes, type),
    do: @boxes[type].handle(state, m, key)

  defp dispatch(state, %{type: :menu} = m, key), do: Menu.handle(state, m, key)

  defp dispatch(state, %{type: :viewmgr} = m, key), do: ViewManager.handle(state, m, key)
  defp dispatch(state, %{type: :prompt} = m, key), do: Prompts.prompt_key(state, m, key)
  defp dispatch(state, %{type: :confirm} = m, key), do: Prompts.confirm_key(state, m, key)
  defp dispatch(state, %{type: :note} = m, key), do: Notes.note_key(state, m, key)
  defp dispatch(state, %{type: :help} = m, key), do: help_key(state, m, key)

  defp dispatch(state, %{type: :devtools} = m, key),
    do: Agendum.TUI.DevTools.handle(state, m, key)

  defp dispatch(state, %{type: :move_item} = m, key), do: Marked.move_key(state, m, key)
  defp dispatch(state, %{type: :scope} = m, key), do: Marked.scope_key(state, m, key)

  defp dispatch(state, %{type: :macros} = m, key), do: Agendum.TUI.Macros.handle(state, m, key)

  defp dispatch(state, %{type: :select_file} = m, key),
    do: Agendum.TUI.Boxes.SelectFile.handle(state, m, key)

  defp dispatch(state, %{type: :browse} = m, key),
    do: Agendum.TUI.Moves.Browse.handle(state, m, key)

  defp dispatch(state, %{type: :calendars} = m, key),
    do: Agendum.TUI.Boxes.CalendarsBox.handle(state, m, key)

  defp dispatch(state, %{type: :column_width} = m, key),
    do: Agendum.TUI.Moves.ColumnWidth.handle(state, m, key)

  defp dispatch(state, %{type: :column_move} = m, key),
    do: Agendum.TUI.Moves.ColumnMove.handle(state, m, key)

  defp dispatch(state, %{type: :section_move} = m, key),
    do: Agendum.TUI.Moves.SectionMove.handle(state, m, key)

  defp dispatch(state, %{type: :searching} = m, key),
    do: SearchBox.searching_key(state, m, key, &ViewKeys.view_key/2)

  defp dispatch(state, mode, key), do: CategoryScreens.handle(state, mode, key)

  # --- help -------------------------------------------------------------------

  defp help_key(state, mode, key) do
    page = State.body_height(state)
    last = max(Agendum.TUI.Render.Help.line_count() - page, 0)

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
end
