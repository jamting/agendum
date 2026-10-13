defmodule Agenda.TUI.FitColumnTest do
  @moduledoc "View ▸ Column ▸ Fit (R22a): the highlighted column fitted to its contents."
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.Core.Database

  setup do
    %{state: start(Agenda.Sample.build(~D[2026-10-08]))}
  end

  defp contact_width(state) do
    [view] = Database.views(state.db)
    view |> Agenda.Core.View.columns(0) |> Enum.at(2) |> Map.fetch!(:width)
  end

  test "fits the highlighted column, as one undo step", %{state: state} do
    # Contact, 16 wide, is the third column
    state = press(state, [:down, :right, :right, :right, {:f, 10}, "v", "c", "f"])
    assert contact_width(state) == 14
    assert screen(state) =~ "Abigail Scheer"
    assert state |> Agenda.TUI.History.undo() |> contact_width() == 16
  end

  test "asks for a column first", %{state: state} do
    state = press(state, [{:f, 10}, "v", "c", "f"])
    assert panel(state) =~ "Highlight a column first"
  end
end
