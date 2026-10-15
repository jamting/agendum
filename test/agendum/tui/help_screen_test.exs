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

    test "from the category manager it lists the commands of every screen", %{state: state} do
      text = screen(press(state, [{:f, 9}, {:f, 1}, "c"]))
      assert text =~ "COMMANDS ON EVERY SCREEN"
      assert text =~ "Undo"
      refute text =~ "Next marked"
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

    test "ESC before a key goes back", %{state: state} do
      assert press(state, [{:f, 1}, "d", :esc]).modes == []
    end
  end
end
