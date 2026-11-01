# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Moves.ItemReposition do
  @moduledoc """
  Item ▸ Reposition (R26a; User's Guide 13-4; checked in Agenda 2.0,
  2026-11-01): the highlighted item itself travels up and down its section.

    * ↑ / ↓ move it one place, never out of its section (at the top or the
      bottom it stays)
    * ENTER puts it down; ESC does too, as Agenda's ESC kept the new place
    * a sorted section, and one whose head has children, refuse it
      (`Agendum.Core.reposition_refused/3`), in Agenda's words

  Unlike moving a section (`Agendum.TUI.Moves.SectionMove`), each step
  changes the file at once, so the view shows the item where it is with
  nothing of its own; putting it down folds the steps into one undo step
  (`Agendum.TUI.History.squash/3`), as a settings box does. Pure.
  """

  alias Agendum.Core
  alias Agendum.TUI.{History, Keymap, Layout, Messages, State}

  @doc "Starts repositioning the highlighted item, or says why it cannot be."
  @spec open(State.t(), map) :: State.t()
  def open(state, %{kind: :item, item: item, sidx: sidx}) do
    case Core.reposition_refused(state.db, State.view(state), sidx) do
      nil ->
        State.push(state, %{
          type: :item_reposition,
          item_id: item.id,
          sidx: sidx,
          # the file and the undo steps as they were: putting it down
          # makes the steps since then one
          opened: %{
            db: state.db,
            view_id: state.view_id,
            cursor_key: state.cursor_key,
            undo: state.history.undo
          }
        })

      :sorted ->
        State.error(state, Messages.text(:reposition_sorted))

      :head_has_children ->
        State.error(state, Messages.text(:reposition_children))
    end
  end

  def open(state, _row), do: State.error(state, Messages.text(:not_on_item))

  @doc "A key while an item is repositioned: the command its keymap binds it to (R65)."
  def handle(state, mode, key) do
    case Keymap.lookup(:item_reposition, key) do
      nil -> state
      id -> command(state, mode, id)
    end
  end

  @doc "F1's text while repositioning an item (R65)."
  @spec about() :: String.t()
  def about do
    """
    You are repositioning the item within its section. ↑ and ↓ move it
    up and down; it does not leave the section.

    ENTER puts it down where it is, and so does ESC.
    """
  end

  @doc "Runs a command of repositioning an item (`Agendum.TUI.Commands`)."
  @spec run(State.t(), atom) :: State.t()
  def run(state, id), do: command(state, State.mode(state), id)

  defp command(state, mode, :up), do: step(state, mode, :before, -1)
  defp command(state, mode, :down), do: step(state, mode, :after, 1)
  defp command(state, mode, :keep), do: put_down(state, mode)
  defp command(state, mode, :close), do: put_down(state, mode)
  defp command(state, _mode, :help), do: Agendum.TUI.HelpScreen.open(state)

  # the item goes before the one above it, or after the one below it, among
  # the items its section shows; at either end there is none, and it stays
  defp step(state, mode, place, n) do
    ids = for row <- Layout.rows(state), row.kind == :item, row.sidx == mode.sidx, do: row.item.id
    at = Enum.find_index(ids, &(&1 == mode.item_id))
    neighbour = if at, do: Enum.at(ids, at + n)

    if neighbour && at + n >= 0 do
      category = Enum.at(State.view(state).sections, mode.sidx).category_id

      state
      |> State.run({:move_item, mode.item_id, category, category, [{place, neighbour}]})
      |> Map.put(:cursor_key, {:item, mode.sidx, mode.item_id})
      |> Layout.settle()
    else
      state
    end
  end

  # one undo step for the whole journey, or none when it came back to
  # where it was (a macro run is one step already)
  defp put_down(state, mode) do
    state
    |> State.pop()
    |> History.squash(mode.opened, state.macro.playing > 0)
  end

  @doc "The control panel's two lines while an item is repositioned: Agenda's."
  @spec panel() :: {String.t(), String.t()}
  def panel, do: {"Use up & down arrow keys to reposition the item.", "Press ENTER when done."}
end
