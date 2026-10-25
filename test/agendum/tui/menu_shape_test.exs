defmodule Agendum.TUI.MenuShapeTest do
  @moduledoc """
  The view's menu in Agenda's shape (AGENDA_PARITY § The steps; the owner,
  2026-10-24): File, Item, Category, View, Print, Utilities, Quit, with
  Utilities' Customize, Execute, Show (Match, Prereqs, Depends, ItemsDone,
  Alarm, Sched, Every) and Questions; no Search menu, Undo and Redo off the top line.
  Commands that left the menus keep their keys; Recalc, which Agenda did
  not have, is reached with CTRL-X; a new file is made by retrieving a name
  that is not a file yet, after asking.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.TUI.{Menu, State, Update}

  setup do
    %{state: start(Agendum.Sample.build(~D[2026-10-08]))}
  end

  defp labels(level), do: Enum.map(level, &elem(&1, 0))
  defp child(level, label), do: level |> Enum.find(&(elem(&1, 0) == label)) |> elem(2)

  test "the top line is Agenda's, without System (out of scope)" do
    assert labels(Menu.shown(:main, false)) ==
             ["File", "Item", "Category", "View", "Print", "Utilities", "Quit"]
  end

  test "Utilities and Utilities ▸ Show hold Agenda's entries that Agendum has" do
    utilities = child(Menu.shown(:main, false), "Utilities")
    assert labels(utilities) == ["Customize", "Execute", "Show", "Questions"]

    assert labels(child(utilities, "Show")) ==
             ["Match", "Prereqs", "Depends", "ItemsDone", "Alarm", "Sched", "Every"]
  end

  test "the keys of the entries that left stay", %{state: state} do
    on_item = press(state, :down)
    assert press(on_item, {:f, 4}).db != on_item.db
    assert press(state, {:ctrl, "z"}) |> Map.get(:db) == state.db
    assert %Agendum.TUI.Modes.SearchBox{} = press(state, {:alt_f, 6}) |> State.mode()
  end

  test "Recalc runs with CTRL-X, as Agenda had no menu entry for it", %{state: state} do
    ran = press(state, [{:ctrl, "x"} | String.graphemes("recalc")] ++ [:enter])
    assert screen(ran) =~ ~r/recalculat|Recalc/i
    assert State.mode(ran) == nil
  end

  describe "File ▸ Retrieve with a name that is not a file yet" do
    test "asks, and Yes makes the new file, not saved yet", %{state: state} do
      asked = Update.loaded(state, "/tmp/nowhere/notes.agendum", {:error, :enoent})
      assert screen(asked) =~ "Create the new file notes.agendum?"

      made = press(asked, :enter)
      assert made.path == "/tmp/nowhere/notes.agendum"
      assert made.dirty
      assert map_size(made.db.items) == 0
      assert screen(made) =~ "New file notes.agendum (not saved yet)"
    end

    test "No keeps the file that is open", %{state: state} do
      asked = Update.loaded(state, "/tmp/nowhere/notes.agendum", {:error, :enoent})
      kept = press(asked, "n")
      assert kept.db == state.db
      assert kept.path == state.path
    end
  end
end
