defmodule Agendum.TUI.Boxes.FieldTyping do
  @moduledoc """
  Typing text into a field of a settings box: a column head's name in
  Column Add and Column Properties (User's Guide 3-17: "Type the name of a
  new or existing category"), a Category note column's title, or a number
  (a width, decimal places, a line number): Agenda's "type your own
  choice" (User's Guide 2-17).

  A character on such a field starts an input line in it (the box's mode
  holds it as `typing: {field, line}`). ENTER hands the text to the box;
  ESC drops it and stays in the box. Pure.
  """

  alias Agendum.Core
  alias Agendum.TUI.{Typing.LineEdit, State}

  @doc "Whether the box's mode is typing into a field."
  def typing?(mode), do: Map.get(mode, :typing) != nil

  @doc "Starts typing into `field` with the character `c`."
  def start(state, mode, field, c),
    do: State.put_mode(state, Map.put(mode, :typing, {field, LineEdit.new(c)}))

  @doc """
  A key while typing. On ENTER, `entered` gets the state (the box on top,
  no longer typing), the field and the text.
  """
  def key(state, %{typing: {field, line}} = mode, key, entered) do
    case key do
      :esc ->
        State.put_mode(state, %{mode | typing: nil})

      :enter ->
        state |> State.put_mode(%{mode | typing: nil}) |> entered.(field, line.text)

      _ ->
        case LineEdit.handle(line, key) do
          {:ok, line} -> State.put_mode(state, %{mode | typing: {field, line}})
          :unhandled -> state
        end
    end
  end

  @doc """
  A typed column head: `chosen` gets the state, the database with the
  category of that name in it (a new one under MAIN if need be, not yet
  kept; `Core.find_or_add_category/2`) and its id. A name several
  categories have is left to the picker (F3).
  """
  def head_named(state, name, chosen) do
    case Core.find_or_add_category(state.db, name) do
      {:ok, db, id} ->
        chosen.(state, db, id)

      {:error, :empty} ->
        state

      {:error, :ambiguous} ->
        State.error(state, "Several categories are called #{String.trim(name)}; F3 picks one")
    end
  end

  @doc "Whether a typed character starts a number (a width, decimal places, a line)."
  @spec digit?(String.t()) :: boolean
  def digit?(c), do: c in ~w(0 1 2 3 4 5 6 7 8 9)

  @doc "A typed whole number from `min` to `max`; `:error` for anything else."
  @spec number(String.t(), integer, integer) :: {:ok, integer} | :error
  def number(text, min, max) do
    case Integer.parse(String.trim(text)) do
      {n, ""} when n >= min and n <= max -> {:ok, n}
      _ -> :error
    end
  end

  @doc "The `editing:` option for `Template.render/3` while typing."
  def editing(%{typing: {field, line}}), do: [editing: {field, line}]
  def editing(_mode), do: []
end
