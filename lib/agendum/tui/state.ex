defmodule Agendum.TUI.State do
  @moduledoc """
  The complete UI state, as a plain value. `Agendum.TUI.Update` transforms
  it in response to keys; `Agendum.TUI.Render` turns it into a screen.

  `modes` is a stack of overlays (menu, category manager, prompts...). An
  empty stack means the user is in the view itself. `edit` holds an inline
  edit in progress on whichever screen is active.

  `collapsed` holds the categories whose families are collapsed wherever
  the hierarchy is shown (a display preference, not part of the file), and
  `last_key` the previous key and when it came, so that pressing a key
  twice can mean more and auto-save (R54) knows how long the keyboard has
  been idle. `count` is the count typed with ALT-digits for the next
  command in a view (R65), nil when there is none.

  `undo` and `redo` hold snapshots for `Agendum.TUI.History`. `saved` is the file
  on disk as last saved or loaded: its database (`saved.db`; the file is
  dirty whenever `db` differs), the stamp of its bytes (`saved.stamp`, nil
  when it was not on disk) and whether an auto-save found another writer
  had changed it (`saved.conflict`, R71).

  Two kinds of field (ROADMAP, Towards many users; `docs/plans/MULTIUSER.md`
  §7, step 5): the **file** (`file_fields/0`), what everyone working in the
  same file shares, which a web server would hold once for them all; and
  the **session** (`session_fields/0`), one person's: what they see, where
  they are, what they are typing, their undo, their settings. Here both are
  in one struct; a web version keeps the first in the file's process and
  the second per person. A test checks every field is one or the other.
  """

  alias Agendum.Core.Database

  @type cursor_key :: {:section, non_neg_integer} | {:item, non_neg_integer, Database.id()} | nil

  # `@type t` names the struct's type for `@spec`s and Dialyzer;
  # `__MODULE__` is this module's own name. `defstruct` below gives each
  # field its default. A struct is a map with a fixed set of keys: a
  # misspelt field in `%State{…}` or `state.fild` is an error, which a
  # plain map would not catch. (`modes` holds structs too: `Agendum.TUI.Modes`.)
  @type t :: %__MODULE__{
          db: Database.t(),
          path: String.t() | nil,
          dirty: boolean,
          today: Date.t(),
          now: NaiveDateTime.t(),
          alarm_rang: boolean,
          width: pos_integer,
          height: pos_integer,
          view_id: Database.id(),
          cursor: non_neg_integer,
          cursor_key: cursor_key,
          col: non_neg_integer,
          scroll: non_neg_integer,
          modes: [Agendum.TUI.Modes.t()],
          edit: map | nil,
          message: {atom, String.t()} | nil,
          collapsed: MapSet.t(Database.id()),
          last: %{
            view: Database.id() | nil,
            removed: Database.id() | nil,
            copied: String.t() | nil,
            commands: [{atom, String.t()}]
          },
          searches: %{
            view: Agendum.Core.Search.t() | nil,
            note: Agendum.TUI.Typing.NoteSearch.settings() | nil
          },
          macro: %{learning: map | nil, last: Database.id() | nil, playing: non_neg_integer},
          key_map: boolean,
          reader: Agendum.Core.Context.t(),
          prefs: Agendum.Preferences.t(),
          fetching: %{optional(pos_integer) => :manual | :auto},
          theme: Agendum.TUI.Terminal.Theme.name(),
          last_key: %{key: term, at: NaiveDateTime.t() | nil},
          count: pos_integer | nil,
          views: %{recent: [Database.id()], by_recent: boolean},
          history: %{undo: [map], redo: [map], step: Database.t() | nil},
          saved: %{
            db: Database.t() | nil,
            stamp: Agendum.Store.stamp() | nil,
            conflict: boolean
          },
          effects: [Agendum.TUI.Effect.t()]
        }

  defstruct db: nil,
            path: nil,
            dirty: false,
            today: nil,
            now: nil,
            alarm_rang: false,
            width: 80,
            height: 25,
            view_id: nil,
            cursor: 0,
            cursor_key: nil,
            col: 0,
            scroll: 0,
            modes: [],
            edit: nil,
            message: nil,
            collapsed: MapSet.new(),
            # what a key goes back to: the view shown before this one
            # (ALT-F8), the item DEL last took out of a section (ALT-Y, R42),
            # the text last cut or copied in a note (F2 PASTE, R63), and the
            # commands last run by name (CTRL-X, F1 c; R65d), the most
            # recent first, each as `{place, name}`
            last: %{view: nil, removed: nil, copied: nil, commands: []},
            searches: %{view: nil, note: nil},
            # macros (R50): what Learn mode is recording, the last macro
            # run (ALT-Z), and how many runs are playing, one inside another
            macro: %{learning: nil, last: nil, playing: 0},
            key_map: true,
            # the person who reads and types dates: their date languages
            # (R14c), input format (R41b) and the date rules compiled for
            # them (`Agendum.Core.Context.prepare/1`); a context without
            # the time, which `context/1` adds
            reader: %Agendum.Core.Context{},
            prefs: %Agendum.Preferences{},
            fetching: %{},
            theme: :classic,
            last_key: %{key: nil, at: nil},
            count: nil,
            # the views shown, the last first, and whether the view manager
            # lists them in that order (R68): the person's, kept with where
            # they left the file (`Agendum.TUI.Places`)
            views: %{recent: [], by_recent: false},
            history: %{undo: [], redo: [], step: nil},
            # the file on disk as Agendum last read or wrote it: its
            # database, the stamp of its bytes (nil: not there then), and
            # whether an auto-save found another writer had changed it,
            # which stops auto-saving until a save the person makes settles
            # it (R71)
            saved: %{db: nil, stamp: nil, conflict: false},
            effects: []

  # Domain: what is shared by everyone in the file (the database, where it
  # is kept and whether it is saved, the calendars being read for it);
  # everything else is one person's session. Undo is the session's: each
  # person undoes their own changes (MULTIUSER §4).
  @file_fields [:db, :path, :saved, :dirty, :fetching]

  @doc "The fields that belong to the file, shared by everyone working in it."
  @spec file_fields() :: [atom]
  def file_fields, do: @file_fields

  @doc "The fields that belong to one person's session: every other field."
  @spec session_fields() :: [atom]
  def session_fields,
    do: (%__MODULE__{} |> Map.from_struct() |> Map.keys() |> Enum.sort()) -- @file_fields

  @spec new(Database.t(), keyword) :: t
  def new(%Database{} = db, opts \\ []) do
    now =
      Keyword.get_lazy(opts, :now, fn ->
        NaiveDateTime.new!(Keyword.fetch!(opts, :today), ~T[09:00:00])
      end)

    state =
      %__MODULE__{
        db: db,
        path: opts[:path],
        today: Keyword.fetch!(opts, :today),
        now: now,
        last_key: %{key: nil, at: now},
        width: Keyword.get(opts, :width, 80),
        height: Keyword.get(opts, :height, 25),
        reader: %Agendum.Core.Context{
          languages: Keyword.get(opts, :languages, [Agendum.Core.DateLanguage.English]),
          input: Keyword.get(opts, :input, %Agendum.Core.InputFormat{})
        },
        prefs: Keyword.get(opts, :prefs, %Agendum.Preferences{}),
        key_map: Keyword.get(opts, :prefs, %Agendum.Preferences{}).key_map,
        theme: Keyword.get(opts, :theme, :classic),
        view_id: hd(db.view_order),
        saved: %{db: db, stamp: opts[:stamp], conflict: false}
      }
      |> prepare_dates()

    # back where the person left this file, if they have been in it (R69);
    # the match tells the compiler's type checker it is still a `State`
    %__MODULE__{} = Agendum.TUI.Places.restore(state)
  end

  # Compiles the date rules for the reader's languages and input format,
  # once rather than at every date read (they are kept by both, so rules
  # for others are never used, only compiled again).
  defp prepare_dates(%__MODULE__{} = state),
    do: %__MODULE__{state | reader: Agendum.Core.Context.prepare(state.reader)}

  @doc """
  What the core needs to read typed dates: the current time, the date
  languages chosen on the command line (R14c) and the person's input
  format (R41b).
  """
  @spec context(t) :: Agendum.Core.Context.t()
  def context(%__MODULE__{now: now, reader: reader}), do: %{reader | now: now}

  @doc "The date languages the person reads and types, the main one first (R14c)."
  @spec languages(t) :: [Agendum.Core.DateLanguage.pack()]
  def languages(state), do: state.reader.languages

  @doc "How the person types dates (R41b)."
  @spec input(t) :: Agendum.Core.InputFormat.t()
  def input(state), do: state.reader.input

  @doc """
  Sets the person's date languages or input format (`languages:`,
  `input:`), and compiles the date rules for them.
  """
  @spec put_reader(t, keyword) :: t
  def put_reader(%__MODULE__{} = state, changes),
    do: prepare_dates(%__MODULE__{state | reader: struct(state.reader, changes)})

  @doc "How numbers are shown and read for this person (R54)."
  @spec number_opts(t) :: [decimal: String.t(), thousands: String.t()]
  def number_opts(state), do: state |> context() |> Agendum.Core.Context.number_opts()

  @doc """
  Changes one of the person's preferences (R40, R14c, R41b): `change`
  updates what the session uses, and the same field of the stored
  preferences, which are saved when there is a preferences file. Only the
  changed setting is saved, never one a flag gave for this session.
  """
  @spec change_preference(t, (t -> t), (Agendum.Preferences.t() -> Agendum.Preferences.t())) :: t
  def change_preference(state, change, change_prefs) do
    before = {languages(state), input(state)}
    state = %{change.(state) | prefs: change_prefs.(state.prefs)}
    state = if {languages(state), input(state)} == before, do: state, else: prepare_dates(state)

    if state.prefs.path,
      do: effect(state, {:save_preferences, state.prefs.path, state.prefs}),
      else: state
  end

  @doc "Shows or hides the key bar (ALT-K, File ▸ Customize; R54), and keeps it so."
  @spec toggle_key_map(t) :: t
  def toggle_key_map(state) do
    shown = not state.key_map
    change_preference(state, &%{&1 | key_map: shown}, &%{&1 | key_map: shown})
  end

  @doc """
  The state for another file (Retrieve, New, Import): a fresh start for
  the file, keeping the session (time, screen size, languages, input
  format, theme, preferences, key map). Where the person was in the file
  they leave is kept in their preferences, and the other file opens where
  they left it (R69). `stamp` is the file's on disk as it was read (R71),
  nil for a file not on disk yet.
  """
  @spec reopen(t, Database.t(), String.t() | nil, Agendum.Store.stamp() | nil) :: t
  def reopen(state, db, path, stamp \\ nil) do
    state = Agendum.TUI.Places.remember(state)

    %{
      new(db,
        path: path,
        stamp: stamp,
        today: state.today,
        now: state.now,
        width: state.width,
        height: state.height,
        languages: languages(state),
        input: input(state),
        theme: state.theme,
        prefs: state.prefs
      )
      | key_map: state.key_map
    }
  end

  @doc """
  The current view; while it is browsed (R47, R48), with the browsed dates
  instead of its own.
  """
  @spec view(t) :: Agendum.Core.View.t()
  def view(%__MODULE__{db: db, view_id: id, modes: modes} = state) do
    view = Database.view(db, id)
    # while browsing (R48), choosing a column's width or moving a column,
    # the view is shown as it would be, before anything is kept
    if modes == [] do
      view
    else
      view
      |> then(&Agendum.TUI.Moves.Browse.view(state, &1))
      |> then(&Agendum.TUI.Moves.ColumnWidth.view(state, &1))
      |> then(&Agendum.TUI.Moves.ColumnMove.view(state, &1))
      |> then(&Agendum.TUI.Moves.SectionMove.view(state, &1))
    end
  end

  # Domain: `modes` is a stack kept as a list, the top first. Opening a box
  # or a menu pushes one (`[mode | modes]`, cheap on a linked list); ESC
  # pops it. What is on top decides who gets the next key
  # (`Update.dispatch/3`) and what is drawn over the view (`Render`).
  @spec mode(t) :: map | nil
  def mode(%__MODULE__{modes: [top | _]}), do: top
  def mode(_), do: nil

  @spec push(t, map) :: t
  # a mode written as a map becomes its struct here (`Agendum.TUI.Modes`)
  def push(state, mode),
    do: %{state | modes: [Agendum.TUI.Modes.new(mode) | state.modes], edit: nil}

  @spec pop(t) :: t
  def pop(%__MODULE__{modes: [_ | rest]} = state), do: %{state | modes: rest, edit: nil}
  def pop(state), do: state

  @doc "Replaces the top mode."
  @spec put_mode(t, map) :: t
  def put_mode(%__MODULE__{modes: [_ | rest]} = state, mode),
    do: %{state | modes: [Agendum.TUI.Modes.new(mode) | rest]}

  @doc """
  Shows another view, remembering the current one for ALT-F8 (LAST VW)
  and as recently used (R68), with the cursor at the top.
  """
  @spec switch_view(t, Database.id()) :: t
  def switch_view(%__MODULE__{view_id: id} = state, id), do: state

  def switch_view(state, view_id) do
    %{
      state
      | last: %{state.last | view: state.view_id},
        view_id: view_id,
        views: %{
          state.views
          | recent:
              Agendum.Preferences.Place.recent([view_id, state.view_id | state.views.recent])
        },
        cursor: 0,
        cursor_key: nil,
        col: 0,
        scroll: 0
    }
  end

  @spec change_db(t, Database.t()) :: t
  def change_db(state, db), do: %{state | db: db, dirty: true}

  @doc """
  Runs a core command (R66, ADR 0036) on the file, at the state's clock.
  A refused one leaves the file as it was and says why.
  """
  @spec run(t, Agendum.Core.Command.t()) :: t
  def run(state, command), do: state |> run_with_changes(command) |> elem(0)

  @doc "Runs a core command and, when it ran, shows `text` (\"Item discarded\")."
  @spec run(t, Agendum.Core.Command.t(), String.t()) :: t
  def run(state, command, text) do
    case run_with_changes(state, command) do
      {state, nil} -> state
      {state, _changes} -> info(state, text)
    end
  end

  @doc """
  Runs a core command and gives back the new state and what changed, or
  the reason it was refused, for the caller to word: the state is left
  as it was then.
  """
  @spec command(t, Agendum.Core.Command.t()) ::
          {:ok, t, Agendum.Core.Command.Changes.t()} | {:error, Agendum.Core.Command.error()}
  def command(state, command) do
    case Agendum.Core.run(state.db, command, context(state)) do
      # a command that changed nothing leaves the state as it was
      {:ok, db, changes} when db == state.db ->
        {:ok, state, changes}

      {:ok, db, changes} ->
        {:ok, change_db(state, db), changes}

      # a command the core does not know, or with the wrong arguments, is
      # a mistake in the TUI, not something to tell the person: let it crash
      {:error, reason} when reason in [:bad_arguments, :unknown_command] ->
        raise ArgumentError, "the core refused #{inspect(command)}: #{reason}"

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  The file as it would be after a command, for showing while the person
  chooses (a column's width, a section dragged): nothing is kept. A
  refused command shows the file as it is.
  """
  @spec preview(t, Agendum.Core.Command.t()) :: Database.t()
  def preview(state, command) do
    case Agendum.Core.run(state.db, command, context(state)) do
      {:ok, db, _changes} -> db
      {:error, _reason} -> state.db
    end
  end

  @doc "Runs a core command, and also returns what changed (nil if refused)."
  @spec run_with_changes(t, Agendum.Core.Command.t()) ::
          {t, Agendum.Core.Command.Changes.t() | nil}
  def run_with_changes(state, command) do
    case command(state, command) do
      {:ok, state, changes} -> {state, changes}
      {:error, reason} -> {error(state, command_error(reason)), nil}
    end
  end

  # the core gives a reason as an atom; the words are the front end's
  defp command_error(:no_such_item), do: "That item is no longer in the file"
  defp command_error(:no_such_category), do: "That category is no longer in the file"
  defp command_error(:no_such_view), do: "That view or section is no longer in the file"
  defp command_error(:empty_text), do: "The text cannot be empty"
  defp command_error(:no_such_macro), do: "That macro is no longer in the file"
  defp command_error(:no_such_calendar), do: "That calendar is no longer in the file"
  # a reason the caller did not expect to need words for (it would have
  # used `command/2`)
  defp command_error(reason), do: "Not done (#{inspect(reason)})"

  @doc """
  Ends an undo step in the middle of a key: what the key changed so far is
  undone on its own, before the rest (`Agendum.TUI.History.record/2`). For
  a key that does two things the person would undo separately, such as
  the first replacement in a note after typing in it.
  """
  @spec end_step(t) :: t
  # `put_in/2` with a path written as field access updates a value two
  # levels down and returns the whole new state; the plain way would be
  # `%{state | history: %{state.history | step: state.db}}`.
  def end_step(state), do: put_in(state.history.step, state.db)

  @doc "Queues a side effect for the imperative shell to perform."
  # Domain: an effect is only data, such as `{:save, path}`. Adding it does
  # nothing yet; `Update.handle/2` returns the list and `App` performs it.
  # (`++` copies the left list; effects come one or two per key, so the
  # order is worth more than the cost.)
  @spec effect(t, Agendum.TUI.Effect.t()) :: t
  def effect(state, effect), do: %{state | effects: state.effects ++ [effect]}

  @doc """
  Asks the shell to save the file to `path` (`{:save, path, opts}`), then
  to do `then` once the save succeeded (R71): nothing (nil), `:quit`, or
  `{:replace_file, command}` (the prompt for Retrieve, New or Import).
  Saved where it was read, the save expects the file as it was then;
  saved under another name, whatever is there (`:any`). `expect:` and
  `auto:` (an auto-save, R54) in `opts` say otherwise.
  """
  @spec save(t, String.t(), keyword) :: t
  def save(state, path, opts \\ []) do
    expect = if path == state.path, do: state.saved.stamp, else: :any

    effect(state, {
      :save,
      path,
      %{
        expect: Keyword.get(opts, :expect, expect),
        then: opts[:then],
        auto: Keyword.get(opts, :auto, false)
      }
    })
  end

  def info(state, text), do: %{state | message: {:message, text}}
  def error(state, text), do: %{state | message: {:error, text}}

  @doc "Number of screen lines available for the view body."
  def body_height(%__MODULE__{height: h, key_map: true}), do: max(h - 3, 1)
  def body_height(%__MODULE__{height: h, key_map: false}), do: max(h - 2, 1)
end
