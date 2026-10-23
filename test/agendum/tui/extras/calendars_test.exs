defmodule Agendum.TUI.Extras.CalendarsTest do
  @moduledoc """
  File ▸ Transfer ▸ Calendars (R45): subscribing to a calendar on the web,
  reading it now or on schedule, and what a refresh does to the view. The
  shell downloads; these tests check the effects and feed the results.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core.Extras.ICal.Event
  alias Agendum.TUI.{History, State, Update}

  @url "https://example.com/work.ics"

  setup do
    state = start(Agendum.Sample.build(~D[2026-10-12]), extras: true)
    %{state: %{state | now: ~N[2026-10-12 10:00:00], today: ~D[2026-10-12]}}
  end

  defp keys(state, keys) do
    Enum.reduce(List.wrap(keys), {state, []}, fn key, {state, effects} ->
      key = if is_binary(key), do: {:char, key}, else: key
      {state, new} = Update.handle(state, key)
      {state, effects ++ new}
    end)
  end

  defp typed(text), do: String.graphemes(text) ++ [:enter]

  # subscribes to Work, returning the state and the calendar's id
  defp subscribe(state) do
    {state, effects} =
      keys(state, [{:f, 10}, "f", "t", "c", :insert] ++ typed(@url) ++ typed("Work"))

    [{:fetch_calendar, id, @url}] = effects
    {state, id}
  end

  defp events,
    do: [
      %Event{uid: "a", summary: "Organising Meeting", start: {:local, ~N[2026-10-16 14:00:00]}},
      %Event{uid: "b", summary: "Tea", start: {:date, ~D[2026-10-13]}}
    ]

  test "the Calendars box lists subscriptions, and says how to add one", %{state: state} do
    state = press(state, [{:f, 10}, "f", "t", "c"])
    assert %{type: :calendars} = State.mode(state)
    assert screen(state) =~ "No calendars yet · INS subscribes to one"
  end

  test "INS asks for the address and a name, then reads the calendar at once", %{state: state} do
    {state, id} = subscribe(state)
    assert state.db.calendars[id].name == "Work"
    assert %{type: :calendars} = State.mode(state)
    assert screen(state) =~ ~r/Work +reading…/
  end

  test "a bad address is refused", %{state: state} do
    {state, effects} =
      keys(state, [{:f, 10}, "f", "t", "c", :insert] ++ typed("ftp://nope") ++ typed("Work"))

    assert effects == [{:sound, :error}]
    assert screen(state) =~ "needs an https:// or webcal:// address"
    assert state.db.calendars == %{}
  end

  test "what is read becomes items; one undo step takes it back", %{state: state} do
    {state, id} = subscribe(state)
    state = Update.calendar_read(state, id, {:ok, events()})
    texts = state.db.items |> Map.values() |> Enum.map(& &1.text)
    assert "Organising Meeting" in texts
    assert screen(state) =~ "Work: 2 new"
    assert screen(state) =~ ~r/Work +read 2026-10-12 10:00/

    state = History.undo(state)
    refute "Organising Meeting" in (state.db.items |> Map.values() |> Enum.map(& &1.text))
  end

  test "a failed read shows in the box", %{state: state} do
    {state, id} = subscribe(state)
    state = Update.calendar_read(state, id, {:error, "could not connect"})
    assert screen(state) =~ "could not connect"
    assert state.db.calendars[id].error == "could not connect"
  end

  test "calendars due are read on the clock's tick, one read at a time", %{state: state} do
    {state, id} = subscribe(state)
    state = Update.calendar_read(state, id, {:ok, events()})
    {state, effects} = Update.tick(state, ~N[2026-10-12 10:30:00])
    assert effects == []
    {state, effects} = Update.tick(state, ~N[2026-10-12 11:00:00])
    assert effects == [{:fetch_calendar, id, @url}]
    {_state, effects} = Update.tick(state, ~N[2026-10-12 11:00:30])
    assert effects == []
  end

  test "a scheduled read changes the view quietly when nothing changed", %{state: state} do
    {state, id} = subscribe(state)
    state = Update.calendar_read(state, id, {:ok, events()})
    state = press(state, :esc) |> press(:esc)
    {state, _} = Update.tick(state, ~N[2026-10-12 11:00:00])
    state = Update.calendar_read(state, id, {:ok, events()})
    refute screen(state) =~ "Work:"
  end

  test "ENTER reads it now; F and A change how often and how far ahead", %{state: state} do
    {state, id} = subscribe(state)
    state = Update.calendar_read(state, id, {:ok, events()})
    {state, effects} = keys(state, :enter)
    assert effects == [{:fetch_calendar, id, @url}]
    state = Update.calendar_read(state, id, {:ok, events()})
    {state, _} = keys(state, ["f", "a"])
    assert state.db.calendars[id].refresh_minutes == 360
    assert state.db.calendars[id].ahead_days == 180
    assert screen(state) =~ "every 6 hours"
    assert screen(state) =~ "180 days ahead"
  end

  test "DEL unsubscribes: Y also discards its items, N keeps them", %{state: state} do
    {state, id} = subscribe(state)
    state = Update.calendar_read(state, id, {:ok, events()})

    {asked, _} = keys(state, :delete)
    assert screen(asked) =~ "Unsubscribe from Work. Discard its 2 items too?"

    {kept, _} = keys(asked, "n")
    assert kept.db.calendars == %{}
    assert "Tea" in (kept.db.items |> Map.values() |> Enum.map(& &1.text))

    {gone, _} = keys(asked, "y")
    refute "Tea" in (gone.db.items |> Map.values() |> Enum.map(& &1.text))

    {cancelled, _} = keys(asked, :esc)
    assert Map.has_key?(cancelled.db.calendars, id)
  end
end
