# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Extras.ZettelLinksTest do
  @moduledoc "Links between zettels in the TUI (R73b)."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.TUI.{Layout, Render, State}

  # Initial Section: "Owl's birthday" (bonalaku), "The party" (pigavono),
  # "Plan: see pigavono and [[kitolido]]"
  setup do
    db = Core.new_file()
    {db, owl} = Core.add_item(db, "Owl's birthday", ~D[2026-10-08], section: section(db))
    {db, party} = Core.add_item(db, "The party", ~D[2026-10-08], section: section(db))

    {db, plan} =
      Core.add_item(db, "Plan: see pigavono and [[kitolido]]", ~D[2026-10-08],
        section: section(db)
      )

    {:ok, db, _} = Core.attach_zettels(db, [owl, party])
    %{state: start(db, extras: true), owl: owl, party: party, plan: plan}
  end

  defp section(db), do: hd(Database.find_categories(db, "Initial Section"))
  defp current(state), do: Layout.current_row(state).item
  defp styled(state), do: state |> Render.render() |> List.flatten()

  # a command without a key, from F1 c: type its name, ENTER runs it
  defp run_by_name(state, name),
    do: press(state, [{:f, 1}, {:f, 6}, :enter] ++ String.graphemes(name) ++ [:enter])

  test "links show in the link colour, a broken one in its own", %{state: state} do
    segments = styled(state)
    assert {:link, "pigavono"} in segments
    assert {:link_broken, "[[kitolido]]"} in segments
    # an id nobody links to is not coloured where it is not written
    refute Enum.any?(segments, &match?({:link, "bonalaku"}, &1))
  end

  test "Follow shows the items an item links to in the Show View; ALT-F8 back",
       %{state: state, party: party} do
    state = state |> press([:down, :down, :down]) |> press([{:f, 10}, "i", "z", "f"])
    assert State.view(state).name == "*Show View*"
    assert screen(state) =~ "1 linked item · ALT-F8 returns to the last view"
    assert screen(state) =~ "The party"
    refute screen(state) =~ "Owl's birthday"
    assert Enum.map(Layout.rows(state), & &1.kind) |> Enum.count(&(&1 == :item)) == 1
    assert current(press(state, :down)).id == party
    assert State.view(press(state, {:alt_f, 8})).name == "Initial View"
  end

  test "Linked from shows the items that link to the item", %{state: state} do
    state = state |> press([:down, :down]) |> press([{:f, 10}, "i", "z", "l"])
    assert screen(state) =~ "1 item linking here"
    assert screen(state) =~ "Plan: see pigavono"
  end

  test "Follow and Linked from say why when there is nothing to show", %{state: state} do
    assert screen(state |> press(:down) |> press([{:f, 10}, "i", "z", "f"])) =~
             "This item has no links to other items"

    assert screen(state |> press([:down, :down, :down]) |> press([{:f, 10}, "i", "z", "l"])) =~
             "The item has no Zettel id, so nothing can link to it"
  end

  test "Item Properties shows the id and lists the items linking here", %{state: state} do
    state = state |> press([:down, :down, {:f, 6}])
    assert screen(state) =~ ~r/Item statistics:\s+pigavono · 2 categories/
    assert screen(state) =~ ~r/Linked from:\s*Plan: see pigavono/
  end

  test "in a note, the marked item's link is typed, and the panel says what it is",
       %{state: state, plan: plan} do
    # mark Owl's birthday, open the plan's note
    state = state |> press([:down, {:f, 7}, :down, :down, {:f, 5}])
    state = run_by_name(state, "insert link")
    assert hd(State.mode(state).edit.lines) == "[[bonalaku]]"
    assert screen(press(state, :left)) =~ "→ bonalaku: Owl's birthday"

    state = press(state, {:f, 5})
    assert state.db.items[plan].note == "[[bonalaku]]"
  end

  test "Insert link with nothing marked says what to do", %{state: state} do
    state = state |> press([:down, {:f, 5}]) |> run_by_name("insert link")
    assert screen(state) =~ "Mark the items to link to with F7 first"
  end

  test "CTRL-G follows, CTRL-R shows what links here, CTRL-L links in a note", %{state: state} do
    assert screen(press(state, [:down, :down, :down, {:ctrl, "g"}])) =~ "1 linked item"
    assert screen(press(state, [:down, :down, {:ctrl, "r"}])) =~ "1 item linking here"

    state = state |> press([:down, {:f, 7}, :down, :down, {:f, 5}, {:ctrl, "l"}])
    assert hd(State.mode(state).edit.lines) == "[[bonalaku]]"
  end
end
