defmodule Agendum.TUI.MenuKeysEntriesTest do
  @moduledoc """
  Menu entries Agenda had for commands Agendum had only on keys (found by
  the menu test, AGENDA_PARITY § The steps; checked in Agenda 2.0,
  2026-10-24): Item ▸ BrkAssign (DEL), Category ▸ Properties (F6) and
  Category ▸ Discard (ALT-F4) in a view, and the category manager's own F10
  menu: Category (Properties, Add, Discard), Return and Quit.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Starters.Planner
  alias Agendum.TUI.{Layout, State}

  @today ~D[2026-10-12]

  # Agenda's words, read in DOSBox
  @not_a_category "The highlight isn't on a category. Highlight the category you want and repeat the command."

  setup do
    db = Planner.build() |> Planner.with_samples(@today)
    %{state: start(db, today: @today, height: 25, width: 80)}
  end

  defp line(state, n), do: state |> screen() |> String.split("\n") |> Enum.at(n)
  defp types(state), do: Enum.map(state.modes, & &1.type)

  describe "in a view" do
    test "Item ▸ BrkAssign removes the item from the section, as DEL", %{state: state} do
      state = press(state, :down)
      item = Layout.current_row(state).item
      by_menu = press(state, [{:f, 10}, "i", "b", :enter])
      assert by_menu.db == press(state, [:delete, :enter]).db
      refute by_menu.db == state.db
      assert Layout.current_row(by_menu).item != item
    end

    test "Category ▸ Properties on a section head opens its category's box", %{state: state} do
      head = Layout.current_row(state)
      assert head.kind == :section
      opened = press(state, [{:f, 10}, "c", "p"])
      assert %Agendum.TUI.Modes.Props{} = State.mode(opened)
      assert screen(opened) =~ "Category Properties"
    end

    test "Category ▸ Properties and Discard on an item say it is not a category", %{state: state} do
      on_item = press(state, :down)

      for letter <- ["p", "d"] do
        said = press(on_item, [{:f, 10}, "c", letter])
        assert said.db == on_item.db
        assert {:error, @not_a_category} = said.message
      end
    end

    test "Category ▸ Discard on a section head asks first, as ALT-F4 there", %{state: state} do
      asked = press(state, [{:f, 10}, "c", "d"])
      assert screen(asked) =~ "Discard category"
      assert asked.db == state.db
    end
  end

  describe "the category manager's menu (F10)" do
    setup %{state: state}, do: %{catmgr: press(state, {:f, 9})}

    test "F10 opens it: Category, Return, Quit", %{catmgr: catmgr} do
      menu = press(catmgr, {:f, 10})
      assert line(menu, 0) =~ ~r/^ +Category +Return +Quit/
      assert line(menu, 1) =~ ~r/Properties +Add +Discard/
      assert types(menu) == [:menu, :catmgr]
    end

    test "Return goes back to the view; F9 and ESC still do at once", %{catmgr: catmgr} do
      assert types(press(catmgr, [{:f, 10}, "r"])) == []
      assert types(press(catmgr, {:f, 9})) == []
      assert types(press(catmgr, :esc)) == []
    end

    test "Category ▸ Properties opens the highlighted category's box, as F6", %{catmgr: catmgr} do
      by_menu = press(catmgr, [:down, {:f, 10}, "c", "p"])
      by_key = press(catmgr, [:down, {:f, 6}])
      assert %Agendum.TUI.Modes.Props{} = State.mode(by_menu)
      assert State.mode(by_menu) == State.mode(by_key)
    end

    test "Category ▸ Add adds a category, as INS; Discard asks, as ALT-F4", %{catmgr: catmgr} do
      added = press(catmgr, [:down, {:f, 10}, "c", "a"])
      assert State.mode(added) == State.mode(press(catmgr, [:down, :insert]))

      # People, a category that can be discarded
      people = press(catmgr, List.duplicate(:down, 4))
      asked = press(people, [{:f, 10}, "c", "d"])
      assert screen(asked) =~ "Discard People and all its children?"
      assert screen(asked) == screen(press(people, {:alt_f, 4}))
    end

    test "the key bar names F10 Menu, as Agenda's", %{catmgr: catmgr} do
      assert slots(catmgr) =~ "F9 To View F10 Menu"
    end
  end
end
