# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Update do
  @moduledoc """
  The UI state machine: `handle/2` maps a key to a new state plus a list of
  side effects for the shell to perform. Pure.

  `Update` keeps the keys that work everywhere (`Agendum.TUI.Keymap`'s
  global keys, `run_global/2`), the clock (`tick/2`), the requests to read
  a feed or a calendar, and the dispatch to the screen on top; the help screen is
  `Agendum.TUI.HelpScreen`. The rest lives in modules of its own under
  `Agendum.TUI.Update`: `ViewKeys` (the view), `Editing` (typing in the
  view), `Marked` (marked items and moving items), `Prompts` (prompts and
  Y/N questions), `Notes`, `Actions` (`perform/2`, the named actions
  shared with the menu) and `Results` (the shell's answers).

  Effects are plain data for the shell (`{:save, path, opts}`, `:quit` …);
  the closed list is `Agendum.TUI.Effect`. The shell hands each result back
  to a function of `Agendum.TUI.Update.Results` (`saved/4`, `loaded/3`,
  `written/3` …).
  """

  alias Agendum.Core

  alias Agendum.TUI.{
    CategoryScreens,
    HelpScreen,
    History,
    Keymap,
    Layout,
    Menu,
    Boxes.SearchBox,
    State
  }

  alias Agendum.TUI.{Boxes.BoxCancel, Boxes.BoxChoices, Boxes.BoxDefaults}
  alias Agendum.TUI.Update.{Actions, Notes, Prompts, ViewKeys}

  # `%State{} = state` in the head both checks that the argument is a
  # `State` struct (anything else fails to match and crashes here, at the
  # border, instead of deep inside) and names it `state`.
  @spec handle(State.t(), term) :: {State.t(), [Agendum.TUI.Effect.t()]}
  def handle(%State{} = state, key) do
    # the end of a macro run is not a keypress: what the run said stays
    message = if key == :macro_done, do: state.message
    state = %{state | message: message, effects: []}
    before = state
    key = normalize(state, key)
    state = splash_closed(state, key)

    # `with` used as a chain of "not mine, pass it on": each step returns
    # `:pass` when the key is not for it, and `with` goes to the next. The
    # first step that returns anything else (a new state) stops the chain,
    # and with no `else`, that value is the result. The order is the
    # priority: a macro key, the keys that work
    # everywhere, an extra's key while the extras are off, the editing keys
    # of a line being typed, the keys every box shares, then the screen on
    # top.
    next =
      try do
        with :pass <- away_uncovered(before, state),
             :pass <- Agendum.TUI.Macros.key(state, key),
             :pass <- global_key(state, key),
             :pass <- extras_key(state, key),
             :pass <- Agendum.TUI.Typing.LineClip.key(state, key),
             :pass <- box_command(state, key),
             do: dispatch(state, State.mode(state), key)
      catch
        # a command refused because a feed or a calendar fills the category
        # (R75a, `State.command/2`): the key stops there, with its message
        {:refused, refused} -> refused
      end

    # a count (ALT-digits, R65) lasts until the next key has used it
    next = if count_key?(key), do: next, else: %{next | count: nil}

    # a box opened from the menu goes back to it on ESC (Agenda's menus)
    next = Menu.resumed(next, key)

    # Learn mode records the key after it has done its work (R50)
    next = Agendum.TUI.Macros.record(state, key, next)
    # Domain: undo is recorded here, once for every key, by comparing the
    # state before the key with the state after it. No key handler records
    # history itself (CLAUDE.md, Undo), so one key is one undo step.
    state = History.record(state, next)
    # a settings box keeps how things were when it opened, for ESC; after
    # the undo step is recorded, so a box shown again after a full screen
    # (a macro's keys edited from Macro Properties) keeps that step too
    state = BoxCancel.track(before, state)
    # a settings box that just closed is one undo step, or none (ADR 0030)
    state = BoxCancel.settle(before, state)
    # and the note's own steps, while one is open (R64g)
    state = Agendum.TUI.Typing.NoteUndo.track(before, key, state)
    changed? = state.db != before.db
    state = if changed?, do: State.follow_marks(before, state), else: state
    state = %{state | dirty: state.db != state.saved.db}
    # Agenda's o, worked out only when the key changed the file (R37)
    state = if changed?, do: State.refresh_circular(before, state), else: state

    state =
      if state.modes == [] or
           match?(%{type: t} when t in [:item_reposition, :searching, :browse], State.mode(state)),
         do: Layout.settle(state),
         else: state

    state = keep_place(before, state)

    # a note keeps where it is scrolled to, also under a box (ALT-F6 …)
    state = %{state | modes: Enum.map(state.modes, &keep_note_top(state, &1))}

    # Agenda's beeps (R76), decided from what the key did
    state = Agendum.TUI.Update.Sounds.after_key(before, key, state)

    # Effects were collected in `state.effects` while the key was handled
    # (`State.effect/2`); they are taken out and returned beside the state,
    # so the state that is kept holds none.
    {%{state | effects: [], last_key: %{key: key, at: state.now}}, state.effects}
  end

  # Domain: only the note on top moves its cursor, but the screen may be
  # resized under a box, so every note on the stack is settled
  defp keep_note_top(state, %{type: :note} = mode),
    do: Agendum.TUI.Render.Note.keep_top(state, mode)

  defp keep_note_top(_state, mode), do: mode

  # Where the person was in the file is kept as they leave it (R69): on
  # Quit here; Retrieve, New and Import keep it as they open the other file
  # (`State.reopen/3`). The preferences are saved before quitting:
  # `Enum.split_while/2` cuts the effects at `:quit`, so the save goes in
  # just before it.
  defp keep_place(before, state) do
    state = if :quit in state.effects, do: Agendum.TUI.Places.remember(state), else: state

    if state.prefs.places != before.prefs.places and state.prefs.path do
      save = {:save_preferences, state.prefs.path, state.prefs}
      {now, rest} = Enum.split_while(state.effects, &(&1 != :quit))
      %{state | effects: now ++ [save | rest]}
    else
      state
    end
  end

  defp count_key?({:alt, d}), do: d in ~w(0 1 2 3 4 5 6 7 8 9)
  defp count_key?(_key), do: false

  # The splash screen goes at any key, and the key then does what it does
  # on the screen under it, as Agenda's (R52; checked in Agenda 2.0,
  # 2026-10-31: a letter typed during its splash landed in the File name).
  # The pattern reaches into the struct: it matches only when the first
  # mode on the stack is a map whose `:type` is `:splash`. A map pattern
  # matches when those keys are present, whatever other keys there are.
  defp splash_closed(%State{modes: [%{type: :splash} | _]} = state, key)
       when key != :macro_done,
       do: Agendum.TUI.Splash.close(state)

  defp splash_closed(state, _key), do: state

  # Our choice: the While you were away box (R70) waits under the splash;
  # the key that takes the splash away only shows it, so its alarms are
  # seen rather than answered unread.
  defp away_uncovered(
         %State{modes: [%{type: :splash} | _]},
         %State{modes: [%{type: :away} | _]} = state
       ),
       do: state

  defp away_uncovered(_before, _state), do: :pass

  @doc """
  How the program starts (R52): the splash screen (`splash`), and when no
  file was named (`ask_file`), under it the prompt for a file to open or
  create, with the last file used. A file named when starting opens
  without the splash, as Agenda's did.
  """
  def start(state, ask_file, splash \\ true) do
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

    if splash, do: Agendum.TUI.Splash.open(state), else: state
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

  # describe key (F1 d) is told the key pressed, not the key it stands for
  defp normalize(%State{modes: [%{type: :help, page: :describe} | _]}, key), do: key

  # the aliases are in `Agendum.TUI.Keymap`
  defp normalize(state, key) do
    case Keymap.alias_of(key) do
      {target, :always} -> target
      {target, :not_typing} -> if typing?(state), do: key, else: target
      {target, :view} -> if State.mode(state) == nil, do: target, else: key
      nil -> key
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

      true ->
        case Keymap.lookup(:global, key) do
          nil -> :pass
          id -> run_global(state, id)
        end
    end
  end

  # An extra's key (R77, ADR 0043) does nothing while the Extras preference
  # is off, as an unbound key does: the key is taken here, before the
  # screen on top could run its command. The place is the one F1 would
  # list commands for (`HelpScreen.place/1`).
  defp extras_key(%State{prefs: %{extras: true}}, _key), do: :pass

  defp extras_key(state, key) do
    place = HelpScreen.place(state)

    case Keymap.lookup(place, key) do
      nil -> :pass
      id -> if Agendum.TUI.Commands.extra?(place, id), do: state, else: :pass
    end
  end

  @doc """
  Runs a global command (`Agendum.TUI.Commands`, `:global`); `:pass`
  where it does not apply (undo over a box, print outside a view).
  """
  @spec run_global(State.t(), atom) :: State.t() | :pass
  def run_global(state, id) do
    top = State.mode(state)

    case id do
      :undo -> if undoable?(top), do: History.undo(state), else: :pass
      :redo -> if undoable?(top), do: History.redo(state), else: :pass
      :key_map -> State.cycle_key_bar(state)
      :run_by_name -> Agendum.TUI.Boxes.RunByName.open(state)
      :macros -> Agendum.TUI.Macros.open(state)
      :export -> if top == nil, do: Actions.perform(state, :export), else: :pass
      id when id in [:save, :retrieve, :quit] -> Actions.perform(state, id)
    end
  end

  @doc """
  The global commands that cannot run where the person is now, each with
  why (R65a): F1 `c` greys them. Undo and Redo work in a view and the
  managers (a box keeps its own changes until it closes).
  """
  @spec unavailable_global(State.t()) :: %{atom => String.t()}
  def unavailable_global(state) do
    top = State.mode(state)

    [
      undo: undo_reason(top, state.history.undo, "undo"),
      redo: undo_reason(top, state.history.redo, "redo"),
      export: top != nil && "Print works in a view"
    ]
    |> Enum.filter(fn {_id, reason} -> is_binary(reason) end)
    |> Map.new()
  end

  defp undo_reason(top, steps, what) do
    cond do
      not undoable?(top) -> "#{String.capitalize(what)} works in a view and the managers"
      steps == [] -> "Nothing to #{what}"
      true -> nil
    end
  end

  # The keys every box shares (`Agendum.TUI.Keymap`'s `:box`, R65): F1
  # help, ESC cancels a settings box, F3 lists a setting's choices, and a
  # letter picks one (an unbound key). `:pass` sends the key on to the box.
  defp box_command(state, key) do
    if Agendum.TUI.Boxes.Box.module(State.mode(state)) != nil,
      do: run_box(state, Keymap.lookup(:box, key), key),
      else: :pass
  end

  @doc "Runs a command every box shares (`Agendum.TUI.Commands`, `:box`); `:pass` where it does not apply."
  @spec run_box(State.t(), atom | nil, term) :: State.t() | :pass
  def run_box(state, :help, _key) do
    mode = State.mode(state)

    if Agendum.TUI.Boxes.Box.module!(mode).typing?(state, mode),
      do: :pass,
      else: HelpScreen.open(state)
  end

  def run_box(state, :cancel, _key), do: BoxCancel.cancel(state, :esc)
  def run_box(state, :choices, _key), do: BoxChoices.key(state, {:f, 3})
  def run_box(state, :edit, _key), do: Agendum.TUI.Boxes.BoxEdit.key(state)
  def run_box(state, id, _key) when id in [:default, :default_all], do: BoxDefaults.key(state, id)
  def run_box(state, nil, key), do: BoxChoices.key(state, key)

  # Undo is offered where the screen does not depend on one particular item.
  defp undoable?(nil), do: true
  defp undoable?(%{type: t}), do: t in [:catmgr, :viewmgr]

  # --- the clock (R38) -----------------------------------------------------------

  @doc """
  Called by the shell with the current time on every pass of its loop:
  updates the clock, forgets the previous day's past alarms when the date
  changes, and rings alarms whose time has come (a message, a bell, and
  the alarm symbol in the title until the alarm list is shown). Ringing
  is not an undo step, nor an edit (R70).
  """
  @spec tick(State.t(), NaiveDateTime.t()) :: {State.t(), [Agendum.TUI.Effect.t()]}
  def tick(%State{} = state, %NaiveDateTime{} = now) do
    today = NaiveDateTime.to_date(now)

    # a new day: forget yesterday's past alarms and re-check conditions,
    # whose relative dates ("this week") may now mean other days (R15a)
    # the clock's own commands: they change the file, but are not undo steps
    # (ADR 0005), so they go straight to the core
    clock = State.context(%{state | now: now})
    # and End of day empties the trash (R24a)
    new_day =
      if today != state.today,
        do: [:clear_old_alarms, :recheck_conditions, {:tidy_trash, :clock}],
        else: []

    {ticked, rung} = run_clock(state, new_day ++ [:ring_alarms], clock)
    ticked = %{ticked | now: now, today: today}

    # a new day re-checks conditions, which may settle or not (R37's o)
    state =
      if ticked.db != state.db, do: State.refresh_circular(state, ticked), else: ticked

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

    state = %{state | dirty: state.db != state.saved.db}
    {state, save} = auto_save(state, now)

    # calendars due to be read again (R45), one read at a time each, and
    # feeds (R75): extras, read only while the extras are on (R77)
    state = %{state | effects: []}

    state =
      if state.prefs.extras do
        state =
          Enum.reduce(Core.calendars_due(state.db, now), state, &fetch_calendar(&2, &1.id, :auto))

        Enum.reduce(Core.feeds_due(state.db, now), state, &fetch_feed(&2, &1.id, :auto))
      else
        state
      end

    {state, fetches} = {%{state | effects: []}, save ++ state.effects}

    case rung do
      [] ->
        {state, fetches}

      ids ->
        state = ring(state, ids)
        {%{state | effects: []}, state.effects ++ fetches}
    end
  end

  # The clock's own changes (R38, R66): not undo steps, and not edits
  # either (R70): they are made to the file as last saved too, so they
  # never cause a "Save changes?" question by themselves; quitting without
  # saving rings the same alarms next time. Returns what the last command
  # gave (the alarms rung). The saved file is only worked on when the
  # clock changed something.
  # Domain: `saved.db` is what is on disk, `db` what is on screen; the file
  # is dirty when they differ. A rung alarm changes both the same way, so
  # they still agree when nothing else changed. `{:ok, db, ...} = ...` is a
  # match used as an assertion: the clock's commands cannot fail, and if
  # they ever did, crashing is better than going on with a wrong state.
  defp run_clock(state, commands, clock) do
    {:ok, db, %{steps: steps}} = Core.run(state.db, {:batch, commands}, clock)
    %{result: result} = List.last(steps)

    saved =
      if db == state.db or state.saved.db == nil do
        state.saved.db
      else
        {:ok, saved, _changes} = Core.run(state.saved.db, {:batch, commands}, clock)
        saved
      end

    modes =
      if db == state.db, do: state.modes, else: clock_into_boxes(state.modes, commands, clock)

    {%{state | db: db, saved: %{state.saved | db: saved}, modes: modes}, result}
  end

  # Domain: what the clock did (an alarm rung, a new day's tidying) is not
  # a change made in a settings box open meanwhile: it goes into the box's
  # snapshot too, so ESC, putting the file back as the box found it, does
  # not ring the alarm again (the review of group f, 2026-10-31), as a
  # feed's read does (`Update.Results`)
  defp clock_into_boxes(modes, commands, clock) do
    Enum.map(modes, fn
      %{opened: %{db: db} = opened} = mode ->
        {:ok, db, _} = Core.run(db, {:batch, commands}, clock)
        %{mode | opened: %{opened | db: db}}

      mode ->
        mode
    end)
  end

  @doc """
  A file just opened (at startup, Retrieve, Import): forgets past alarms
  from before today, and rings the alarms that came due while it was
  closed. With the extras on they ring quietly, and the "While you were
  away" box lists them (R70), under the splash screen at startup; with
  them off they ring as Agenda's do, a message and the alarm's sound, and
  show `@` (R77).
  """
  @spec arrive(State.t()) :: State.t()
  def arrive(%State{} = state) do
    # an older file's blog upload settings to the person's preferences (R74)
    state = Agendum.TUI.Extras.UploadBox.move_from_file(state)

    # File Properties ▸ Make backup on open (R82): the file as it is on disk
    # only a file read from disk (a stamp): a new one has nothing to copy
    state =
      if state.path && state.saved.stamp && state.db.backup_on_open,
        do: State.effect(state, {:backup_file, state.path}),
        else: state

    # the trash emptied as File Properties ▸ Empty trash says (R24a), then
    # the alarms; the alarms' result is the last command's
    {state, rung} =
      run_clock(
        state,
        [{:tidy_trash, :open}, :clear_old_alarms, :ring_alarms],
        State.context(state)
      )

    state = %{state | dirty: state.db != state.saved.db}

    cond do
      rung == [] -> state
      state.prefs.extras -> Agendum.TUI.Boxes.AwayBox.open(state, rung)
      true -> ring(state, rung)
    end
  end

  # alarms ringing: the message and the alarm's sound (unless the person
  # turned sounds off); `@` shows on the View line while past alarms are
  # listed (`Render.ControlPanel`)
  defp ring(state, ids) do
    texts = Enum.map_join(ids, " · ", &state.db.items[&1].text)
    state = State.info(state, "Alarm: " <> texts)

    %{
      state
      | effects: Agendum.TUI.Update.Sounds.quiet(state, state.effects ++ [{:sound, :alarm}])
    }
  end

  # Auto-save (R54): a named file with unsaved changes is saved once no key
  # has come for the person's interval; trying restarts the idle time, so
  # a save that fails is tried again an interval later, not every second.
  # A file another writer changed is not auto-saved at all (R71) until a
  # save the person makes settles it.
  defp auto_save(
         %State{prefs: %{auto_save: minutes}, dirty: true, path: path, saved: %{conflict: false}} =
           state,
         now
       )
       when minutes > 0 and path != nil do
    idle_since = state.last_key.at || now

    # not while a settings box is open: its changes reach the file on
    # ENTER (ADR 0030); the save comes once it has closed
    box_open? = Enum.any?(state.modes, &(Map.get(&1, :opened) != nil))

    if NaiveDateTime.diff(now, idle_since) >= minutes * 60 and not box_open? do
      state = %{state | last_key: %{state.last_key | at: now}, effects: []}
      saving = State.save(state, path, auto: true)
      {%{saving | effects: []}, saving.effects}
    else
      {state, []}
    end
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
        %{state | fetching: Map.put(state.fetching, cal_id, {kind, cal.url})}
        |> State.effect({:fetch_calendar, cal_id, cal.url})
  end

  @doc """
  Asks the shell to read a feed (`{:fetch_feed, id, url}`, R75), unless it
  is being read already; `kind` as for calendars.
  """
  def fetch_feed(state, feed_id, kind) do
    feed = state.db.feeds[feed_id]

    if feed == nil or Map.has_key?(state.fetching, feed_id),
      do: state,
      else:
        %{state | fetching: Map.put(state.fetching, feed_id, {kind, feed.url})}
        |> State.effect({:fetch_feed, feed_id, feed.url})
  end

  # --- dispatch --------------------------------------------------------------

  # A module attribute is computed when the module is compiled: the
  # registry (a map from mode type to box module) is built once, and can
  # be used in a guard below, where function calls are not allowed.
  @boxes Agendum.TUI.Boxes.Box.registry()

  @doc """
  A key for the box on top alone, without what `handle/2` does around it
  (undo, macros): `Agendum.TUI.Boxes.BoxChoices` tries SPACE with it.
  """
  @spec box_key(State.t(), term) :: State.t()
  def box_key(state, key), do: dispatch(state, State.mode(state), key)

  # Domain: the mode on top of the stack decides who gets the key; no mode
  # (nil) means the view itself. One clause per kind of mode, tried in
  # order; the last one catches the screens that list categories (the
  # category manager, pickers, the assignment profile: `CategoryScreens`).
  defp dispatch(state, nil, key), do: ViewKeys.view_key(state, key)

  # a box with a module of its own (`Agendum.TUI.Boxes.Box`)
  defp dispatch(state, %{type: type} = m, key) when is_map_key(@boxes, type),
    do: Agendum.TUI.Boxes.Box.dispatch(@boxes[type], state, m, key)

  defp dispatch(state, %{type: :menu} = m, key), do: Menu.handle(state, m, key)

  defp dispatch(state, %{type: :prompt} = m, key), do: Prompts.prompt_key(state, m, key)
  defp dispatch(state, %{type: :note} = m, key), do: Notes.note_key(state, m, key)
  defp dispatch(state, %{type: :help} = m, key), do: HelpScreen.handle(state, m, key)

  defp dispatch(state, %{type: :devtools} = m, key),
    do: Agendum.TUI.DevTools.handle(state, m, key)

  defp dispatch(state, %{type: :browse} = m, key),
    do: Agendum.TUI.Moves.Browse.handle(state, m, key)

  defp dispatch(state, %{type: :column_width} = m, key),
    do: Agendum.TUI.Moves.ColumnWidth.handle(state, m, key)

  defp dispatch(state, %{type: :column_move} = m, key),
    do: Agendum.TUI.Moves.ColumnMove.handle(state, m, key)

  defp dispatch(state, %{type: :item_reposition} = m, key),
    do: Agendum.TUI.Moves.ItemReposition.handle(state, m, key)

  defp dispatch(state, %{type: :section_move} = m, key),
    do: Agendum.TUI.Moves.SectionMove.handle(state, m, key)

  defp dispatch(state, %{type: :searching} = m, key),
    do: SearchBox.searching_key(state, m, key, &ViewKeys.view_key/2)

  defp dispatch(state, mode, key), do: CategoryScreens.handle(state, mode, key)
end
