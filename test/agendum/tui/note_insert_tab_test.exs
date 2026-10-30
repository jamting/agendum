# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.NoteInsertTabTest do
  @moduledoc """
  INS / OVR and TAB in a note (R64e, NOTE_EDITOR.md step 5; the owner's
  choices, 2026-10-17): INS or CTRL-N switch typing over; TAB types spaces
  to the next tab stop, File Properties ▸ Tab size apart (5, as Agenda).
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Core
  alias Agendum.Starters.Planner
  alias Agendum.TUI.{History, State}

  @today ~D[2026-10-12]

  setup do
    db = Planner.build() |> Planner.with_samples(@today)
    state = start(db, today: @today, height: 25, width: 80)
    %{state: state, note: press(state, [:down, {:f, 5}])}
  end

  defp edit(state), do: State.mode(state).edit
  defp line(state, n), do: Enum.at(edit(state).lines, n)
  defp header(state), do: state |> screen() |> String.split("\n") |> hd()

  describe "INS / OVR" do
    test "INS switches to typing over, shown as OVR; again back to INS", %{note: note} do
      over = press(note, :insert)
      assert header(over) =~ ~r/Line +2 OVR EDIT/
      assert header(press(over, :insert)) =~ ~r/Line +2 INS EDIT/
    end

    test "CTRL-N switches it too (it stands for INS)", %{note: note} do
      assert header(press(note, {:ctrl, "n"})) =~ "OVR"
    end

    test "typing over replaces the character under the cursor, at the end adds", %{note: note} do
      typed = press(note, [:home, :home, :insert, "Tel"])
      assert line(typed, 1) == "Tel Anna about the hosting costs."
      assert line(press(typed, [:end, "!"]), 1) == "Tel Anna about the hosting costs.!"
    end
  end

  describe "TAB" do
    test "types spaces to the next tab stop, 5 apart", %{note: note} do
      assert line(press(note, [:home, :home, :tab]), 1) ==
               "     Ask Anna about the hosting costs."

      assert line(press(note, [:home, :home, :right, :right, :tab]), 1) ==
               "As   k Anna about the hosting costs."
    end

    test "with another Tab size", %{state: state} do
      state = %{state | db: Core.set_tab_size(state.db, 8)}
      note = press(state, [:down, {:f, 5}, :home, :home, "x", :tab])
      assert line(note, 1) == "x       Ask Anna about the hosting costs."
    end
  end

  describe "File Properties ▸ Tab size" do
    test "shows 5; a number typed sets it, one undo step", %{state: state} do
      props = state |> press([{:f, 10}, "f", "p"]) |> to_setting("Tab size")
      assert screen(props) =~ ~r/Tab size: +5/

      set = press(props, ["8", :enter])
      assert set.db.tab_size == 8
      assert screen(set) =~ ~r/Tab size: +8/
      assert History.undo(set).db.tab_size == 5
    end

    test "only 1 to 16", %{state: state} do
      props = state |> press([{:f, 10}, "f", "p"]) |> to_setting("Tab size")
      refused = press(props, ["0", :enter])
      assert refused.db.tab_size == 5
      assert {:error, message} = refused.message
      assert message == Agendum.TUI.Messages.text(:bad_number)
    end
  end
end
