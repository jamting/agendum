# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Boxes.FieldHelp do
  @moduledoc """
  Help for the highlighted field of a box, shown in the control panel
  while the box is open, as Agenda did (screenshots 130 to 143: "Enter a
  short description of the file. Press F2 to edit."). What a setting
  does, then the keys that change it.

  A box module (`Agendum.TUI.Boxes.Box`) keeps its help and says which field
  is highlighted (`help/0`, `field/2`); the tests check every text here
  together: each fits the control panel's two lines at 80 columns. The
  texts follow Agenda's help (its F1 help's SETTING/DESCRIPTION tables),
  with Agendum's keys. A box without help leaves the control panel's two
  lines blank, as the box has them to itself. Pure.
  """

  alias Agendum.TUI.Boxes.Box
  alias Agendum.TUI.State

  @registered Box.registry()

  @doc "The help for the highlighted field of the box on top, or nil."
  @spec text(State.t()) :: String.t() | nil
  def text(state) do
    mode = State.mode(state)

    case Box.module(mode) do
      nil -> nil
      box -> Box.help_text(box, state, mode)
    end
  end

  @doc "Every help text, for the tests."
  @spec all() :: [String.t()]
  def all, do: Enum.flat_map(Map.values(@registered), &Box.help_texts/1)

  @doc "The box types with help for each field, with their modules, for the tests."
  @spec boxes() :: %{atom => module}
  def boxes, do: for({type, box} <- @registered, is_map(box.help()), into: %{}, do: {type, box})
end
