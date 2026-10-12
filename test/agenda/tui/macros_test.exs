defmodule Agenda.TUI.MacrosTest do
  @moduledoc """
  The macro manager, Learn mode and running macros (R50; Working with
  Macros, chapter 1). `press/2` plays a run's keys as the shell does.
  """
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.Core
  alias Agenda.TUI.{History, State}

  setup do
    %{state: start(Agenda.Sample.build(~D[2026-10-08]))}
  end

  defp count(state, text), do: state.db.items |> Map.values() |> Enum.count(&(&1.text == text))
  defp macro(state, name), do: Agenda.Core.Database.find_macro(state.db, name)

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
    before = length(state.undo)
    state = press(state, [{:alt_f, 3}, :down, :enter])
    assert length(state.undo) == before
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
    assert press(asked, ["x.agendum", :enter]).path =~ "x.agendum"

    learning = press(state, [{:alt_f, 3}, :insert, "Half", :enter, {:f, 7}, "half an item"])
    assert learning.edit != nil
    stopped = press(learning, {:alt_f, 3})
    assert stopped.macro.learning == nil
    assert macro(stopped, "Half").keys == "half an item"
  end
end
