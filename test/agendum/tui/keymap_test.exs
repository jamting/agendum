# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.KeymapTest do
  @moduledoc """
  Keys run named commands through keymaps (R65, ADR 0033): the keymap and
  the command list must agree, as the menu's first letters must.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Starters.Planner
  alias Agendum.TUI.{CategoryScreens, Commands, Keymap}
  alias Agendum.TUI.Update.ViewKeys

  @today ~D[2026-10-12]

  # the places whose keys are in keymaps (ADR 0033)
  @places [:view, :catmgr, :viewmgr, :note, :menu, :box, :global] ++
            [:move_item, :searching, :browse, :column_width, :column_move, :section_move] ++
            [:line, :text]

  test "every key in a keymap runs a command in its place's command list" do
    unknown =
      for place <- @places,
          {key, id} <- Keymap.bindings(place),
          Commands.get(place, id) == nil,
          do: {place, key, id}

    assert unknown == []
  end

  test "the global keymap and the global commands agree, and every one runs" do
    state = start(Planner.build(), today: @today)

    for {_key, id} <- Keymap.bindings(:global), do: assert(Commands.get(:global, id), "#{id}")

    for c <- Commands.all(:global) do
      assert Keymap.keys_for(:global, c.id) != []
      assert Agendum.TUI.Update.run_global(state, c.id) != nil
    end
  end

  # commands with no key of their own: reached from the menu and F1 c
  # (Clear in a note: Agenda had no key for it either)
  # Recalc: Agenda had no such command, so neither a key nor a menu entry
  @keyless [{:note, :clear}, {:view, :recalc}]

  test "every command has a key" do
    unbound =
      for place <- @places,
          c <- Commands.all(place),
          Keymap.keys_for(place, c.id) == [],
          {place, c.id} not in @keyless,
          do: {place, c.id}

    assert unbound == []
  end

  test "names and summaries fit the command list on an 80-column screen" do
    for place <- @places, c <- Commands.all(place) do
      assert String.length(c.name) <= 17, c.name
      assert String.length(c.summary) <= 38, c.summary
    end
  end

  test "command ids are unique in a place and every command has a name and a summary" do
    for place <- @places do
      ids = Enum.map(Commands.all(place), & &1.id)
      assert ids == Enum.uniq(ids)
      assert Enum.all?(Commands.all(place), &(&1.name != "" and &1.summary != ""))
    end
  end

  test "⌥↑ stands for CTRL-PGUP in a view only: in the category manager it moves" do
    assert Keymap.alias_in(:view, {:alt, :up}) == :ctrl_pgup
    assert Keymap.alias_in(:catmgr, {:alt, :up}) == nil
    assert {:alt, :up} in Keymap.keys_for(:catmgr, :move_up)
    refute {:alt, :up} in Keymap.keys_for(:catmgr, :previous_sibling)
  end

  test "every view manager command runs, on the first view and on another" do
    state = start(Planner.build() |> Planner.with_samples(@today), today: @today)
    first = press(state, [{:f, 8}, :home])
    other = press(first, :down)

    for c <- Commands.all(:viewmgr), from <- [first, other] do
      assert %Agendum.TUI.State{} = Agendum.TUI.Boxes.ViewManager.run(from, c.id),
             "#{c.id} failed"
    end
  end

  test "CTRL-E and CTRL-K are F2 and F4 outside a note; in a note they edit the text" do
    assert Keymap.alias_in(:view, {:ctrl, "e"}) == {:f, 2}
    assert Keymap.alias_in(:note, {:ctrl, "e"}) == nil
    assert Keymap.alias_in(:note, {:ctrl, "n"}) == :insert
    refute {:ctrl, "k"} in Keymap.keys_for(:note, :cut)
  end

  test "every note command runs, in an item's note" do
    state = start(Planner.build() |> Planner.with_samples(@today), today: @today)
    in_note = press(state, [:down, {:f, 5}, "Call Bob about the plan"])

    for c <- Commands.all(:note) do
      assert %Agendum.TUI.State{} = Agendum.TUI.Update.Notes.run(in_note, c.id), "#{c.id} failed"
    end
  end

  test "every box has a keymap (the view manager's is a place of its own)" do
    without =
      for {type, box} <- Agendum.TUI.Boxes.Box.registry(),
          type != :viewmgr,
          box.commands(%{type: type}) == [],
          do: type

    assert without == []
  end

  test "a box's keymap and its commands agree, and fit the command list" do
    boxes =
      for {type, box} <- Agendum.TUI.Boxes.Box.registry(),
          box.commands(%{type: type}) != [],
          do: {box, %{type: type}}

    assert boxes != []

    for {box, mode} <- boxes do
      ids = for {id, _, _} <- box.commands(mode), do: id
      assert ids == Enum.uniq(ids), inspect(box)

      for {key, id} <- box.keymap(mode),
          do: assert(id in ids, "#{inspect(box)}: #{inspect(key)}")

      for {id, name, summary} <- box.commands(mode) do
        assert id in Map.values(box.keymap(mode)), "#{inspect(box)}: #{id} has no key"
        assert String.length(name) <= 17 and String.length(summary) <= 38, name
      end
    end
  end

  # Every key with a name of more than one character: F-, ALT-, CTRL- and
  # SHIFT-keys, and the named ones (ENTER, BACKSPACE, PGUP …); a letter or
  # an arrow is one character, which any text contains (meeting
  # 2026-10-22-2337, § 5: what a test can check is not left to a checklist).
  test "docs/KEYBOARD.md names every named key in the keymaps" do
    doc = File.read!("docs/KEYBOARD.md")

    missing =
      for place <- @places,
          {key, id} <- Keymap.bindings(place),
          String.length(Keymap.name(key)) > 1,
          not named?(doc, Keymap.name(key)),
          do: "#{place}: #{Keymap.name(key)} (#{id})"

    assert missing == [], "Not in KEYBOARD.md:\n" <> Enum.join(missing, "\n")
  end

  # The name on its own, not inside a longer one: BACKSPACE is not named by
  # ALT-BACKSPACE, nor F1 by F10. `(?<!…)` and `(?!…)` look at the
  # character before and after without taking it into the match.
  defp named?(doc, name),
    do: Regex.match?(~r/(?<![A-Z0-9-])#{Regex.escape(name)}(?![A-Za-z0-9])/u, doc)

  test "key names read back as keys; a dash is no key" do
    for key <- [{:f, 4}, {:alt_f, 10}, {:ctrl, "d"}, {:alt, "m"}, :pgdn, :ctrl_home, {:alt, :up}] do
      assert Keymap.parse(Keymap.name(key)) == key
    end

    assert Keymap.parse("SPACE") == {:char, " "}
    assert Keymap.parse("y") == {:char, "y"}
    assert Keymap.parse("—") == nil
    assert Keymap.parse("type") == nil
  end

  test "every category manager command runs, on MAIN and on a category below it" do
    state = start(Planner.build() |> Planner.with_samples(@today), today: @today)
    on_main = press(state, {:f, 9})
    below = press(on_main, [:down, :down])

    for c <- Commands.all(:catmgr), from <- [on_main, below] do
      assert %Agendum.TUI.State{} = CategoryScreens.Manager.run(from, c.id), "#{c.id} failed"
    end
  end

  test "every view command runs, on an item and on a section head" do
    state = start(Planner.build() |> Planner.with_samples(@today), today: @today)
    on_item = press(state, :down)

    for c <- Commands.all(:view), from <- [state, on_item] do
      assert %Agendum.TUI.State{} = ViewKeys.run(from, c.id), "#{c.id} failed"
    end
  end

  test "a printable character is not bound: it starts typing an item" do
    state = start(Planner.build(), today: @today) |> press(:down)
    assert Keymap.lookup(:view, {:char, "x"}) == nil
    assert press(state, "x").edit != nil
  end
end
