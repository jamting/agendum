defmodule Agendum.TUI.AlarmsTest do
  @moduledoc "Times of day, the clock and alarms in the TUI (R14b, R38)."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.TUI.{Layout, State, Update}

  setup do
    %{state: start(Agendum.Sample.build(~D[2026-10-08]), now: ~N[2026-10-08 10:00:00])}
  end

  defp current(state), do: Layout.current_row(state).item

  test "the title bar shows the date and time", %{state: state} do
    assert screen(state) =~ "10/08/26 10:00am"
    {state, []} = Update.tick(state, ~N[2026-10-08 10:01:30])
    assert screen(state) =~ "10/08/26 10:01am"
  end

  test "a time in the text shows in the When column", %{state: state} do
    state = press(state, ["Call Bob Tuesday at 3:00", :enter])
    assert screen(state) =~ ~r/Call Bob Tuesday at 3:00[\s»]+10\/13\/26 3:00pm/
  end

  test "ALT-A sets an alarm (default 5 minutes before) and the item shows @", %{state: state} do
    state = press(state, ["Personnel meeting at 2:00", :enter, {:alt, "a"}])
    assert screen(state) =~ "Alarm: minutes before the When time"

    state = press(state, :enter)
    assert current(state).alarm_minutes == 5
    assert screen(state) =~ "Alarm set for 10/08/26 1:55pm"
    assert screen(state) =~ "@ Personnel meeting"
  end

  test "the alarm message uses the file's date format (R41)", %{state: state} do
    format = %Agendum.Core.DateFormat{order: :ddmmyy, separator: ".", clock: 12}
    state = %{state | db: Agendum.Core.set_date_format(state.db, format)}
    state = press(state, ["Personnel meeting at 2:00", :enter, {:alt, "a"}, :enter])
    assert screen(state) =~ "Alarm set for 08.10.26 1:55pm"
  end

  test "ALT-A again cancels; an item without a When date cannot have an alarm", %{state: state} do
    state = press(state, ["Personnel meeting at 2:00", :enter, {:alt, "a"}, :enter, {:alt, "a"}])
    assert current(state).alarm_minutes == nil

    # the new item went to the top of the section; the "Don't forget to call
    # Anna Lasky..." item two rows below it has no When date
    state = press(state, [:home, :down, :down, :down, {:alt, "a"}])
    assert current(state).text =~ "Anna Lasky"
    assert current(state).when == nil
    assert panel(state) =~ message(:needs_date)
  end

  test "an alarm rings on the tick when its time comes", %{state: state} do
    state = press(state, ["Personnel meeting at 2:00", :enter, {:alt, "a"}, :enter])
    {state, []} = Update.tick(state, ~N[2026-10-08 13:54:00])

    {state, effects} = Update.tick(state, ~N[2026-10-08 13:55:00])
    assert effects == [{:sound, :alarm}]
    assert screen(state) =~ "Alarm: Personnel meeting at 2:00"
    assert state.alarm_rang
    assert current(state).alarm_minutes == nil
  end

  test "the alarm list shows current and past alarms; DEL removes a past one", %{state: state} do
    state = press(state, ["Personnel meeting at 2:00", :enter, {:alt, "a"}, :enter])
    state = press(state, ["Review at 4pm", :enter, {:alt, "a"}, {:ctrl, "u"}, "10", :enter])
    {state, _} = Update.tick(state, ~N[2026-10-08 14:00:00])

    state = press(state, [{:f, 10}, "u", "s", "a"])
    refute state.alarm_rang
    screen = screen(state)
    assert screen =~ "Alarm list"
    assert screen =~ ~r/Review at 4pm.*rings 10\/08\/26 3:50pm/
    assert screen =~ ~r/Personnel meeting at 2:00.*rang 1:55pm/

    state = press(state, [:down, :delete])
    assert Agendum.Core.alarm_list(state.db).past == []
    assert %{type: :alarm_list} = State.mode(state)
  end

  test "the day's past alarms are forgotten when the date changes", %{state: state} do
    state = press(state, ["Personnel meeting at 2:00", :enter, {:alt, "a"}, :enter])
    {state, _} = Update.tick(state, ~N[2026-10-08 14:00:00])
    {state, _} = Update.tick(state, ~N[2026-10-09 00:00:05])
    assert Agendum.Core.alarm_list(state.db).past == []
    assert state.today == ~D[2026-10-09]
  end
end
