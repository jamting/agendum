defmodule Agendum.TUI.Update do
  @moduledoc """
  The UI state machine: `handle/2` maps a key to a new state plus a list of
  side effects for the shell to perform. Pure.

  `Update` keeps the keys that work everywhere (`Agendum.TUI.Keymap`'s
  global keys, `run_global/2`), the clock (`tick/2`), the results of
  effects, and the dispatch to the screen on top; the help screen is
  `Agendum.TUI.HelpScreen`. The rest lives in modules of its own under
  `Agendum.TUI.Update`: `ViewKeys` (the view), `Editing` (typing in the
  view), `Marked` (marked items and moving items), `Prompts` (prompts and
  Y/N questions), `Notes` and `Actions` (`perform/2`, the named actions
  shared with the menu).

  Effects:
    * `{:save, path, opts}` – write `state.db` to `path` if the file there
      is as `opts.expect` says (R71), then call `saved/4`
    * `{:load, path}` – read a file, then call `loaded/3`
    * `{:write_text, path, text}` – export text, then call `written/3`
    * `:quit`
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

  alias Agendum.TUI.{Boxes.BoxCancel, Boxes.BoxChoices}
  alias Agendum.TUI.Update.{Actions, Marked, Notes, Prompts, ViewKeys}

  # `%State{} = state` in the head both checks that the argument is a
  # `State` struct (anything else fails to match and crashes here, at the
  # border, instead of deep inside) and names it `state`.
  @spec handle(State.t(), term) :: {State.t(), [term]}
  def handle(%State{} = state, key) do
    # the end of a macro run is not a keypress: what the run said stays
    message = if key == :macro_done, do: state.message
    state = %{state | message: message, effects: []}
    before = state
    key = normalize(state, key)

    # `with` used as a chain of "not mine, pass it on": each step returns
    # `:pass` when the key is not for it, and `with` goes to the next. The
    # first step that returns anything else (a new state) stops the chain,
    # and with no `else`, that value is the result. The order is the
    # priority: the splash screen, a macro key, the keys that work
    # everywhere, the keys every box shares, then the screen on top.
    next =
      with :pass <- splash_key(state, key),
           :pass <- Agendum.TUI.Macros.key(state, key),
           :pass <- global_key(state, key),
           :pass <- box_command(state, key),
           do: dispatch(state, State.mode(state), key)

    # a count (ALT-digits, R65) lasts until the next key has used it
    next = if count_key?(key), do: next, else: %{next | count: nil}

    # a settings box keeps how things were when it opened, for ESC
    next = BoxCancel.track(state, next)

    # a box opened from the menu goes back to it on ESC (Agenda's menus)
    next = Menu.resumed(next, key)

    # Learn mode records the key after it has done its work (R50)
    next = Agendum.TUI.Macros.record(state, key, next)
    # Domain: undo is recorded here, once for every key, by comparing the
    # state before the key with the state after it. No key handler records
    # history itself (CLAUDE.md, Undo), so one key is one undo step.
    state = History.record(state, next)
    state = %{state | dirty: state.db != state.saved.db}

    state =
      if state.modes == [] or
           match?(%{type: t} when t in [:move_item, :searching, :browse], State.mode(state)),
         do: Layout.settle(state),
         else: state

    state = keep_place(before, state)

    # Effects were collected in `state.effects` while the key was handled
    # (`State.effect/2`); they are taken out and returned beside the state,
    # so the state that is kept holds none.
    {%{state | effects: [], last_key: %{key: key, at: state.now}}, state.effects}
  end

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

  # the splash screen goes at any key, which does nothing else (R52)
  # The pattern reaches into the struct: it matches only when the first
  # mode on the stack is a map whose `:type` is `:splash`. A map pattern
  # matches when those keys are present, whatever other keys there are.
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
      :key_map -> State.toggle_key_map(state)
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
  @spec tick(State.t(), NaiveDateTime.t()) :: {State.t(), [term]}
  def tick(%State{} = state, %NaiveDateTime{} = now) do
    today = NaiveDateTime.to_date(now)

    # a new day: forget yesterday's past alarms and re-check conditions,
    # whose relative dates ("this week") may now mean other days (R15a)
    # the clock's own commands: they change the file, but are not undo steps
    # (ADR 0005), so they go straight to the core
    clock = State.context(%{state | now: now})
    new_day = if today != state.today, do: [:clear_old_alarms, :recheck_conditions], else: []

    {state, rung} = run_clock(state, new_day ++ [:ring_alarms], clock)
    state = %{state | now: now, today: today}

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

    # calendars due to be read again (R45), one read at a time each
    state =
      state.db
      |> Core.calendars_due(now)
      |> Enum.reduce(%{state | effects: []}, &fetch_calendar(&2, &1.id, :auto))

    # and feeds (R75)
    state = state.db |> Core.feeds_due(now) |> Enum.reduce(state, &fetch_feed(&2, &1.id, :auto))

    {state, fetches} = {%{state | effects: []}, save ++ state.effects}

    case rung do
      [] ->
        {state, fetches}

      ids ->
        texts = Enum.map_join(ids, " · ", &state.db.items[&1].text)
        {%{state | alarm_rang: true} |> State.info("Alarm: " <> texts), [:bell | fetches]}
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

    {%{state | db: db, saved: %{state.saved | db: saved}}, result}
  end

  @doc """
  A file just opened (at startup, Retrieve, Import): forgets past alarms
  from before today, and rings the alarms that came due while it was
  closed, quietly; when there are any, the "While you were away" box
  lists them (R70), under the splash screen at startup.
  """
  @spec arrive(State.t()) :: State.t()
  def arrive(%State{} = state) do
    {state, rung} = run_clock(state, [:clear_old_alarms, :ring_alarms], State.context(state))
    state = %{state | dirty: state.db != state.saved.db}

    if rung == [], do: state, else: Agendum.TUI.Boxes.AwayBox.open(state, rung)
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

    if NaiveDateTime.diff(now, idle_since) >= minutes * 60 do
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
      next = %{History.record(state, next) | dirty: next.db != next.saved.db}
      if next.modes == [], do: Layout.settle(next), else: next
    end
  end

  defp read_into(state, cal, kind, {:ok, events}) do
    {:ok, state, %{result: counts}} = State.command(state, {:sync_calendar, cal.id, events})

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
    state = State.run(state, {:calendar_failed, cal.id, message})
    if kind == :manual, do: State.error(state, "#{cal.name}: #{message}"), else: state
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
        %{state | fetching: Map.put(state.fetching, feed_id, kind)}
        |> State.effect({:fetch_feed, feed_id, feed.url})
  end

  @doc "After the shell read a feed: its entries are filed into the file (R75), or why not."
  def feed_read(state, feed_id, result) do
    {kind, fetching} = Map.pop(state.fetching, feed_id)
    state = %{state | fetching: fetching}
    feed = state.db.feeds[feed_id]

    if feed == nil do
      state
    else
      next = feed_into(state, feed, kind, result)
      next = %{History.record(state, next) | dirty: next.db != next.saved.db}
      if next.modes == [], do: Layout.settle(next), else: next
    end
  end

  defp feed_into(state, feed, kind, {:ok, entries}) do
    {:ok, state, %{result: counts}} = State.command(state, {:sync_feed, feed.id, entries})

    parts =
      [added: "new", updated: "changed", faded: "faded"]
      |> Enum.filter(fn {key, _} -> counts[key] > 0 end)
      |> Enum.map_join(", ", fn {key, word} -> "#{counts[key]} #{word}" end)

    cond do
      parts != "" -> State.info(state, "#{feed.name}: #{parts}")
      kind == :manual -> State.info(state, "#{feed.name}: nothing new")
      true -> state
    end
  end

  defp feed_into(state, feed, kind, {:error, message}) do
    state = State.run(state, {:feed_failed, feed.id, message})
    if kind == :manual, do: State.error(state, "#{feed.name}: #{message}"), else: state
  end

  @doc "After the browser was asked to open a link (R75)."
  def url_opened(state, url, :ok), do: State.info(state, "Opened #{url}")

  def url_opened(state, _url, {:error, reason}),
    do: State.error(state, "Could not open it: #{reason}")

  @doc "A feed list read for OPML import (R75): each feed not in the file yet is subscribed."
  def opml_read(state, path, {:ok, text}) do
    case State.command(state, {:import_opml, text}) do
      {:ok, state, %{result: []}} ->
        State.info(state, "#{Path.basename(path)}: no feeds the file does not have already")

      {:ok, state, %{result: ids}} ->
        state = Enum.reduce(ids, state, &fetch_feed(&2, &1, :auto))

        State.info(
          state,
          "Subscribed to #{Agendum.TUI.Terminal.Draw.count(length(ids), "feed")} from #{Path.basename(path)}"
        )

      {:error, :not_opml} ->
        State.error(state, "#{Path.basename(path)} is not an OPML feed list")
    end
  end

  def opml_read(state, _path, {:error, :enoent}), do: State.error(state, "File not found")

  def opml_read(state, _path, {:error, reason}),
    do: State.error(state, "Could not read: #{inspect(reason)}")

  # --- results of effects -----------------------------------------------------
  #
  # `App` calls these after it has carried out an effect, with its result.
  # Each has a clause per result shape (`:ok`, `{:ok, value}`,
  # `{:error, reason}`), so a failure becomes a message, never a crash.

  @doc "After saving the person's preferences (R41b): only a failure is reported."
  def preferences_saved(state, :ok), do: state

  def preferences_saved(state, {:error, reason}),
    do: State.error(state, "Could not save your preferences: #{inspect(reason)}")

  # Domain: after a good save the database on screen becomes the saved one
  # (`saved.db`), so the file is clean, and what waited for the
  # save goes on (`opts.then`). A failed save changes nothing but the
  # message: the changes are still unsaved, say so, and nothing that
  # waited for them happens (R71): Quit stays, Retrieve opens nothing.
  @doc """
  After the shell saved the file (`{:save, path, opts}`): the result is
  the new stamp, or why it was not saved; a file changed on disk is asked
  about, except by auto-save, which says so and stops (R71).
  """
  @spec saved(State.t(), String.t(), {:ok, Agendum.Store.stamp()} | {:error, term}, map) ::
          State.t()
  def saved(state, path, {:ok, stamp}, opts) do
    %{
      state
      | path: path,
        dirty: false,
        saved: %{db: state.db, stamp: stamp, conflict: false}
    }
    |> remember(path)
    |> State.info("Saved #{Path.basename(path)}")
    |> after_save(opts.then)
  end

  def saved(state, path, {:error, :changed_on_disk}, %{auto: true}) do
    %{state | saved: %{state.saved | conflict: true}}
    |> State.error(
      "Not auto-saved: #{Path.basename(path)} changed on disk; save it yourself to choose"
    )
  end

  def saved(state, path, {:error, :changed_on_disk}, opts) do
    # `opts.expect` nil: no file was there when this one was read
    what = if opts.expect == nil, do: "already exists", else: "has changed on disk"

    Prompts.ask(
      state,
      "#{Path.basename(path)} #{what} since Agendum read it. Save over it?",
      {:overwrite, path, opts.then}
    )
  end

  def saved(state, _path, {:error, reason}, opts) do
    tail = if opts.then == :quit, do: " (not quitting)", else: ""
    State.error(state, "Could not save: #{inspect(reason)}#{tail}")
  end

  # what waited for the save: quitting keeps the person's place in the
  # file first (R69), as `handle/2` does for a Quit without a save
  defp after_save(state, nil), do: state

  defp after_save(state, :quit),
    do: state |> Agendum.TUI.Places.remember() |> State.effect(:quit)

  defp after_save(state, {:replace_file, command}), do: Prompts.replace_file(state, command)

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

  # `%State{expr | message: ...}` is the struct update syntax with the
  # struct's name: it also checks that `expr` is a `State`. Domain: the new
  # file goes through `arrive/1` too, as at startup, for its alarms (R70).
  def loaded(state, path, {:ok, db, stamp}) do
    %State{
      State.reopen(state, db, path, stamp)
      | message: {:message, "Retrieved #{Path.basename(path)}"}
    }
    |> remember(path)
    |> Layout.settle()
    |> arrive()
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
    # Domain: one Import for both kinds of file, told apart by what is in
    # them (R72): an Agenda file starts with "T", JSON with "{"
    if Core.agenda_file?(text),
      do: import_ag(state, path, text, nil),
      else: import_json(state, path, text)
  end

  def imported(state, _path, {:error, :enoent}), do: State.error(state, "File not found")

  def imported(state, _path, {:error, reason}),
    do: State.error(state, "Could not read: #{inspect(reason)}")

  defp import_json(state, path, text) do
    case Core.import_json(text) do
      {:ok, db} ->
        %State{
          State.reopen(state, db, nil)
          | dirty: true,
            saved: %{db: nil, stamp: nil, conflict: false},
            message: {:message, "Imported #{Path.basename(path)} (save it to keep it)"}
        }
        |> Layout.settle()
        |> arrive()

      {:error, reason} ->
        State.error(state, "Could not import #{Path.basename(path)}: #{reason}")
    end
  end

  @doc """
  Imports a Lotus Agenda file (R72) read from `path`: it opens as a new
  file of the same name with Agendum's extension, beside it, not saved
  yet (a file already there is asked about at the first save, R71), and
  the report of what came over shows. A file with a password asks for it
  (`password` nil: not asked yet), again when it was wrong.
  """
  @spec import_ag(State.t(), String.t(), binary, String.t() | nil) :: State.t()
  def import_ag(state, path, bytes, password) do
    name = Path.basename(path)

    case Core.import_ag(bytes, password: password, clock: State.context(state)) do
      {:ok, db, report} ->
        into = Path.rootname(path) <> Agendum.Store.extension()

        %State{
          State.reopen(state, db, into)
          | dirty: true,
            saved: %{db: nil, stamp: nil, conflict: false},
            message: {:message, "Imported #{name} as #{Path.basename(into)} (save it to keep it)"}
        }
        |> Layout.settle()
        |> arrive()
        |> Agendum.TUI.Boxes.ImportReportBox.open(path, report)

      {:error, :password_required} ->
        Prompts.password(state, "Password of #{name}:", {:ag_password, path, bytes})

      # as Agenda said it; the prompt has both top lines, so it says it
      {:error, :wrong_password} ->
        Prompts.password(
          state,
          "The password you typed is incorrect. Retype the password of #{name}:",
          {:ag_password, path, bytes}
        )

      {:error, :not_an_agenda_file} ->
        State.error(state, "#{name} is not an Agenda file Agendum can read")

      {:error, message} ->
        State.error(state, "Could not import #{name}: #{message}")
    end
  end

  def written(state, path, :ok), do: State.info(state, "Wrote #{path}")

  def written(state, _path, {:error, reason}),
    do: State.error(state, "Could not write: #{inspect(reason)}")

  @doc """
  The site's folder read (R74): what publishing would change there is
  shown before anything is written.
  """
  def publish_scanned(state, folder, files, {:ok, scan}) do
    changes = Core.site_changes(files, scan.existing, scan.published)

    if Agendum.TUI.Boxes.PublishPreviewBox.nothing?(changes) and state.db.blog.upload == :none,
      do: State.info(state, "The folder already holds this site: nothing to publish"),
      else: Agendum.TUI.Boxes.PublishPreviewBox.open(state, folder, files, changes)
  end

  def publish_scanned(state, _folder, _files, {:error, reason}),
    do: State.error(state, "Could not read the site's folder: #{reason}")

  @doc """
  The site written and uploaded (R74), or why not; an SFTP server that
  refused the keys asks for a password, with the preview still open.
  """
  def published(state, changes, :ok) do
    preview = Agendum.TUI.Boxes.PublishPreviewBox
    where = if state.db.blog.upload == :none, do: "", else: " and uploaded"

    state
    |> pop_publish_preview()
    |> State.info("Published#{where}: #{preview.summary(changes)}")
  end

  def published(state, _changes, {:error, :password}) do
    user = state.db.blog.user

    Prompts.password(
      state,
      "Password of #{user}@#{state.db.blog.target} (not kept):",
      {:sftp_password}
    )
  end

  def published(state, _changes, {:error, reason}),
    do: state |> pop_publish_preview() |> State.error("Not published: #{reason}")

  defp pop_publish_preview(state) do
    case State.mode(state) do
      %{type: :publish_preview} -> State.pop(state)
      _ -> state
    end
  end

  @doc "A folder read for the Select File box (R51)."
  def dir_listed(state, dir, result), do: Agendum.TUI.Boxes.SelectFile.listed(state, dir, result)

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

  defp dispatch(state, %{type: :move_item} = m, key), do: Marked.move_key(state, m, key)

  defp dispatch(state, %{type: :browse} = m, key),
    do: Agendum.TUI.Moves.Browse.handle(state, m, key)

  defp dispatch(state, %{type: :column_width} = m, key),
    do: Agendum.TUI.Moves.ColumnWidth.handle(state, m, key)

  defp dispatch(state, %{type: :column_move} = m, key),
    do: Agendum.TUI.Moves.ColumnMove.handle(state, m, key)

  defp dispatch(state, %{type: :section_move} = m, key),
    do: Agendum.TUI.Moves.SectionMove.handle(state, m, key)

  defp dispatch(state, %{type: :searching} = m, key),
    do: SearchBox.searching_key(state, m, key, &ViewKeys.view_key/2)

  defp dispatch(state, mode, key), do: CategoryScreens.handle(state, mode, key)
end
