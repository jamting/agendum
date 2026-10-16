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

  `undo` and `redo` hold snapshots for `Agendum.TUI.History`. `saved_db` is the
  database as last saved or loaded; the file is dirty whenever `db` differs.
  """

  alias Agendum.Core.Database

  @type cursor_key :: {:section, non_neg_integer} | {:item, non_neg_integer, Database.id()} | nil

  # `@type t` names the struct's type for `@spec`s and Dialyzer;
  # `__MODULE__` is this module's own name. `defstruct` below gives each
  # field its default. A struct is a map with a fixed set of keys: a
  # misspelt field in `%State{…}` or `state.fild` is an error, which a
  # plain map would not catch. (`modes` is still a list of plain maps.)
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
          modes: [map],
          edit: map | nil,
          message: {atom, String.t()} | nil,
          collapsed: MapSet.t(Database.id()),
          last: %{
            view: Database.id() | nil,
            removed: Database.id() | nil,
            copied: String.t() | nil
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
          history: %{undo: [map], redo: [map], step: Database.t() | nil},
          saved_db: Database.t() | nil,
          effects: [term]
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
            # the text last cut or copied in a note (F2 PASTE, R63)
            last: %{view: nil, removed: nil, copied: nil},
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
            history: %{undo: [], redo: [], step: nil},
            saved_db: nil,
            effects: []

  @spec new(Database.t(), keyword) :: t
  def new(%Database{} = db, opts \\ []) do
    now =
      Keyword.get_lazy(opts, :now, fn ->
        NaiveDateTime.new!(Keyword.fetch!(opts, :today), ~T[09:00:00])
      end)

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
      saved_db: db
    }
    |> prepare_dates()
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
  format, theme, preferences, key map).
  """
  @spec reopen(t, Database.t(), String.t() | nil) :: t
  def reopen(state, db, path) do
    %{
      new(db,
        path: path,
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
  def push(state, mode), do: %{state | modes: [mode | state.modes], edit: nil}

  @spec pop(t) :: t
  def pop(%__MODULE__{modes: [_ | rest]} = state), do: %{state | modes: rest, edit: nil}
  def pop(state), do: state

  @doc "Replaces the top mode."
  @spec put_mode(t, map) :: t
  def put_mode(%__MODULE__{modes: [_ | rest]} = state, mode), do: %{state | modes: [mode | rest]}

  @doc """
  Shows another view, remembering the current one for ALT-F8 (LAST VW),
  with the cursor at the top.
  """
  @spec switch_view(t, Database.id()) :: t
  def switch_view(%__MODULE__{view_id: id} = state, id), do: state

  def switch_view(state, view_id) do
    %{
      state
      | last: %{state.last | view: state.view_id},
        view_id: view_id,
        cursor: 0,
        cursor_key: nil,
        col: 0,
        scroll: 0
    }
  end

  @spec change_db(t, Database.t()) :: t
  def change_db(state, db), do: %{state | db: db, dirty: true}

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
  @spec effect(t, term) :: t
  def effect(state, effect), do: %{state | effects: state.effects ++ [effect]}

  def info(state, text), do: %{state | message: {:message, text}}
  def error(state, text), do: %{state | message: {:error, text}}

  @doc "Number of screen lines available for the view body."
  def body_height(%__MODULE__{height: h, key_map: true}), do: max(h - 3, 1)
  def body_height(%__MODULE__{height: h, key_map: false}), do: max(h - 2, 1)
end
