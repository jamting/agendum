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

  # File ▸ Properties ▸ Auto-assign settings ▸ Confirm assignments
  defp to_confirm(state) do
    state
    |> press([{:f, 10}, "f", "p"])
    |> to_setting("Auto-assign settings")
    |> press(" ")
    |> to_setting("Confirm assignments")
  end

  defp confirm_always(state), do: state |> to_confirm() |> press([" ", :enter, :enter])

  test "File Properties ▸ Auto-assign settings sets Confirm assignments", %{state: state} do
    state = to_confirm(state)
    assert screen(state) =~ "Auto-assign Global Settings"
    assert screen(state) =~ ~r/Confirm assignments:\s+Never/
    state = press(state, " ")
    assert state.db.confirm_assignments == :always
    assert screen(state) =~ ~r/Confirm assignments:\s+Always/
    state = press(state, " ")
    assert state.db.confirm_assignments == :sometimes
  end

  test "with Always, a match shows ? and Questions confirms it", %{state: state} do
    state = state |> confirm_always() |> press(["Ring Anna about Meetings", :enter])
    new = item(state, "Ring Anna about Meetings")
    refute Database.member?(state.db, new.id, cat(state, "Meetings"))
    assert screen(state) =~ "? READY"

    state = press(state, [{:f, 10}, "u", "q"])
    assert %{type: :questions} = State.mode(state)
    # drawn as Agenda's (checked in Agenda 2.0, 2026-10-25): each suggestion
    # as Parent:Child with ? before it until SPACE marks it *
    text = screen(state)
    assert text =~ "Questions"
    assert text =~ ~s(Suggested categories for "Ring Anna about Meetings")
    assert text =~ ~r/\?│ +Contact:Anna Lasky/
    assert text =~ ~r/\?│ +Meetings/
    assert text =~ "Press ENTER to accept"

    # pick Meetings only, then ENTER (suggestions come in preference order)
    [{_, suggested}] = Agendum.Core.questions(state.db)
    downs = Enum.find_index(suggested, &(&1 == cat(state, "Meetings")))
    state = press(state, List.duplicate(:down, downs) ++ [" "])
    assert screen(state) =~ ~r/\* │ +Meetings/
    state = press(state, :enter)
    assert state.modes == []
    assert Database.member?(state.db, new.id, cat(state, "Meetings"))
    refute Database.member?(state.db, new.id, cat(state, "Anna Lasky"))
    refute screen(state) =~ "? READY"
  end

  test "TAB picks every suggestion; questions go one item after another", %{state: state} do
    state = state |> confirm_always() |> press(["Ask Anna", :enter, "Plan Meetings", :enter])
    state = press(state, [{:f, 10}, "u", "q", :tab, :enter])
    assert %{type: :questions} = State.mode(state)
    state = press(state, [:tab, :enter])
    assert state.modes == []
    assert Database.member?(state.db, item(state, "Ask Anna").id, cat(state, "Anna Lasky"))
    assert Database.member?(state.db, item(state, "Plan Meetings").id, cat(state, "Meetings"))
  end

  # Agenda's box (checked 2026-10-25), which any key closes
  test "with no questions, Questions says so in a box", %{state: state} do
    state = press(state, [{:f, 10}, "u", "q"])
    assert %{type: :questions} = State.mode(state)
    assert screen(state) =~ "There are no assignments to be confirmed."
    assert screen(state) =~ "Press any key to continue"
    assert press(state, "x").modes == []
  end
end
