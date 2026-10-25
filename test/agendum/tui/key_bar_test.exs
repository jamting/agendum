defmodule Agendum.TUI.KeyBarTest do
  @moduledoc """
  The key bar (SPEC § The key bar): in a view, a note, the category and
  view managers, a box and the menu Agenda's two lines of ten slots (R80);
  while typing one line of hints, whose entries that do not fit are left
  out whole, never cut mid-word: the last entries go.
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

  for width <- [80, 64] do
    test "a box at #{width} columns has Agenda's slots, not a line of hints" do
      state = unquote(width) |> planner() |> press([{:f, 10}, "v", "p"])
      [keys, labels] = texts(state)
      assert keys =~ ~r/^ +F1 +│ +F2 +│/
      # narrower slots cut their labels, as a view's do
      assert labels =~ ~r/^ ?Help +│ ?Edit +│Choic/
      refute labels =~ "SPACE"
    end
  end

  test "typing in a box's field keeps a line of hints, ENTER and ESC last to go" do
    state = 80 |> planner() |> press([{:f, 10}, "v", "p"]) |> to_setting("Item sorting")
    state = state |> press(:right) |> press("Calls")
    assert Map.get(State.mode(state), :typing) != nil or state.edit != nil
    assert String.trim(hd(texts(state))) == ""
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
             " Help  │ Edit  │       │       │ Note  │ Props │Promote│Demote │To View│ Menu   "
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

  test "the view shows one row fewer, and hiding the bar gives both lines back" do
    state = planner(80)
    assert State.body_height(state) == 21
    # ALT-K shows the ALT, CTRL and SHIFT keys first, then hides the bar
    state = press(state, List.duplicate({:alt, "k"}, 4))
    assert State.body_height(state) == 23
    assert state |> screen() |> String.split("\n") |> length() == 25
  end

  describe "ALT-K shows the ALT, CTRL and SHIFT keys in turn (meeting 2026-10-24, § 5)" do
    test "normal, ALT, CTRL, SHIFT, hidden, normal: Agenda's bars" do
      state = planner(80)
      alt = press(state, {:alt, "k"})

      assert texts(alt) == [
               " AltF1 │ AltF2 │ AltF3 │ AltF4 │ AltF5 │ AltF6 │ AltF7 │ AltF8 │ AltF9 │AltF10  ",
               "       │ When  │ Macro │Discard│ Go To │Search │UnmkAll│Last Vw│ Copy  │ Move   "
             ]

      ctrl = press(alt, {:alt, "k"})
      assert [" CtlF1 │" <> _, _] = texts(ctrl)

      shift = press(ctrl, {:alt, "k"})
      assert [" ShfF1 │" <> _, _] = texts(shift)

      hidden = press(shift, {:alt, "k"})
      refute hidden.key_map
      assert State.body_height(hidden) == State.body_height(state) + 2

      back = press(hidden, {:alt, "k"})
      assert texts(back) == texts(state)
    end

    test "a macro on a SHIFT-F key shows by its name on the SHIFT bar" do
      {:ok, db, id} = Agendum.Core.add_macro(Planner.build(), "Weekly review")
      db = db |> Agendum.Core.set_macro_keys(id, "x") |> Agendum.Core.attach_macro(id, "{ShfF10}")
      state = start(db, width: 80, height: 25)
      [_, labels] = state |> press(List.duplicate({:alt, "k"}, 3)) |> texts()
      assert labels =~ "│Weekly  "
    end

    test "only shown or hidden is kept: the preference saves only when the bar hides or shows" do
      state = planner(80) |> Map.update!(:prefs, &%{&1 | path: "/tmp/prefs"})
      saves = fn s -> Enum.filter(s.effects, &match?({:save_preferences, _, _}, &1)) end
      {alt, effects} = Agendum.TUI.Update.handle(state, {:alt, "k"})
      assert alt.key_map == :alt
      refute Enum.any?(effects, &match?({:save_preferences, _, _}, &1))
      assert saves.(alt) == []

      {hidden, effects} =
        Enum.reduce(1..3, {alt, []}, fn _, {s, _} -> Agendum.TUI.Update.handle(s, {:alt, "k"}) end)

      refute hidden.key_map

      assert [{:save_preferences, _, %{key_map: false}}] =
               Enum.filter(effects, &match?({:save_preferences, _, _}, &1))
    end
  end
end
