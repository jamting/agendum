# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.ItemRepositionTest do
  @moduledoc """
  Item ▸ Reposition (R26a; checked in Agenda 2.0, 2026-11-01): the item
  itself travels up and down its section with ↑ ↓, never leaving it, and
  ENTER or ESC puts it down: one undo step. Refused in a sorted section and
  under a section head with children, with Agenda's words.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Core
  alias Agendum.TUI.{History, Layout, Messages, State}

  # Alpha, Beta and Gamma in the Initial Section, the highlight on Gamma
  setup do
    db = Core.new_file()
    section = hd(Core.Database.views(db)).sections |> hd() |> Map.fetch!(:category_id)

    db =
      Enum.reduce(~w(Alpha Beta Gamma), db, fn text, db ->
        {db, _} = Core.add_item(db, text, ~D[2026-11-01], section: section)
        db
      end)

    state = start(db)
    %{state: on(state, "Gamma"), section: section}
  end

  defp on(state, text) do
    index =
      state |> Layout.rows() |> Enum.find_index(&(&1.kind == :item and &1.item.text == text))

    Layout.move_to(state, index)
  end

  defp reposition(state), do: press(state, [{:f, 10}, "i", "r"])

  # the items' texts in the order the screen shows them
  defp order(state) do
    for row <- Layout.rows(state), row.kind == :item, do: row.item.text
  end

  test "↑ carries the item up its section, and stops at the top", %{state: state} do
    state = reposition(state)
    assert panel(state) =~ "Use up & down arrow keys to reposition the item."
    assert panel(state) =~ "Press ENTER when done."

    state = press(state, :up)
    assert order(state) == ~w(Alpha Gamma Beta)
    state = press(state, [:up, :up])
    assert order(state) == ~w(Gamma Alpha Beta)
    assert Layout.current_row(state).item.text == "Gamma"
  end

  test "ENTER puts it down: one undo step takes it back", %{state: state} do
    state = state |> reposition() |> press([:up, :up, :enter])
    assert State.mode(state) == nil
    assert order(state) == ~w(Gamma Alpha Beta)
    assert Layout.current_row(state).item.text == "Gamma"

    assert order(History.undo(state)) == ~w(Alpha Beta Gamma)
  end

  test "ESC puts it down where it is too, as Agenda's", %{state: state} do
    state = state |> on("Alpha") |> reposition() |> press([:down, :esc])
    assert State.mode(state) == nil
    assert order(state) == ~w(Beta Alpha Gamma)
  end

  test "↓ at the bottom leaves it there, never in the next section", %{state: state} do
    state = state |> reposition() |> press([:down, :enter])
    assert order(state) == ~w(Alpha Beta Gamma)
    # nothing changed, so nothing to undo
    assert state.history.undo == []
  end

  test "a sorted section refuses, in Agenda's words", %{state: state} do
    view = State.view(state)
    sort = [%Core.View.SortKey{on: :text}]
    state = put_in(state.db.views[view.id].sort, sort) |> reposition()

    assert State.mode(state) == nil
    assert panel(state) =~ "Items in this section are sorted automatically"
  end

  test "a section head with children refuses, in Agenda's words", %{state: state, section: s} do
    {:ok, db, _child} = Core.add_category(state.db, s, "Little one")
    state = %{state | db: db} |> on("Gamma") |> reposition()

    assert State.mode(state) == nil
    assert panel(state) =~ Messages.text(:reposition_children)
  end

  test "on a section head it asks for an item", %{state: state} do
    state = state |> Layout.move_to(0) |> reposition()
    assert State.mode(state) == nil
    assert panel(state) =~ "The highlight isn't on an item"
  end
end
