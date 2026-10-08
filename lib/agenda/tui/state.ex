defmodule Agenda.TUI.State do
  @moduledoc """
  The complete UI state, as a plain value. `Agenda.TUI.Update` transforms
  it in response to keys; `Agenda.TUI.Render` turns it into a screen.

  `modes` is a stack of overlays (menu, category manager, prompts...). An
  empty stack means the user is in the view itself. `edit` holds an inline
  edit in progress on whichever screen is active.
  """

  alias Agenda.Core.Database

  @type cursor_key :: {:section, non_neg_integer} | {:item, non_neg_integer, Database.id()} | nil

  @type t :: %__MODULE__{
          db: Database.t(),
          path: String.t() | nil,
          dirty: boolean,
          today: Date.t(),
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
          clipboard: Database.id() | nil,
          effects: [term]
        }

  defstruct db: nil,
            path: nil,
            dirty: false,
            today: nil,
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
            clipboard: nil,
            effects: []

  @spec new(Database.t(), keyword) :: t
  def new(%Database{} = db, opts \\ []) do
    %__MODULE__{
      db: db,
      path: opts[:path],
      today: Keyword.fetch!(opts, :today),
      width: Keyword.get(opts, :width, 80),
      height: Keyword.get(opts, :height, 25),
      view_id: hd(db.view_order)
    }
  end

  @spec view(t) :: Agenda.Core.View.t()
  def view(%__MODULE__{db: db, view_id: id}), do: Database.view(db, id)

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

  @spec change_db(t, Database.t()) :: t
  def change_db(state, db), do: %{state | db: db, dirty: true}

  @doc "Queues a side effect for the imperative shell to perform."
  @spec effect(t, term) :: t
  def effect(state, effect), do: %{state | effects: state.effects ++ [effect]}

  def info(state, text), do: %{state | message: {:message, text}}
  def error(state, text), do: %{state | message: {:error, text}}

  @doc "Number of screen lines available for the view body."
  def body_height(%__MODULE__{height: h}), do: max(h - 4, 1)
end
