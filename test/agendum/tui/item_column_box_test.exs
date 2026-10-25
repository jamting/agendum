defmodule Agendum.TUI.ItemColumnBoxTest do
  @moduledoc """
  Item Column Properties (View ▸ Column ▸ Properties on the item text;
  User's Guide 3-18 to 3-19, Help "Item Column Properties Box"): the
  section head, Set width (Automatically or Manually), Width or Minimum
  width, and Link with other sections (R55).
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  import Agendum.Fixtures, only: [cat: 2, with_categories: 2]

  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.TUI.{History, State}

  # Calls and Follow up, each with When; the cursor on an item's text in
  # Calls, the box open. Its fields: Section head, Width, Set width,
  # Minimum width (automatic only), Link with other sections.
  setup do
    db = Core.new_file(view_name: "Activities", section_name: "Calls")
    db = with_categories(db, ["Follow up"])
    [view] = Database.views(db)
    db = Core.add_section(db, view.id, cat(db, "Follow up"), 1)
    {db, _} = Core.add_item(db, "Call the plumber", ~D[2026-10-08], section: cat(db, "Calls"))
    state = db |> start() |> press([:down, {:f, 10}, "v", "c", "p"])
    %{state: state, view_id: view.id}
  end

  defp items(state, view_id, sidx),
    do: Enum.at(state.db.views[view_id].sections, sidx).item_column

  # Agenda's rows (checked in Agenda 2.0, 2026-10-25): Width, the width
  # now, above Set width; Minimum width only while it is automatic
  test "shows the section's item column, automatic at first", %{state: state} do
    assert %{type: :item_column} = State.mode(state)
    text = screen(state)
    assert text =~ "Item Column Properties"
    assert text =~ ~r/Section head: +Calls/
    # the screen is 100 wide: 6 before the text, 17 for When
    assert text =~ ~r/Width: +77[^\n]*\n[^\n]*Set width: +Automatically/
    assert text =~ ~r/Minimum width: +10/
    assert text =~ ~r/Link with other sections: +Yes/
  end

  test "a typed width sets it by hand, in the linked sections too, as Agenda's",
       %{state: state, view_id: v} do
    state = state |> to_setting("Width") |> press(["7", "8", :enter])
    assert items(state, v, 0).set == :manual
    assert {items(state, v, 0).width, items(state, v, 1).width} == {78, 78}
    text = screen(state)
    assert text =~ ~r/Set width: +Manually/
    refute text =~ "Minimum width"
    assert state |> History.undo() |> items(v, 0) |> Map.fetch!(:set) == :auto
  end

  test "Manually keeps the width it has", %{state: state, view_id: v} do
    state = state |> to_setting("Set width") |> press(" ")
    assert items(state, v, 0).set == :manual
    assert items(state, v, 0).width == 77
    assert screen(state) =~ ~r/Width: +77/
  end

  test "a narrow item column: the columns follow it, not the screen's edge",
       %{state: state} do
    # 40 wide (typed; ENTER keeps the width, ENTER again the box)
    state = state |> to_setting("Width") |> press(["4", "0", :enter, :enter])
    # "    •♦", 40 for the text, a space: When starts at 47, as its entries
    # do (not at the screen's right edge, where an automatic one puts it)
    head = state |> screen() |> String.split("\n") |> Enum.find(&(&1 =~ "Calls"))
    assert :binary.match(head, "When") == {47, 4}
  end

  test "Minimum width, and unlinking: the section changes alone", %{state: state, view_id: v} do
    state = state |> to_setting("Link with other sections") |> press(" ")
    state = state |> to_setting("Minimum width") |> press(["1", "2", :enter])
    assert items(state, v, 0).linked == false
    assert {items(state, v, 0).minimum, items(state, v, 1).minimum} == {12, 10}
    assert screen(state) =~ ~r/Link with other sections: +No/
  end

  test "F3 on Section head picks another category", %{state: state, view_id: v} do
    state = press(state, [{:f, 3}, "f", "o", :enter])
    assert hd(state.db.views[v].sections).category_id == cat(state.db, "Follow up")
    assert screen(state) =~ ~r/Section head: +Follow up/
  end
end
