# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.AwayTest do
  @moduledoc """
  "While you were away" (R70; meeting 2026-10-16-1905, § 6): alarms that came
  due while the file was closed are listed in a box after the splash
  screen, grouped by text; ringing is not an edit, so it never asks to
  save by itself.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.TUI.{State, Update}

  @yesterday ~N[2026-10-07 10:00:00]

  # a file last used yesterday, with alarms that came due since
  setup do
    db = Agendum.Sample.build(~D[2026-10-07])
    {db, meeting} = Core.add_item(db, "Personnel meeting at 2:00", @yesterday)
    {db, standup} = Core.add_item(db, "Stand-up at 9:00", ~N[2026-10-06 10:00:00])
    {db, standup2} = Core.add_item(db, "Stand-up at 9:00", @yesterday)
    {db, later} = Core.add_item(db, "Review tomorrow at 4pm", @yesterday)

    db =
      Enum.reduce([meeting, standup, standup2, later], db, fn id, db ->
        {:ok, db} = Core.set_alarm(db, id, 5)
        db
      end)

    state = start(db, today: ~D[2026-10-08], now: ~N[2026-10-08 09:00:00], extras: true)
    %{state: state, meeting: meeting, later: later}
  end

  test "the alarms that came due while the file was closed are listed, grouped", %{
    state: state,
    meeting: meeting,
    later: later
  } do
    state = Update.arrive(state)
    text = screen(state)
    assert text =~ "While you were away"
    assert text =~ "3 alarms came due:"
    # the latest first; the two stand-ups on one line, counted
    assert text =~ ~r/10\/07\/26 1:55pm  Personnel meeting at 2:00/
    assert text =~ ~r/10\/07\/26 8:55am  Stand-up at 9:00 ×2/
    assert :binary.match(text, "Personnel") < :binary.match(text, "Stand-up")
    refute text =~ "Review tomorrow"

    # they are past alarms now; the one still to come is not rung
    assert meeting in Core.alarm_list(state.db).past
    assert Core.alarm_list(state.db).current == [later]

    # ringing is not an edit: quitting asks nothing
    refute state.dirty
    {_state, effects} = Update.handle(press(state, :enter), {:ctrl, "q"})
    assert effects == [:quit]
  end

  test "ENTER or ESC closes the box; Show Alarm still lists them", %{state: state} do
    for key <- [:enter, :esc] do
      closed = press(Update.arrive(state), key)
      assert closed.modes == []

      assert screen(press(closed, [{:f, 10}, "u", "s", "a"])) =~
               ~r/!Past Alarms!\n.*Personnel meeting/
    end
  end

  test "the box comes after the splash screen", %{state: state} do
    state = state |> Update.arrive() |> Update.start(false)
    assert %{type: :splash} = State.mode(state)
    refute screen(state) =~ "While you were away"
    assert screen(press(state, :enter)) =~ "While you were away"
  end

  test "no box when nothing came due", %{state: state} do
    state = %{state | now: ~N[2026-10-06 08:00:00], today: ~D[2026-10-06]}
    assert Update.arrive(state).modes == []
  end

  test "a retrieved file shows its alarms too", %{state: state} do
    state = Update.Results.loaded(state, "/home/rabbit/rabbit.agendum", {:ok, state.db, "stamp"})
    assert screen(state) =~ "While you were away"
    refute state.dirty
  end

  test "an alarm ringing while the file is open is not an edit either", %{state: state} do
    state = state |> Update.arrive() |> press(:enter)
    refute state.dirty
    {state, effects} = Update.tick(state, ~N[2026-10-08 15:55:00])
    assert {:sound, :alarm} in effects
    assert screen(state) =~ "Alarm: Review tomorrow at 4pm"
    refute state.dirty

    # an unsaved change stays one
    state = press(state, ["Water the haycorns", :enter])
    assert state.dirty
  end
end
