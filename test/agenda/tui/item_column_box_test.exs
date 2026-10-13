defmodule Agenda.TUI.ItemColumnBoxTest do
  @moduledoc """
  Item Column Properties (View ▸ Column ▸ Properties on the item text;
  User's Guide 3-18 to 3-19, Help "Item Column Properties Box"): the
  section head, Set width (Automatically or Manually), Width or Minimum
  width, and Link with other sections (R55).
  """
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  import Agenda.Fixtures, only: [cat: 2, with_categories: 2]

  alias Agenda.Core
  alias Agenda.Core.Database
  alias Agenda.TUI.{History, State}

  # Calls and Follow up, each with When; the cursor on an item's text in
  # Calls, the box open. Its fields: Section head, Set width, Width or
  # Minimum width, Link with other sections.
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

  test "shows the section's item column, automatic at first", %{state: state} do
    assert %{type: :item_column} = State.mode(state)
    text = screen(state)
    assert text =~ "Item Column Properties"
    assert text =~ ~r/Section head: +Calls/
    assert text =~ ~r/Set width: +Automatically/
    assert text =~ ~r/Minimum width: +10/
    refute text =~ ~r/ Width: +\d/
    assert text =~ ~r/Link with other sections: +Yes/
  end

  test "Manually keeps the width it has, then → ← change it, in the linked sections too",
       %{state: state, view_id: v} do
    state = press(state, [:down, " "])
    # the screen is 100 wide: 3 for the bullet and margin, 17 for When
    assert items(state, v, 0).set == :manual
    assert items(state, v, 0).width == 80
    assert screen(state) =~ ~r/Width: +80/
    state = press(state, [:down, :left, :left])
    assert {items(state, v, 0).width, items(state, v, 1).width} == {78, 78}
    assert state |> History.undo() |> items(v, 0) |> Map.fetch!(:width) == 79
  end

  test "a narrow item column: the columns follow it, not the screen's edge",
       %{state: state} do
    # Manually, then 40 steps narrower: 40 wide
    state = press(state, [:down, " ", :down] ++ List.duplicate(:left, 40) ++ [:esc])
    # the section head line: a space, 41 for the name, a space, then When
    # (not at the screen's right edge, where an automatic one puts it)
    head = state |> screen() |> String.split("\n") |> Enum.find(&(&1 =~ "Calls"))
    assert :binary.match(head, "When") == {43, 4}
  end

  test "Minimum width, and unlinking: the section changes alone", %{state: state, view_id: v} do
    state = press(state, [:down, :down, :down, " ", :up, :right, :right])
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
