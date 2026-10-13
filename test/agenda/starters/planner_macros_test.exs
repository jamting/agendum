defmodule Agenda.Starters.PlannerMacrosTest do
  @moduledoc """
  The Activities Planner's keystroke macros (R60; screenshots 78-109 in
  `docs/reference/screens/notes.md`), each run from the macro manager
  (ALT-F3, ENTER) as a person would.
  """
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers

  alias Agenda.Core.Database
  alias Agenda.Starters.Planner
  alias Agenda.TUI.State

  setup_all do
    %{db: Planner.build()}
  end

  # runs the macro at `index` in the manager's list
  defp run(db, index) do
    db |> start() |> press([{:alt_f, 3}] ++ List.duplicate(:down, index) ++ [:enter])
  end

  test "three macros, in Agenda's order, run from views only (shots 78, 89, 92, 96)",
       %{db: db} do
    macros = Enum.map(db.macro_order, &db.macros[&1])

    assert Enum.map(macros, & &1.name) ==
             ["Customize date settings", "Hide/Display done items", "Print current view"]

    for m <- macros,
        do: assert(m.run_from == %{view: true, note: false, catmgr: false, elsewhere: false})
  end

  test "Customize date settings opens the file's date settings", %{db: db} do
    assert %{type: :file_props} = db |> run(0) |> State.mode()
  end

  test "Hide/Display done items hides them, and a second run shows them", %{db: db} do
    state = run(db, 0 + 1)
    assert State.view(state).hide_done
    state = press(state, [{:alt_f, 3}, :down, :enter])
    refute State.view(state).hide_done
  end

  test "Print current view asks where to print it", %{db: db} do
    assert panel(run(db, 2)) =~ "Print view to text file"
  end

  test "Sort items in view and Create/Update contact list are left out", %{db: db} do
    names = for {_, m} <- db.macros, do: m.name
    refute "Sort items in view" in names
    refute "Create/Update contact list" in names
    assert Database.views(db) |> Enum.any?(&(&1.name == "Contacts"))
  end
end
