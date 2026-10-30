# SPDX-License-Identifier: AGPL-3.0-only
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

  alias Agendum.TUI.{Typing.Completion, Typing.LineEdit, State}

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
    completing = Completion.box_field?(state)

    case key do
      :esc ->
        State.put_mode(state, done(mode))

      # a category's field takes the match completion shows (R32), as
      # Agenda's; `{:category, id}` is it, for `head_named/3`
      :enter when completing ->
        shown = Completion.shown(state)
        typed = if shown, do: {:category, shown}, else: line.text
        state |> State.put_mode(done(mode)) |> entered.(field, typed)

      :enter ->
        state |> State.put_mode(done(mode)) |> entered.(field, line.text)

      # NEXTSEL and PREVSEL, and NEWCAT: exactly what was typed
      k when completing and k in [{:f, 8}, {:alt, "n"}] ->
        Completion.cycle(state, 1)

      k when completing and k in [{:f, 7}, {:alt, "p"}] ->
        Completion.cycle(state, -1)

      k when completing and k in [{:f, 5}, :insert] ->
        state |> State.put_mode(done(mode)) |> entered.(field, line.text)

      # CHOICES: the field's own list, the typing dropped
      {:f, 3} when completing ->
        state |> State.put_mode(done(mode)) |> Agendum.TUI.Update.box_key({:f, 3})

      _ ->
        case LineEdit.handle(line, key) do
          # typing starts the completion over at the first match
          {:ok, line} -> State.put_mode(state, restart(%{mode | typing: {field, line}}))
          :unhandled -> state
        end
    end
  end

  # (F2's editing stays without completion: `choice: :off`, `Boxes.BoxEdit`)
  defp restart(%{choice: :off} = mode), do: mode
  defp restart(%{choice: _} = mode), do: %{mode | choice: 0}
  defp restart(mode), do: mode

  # the typing ended: no field typed in, completion as it starts
  defp done(%{choice: _} = mode), do: %{mode | typing: nil, choice: nil}
  defp done(mode), do: %{mode | typing: nil}

  @doc """
  A typed column head: `chosen` gets the state, with the category of that
  name in its file (a new one under MAIN if need be; the command
  `:find_or_add_category`), and its id; what `chosen` does with them is
  the same change, one undo step. A name several
  categories have is left to the picker (F3).
  """
  def head_named(state, {:category, id}, chosen), do: chosen.(state, id)

  def head_named(state, name, chosen) do
    case State.command(state, {:find_or_add_category, name}) do
      {:ok, state, %{new: id}} ->
        chosen.(state, id)

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

  @doc """
  The `editing:` option for `Template.render/3` while typing. A head's
  category name is typed in the control panel, as Agenda's
  (`Render.ControlPanel.entry/1`), so the box shows the head it has.
  """
  # (a new section's name in View Properties stays typed in its row)
  def editing(%{typing: {{:new_section, _}, _} = typing}), do: [editing: typing]

  def editing(%{typing: {field, line}} = mode) do
    # a category's field is typed on the control panel's second line
    if Agendum.TUI.Boxes.Box.category_field?(mode, field),
      do: [],
      else: [editing: {field, line}]
  end

  def editing(_mode), do: []
end
