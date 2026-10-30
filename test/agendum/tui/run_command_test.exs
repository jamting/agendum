# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.RunCommandTest do
  @moduledoc "The TUI sends core commands (R66): `State.run/2,3`."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.TUI.State

  setup do
    %{state: start(Agendum.Sample.build(~D[2026-10-08]))}
  end

  test "a command runs on the file and can say so", %{state: state} do
    [id | _] = state.db.item_order
    next = State.run(state, {:toggle_mark, id}, "Marked")

    assert next.db.items[id].marked
    assert next.message == {:message, "Marked"}
  end

  test "a refused command leaves the file as it was and says why", %{state: state} do
    next = State.run(state, {:toggle_mark, 999_999}, "Marked")

    assert next.db == state.db
    assert next.message == {:error, "That item is no longer in the file"}
  end

  test "F7 marks the highlighted item through a command, and one undo unmarks it", %{
    state: state
  } do
    marked = press(state, [{:f, 7}])
    assert Agendum.Core.marked_items(marked.db) != []
    assert Agendum.Core.marked_items(press(marked, [{:ctrl, "z"}]).db) == []
  end
end
