defmodule Agendum.TUI.MacrosTest do
  @moduledoc """
  The macro manager, Learn mode and running macros (R50; Working with
  Macros, chapter 1). `press/2` plays a run's keys as the shell does.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.TUI.{History, State}

  setup do
    %{state: start(Agendum.Sample.build(~D[2026-10-08]))}
  end

  defp count(state, text), do: state.db.items |> Map.values() |> Enum.count(&(&1.text == text))
  defp macro(state, name), do: Agendum.Core.Database.find_macro(state.db, name)

  # a macro "Water" that types an item into the first section
  defp learned(state) do
    press(state, [
      {:alt_f, 3},
      :insert,
      "Water",
      :enter,
      {:f, 7},
      "Water the lettuces",
      :enter,
      {:alt_f, 3}
    ])
  end

  test "ALT-F3 opens the macro manager; INS names a new macro", %{state: state} do
    state = press(state, {:alt_f, 3})
    assert %{type: :macros} = State.mode(state)
    assert screen(state) =~ "No macros yet"

    state = press(state, [:insert, "Water", :enter])
    assert %{type: :macros, cursor: 0} = State.mode(state)
    assert screen(state) =~ ~r/│ Water/
    assert screen(state) =~ "F7 learns its keystrokes"
  end

  test "F7 learns: the keys do their work and are recorded until ALT-F3", %{state: state} do
    state = press(state, [{:alt_f, 3}, :insert, "Water", :enter, {:f, 7}])
    assert state.modes == []
    assert screen(state) =~ "LEARN"

    state = press(state, ["Water the lettuces", :enter])
    assert count(state, "Water the lettuces") == 1
    assert screen(state) =~ "LEARN"

    state = press(state, {:alt_f, 3})
    refute screen(state) =~ "LEARN"
    assert macro(state, "Water").keys == "Water the lettuces{ENTER}"
    assert panel(state) =~ "Learn mode is off: Water has 19 new keys"
  end

  test "undo while learning takes the new macro away; stopping then keeps nothing (fuzz)",
       %{state: state} do
    learning = press(state, [{:alt_f, 3}, :insert, "Water", :enter, {:f, 7}])
    stopped = press(learning, [{:ctrl, "z"}, {:alt_f, 3}])
    assert macro(stopped, "Water") == nil
    assert stopped.macro.learning == nil
    assert screen(stopped) =~ "the macro was undone"
  end

  test "ENTER in the manager runs it; ALT-Z runs it again", %{state: state} do
    state = learned(state)
    state = press(state, [{:alt_f, 3}, :enter])
    assert count(state, "Water the lettuces") == 2
    assert state.macro.playing == 0

    state = press(state, {:alt, "z"})
    assert count(state, "Water the lettuces") == 3
  end

  test "a run is one undo step; a run that changes nothing is none", %{state: state} do
    state = learned(state)
    ran = press(state, [{:alt_f, 3}, :enter])
    assert count(ran, "Water the lettuces") == 2
    assert ran |> History.undo() |> count("Water the lettuces") == 1

    {:ok, db, look} = Core.add_macro(state.db, "Look")
    db = Core.set_macro_keys(db, look, "{DOWN}{DOWN}{UP}")
    state = %{state | db: db}
    before = length(state.history.undo)
    state = press(state, [{:alt_f, 3}, :down, :enter])
    assert length(state.history.undo) == before
  end

  test "F7 on a macro with keystrokes asks: replace or append", %{state: state} do
    state = learned(state)
    asked = press(state, [{:alt_f, 3}, {:f, 7}])
    assert %{type: :choice, kind: :learn} = State.mode(asked)

    appended = press(asked, ["a", "x", {:alt_f, 3}])
    assert macro(appended, "Water").keys == "Water the lettuces{ENTER}x"

    replaced = press(asked, ["r", "y", {:alt_f, 3}])
    assert macro(replaced, "Water").keys == "y"
  end

  test "a macro cannot run away", %{state: state} do
    {:ok, db, again} = Core.add_macro(state.db, "Again")
    db = Core.set_macro_keys(db, again, "x{AltZ}")
    {:ok, db, deep} = Core.add_macro(db, "Deeper")
    # opens the manager and runs the first macro, itself, from inside
    db = Core.set_macro_keys(db, deep, "{AltF3}{DOWN}{ENTER}")
    state = %{state | db: db}

    # ALT-Z inside a run does nothing
    state = press(state, [{:alt_f, 3}, :enter, :esc])
    assert state.macro.playing == 0

    stopped = press(state, [{:alt_f, 3}, :down, :enter])
    assert stopped.macro.playing == 0
    assert panel(stopped) =~ "Macros started 8 deep; stopped"
  end

  test "a macro without keystrokes says so; ALT-Z before any run says so", %{state: state} do
    assert panel(press(state, {:alt, "z"})) =~ "No macro run yet"
    state = press(state, [{:alt_f, 3}, :insert, "Empty", :enter, :enter])
    assert panel(state) =~ "Empty has no keystrokes yet"
  end

  test "names are checked", %{state: state} do
    state = press(state, [{:alt_f, 3}, :insert, "Water", :enter, :insert, "water", :enter])
    assert panel(state) =~ "A macro is already called water"
  end

  test "Learn mode works in notes and the category manager too", %{state: state} do
    state =
      press(state, [
        {:alt_f, 3},
        :insert,
        "Sign",
        :enter,
        {:f, 7},
        :down,
        {:f, 5},
        "— Rabbit",
        :esc,
        {:alt_f, 3}
      ])

    assert macro(state, "Sign").keys == "{DOWN}{F5}— Rabbit{ESC}"
  end

  test "not over a prompt or a line being typed; Learn mode still stops there", %{state: state} do
    # ALT-W on an untitled file asks for a name; ALT-F3 leaves the prompt be
    asked = press(state, [{:alt, "w"}, {:alt_f, 3}])
    assert %{type: :prompt} = State.mode(asked)
    press(asked, ["x.agendum", :enter])
    assert {:save, path, _} = List.last(effects())
    assert path =~ "x.agendum"

    learning = press(state, [{:alt_f, 3}, :insert, "Half", :enter, {:f, 7}, "half an item"])
    assert learning.edit != nil
    stopped = press(learning, {:alt_f, 3})
    assert stopped.macro.learning == nil
    assert macro(stopped, "Half").keys == "half an item"
  end

  describe "editing, properties and attached keys" do
    setup %{state: state} do
      %{state: learned(state)}
    end

    test "F2 edits the keystrokes as text, a line after each {ENTER}", %{state: state} do
      state = press(state, [{:alt_f, 3}, {:f, 2}])
      assert screen(state) =~ ~r/^ Edit macro:  Water +Line +2 INS EDIT/
      assert screen(state) =~ "Water the lettuces{ENTER}"

      state = press(state, [:ctrl_end, "Weed{ENTER}", {:f, 5}])
      assert macro(state, "Water").keys == "Water the lettuces{ENTER}\nWeed{ENTER}"
      state = press(state, [:esc, {:alt_f, 3}, :enter])
      assert count(state, "Weed") == 1
    end

    test "a key attached in Properties runs the macro, in views by default", %{state: state} do
      state = press(state, [{:alt_f, 3}, {:f, 6}, :down, :down, " ", "{F4}", :enter])
      assert macro(state, "Water").key == "{F4}"
      assert screen(state) =~ ~r/Attach to key +: \{F4\}/

      # ENTER keeps it (ESC would cancel), ESC closes the manager
      state = press(state, [:enter, :esc])
      # the key bar shows the macro's name on F4
      assert screen(state) =~ "F4 Water"
      state = press(state, {:f, 4})
      assert count(state, "Water the lettuces") == 2

      # not in the category manager unless it may run there
      state =
        press(state, [{:alt_f, 3}, {:f, 6}, :down, :down, :down, :down, :down, " ", :enter, :esc])

      refute macro(state, "Water").run_from.catmgr
      assert press(state, [{:f, 9}, {:f, 4}]) |> count("Water the lettuces") == 2
    end

    test "Everywhere else needs an attached key; ALT-F3 cannot be one", %{state: state} do
      state =
        state
        |> press([{:alt_f, 3}, {:f, 6}])
        |> to_setting("Run from Everywhere else")
        |> press(" ")

      assert panel(state) =~ "Only a macro attached to a key runs everywhere else"

      state = state |> to_setting("Attach to key") |> press([" ", "{AltF3}", :enter])
      assert panel(state) =~ "ALT-F1, ALT-F3 and ALT-Z cannot run a macro"

      state = press(state, [" ", "{F4}{F5}", :enter])
      assert panel(state) =~ "Type one key"
    end

    test "inside a run, an attached key does its own work", %{state: state} do
      {:ok, db, mark} = Core.add_macro(state.db, "Mark")
      db = db |> Core.set_macro_keys(mark, "{F7}") |> Core.attach_macro(mark, "{F7}")
      state = %{state | db: db}
      # F7 runs Mark, whose F7 marks the item
      state = press(state, [:down, {:f, 7}])
      assert Enum.any?(Map.values(state.db.items), & &1.marked)
    end

    test "learning records an attached key as a call; {CALL} runs it", %{state: state} do
      state =
        press(state, [{:alt_f, 3}, {:f, 6}, :down, :down, " ", "{F4}", :enter, :enter, :esc])

      state = press(state, [{:alt_f, 3}, :insert, "Twice", :enter, {:f, 7}, {:f, 4}, {:alt_f, 3}])
      assert macro(state, "Twice").keys == "{CALL Water}"
      assert count(state, "Water the lettuces") == 2

      state = press(state, [{:alt_f, 3}, :down, :enter])
      assert count(state, "Water the lettuces") == 3
    end

    test "DEL deletes after asking; ALT-F5 sorts; ALT-↑↓ moves", %{state: state} do
      state = press(state, [{:alt_f, 3}, :insert, "Apples", :enter])
      names = fn s -> s.db |> Agendum.Core.Database.macros() |> Enum.map(& &1.name) end
      assert names.(state) == ["Water", "Apples"]

      state = press(state, {:alt_f, 5})
      assert names.(state) == ["Apples", "Water"]
      assert %{cursor: 0} = State.mode(state)

      state = press(state, {:alt, :down})
      assert names.(state) == ["Water", "Apples"]
      assert %{cursor: 1} = State.mode(state)

      state = press(state, [:delete, "y"])
      assert names.(state) == ["Water"]
    end

    test "Properties renames", %{state: state} do
      state = press(state, [{:alt_f, 3}, {:f, 6}, {:f, 2}, {:ctrl, "u"}, "Watering", :enter])
      assert macro(state, "Watering")
    end
  end

  # found by the fuzz walks: the box of a macro deleted from a manager
  # opened over it was drawn for a macro no longer there
  test "deleting a macro closes its properties box and editor beneath", %{state: state} do
    state = learned(state)
    props = press(state, [{:alt_f, 3}, {:f, 6}, {:alt_f, 3}])
    assert Enum.map(props.modes, & &1.type) == [:macros, :macro_props, :macros]

    deleted = press(props, [:delete, :enter])
    assert macro(deleted, "Water") == nil
    refute :macro_props in Enum.map(deleted.modes, & &1.type)
    assert is_binary(screen(deleted))

    editing = press(state, [{:alt_f, 3}, {:f, 2}, {:alt_f, 3}, :delete, :enter])
    refute Enum.any?(editing.modes, &match?(%{type: :note, target: {:macro, _}}, &1))
    assert is_binary(screen(editing))
  end
end
