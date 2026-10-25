defmodule Agendum.TUI.Boxes.BoxEdit do
  @moduledoc """
  F2 (EDIT) in a settings box, as in Agenda (User's Guide 2-17: "Press F2
  (EDIT) to edit the existing choice for the setting"; checked in Agenda
  2.0, 2026-10-25): on a setting you type (a name, a number, a category)
  it starts typing with the text the setting has, the cursor after it; on
  a "..." setting it opens its box, as SPACE does; on a list of choices it
  does nothing. A box that binds F2 itself (View Properties, Item
  Properties …) keeps its own.

  Rather than each box saying how its typing starts, the setting's text is
  typed into the box as if by hand: the first character starts the typing
  as it always does there, and the rest follow. Pure.
  """

  alias Agendum.TUI.Boxes.{Box, BoxChoices}
  alias Agendum.TUI.Render.Boxes
  alias Agendum.TUI.{State, Update}

  @doc "F2 on the box on top; `:pass` where the box takes it itself."
  @spec key(State.t()) :: State.t() | :pass
  def key(state) do
    mode = State.mode(state)
    box = Box.module!(mode)

    cond do
      box.typing?(state, mode) or Map.has_key?(box.keymap(mode), {:f, 2}) -> :pass
      not Box.settings?(box, mode) -> :pass
      true -> edit(state, String.trim(Boxes.selected_value(state)))
    end
  end

  defp edit(state, "..."), do: Update.box_key(state, {:char, " "})

  defp edit(state, text) do
    cond do
      # a list of choices: nothing to edit, as Agenda's
      BoxChoices.choices(state) != [] -> state
      # nothing to type, or a value shown cut short or as a placeholder
      # ("(none)"), which typed back would not be the setting's text
      text == "" or String.ends_with?(text, "…") or String.starts_with?(text, "(") -> state
      true -> type(state, text)
    end
  end

  # the text typed character by character; when the first one starts no
  # typing in the box, F2 does nothing there
  defp type(state, text) do
    [first | rest] = String.graphemes(text)
    started = Update.box_key(state, {:char, first})

    if typing?(started) do
      started = without_completion(started)
      Enum.reduce(rest, started, &Update.box_key(&2, {:char, &1}))
    else
      state
    end
  end

  # F2 edits a category's name as it is, without completion, as Agenda's
  # EDIT (checked in Agenda 2.0, 2026-10-25): `Typing.Completion`
  defp without_completion(state) do
    case State.mode(state) do
      %{choice: _} = mode -> State.put_mode(state, %{mode | choice: :off})
      _ -> state
    end
  end

  defp typing?(state), do: state.edit != nil or Map.get(State.mode(state) || %{}, :typing) != nil
end
