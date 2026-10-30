# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.ShowViewTest do
  @moduledoc """
  Utilities ▸ Show ▸ ItemsDone and Every (User's Guide 13-9, 13-21; checked
  in Agenda 2.0, 2026-10-25): the *Show View* with the done items under a
  section called *Show*, or every item under MAIN.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core.Database

  setup do
    %{state: start(Agendum.Sample.build(~D[2026-10-08]), width: 80, height: 25)}
  end

  defp items(state),
    do: for(%{kind: :item, item: item} <- Agendum.TUI.Layout.rows(state), do: item.text)

  test "ItemsDone shows the done items under *Show*", %{state: state} do
    state = press(state, [:down, {:f, 4}])
    done = Agendum.TUI.Layout.current_row(state).item.text

    state = press(state, [{:f, 10}, "u", "s", "i"])
    assert screen(state) =~ "View: *Show View*"
    assert screen(state) =~ ~r/^ \*Show\*/m
    assert items(state) == [done]
  end

  test "Every shows every item under MAIN, after Agenda's question", %{state: state} do
    state = press(state, [{:f, 10}, "u", "s", "i"])
    state = press(state, [{:f, 10}, "u", "s", "e"])
    assert screen(state) =~ "Delete the existing Show view?"

    state = press(state, :enter)
    assert screen(state) =~ ~r/^ MAIN/m
    assert length(items(state)) == length(Database.items(state.db))
  end

  # Show Circular (User's Guide 20-21; checked in Agenda 2.0, 2026-10-26):
  # !Circular Reference!, empty when nothing is caught
  test "Circular shows the items caught in a circular reference", %{state: state} do
    state = press(state, [{:f, 10}, "u", "s", "c"])
    assert screen(state) =~ "View: *Show View*"
    assert screen(state) =~ ~r/^ !Circular Reference!/m
    assert items(state) == []
  end
end
