# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.HopTest do
  @moduledoc """
  ALT-H, hop to the next occurrence of the highlighted item (R42; User's
  Guide 13-9; Help: "Hop to next occurrence of item in current or next
  view"): further down this view, else in the next view that shows it.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Core.Database
  alias Agendum.Starters.Planner
  alias Agendum.TUI.{Layout, State}

  @today ~D[2026-10-12]

  setup do
    db = Planner.build() |> Planner.with_samples(@today)
    %{state: start(db, today: @today, height: 60)}
  end

  defp in_view(state, name),
    do: State.switch_view(state, Enum.find(Database.views(state.db), &(&1.name == name)).id)

  defp to_item(state, text) do
    index = Enum.find_index(Layout.rows(state), &(&1.kind == :item and &1.item.text == text))
    Layout.move_to(state, index)
  end

  defp at(state), do: {State.view(state).name, Layout.current_row(state)}

  test "further down the same view: the item in its next section", %{state: state} do
    state = state |> in_view("People") |> to_item("Weekly status meeting")
    {"People", first} = at(state)
    assert first.category.name == "Anna Berg"

    state = press(state, {:alt, "h"})

    assert {"People",
            %{item: %{text: "Weekly status meeting"}, category: %{name: "Maria Svensson"}}} =
             at(state)
  end

  test "else the next view that shows it, by the view manager's order", %{state: state} do
    text = "Call Anna Berg about the hosting contract"
    state = state |> to_item(text) |> press({:alt, "h"})
    assert {"Activities", %{item: %{text: ^text}}} = at(state)
    assert panel(state) =~ "In view Activities"
    assert {"Calls", %{item: %{text: ^text}}} = at(press(state, {:alt, "h"}))
  end

  test "the views wrap around; an item shown once has no other occurrence", %{state: state} do
    # Tomorrow is the last view: from there the hop goes round to Tasks
    text = "Design review with David Chen"
    state = state |> in_view("Tomorrow") |> to_item(text) |> press({:alt, "h"})
    assert {"Tasks", %{item: %{text: ^text}}} = at(state)

    # a blank contact item: only in Contacts
    state = state |> in_view("Contacts") |> press([:down, {:alt, "h"}])
    assert panel(state) =~ "No other occurrence"
    assert State.view(state).name == "Contacts"
  end

  test "on a section head there is no item to hop from", %{state: state} do
    assert state |> press({:alt, "h"}) |> panel() =~ "Highlight an item"
  end
end
