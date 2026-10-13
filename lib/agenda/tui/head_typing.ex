defmodule Agenda.TUI.HeadTyping do
  @moduledoc """
  Typing a column head's name in a box: Column Add and Column Properties
  (User's Guide 3-17: "Type the name of a new or existing category").

  A letter on the Column head field starts an input line in the field
  (the box's mode holds it as `typing`). ENTER takes the name: the
  category of that name, or a new one under MAIN
  (`Core.find_or_add_category/2`); a name several categories have is
  left to the picker (F3). ESC drops the name and stays in the box. Pure.
  """

  alias Agenda.Core
  alias Agenda.TUI.{LineEdit, State}

  @doc "Whether the box's mode is typing a name."
  def typing?(mode), do: Map.get(mode, :typing) != nil

  @doc "Starts typing a name with the character `c`."
  def start(state, mode, c), do: State.put_mode(state, Map.put(mode, :typing, LineEdit.new(c)))

  @doc """
  A key while typing. On ENTER with a name found or made, `chosen` gets
  the state (the box on top, no longer typing), the database with the
  category in it (new or not, not yet kept), and its id.
  """
  def key(state, mode, key, chosen) do
    case key do
      :esc ->
        State.put_mode(state, %{mode | typing: nil})

      :enter ->
        name = mode.typing.text
        state = State.put_mode(state, %{mode | typing: nil})

        case Core.find_or_add_category(state.db, name) do
          {:ok, db, id} ->
            chosen.(state, db, id)

          {:error, :empty} ->
            state

          {:error, :ambiguous} ->
            State.error(state, "Several categories are called #{String.trim(name)}; F3 picks one")
        end

      _ ->
        case LineEdit.handle(mode.typing, key) do
          {:ok, line} -> State.put_mode(state, %{mode | typing: line})
          :unhandled -> state
        end
    end
  end

  @doc "The `editing:` option for `Template.render/3` while typing."
  def editing(mode), do: if(typing?(mode), do: [editing: {:head, mode.typing}], else: [])
end
