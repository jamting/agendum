defmodule Agendum.TUI.RecurringTest do
  @moduledoc "Recurring items in the TUI (R14a)."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core.Database
  alias Agendum.TUI.Layout

  # Thursday 2026-10-08; the new item goes to the top of the Calls section
  setup do
    state = start(Agendum.Sample.build(~D[2026-10-08]))
    %{state: press(state, ["Status meeting every Monday", :enter])}
  end

  defp meetings(state),
    do: Enum.filter(Database.items(state.db), &(&1.text == "Status meeting every Monday"))

  test "F4 on a recurring item marks it done and says when the next one is", %{state: state} do
    state = press(state, {:f, 4})
    assert [done, next] = meetings(state)
    assert done.done == ~D[2026-10-08]
    assert next.when == ~D[2026-10-19]
    assert screen(state) =~ "Done · the next one is on 2026-10-19"
    # one undo takes back both
    state = press(state, {:ctrl, "z"})
    assert [only] = meetings(state)
    assert only.done == nil
  end

  test "Item Properties shows the rule beside the When date", %{state: state} do
    assert Layout.current_row(state).item.text == "Status meeting every Monday"
    assert screen(press(state, {:f, 6})) =~ "When (2026-10-12) · every Monday"
  end
end
