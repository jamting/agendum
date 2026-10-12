defmodule Agenda.TUI.State do
  @moduledoc """
  The complete UI state, as a plain value. `Agenda.TUI.Update` transforms
  it in response to keys; `Agenda.TUI.Render` turns it into a screen.

  `modes` is a stack of overlays (menu, category manager, prompts...). An
  empty stack means the user is in the view itself. `edit` holds an inline
  edit in progress on whichever screen is active.

  `collapsed` holds the categories whose families are collapsed wherever
  the hierarchy is shown (a display preference, not part of the file), and
  `last_key` the previous key, so that pressing a key twice can mean more.

  `undo` and `redo` hold snapshots for `Agenda.TUI.History`. `saved_db` is the
  database as last saved or loaded; the file is dirty whenever `db` differs.
  """

  alias Agenda.Core.Database

  @type cursor_key :: {:section, non_neg_integer} | {:item, non_neg_integer, Database.id()} | nil

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
          last_view_id: Database.id() | nil,
          last_search: Agenda.Core.Search.t() | nil,
          last_note_search: Agenda.TUI.NoteSearch.settings() | nil,
          key_map: boolean,
          languages: [Agenda.Core.DateLanguage.pack()],
          input: Agenda.Core.InputFormat.t(),
          prefs: Agenda.Preferences.t(),
          fetching: %{optional(pos_integer) => :manual | :auto},
          theme: Agenda.TUI.Theme.name(),
          last_key: term,
          undo: [map],
          redo: [map],
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
            last_view_id: nil,
            last_search: nil,
            last_note_search: nil,
            key_map: true,
            languages: [Agenda.Core.DateLanguage.English],
            input: %Agenda.Core.InputFormat{},
            prefs: %Agenda.Preferences{},
            fetching: %{},
            theme: :classic,
            last_key: nil,
            undo: [],
            redo: [],
            saved_db: nil,
            effects: []

  @spec new(Database.t(), keyword) :: t
  def new(%Database{} = db, opts \\ []) do
    %__MODULE__{
      db: db,
      path: opts[:path],
      today: Keyword.fetch!(opts, :today),
      now:
        Keyword.get_lazy(opts, :now, fn ->
          NaiveDateTime.new!(Keyword.fetch!(opts, :today), ~T[09:00:00])
        end),
      width: Keyword.get(opts, :width, 80),
      height: Keyword.get(opts, :height, 25),
      languages: Keyword.get(opts, :languages, [Agenda.Core.DateLanguage.English]),
      input: Keyword.get(opts, :input, %Agenda.Core.InputFormat{}),
      prefs: Keyword.get(opts, :prefs, %Agenda.Preferences{}),
      theme: Keyword.get(opts, :theme, :classic),
      view_id: hd(db.view_order),
      saved_db: db
    }
  end

  @doc """
  What the core needs to read typed dates: the current time, the date
  languages chosen on the command line (R14c) and the person's input
  format (R41b).
  """
  @spec context(t) :: Agenda.Core.Context.t()
  def context(%__MODULE__{now: now, languages: languages, input: input}),
    do: %Agenda.Core.Context{now: now, languages: languages, input: input}

  @doc """
  Changes one of the person's preferences (R40, R14c, R41b): `change`
  updates what the session uses, and the same field of the stored
  preferences, which are saved when there is a preferences file. Only the
  changed setting is saved, never one a flag gave for this session.
  """
  @spec change_preference(t, (t -> t), (Agenda.Preferences.t() -> Agenda.Preferences.t())) :: t
  def change_preference(state, change, change_prefs) do
    state = %{change.(state) | prefs: change_prefs.(state.prefs)}

    if state.prefs.path,
      do: effect(state, {:save_preferences, state.prefs.path, state.prefs}),
      else: state
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
        languages: state.languages,
        input: state.input,
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
  @spec view(t) :: Agenda.Core.View.t()
  def view(%__MODULE__{db: db, view_id: id, modes: modes} = state) do
    view = Database.view(db, id)
    if modes == [], do: view, else: Agenda.TUI.Browse.view(state, view)
  end

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
      | last_view_id: state.view_id,
        view_id: view_id,
        cursor: 0,
        cursor_key: nil,
        col: 0,
        scroll: 0
    }
  end

  @spec change_db(t, Database.t()) :: t
  def change_db(state, db), do: %{state | db: db, dirty: true}

  @doc "Queues a side effect for the imperative shell to perform."
  @spec effect(t, term) :: t
  def effect(state, effect), do: %{state | effects: state.effects ++ [effect]}

  def info(state, text), do: %{state | message: {:message, text}}
  def error(state, text), do: %{state | message: {:error, text}}

  @doc "Number of screen lines available for the view body."
  def body_height(%__MODULE__{height: h, key_map: true}), do: max(h - 3, 1)
  def body_height(%__MODULE__{height: h, key_map: false}), do: max(h - 2, 1)
end
