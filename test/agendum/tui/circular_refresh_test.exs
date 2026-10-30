# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.CircularRefreshTest do
  @moduledoc """
  Agenda's o (R37): the items caught in a circular reference are worked
  out again after a key that changed them, and a key may change an item
  only by making one of its assignments conditional (found by the fuzz
  walk, 2026-10-27: SPACE in the item's profile left the o off).
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.TUI.State

  # the circular items as worked out afresh, from the whole file
  defp fresh(state),
    do: MapSet.new(Agendum.Core.circular_items(state.db, State.context(state)))

  test "an assignment made conditional again marks its item as caught" do
    # Ed, under Folk, if not in Folk: an item in Ed can never settle
    db = Agendum.Sample.build(~D[2026-10-08])
    {:ok, db, folk} = Agendum.Core.add_category(db, db.main_id, "Folk")
    {:ok, db, ed} = Agendum.Core.add_category(db, folk, "Ed")
    {:ok, db} = Agendum.Core.add_condition(db, ed, folk, :not_assigned)
    state = start(db, width: 68, height: 25)

    # the last item's profile, the highlight on Ed; F7 takes it out of
    # the circle, and SPACE puts it back in, changing only whether its
    # assignment is conditional
    state = press(state, [:ctrl_end, {:f, 3}, :pgdn, {:f, 7}])
    item = State.mode(state).item_id
    refute MapSet.member?(state.circular, item)

    before = state.db
    state = press(state, {:char, " "})
    assert state.db.links == before.links
    assert MapSet.member?(state.db.conditional, {item, ed})

    assert state.circular == fresh(state)
    assert MapSet.member?(state.circular, item)
  end
end
