defmodule Agendum.TUI.QuestionsTest do
  @moduledoc "Confirm assignments and Utilities Questions (R16; User's Guide 19-9, 19-12)."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core.Database
  alias Agendum.TUI.State

  setup do
    %{state: start(Agendum.Sample.build(~D[2026-10-08]))}
  end

  defp cat(state, name), do: hd(Database.find_categories(state.db, name))
  defp item(state, text), do: Enum.find(Database.items(state.db), &(&1.text == text))

  # File ▸ Properties ▸ Auto-assign settings (beside Global date settings),
  # then down to Confirm assignments, the fourth row of that box
  @to_confirm [:down, :right, " ", :down, :down, :down]

  defp confirm_always(state),
    do: press(state, [{:f, 10}, "f", "p"] ++ @to_confirm ++ [" ", :enter, :enter])

  test "File Properties ▸ Auto-assign settings sets Confirm assignments", %{state: state} do
    state = press(state, [{:f, 10}, "f", "p"] ++ @to_confirm)
    assert screen(state) =~ "Auto-assign settings"
    assert screen(state) =~ ~r/Confirm assignments\s+: Never/
    state = press(state, " ")
    assert state.db.confirm_assignments == :always
    assert screen(state) =~ ~r/Confirm assignments\s+: Always/
    state = press(state, " ")
    assert state.db.confirm_assignments == :sometimes
  end

  test "with Always, a match shows ? and Questions confirms it", %{state: state} do
    state = state |> confirm_always() |> press(["Ring Anna about Meetings", :enter])
    new = item(state, "Ring Anna about Meetings")
    refute Database.member?(state.db, new.id, cat(state, "Meetings"))
    assert screen(state) =~ "? READY"

    state = press(state, [{:f, 10}, "c", "q"])
    assert %{type: :questions} = State.mode(state)
    text = screen(state)
    assert text =~ "Ring Anna about Meetings"
    assert text =~ "Anna Lasky"
    assert text =~ "Meetings"

    # pick Meetings only, then ENTER (suggestions come in preference order)
    [{_, suggested}] = Agendum.Core.questions(state.db)
    downs = Enum.find_index(suggested, &(&1 == cat(state, "Meetings")))
    state = press(state, List.duplicate(:down, downs) ++ [" ", :enter])
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
