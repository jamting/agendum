# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.SectionSelectTest do
  @moduledoc """
  View Properties ▸ Sections ▸ F3: Agenda's Section Select (User's Guide
  9-8, 9-11; checked in Agenda 2.0, 2026-10-25; the owner's choice): the
  hierarchy with * on the view's section heads; SPACE (F7 INCLCAT) makes a
  category a section or not, F5 (CHLDRN) a parent's children instead of
  the parent, F4 (CLRCATS) none; ENTER or ESC go back keeping it, as every
  category list (R81b). A view left without sections is refused on ENTER,
  with Agenda's error.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Starters.Planner
  alias Agendum.TUI.{CategoryScreens, Layout, State}

  @today ~D[2026-10-12]

  setup do
    db = Planner.build() |> Planner.with_samples(@today)
    state = start(db, today: @today, height: 30, width: 80)
    people = Enum.find(Map.values(state.db.views), &(&1.name == "People"))
    state = state |> State.switch_view(people.id) |> Layout.settle()
    %{state: state, list: state |> props(:view) |> press([:right, {:f, 3}]), view: people.id}
  end

  defp heads(state, view),
    do: Enum.map(state.db.views[view].sections, &state.db.categories[&1.category_id].name)

  # the highlight on the category named `name`
  defp to(state, name) do
    mode = State.mode(state)
    rows = CategoryScreens.rows(state, mode)
    at = Enum.find_index(rows, fn {id, _} -> state.db.categories[id].name == name end)
    keys = if at > mode.cursor, do: :down, else: :up
    press(state, List.duplicate(keys, abs(at - mode.cursor)))
  end

  test "Section Select: the view named, its section heads starred", %{list: list} do
    text = screen(list)
    assert text =~ "Section Select"
    assert text =~ "Current View: People"
    assert text =~ ~r/\* +Anna Berg/
    assert text =~ "Highlight each category for the section head(s) and press SPACE BAR."
    # Agenda's bar there, F2 Edit aside
    bar =
      text |> String.split("\n") |> List.last() |> String.split("│") |> Enum.map(&String.trim/1)

    assert Enum.slice(bar, 3..6) == ["ClrCats", "Chldrn", "Props", "InclCat"]
  end

  test "SPACE makes a category a section, and again not", %{list: list, view: v} do
    added = list |> to("Calls") |> press(" ")
    assert "Calls" in heads(added, v)
    removed = press(added, " ")
    refute "Calls" in heads(removed, v)
  end

  test "F7 (INCLCAT) is SPACE", %{list: list, view: v} do
    assert "Calls" in heads(list |> to("Calls") |> press({:f, 7}), v)
  end

  test "F5 (CHLDRN): a parent's children instead of the parent", %{list: list, view: v} do
    done = list |> to("Priority") |> press({:f, 5})
    assert ["High", "Medium", "Low"] -- heads(done, v) == []
    refute "Priority" in heads(done, v)
  end

  test "F4 (CLRCATS) takes every section away; ENTER on the box is then refused",
       %{list: list, view: v} do
    cleared = press(list, {:f, 4})
    assert heads(cleared, v) == []
    back = press(cleared, :enter)
    assert %{type: :view_props} = State.mode(back)
    refused = press(back, :enter)
    assert screen(refused) =~ "Every view must have at least one section."
    assert %{type: :view_props} = State.mode(refused)
    # with no sections left, the highlight is on Filter, the setting
    # nearest the empty list (the review of group g, 2026-10-31: the keys
    # on a section that was gone crashed)
    assert %{type: :picker, purpose: {:filter, :view}} = refused |> press(" ") |> State.mode()
  end

  test "ESC keeps what was chosen, as every category list", %{list: list, view: v} do
    back = list |> to("Calls") |> press([" ", :esc])
    assert %{type: :view_props} = State.mode(back)
    assert "Calls" in heads(back, v)
  end
end
