defmodule Agenda.TUI.HideColumnHeadsTest do
  @moduledoc """
  Hide column heads (R57; User's Guide 5-14 to 5-15, 15-21; screenshots
  55, 67, 69, 71, 143): column heads only on the first section head on
  the screen, so the same heads do not repeat in every section.
  """
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  import Agenda.Fixtures, only: [cat: 2, with_categories: 2]

  alias Agenda.Core
  alias Agenda.Core.Database
  alias Agenda.TUI.{History, State}

  # Calls, Follow up and Errands, each with a linked People column and an
  # item; the cursor on Calls.
  setup do
    db = Core.new_file(view_name: "Activities", section_name: "Calls")
    db = with_categories(db, ["Follow up", "Errands", "People"])
    [view] = Database.views(db)
    db = Core.add_section(db, view.id, cat(db, "Follow up"), 1)
    db = Core.add_section(db, view.id, cat(db, "Errands"), 2)
    db = Core.add_column(db, view.id, cat(db, "People"), {0, 0}, 12)

    db =
      Enum.reduce(["Calls", "Follow up", "Errands"], db, fn section, db ->
        {db, _} = Core.add_item(db, "In #{section}", ~D[2026-10-08], section: cat(db, section))
        db
      end)

    %{state: start(db), view_id: view.id}
  end

  defp heads(state), do: Regex.scan(~r/People/, screen(state)) |> length()

  defp hide(state), do: press(state, [{:f, 10}, "v", "h", "c"])

  test "off by default: every section shows its column heads", %{state: state, view_id: v} do
    refute state.db.views[v].hide_column_heads
    assert heads(state) == 3
  end

  test "View ▸ Hide ▸ Column heads: only the first section shows them; again shows them all",
       %{state: state, view_id: v} do
    state = hide(state)
    assert state.db.views[v].hide_column_heads
    assert heads(state) == 1
    assert screen(state) =~ ~r/Calls +People/
    assert screen(state) =~ "Follow up"

    state = hide(state)
    assert heads(state) == 3
  end

  test "one undo step", %{state: state, view_id: v} do
    state = hide(state)
    refute History.undo(state).db.views[v].hide_column_heads
  end

  test "the first section on the screen shows them when the view is scrolled",
       %{view_id: v} = context do
    # 5 lines of view: Calls is scrolled off once the cursor is on Errands
    state = %{context.state | height: 9} |> hide()
    state = press(state, [:down, :down, :down, :down, :down])
    assert State.view(state).id == v
    refute screen(state) =~ "Calls"
    assert screen(state) =~ ~r/Follow up +People/
    assert heads(state) == 1
  end

  test "a section head whose column head is highlighted shows its heads",
       %{state: state} do
    # Follow up's head, then → to its People head
    state = state |> hide() |> press([:down, :down, :right])
    assert screen(state) =~ ~r/Follow up +People/
    assert heads(state) == 2
  end
end
