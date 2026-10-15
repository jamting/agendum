defmodule Agendum.TUI.HelpScreenTest do
  @moduledoc """
  The help screen's other pages (R65, ADR 0033): F1 then `c` lists the
  commands that can run where F1 was pressed, F1 then `d` describes a key.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Core
  alias Agendum.Starters.Planner
  alias Agendum.TUI.{HelpScreen, State}

  @today ~D[2026-10-12]

  setup do
    db = Planner.build() |> Planner.with_samples(@today)
    %{state: start(db, today: @today, height: 40, width: 100)}
  end

  defp to_command(state, name) do
    index = Enum.find_index(HelpScreen.commands(:view), fn {c, _, _} -> c.name == name end)
    press(state, List.duplicate(:down, index))
  end

  test "the keys page says how to reach the other pages", %{state: state} do
    assert screen(press(state, {:f, 1})) =~ "c commands · d describe a key"
  end

  describe "F1 c, the command list" do
    test "lists the view's commands with their keys and summaries, then the global ones",
         %{state: state} do
      text = screen(press(state, [{:f, 1}, "c"]))
      assert text =~ "COMMANDS IN A VIEW"
      assert text =~ ~r/Down +↓ ENTER +Highlight the row below/
      assert text =~ ~r/Insert +INS ALT-I CTRL-N/

      names = for {c, _, _} <- HelpScreen.commands(:view), do: c.name
      assert "Undo" in names
      assert Enum.find_index(names, &(&1 == "Undo")) > Enum.find_index(names, &(&1 == "Down"))
      # Save is the view's ALT-W and the global CTRL-S: listed once
      assert Enum.count(names, &(&1 == "Save")) == 1
    end

    test "ENTER runs the highlighted command where F1 was pressed", %{state: state} do
      shown = state |> press([{:f, 1}, "c"]) |> to_command("Next view") |> press(:enter)
      assert shown.modes == []
      assert shown.view_id == press(state, {:alt, "n"}).view_id
    end

    test "a global command runs too: Undo", %{state: state} do
      changed = press(state, [:down, {:f, 7}])
      assert Core.marked_items(changed.db) != []
      undone = changed |> press([{:f, 1}, "c"]) |> to_command("Undo") |> press(:enter)
      assert Core.marked_items(undone.db) == []
    end

    test "ESC returns without running anything", %{state: state} do
      back = press(state, [{:f, 1}, "c", :down, :esc])
      assert back.modes == [] and back.cursor == state.cursor
    end

    test "from the category manager it lists the manager's commands, then the global ones",
         %{state: state} do
      text = screen(press(state, [{:f, 9}, {:f, 1}, "c"]))
      assert text =~ "COMMANDS IN THE CATEGORY MANAGER"
      assert text =~ ~r/Promote +F7 +Move the category up a level/
      refute text =~ "Next marked"
    end

    test "in the view manager: F1 opens the help, and c lists its commands", %{state: state} do
      text = screen(press(state, [{:f, 8}, {:f, 1}, "c"]))
      assert text =~ "COMMANDS IN THE VIEW MANAGER"
      # keys that do not fit go on to the next line
      assert text =~ ~r/Discard +DEL F4 ALT-F4 CTRL-D +Discard the view.*\n +CTRL-K\n/
      back = press(state, [{:f, 8}, {:f, 1}, "c", :esc])
      assert Enum.map(back.modes, & &1.type) == [:viewmgr]
    end

    test "in a note: its commands only, since the keys of every screen edit text there",
         %{state: state} do
      text = screen(press(state, [:down, {:f, 5}, {:f, 1}, "c"]))
      assert text =~ "COMMANDS IN A NOTE"
      assert text =~ ~r/Cut +F4 +Cut the marked text/
      refute text =~ "Undo"
    end

    test "ENTER runs a note command in the note", %{state: state} do
      in_note = press(state, [:down, {:f, 5}, "hello"])

      index =
        Enum.find_index(HelpScreen.commands(:note), fn {c, _, _} -> c.id == :insert_date end)

      ran = press(in_note, [{:f, 1}, "c"] ++ List.duplicate(:down, index) ++ [:enter])
      assert Enum.map(ran.modes, & &1.type) == [:note]
      assert screen(ran) =~ "hello2026-10-12"
    end

    test "ENTER runs a category manager command there", %{state: state} do
      in_catmgr = press(state, [{:f, 9}, :down, :down])
      index = Enum.find_index(HelpScreen.commands(:catmgr), fn {c, _, _} -> c.id == :parent end)
      ran = press(in_catmgr, [{:f, 1}, "c"] ++ List.duplicate(:down, index) ++ [:enter])
      assert ran == press(in_catmgr, :home) |> Map.put(:last_key, ran.last_key)
    end
  end

  describe "F1 d, describe key" do
    defp described(state, key), do: state |> press([{:f, 1}, "d", key]) |> screen()

    test "says which command a key runs in a view, and whether it takes a count",
         %{state: state} do
      text = described(state, {:alt, "j"})
      assert text =~ "ALT-J runs Next marked in a view."
      assert text =~ "Highlight the next marked item"
      assert text =~ "Takes a count"
    end

    test "a key that stands for another says so", %{state: state} do
      assert described(state, {:ctrl, "n"}) =~
               "CTRL-N stands for INS. CTRL-N runs Insert in a view."
    end

    test "a global key", %{state: state} do
      assert described(state, {:ctrl, "z"}) =~ "CTRL-Z runs Undo, everywhere but while typing."
    end

    test "a character, a count digit and an unbound key", %{state: state} do
      assert described(state, "x") =~ "x starts typing an item"
      assert described(state, {:alt, "3"}) =~ "ALT-3 adds a digit to a count"
      assert described(state, {:f, 11}) =~ "F11 does nothing in a view."
    end

    test "a key attached to a macro names the macro, and what it hides", %{state: state} do
      {:ok, db, id} = Core.add_macro(state.db, "Tidy")
      state = State.change_db(state, Core.attach_macro(db, id, "{AltJ}"))
      text = described(state, {:alt, "j"})
      assert text =~ "ALT-J runs the macro Tidy, attached to it in this file."
      assert text =~ "Without the macro it would run Next marked."
    end

    test "describing does not run the key, and the next key returns", %{state: state} do
      described = press(state, [:down, {:f, 1}, "d", "x"])
      assert described.edit == nil
      back = press(described, :down)
      assert back.modes == [] and back.edit == nil
      assert back.cursor == described.cursor
    end

    test "in the category manager: its own command, and ⌥↑ is its own key there",
         %{state: state} do
      in_catmgr = press(state, {:f, 9})
      assert described(in_catmgr, {:alt, :up}) =~ "ALT-↑ runs Move up in the category manager."
      assert described(in_catmgr, "x") =~ "x starts typing a new category"
      assert described(state, {:alt, :up}) =~ "ALT-↑ stands for CTRL-PGUP."
    end

    test "in the view manager: F4 discards, a letter finds a view", %{state: state} do
      in_viewmgr = press(state, {:f, 8})
      assert described(in_viewmgr, {:f, 4}) =~ "F4 runs Discard in the view manager."
      assert described(in_viewmgr, "w") =~ "w highlights the next view whose name starts"
    end

    test "in a note: a command, a key that edits, and CTRL-Z, which is not undo there",
         %{state: state} do
      in_note = press(state, [:down, {:f, 5}])
      assert described(in_note, {:f, 4}) =~ "F4 runs Cut in a note."
      assert described(in_note, :left) =~ "← edits the text"
      assert described(in_note, {:ctrl, "e"}) =~ "CTRL-E edits the text"
      refute described(in_note, {:ctrl, "z"}) =~ "Undo"
    end

    test "ESC before a key goes back", %{state: state} do
      assert press(state, [{:f, 1}, "d", :esc]).modes == []
    end
  end

  describe "in a box (Item Properties)" do
    setup %{state: state}, do: %{box: press(state, [:down, {:f, 6}])}

    test "F1 opens the help over the box, and ESC goes back to it", %{box: box} do
      back = press(box, [{:f, 1}, :esc])
      assert Enum.map(back.modes, & &1.type) == [:item_props]
    end

    test "c lists the box's commands from its keymap, then the shared and global ones",
         %{box: box} do
      text = screen(press(box, [{:f, 1}, "c"]))
      assert text =~ "COMMANDS IN THIS BOX"
      assert text =~ ~r/Edit +F2 +Edit the text, or open the note/
      assert text =~ ~r/Help +F1 +Show the keys/
      assert text =~ "Save"
      # ESC is the box's own Cancel, so the shared one is not listed again
      refute text =~ "put back the box's changes"
    end

    test "ENTER on one of the box's commands runs it in the box", %{box: box} do
      index =
        Enum.find_index(
          Agendum.TUI.Boxes.ItemProperties.commands(%{}),
          &(elem(&1, 0) == :profile)
        )

      ran = press(box, [{:f, 1}, "c"] ++ List.duplicate(:down, index) ++ [:enter])
      assert Enum.map(ran.modes, & &1.type) == [:profile, :item_props]
    end

    test "d describes a key of the box and a shared key", %{box: box} do
      assert described(box, {:f, 2}) =~ "F2 runs Edit in this box."
      assert described(box, {:ctrl, "s"}) =~ "CTRL-S runs Save"
    end

    test "a box opened over the help does not upset its pages (found by the fuzz)",
         %{box: box} do
      over = press(box, [{:f, 1}, "c", {:alt_f, 3}])
      assert Enum.map(over.modes, & &1.type) == [:macros, :help, :item_props]
      assert screen(over) =~ "COMMANDS IN THIS BOX"
    end

    test "F1 while typing in the box does not open the help", %{box: box} do
      typing = press(box, {:f, 2})
      assert typing.edit != nil
      assert State.mode(press(typing, {:f, 1})).type == :item_props
    end
  end

  describe "in a settings box with a keymap (File Properties)" do
    setup %{state: state}, do: %{box: Agendum.TUI.Boxes.FileProperties.open(state)}

    test "c lists its commands from its keymap, and ENTER runs one", %{box: box} do
      text = screen(press(box, [{:f, 1}, "c"]))
      assert text =~ ~r/Change +SPACE +Next choice of the setting/
      assert text =~ ~r/Next +TAB +The next setting/
      ran = press(box, [{:f, 1}, "c", :down, :down, :enter])
      assert State.mode(ran).cursor == State.mode(press(box, :down)).cursor
    end

    test "d describes a key of its keymap", %{box: box} do
      assert described(box, {:char, " "}) =~ "SPACE runs Change in this box."
      assert described(box, :enter) =~ "ENTER runs Done in this box."
    end
  end

  describe "in a list box (Go To)" do
    setup %{state: state}, do: %{box: press(state, {:alt_f, 5})}

    test "c lists its commands, and ENTER runs one", %{box: box} do
      text = screen(press(box, [{:f, 1}, "c"]))
      assert text =~ ~r/Go +ENTER +Highlight that section in the view/
      ran = press(box, [{:f, 1}, "c", :enter])
      assert ran.modes == []
    end

    test "d describes its keys; a letter, which it reads itself, is described as typing",
         %{box: box} do
      assert described(box, :enter) =~ "ENTER runs Go in this box."
      assert described(box, "x") =~ "x picks"
    end
  end

  describe "in the menu" do
    setup %{state: state}, do: %{menu: press(state, {:f, 10})}

    test "F1 opens the help, and ESC goes back to the menu", %{menu: menu} do
      back = press(menu, [{:f, 1}, :esc])
      assert Enum.map(back.modes, & &1.type) == [:menu]
    end

    test "c lists the level's entries by their letters, then the menu's keys", %{menu: menu} do
      text = screen(press(menu, [{:f, 1}, "c"]))
      assert text =~ "COMMANDS IN THE MENU"
      assert text =~ ~r/File +F +Retrieve, save or create files/
      assert text =~ ~r/Back +ESC BACKSPACE +Back up a level/
      # the keys of every screen do nothing in the menu: not listed
      refute text =~ ~r/Undo +CTRL-Z/
    end

    test "ENTER on an entry chooses it, as its letter would", %{menu: menu} do
      ran = press(menu, [{:f, 1}, "c", :enter])
      assert ran.modes == press(menu, "f").modes
    end

    test "d describes a letter and a key", %{menu: menu} do
      assert described(menu, "f") =~ "f chooses File."
      assert described(menu, "z") =~ "no entry of this level begins with it"
      assert described(menu, :backspace) =~ "BACKSPACE runs Back in the menu."
    end
  end

  describe "while moving or browsing" do
    test "moving items: F1 opens the help, c lists drop and the view's moves", %{state: state} do
      moving = press(state, [:down, {:alt_f, 10}])
      assert State.mode(moving).type == :move_item
      text = screen(press(moving, [{:f, 1}, "c"]))
      assert text =~ "COMMANDS WHILE MOVING ITEMS"
      assert text =~ ~r/Drop +ENTER +Move the item\(s\) here/
      assert described(moving, :down) =~ "↓ runs Down while moving items."
      assert State.mode(press(moving, [{:f, 1}, :esc])).type == :move_item
    end

    test "browsing a datebook: c lists its moves, ENTER on one runs it", %{state: state} do
      datebook = Enum.find(Agendum.Core.Database.views(state.db), & &1.datebook)
      browsing = state |> State.switch_view(datebook.id) |> press({:alt, "b"})
      assert State.mode(browsing).type == :browse
      later = press(browsing, [{:f, 1}, "c", :down, :enter])
      assert State.mode(later).date == State.mode(press(browsing, :right)).date
    end
  end
end
