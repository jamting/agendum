defmodule Agenda.TUI.ColumnWidthTest do
  @moduledoc """
  View ▸ Column ▸ Width (User's Guide 5-21 to 5-22): the highlighted
  column's width, shown in the control panel and changed with ← →, by
  typing a number, or fitted to its contents with SHIFT-? (R22a). The view
  shows the new width at once; ENTER keeps it, one undo step, and ESC goes
  back to the old one.
  """
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.Core.{Database, View}
  alias Agenda.TUI.{History, State}

  # the sample's Activities view; Contact, 16 wide, is the third column
  setup do
    state = start(Agenda.Sample.build(~D[2026-10-08]))
    %{state: press(state, [:down, :right, :right, :right])}
  end

  @width [{:f, 10}, "v", "c", "w"]

  defp contact_width(state) do
    [view] = Database.views(state.db)
    view |> View.columns(0) |> Enum.at(2) |> Map.fetch!(:width)
  end

  # the width the view shows, which may be the one being chosen
  defp shown_width(state),
    do: state |> State.view() |> View.columns(0) |> Enum.at(2) |> Map.fetch!(:width)

  test "shows the width; ← → change it in the view, ENTER keeps it, one undo step",
       %{state: state} do
    state = press(state, @width)
    assert panel(state) =~ "Column width: 16"
    state = press(state, [:left, :left, :left])
    assert panel(state) =~ "Column width: 13"
    assert shown_width(state) == 13
    # the file is not changed until ENTER
    assert contact_width(state) == 16
    state = press(state, :enter)
    assert State.mode(state) == nil
    assert contact_width(state) == 13
    assert state |> History.undo() |> contact_width() == 16
  end

  test "a typed number replaces the width", %{state: state} do
    state = press(state, @width ++ ["1", "0"])
    assert panel(state) =~ "Column width: 10"
    # the column ends right after the short names (User's Guide 19-2)
    assert screen(state) =~ ~r/Low\s+Abigail\n/
    state = press(state, [:backspace, :backspace, "2", "0", :enter])
    assert contact_width(state) == 20
  end

  test "ESC goes back to the old width", %{state: state} do
    state = press(state, @width ++ [:right, :right, :esc])
    assert State.mode(state) == nil
    assert {contact_width(state), shown_width(state)} == {16, 16}
    assert state.undo == []
  end

  test "SHIFT-? fits the column to its head and entries (R22a)", %{state: state} do
    state = press(state, @width ++ ["?"])
    assert panel(state) =~ "Column width: 14"
    assert screen(state) =~ "Abigail Scheer"
    state = press(state, :enter)
    assert contact_width(state) == 14
    assert state |> History.undo() |> contact_width() == 16
  end

  test "asks for a column first", %{state: state} do
    state = press(state, [:left, :left, :left] ++ @width)
    assert panel(state) =~ "Highlight a column"
  end
end
