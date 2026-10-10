defmodule Agenda.TUI.QuestionsTest do
  @moduledoc "Confirm assignments and Utilities Questions (R16; User's Guide 19-9, 19-12)."
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.Core.Database
  alias Agenda.TUI.State

  setup do
    %{state: start(Agenda.Sample.build(~D[2026-10-08]))}
  end

  defp cat(state, name), do: hd(Database.find_categories(state.db, name))
  defp item(state, text), do: Enum.find(Database.items(state.db), &(&1.text == text))

  # File ▸ Properties; Confirm assignments is the last row
  # Confirm assignments is the last row of File Properties
  @to_confirm List.duplicate(:down, 20)

  defp confirm_always(state),
    do: press(state, [{:f, 10}, "f", "p"] ++ @to_confirm ++ [" ", :esc])

  test "File Properties sets Confirm assignments", %{state: state} do
    state = press(state, [{:f, 10}, "f", "p"])
    assert screen(state) =~ ~r/Confirm assignments\s+: Never/
    state = press(state, @to_confirm ++ [" "])
    assert state.db.confirm_assignments == :always
    assert screen(state) =~ ~r/Confirm assignments\s+: Always/
  end

  test "with Always, a match shows ? and Questions confirms it", %{state: state} do
    state = state |> confirm_always() |> press(["Call Anna about Meetings", :enter])
    new = item(state, "Call Anna about Meetings")
    refute Database.member?(state.db, new.id, cat(state, "Meetings"))
    assert screen(state) =~ "? READY"

    state = press(state, [{:f, 10}, "c", "q"])
    assert %{type: :questions} = State.mode(state)
    text = screen(state)
    assert text =~ "Call Anna about Meetings"
    assert text =~ "Anna Lasky"
    assert text =~ "Meetings"

    # pick the second suggestion only, then ENTER
    state = press(state, [:down, " ", :enter])
    assert state.modes == []
    assert Database.member?(state.db, new.id, cat(state, "Meetings"))
    refute Database.member?(state.db, new.id, cat(state, "Anna Lasky"))
    refute screen(state) =~ "? READY"
  end

  test "TAB picks every suggestion; questions go one item after another", %{state: state} do
    state = state |> confirm_always() |> press(["Ask Anna", :enter, "Plan Meetings", :enter])
    state = press(state, [{:f, 10}, "c", "q", :tab, :enter])
    assert %{type: :questions} = State.mode(state)
    state = press(state, [:tab, :enter])
    assert state.modes == []
    assert Database.member?(state.db, item(state, "Ask Anna").id, cat(state, "Anna Lasky"))
    assert Database.member?(state.db, item(state, "Plan Meetings").id, cat(state, "Meetings"))
  end

  test "with no questions, Questions says so", %{state: state} do
    state = press(state, [{:f, 10}, "c", "q"])
    assert screen(state) =~ "No suggested assignments"
  end
end
