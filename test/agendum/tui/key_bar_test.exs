defmodule Agendum.TUI.KeyBarTest do
  @moduledoc """
  The key bar (SPEC § The key bar): in a view, a note and the category and
  view managers Agenda's two lines of ten slots (R80); elsewhere one line of
  hints, whose entries that do not fit are left out whole, never cut
  mid-word. A box drops ENTER and ESC first, as its bottom edge names them;
  elsewhere the last entries go.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Starters.Planner
  alias Agendum.TUI.{Render.KeyBar, State}

  @today ~D[2026-10-12]

  defp planner(width) do
    Planner.build()
    |> Planner.with_samples(@today)
    |> start(today: @today, width: width, height: 25)
  end

  # the bar's lines as text
  defp texts(state),
    do: state |> KeyBar.lines() |> Enum.map(fn line -> Enum.map_join(line, &elem(&1, 1)) end)

  # the hint line of a place without slots (the bottom one; the top is empty)
  defp bar(state) do
    [top, bottom] = texts(state)
    assert String.trim(top) == ""
    String.trim(bottom)
  end

  # the box's keys as the short bar writes them, "F2 Edit"
  defp entries(state) do
    mode = State.mode(state)

    Agendum.TUI.Boxes.Box.registry()[mode.type].keys(state, mode)
    |> Enum.map(&(elem(&1, 0) <> " " <> elem(&1, 1)))
  end

  # the bar is some of the entries, whole, in their order
  defp whole_entries!(state) do
    bar = bar(state)
    shown = Enum.filter(entries(state), &String.contains?(bar, &1))
    assert bar == Enum.join(shown, " ")
    shown
  end

  for width <- [80, 64] do
    test "View Properties at #{width} columns: whole entries, ENTER and ESC dropped first" do
      state = unquote(width) |> planner() |> press([{:f, 10}, "v", "p"])
      shown = whole_entries!(state)
      assert "SPACE Change" in shown
      refute Enum.any?(shown, &String.starts_with?(&1, ["ENTER", "ESC"]))
    end

    test "Section Properties at #{width} columns: whole entries" do
      state = unquote(width) |> planner() |> press({:f, 6})
      assert %{type: :section_props} = State.mode(state)
      whole_entries!(state)
    end
  end

  test "a box whose keys all fit keeps ENTER and ESC" do
    state = 120 |> planner() |> press([{:f, 10}, "v", "p"])
    shown = whole_entries!(state)
    assert "ENTER Done" in shown
    assert "ESC Cancel" in shown
  end

  test "outside a box, the last entries go first: ENTER and ESC stay" do
    state = 33 |> planner() |> press({:f, 2})
    assert state.edit != nil
    # "^A/^E Start/End" and "^U Clear" do not fit 33 columns
    assert bar(state) == "ENTER Done ESC Cancel ←→ Move"
  end

  # Agenda's own bar in a view, read in DOSBox (PLANNER, 2026-10-24)
  @agenda_view [
    "  F1   │  F2   │  F3   │  F4   │  F5   │  F6   │  F7   │  F8   │  F9   │  F10   ",
    " Help  │ Edit  │Choices│ Done  │ Note  │ Props │ Mark  │Vw Mgr │Cat Mgr│ Menu   "
  ]

  test "a view at 80 columns has Agenda's two lines, F10 Menu included (R80)" do
    state = planner(80)
    assert texts(state) == @agenda_view
    # the bar is the screen's last two lines
    assert state |> screen() |> String.split("\n") |> Enum.take(-2) ==
             Enum.map(@agenda_view, &String.trim_trailing/1)
  end

  test "a key that does nothing there leaves its slot empty, so the keys stay in place" do
    state = 80 |> planner() |> press({:f, 9})
    [keys, labels] = texts(state)
    assert keys == Enum.at(@agenda_view, 0)

    assert labels ==
             " Help  │ Edit  │       │       │ Note  │ Props │Promote│Demote │To View│To View "
  end

  test "a note names Agenda's keys in their slots, not the ALT keys" do
    state = 80 |> planner() |> press({:f, 5})
    assert %{type: :note} = State.mode(state)
    [_, labels] = texts(state)

    assert labels ==
             " Help  │ Paste │ Copy  │  Cut  │Return │       │ Mark  │       │       │ Menu   "
  end

  test "a wider screen widens the slots evenly, with the fuller labels when the extras are on" do
    [keys, labels] = 130 |> planner() |> texts()
    assert String.length(keys) == 130
    assert labels =~ "│   Vw Mgr   │"

    # the commands' own names, when every one fits its slot
    extras = &(&1 |> planner() |> Map.update!(:prefs, fn p -> %{p | extras: true} end) |> texts())
    assert [_, "    Help    │" <> _] = extras.(130)
    [_, labels] = extras.(170)
    assert labels =~ "│  View manager  │Category manager│"
  end

  test "the view shows one row fewer, and ALT-K hides both lines" do
    state = planner(80)
    assert State.body_height(state) == 21
    state = press(state, {:alt, "k"})
    assert State.body_height(state) == 23
    assert state |> screen() |> String.split("\n") |> length() == 25
  end
end
