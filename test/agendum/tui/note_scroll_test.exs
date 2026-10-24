defmodule Agendum.TUI.NoteScrollTest do
  @moduledoc """
  Scrolling in a note longer than the screen: the note scrolls only when
  the cursor would leave it, as in any editor. Moving up from the bottom
  moves the cursor up the screen; the rows shown stay until the cursor
  reaches the top row.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.TUI.{Layout, State}

  # 40 lines, "line 01" to "line 40"; 24 rows high, the note shows 21 (the
  # control panel and the key bar take 3)
  @note Enum.map_join(1..40, "\n", &"line #{String.pad_leading(Integer.to_string(&1), 2, "0")}")

  setup do
    state = start(Agendum.Sample.build(~D[2026-10-08]), height: 25) |> press(:down)
    item = Layout.current_row(state).item
    state = %{state | db: Core.set_note(state.db, item.id, @note, state.today)}
    %{state: press(state, {:f, 5})}
  end

  defp row(state), do: State.mode(state).edit.row
  defp shown?(state, text), do: screen(state) =~ text

  test "the note opens at its end, the last rows shown", %{state: state} do
    assert row(state) == 39
    assert shown?(state, "line 40")
    refute shown?(state, "line 19")
  end

  test "↑ from the bottom moves the cursor up, not the note", %{state: state} do
    state = press(state, :up)
    assert row(state) == 38
    assert shown?(state, "line 40")

    # up to the top row shown: the same rows stay
    state = press(state, List.duplicate(:up, 19))
    assert row(state) == 19
    assert shown?(state, "line 40")
    assert shown?(state, "line 20")

    # one more: the note scrolls by one row
    state = press(state, :up)
    assert row(state) == 18
    assert shown?(state, "line 19")
    refute shown?(state, "line 40")
    assert shown?(state, "line 39")
  end

  test "↓ again after going up does not scroll until the bottom", %{state: state} do
    state = press(state, List.duplicate(:up, 39))
    assert row(state) == 0
    assert shown?(state, "line 01")

    state = press(state, List.duplicate(:down, 20))
    assert shown?(state, "line 01")
    assert shown?(state, "line 21")

    state = press(state, :down)
    refute shown?(state, "line 01")
    assert shown?(state, "line 22")
  end
end
