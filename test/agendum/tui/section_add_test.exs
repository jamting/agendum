# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.SectionAddTest do
  @moduledoc """
  The Section Add box (View ▸ Section ▸ Add; Agenda's, checked in Agenda
  2.0, 2026-10-24; User's Guide 5-5 to 5-10): the Section Properties box
  left blank, with Insert, Below current section (the default) or Above.
  The section is added when its head is typed or picked, and the box goes
  on as its settings; ESC takes it all back, the new section included.
  ALT-D and ALT-U keep the quick picker.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Core.Database
  alias Agendum.Starters.Planner
  alias Agendum.TUI.State

  @today ~D[2026-10-12]

  # the Planner's Activities view, the cursor on its first section's head
  setup do
    db = Planner.build() |> Planner.with_samples(@today)
    view = Enum.find(Database.views(db), &(&1.name == "Activities"))
    state = db |> start(today: @today, width: 100, height: 40) |> State.switch_view(view.id)
    %{state: state, view: view.id}
  end

  defp add_box(state), do: press(state, [{:f, 10}, "v", "s", "a"])

  defp heads(state, view),
    do: Enum.map(state.db.views[view].sections, &state.db.categories[&1.category_id].name)

  test "it opens blank, with Insert: Below current section", %{state: state} do
    box = add_box(state)
    text = screen(box)
    assert text =~ "Section Add"
    assert text =~ ~r/Section head +: +│/u
    assert text =~ ~r/Insert +: Below current section/
    refute text =~ "Item sorting"
    assert box.db == state.db
  end

  test "a typed head adds the section below; the box goes on with its settings",
       %{state: state, view: view} do
    [first | _] = heads(state, view)
    added = state |> add_box() |> press(["Errands", :enter])
    assert Enum.take(heads(added, view), 2) == [first, "Errands"]
    assert screen(added) =~ ~r/Item sorting +: /
    assert screen(added) =~ "Section Add"

    kept = press(added, :enter)
    assert State.mode(kept) == nil
    assert Enum.take(heads(kept, view), 2) == [first, "Errands"]
  end

  test "Insert switched to Above, before or after the head, puts it above",
       %{state: state, view: view} do
    [first | _] = heads(state, view)
    before = state |> add_box() |> to_setting("Insert") |> press(" ")
    assert screen(before) =~ ~r/Insert +: Above current section/
    above = before |> to_setting("Section head") |> press(["Errands", :enter])
    assert Enum.take(heads(above, view), 2) == ["Errands", first]

    after_head =
      state |> add_box() |> press(["Errands", :enter]) |> to_setting("Insert") |> press(" ")

    assert Enum.take(heads(after_head, view), 2) == ["Errands", first]
  end

  test "ESC takes it all back, the new section included", %{state: state} do
    cancelled = state |> add_box() |> press(["Errands", :enter, :esc])
    # back in the menu it was opened from, as ESC steps back there
    assert %{type: :menu} = State.mode(cancelled)
    assert cancelled.db.views == state.db.views
  end

  test "ENTER with no head yet adds nothing and says what is needed", %{state: state} do
    box = state |> add_box() |> press(:enter)
    assert %{type: :section_props} = State.mode(box)
    assert {:error, _} = box.message
    assert box.db == state.db
  end

  test "F3 on the head picks it", %{state: state, view: view} do
    picker = state |> add_box() |> press({:f, 3})
    assert screen(picker) =~ "Calls"
    picked = press(picker, [:ctrl_home | String.graphemes("Calls")] ++ [:enter])
    assert "Calls" in heads(picked, view)
    assert screen(picked) =~ ~r/Section head +: Calls/
  end

  test "ALT-D still opens the quick picker", %{state: state} do
    assert screen(press(state, {:alt, "d"})) =~ "Section head"
    refute screen(press(state, {:alt, "d"})) =~ "Section Add"
  end
end
