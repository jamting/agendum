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
  with Agendum's keys. A box without help leaves the control panel as it
  was. Pure.
  """

  alias Agendum.TUI.Boxes.Box
  alias Agendum.TUI.State

  @registered Box.registry()

  # Help for boxes that are lists: the same whatever is highlighted
  @lists %{
    calendars:
      "Your calendar subscriptions. ENTER reads one now, F sets how often, " <>
        "A how far ahead; INS adds one, DEL removes it.",
    copy_items:
      "Highlight the section to copy the item to and press ENTER; " <>
        "it stays in its other sections.",
    choice_list: "Highlight the choice and press ENTER.",
    viewmgr:
      "To display a view, highlight the view name and press ENTER. " <>
        "Press INS to create a new view.",
    confirm: "Y or N answers. SPACE switches the answer; ENTER accepts the one shown.",
    questions:
      "Pick the categories to assign the item to: SPACE one, TAB all. " <>
        "ENTER assigns them and shows the next item.",
    alarm_list:
      "The items with alarms, and today's alarms that have gone off. " <>
        "DEL removes a past alarm, ALT-A cancels a current one.",
    calendar:
      "Move the highlight to a date and press ENTER. PGUP/PGDN for another month; " <>
        "type a date to go there; F6 adds a time."
  }

  @doc "The help for the highlighted field of the box on top, or nil."
  @spec text(State.t()) :: String.t() | nil
  def text(state) do
    mode = State.mode(state)

    case mode do
      nil ->
        nil

      %{type: type} when is_map_key(@registered, type) ->
        Box.help_text(@registered[type], state, mode)

      %{type: type} ->
        @lists[type]
    end
  end

  @doc "Every help text, for the tests."
  @spec all() :: [String.t()]
  def all, do: Map.values(@lists) ++ Enum.flat_map(Map.values(@registered), &Box.help_texts/1)

  @doc "The box types with help for each field, with their modules, for the tests."
  @spec boxes() :: %{atom => module}
  def boxes, do: for({type, box} <- @registered, is_map(box.help()), into: %{}, do: {type, box})
end
