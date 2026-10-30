# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.CatmgrKeysTest do
  @moduledoc """
  Inserting categories with Agenda's accelerator keys in the category
  manager (R42; User's Guide 16-11).
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core.Database

  # Category manager rows: MAIN Entry When Done Calls Priority High Medium Low ...
  setup do
    %{state: start(Agendum.Sample.build(~D[2026-10-08]))}
  end

  defp at(state, row), do: press(state, [{:f, 9}] ++ List.duplicate(:down, row))
  defp id(state, name), do: hd(Database.find_categories(state.db, name))
  defp names(state, ids), do: Enum.map(ids, &state.db.categories[&1].name)
  defp children(state, name), do: names(state, state.db.categories[id(state, name)].children)

  # Agenda's category manager (checked in Agenda 2.0, 2026-10-25, PLANNER):
  # MAIN in the third column, each level two further; a mark two left of
  # the name (♪ a note, ☼ a date category, # a numeric one); ┌ ├ └ just
  # before the children of an exclusive family ([ for a lone child); no
  # counts or tags. The owner's choice, 2026-10-25
  test "the category manager is drawn as Agenda's", %{state: state} do
    calls = id(state, "Calls")
    state = %{state | db: Agendum.Core.set_category_note(state.db, calls, "Who to ring")}
    lines = state |> press({:f, 9}) |> screen() |> String.split("\n")
    line = fn name -> Enum.find(lines, &(&1 =~ ~r/[ ┌├└\[]#{name}\s*$/)) end

    assert line.("MAIN") == "  MAIN"
    assert line.("When") == "  ☼ When"
    assert line.("Calls") == "  ♪ Calls"
    assert line.("Priority") == "    Priority"
    assert line.("High") == "     ┌High"
    assert line.("Medium") == "     ├Medium"
    assert line.("Low") == "     └Low"
    # no counts, tags or "aka" names; the second line has no count either
    refute Enum.any?(lines, &(&1 =~ ~r/aka |exclusive|  \d+$/))
    assert Enum.at(lines, 1) =~ ~r/^ Category Manager\s*$/
  end

  test "ALT-R inserts a child of the highlighted category, as its first child", %{state: state} do
    state = state |> at(5) |> press([{:alt, "r"}, "Urgent", :enter])
    assert children(state, "Priority") == ["Urgent", "High", "Medium", "Low"]
  end

  test "ALT-R does not work on a date category", %{state: state} do
    state = state |> at(2) |> press({:alt, "r"})
    assert state.edit == nil
    assert screen(state) =~ "only to standard categories"
  end

  test "ALT-L inserts a new family after the parent", %{state: state} do
    state = state |> at(6) |> press([{:alt, "l"}, "Someday", :enter])

    assert children(state, "MAIN") |> Enum.drop_while(&(&1 != "Priority")) |> Enum.take(2) ==
             ["Priority", "Someday"]
  end

  test "ALT-L does not work on a child of MAIN", %{state: state} do
    state = state |> at(4) |> press({:alt, "l"})
    assert state.edit == nil
    assert screen(state) =~ "same level as MAIN"
  end

  test "ALT-U inserts a sibling above; ALT-D and ALT-I below", %{state: state} do
    state = state |> at(7) |> press([{:alt, "u"}, "Above", :enter])
    assert children(state, "Priority") == ["High", "Above", "Medium", "Low"]

    state = press(state, [{:alt, "d"}, "Below", :enter])
    assert children(state, "Priority") == ["High", "Above", "Below", "Medium", "Low"]

    state = press(state, [{:alt, "i"}, "Next", :enter])
    assert children(state, "Priority") == ["High", "Above", "Below", "Next", "Medium", "Low"]
  end

  test "ALT-U on the first child puts the new category first", %{state: state} do
    state = state |> at(6) |> press([{:alt, "u"}, "Top", :enter])
    assert children(state, "Priority") == ["Top", "High", "Medium", "Low"]
  end

  test "ALT-U and ALT-L do nothing on MAIN", %{state: state} do
    for key <- [{:alt, "u"}, {:alt, "l"}] do
      state = state |> at(0) |> press(key)
      assert state.edit == nil
    end
  end
end
