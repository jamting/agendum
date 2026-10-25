defmodule Agendum.TUI.Boxes.BoxDefaults do
  @moduledoc """
  F8 (DEFAULT) and ALT-F8 (DFLTALL) in a settings box, as in Agenda (User's
  Guide 2-17; checked in Agenda 2.0, 2026-10-24): F8 puts the highlighted
  setting back to its default, ALT-F8 every setting of the box. A box says
  which fields have a default and how to put each back (`c:Agendum.TUI.
  Boxes.Box.defaults/2`); the default is what something new gets, or what
  File Properties says where it says (a date column's format). A setting
  without one is left as it is: a name, a list, without a word, as Agenda
  does (checked in Agenda 2.0, 2026-10-25; the owner's choice). Like any
  change in a box it shows in the box, and applies on ENTER (ADR 0030).
  Pure.
  """

  alias Agendum.TUI.Boxes.Box
  alias Agendum.TUI.State

  @doc "F8 or ALT-F8 (`:default`, `:default_all`) on the box on top; `:pass` where they do nothing."
  @spec key(State.t(), :default | :default_all) :: State.t() | :pass
  def key(state, id) do
    mode = State.mode(state)
    box = Box.module!(mode)
    defaults = box.defaults(state, mode)

    cond do
      box.typing?(state, mode) or not Box.settings?(box, mode) ->
        :pass

      defaults == %{} ->
        state

      id == :default_all ->
        Enum.reduce(defaults, state, fn {_field, back}, state -> back.(state) end)

      true ->
        default(state, defaults, box.field(state, mode))
    end
  end

  defp default(state, defaults, field) do
    case defaults do
      %{^field => back} -> back.(state)
      _ -> state
    end
  end
end
