defmodule Agendum.TUI.Boxes.AlarmList do
  @moduledoc """
  The alarm list (Search ▸ Alarms; Agenda's Utilities Show Alarm, User's
  Guide 10-18 to 10-20): items with alarms set, and today's alarms that
  have gone off. DEL on a past alarm removes it from the list, ALT-A on a
  current one cancels it. Opening the list clears the alarm symbol in the
  title. Agenda shows this as a Show View with !Current Alarms! and !Past
  Alarms! sections; ours is a box. Pure.
  """

  alias Agendum.Core
  alias Agendum.TUI.State

  def open(state), do: State.push(%{state | alarm_rang: false}, %{type: :alarm_list, cursor: 0})

  @doc "The rows: `{:current, id}` and `{:past, id}`."
  def rows(state) do
    %{current: current, past: past} = Core.alarm_list(state.db, state.today)
    Enum.map(current, &{:current, &1}) ++ Enum.map(past, &{:past, &1})
  end

  def handle(state, mode, key) do
    rows = rows(state)
    mode = %{mode | cursor: mode.cursor |> min(length(rows) - 1) |> max(0)}
    row = Enum.at(rows, mode.cursor)

    case {key, row} do
      {k, _} when k in [:esc, :enter] ->
        State.pop(state)

      {:up, _} ->
        State.put_mode(state, %{mode | cursor: max(mode.cursor - 1, 0)})

      {:down, _} ->
        State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, max(length(rows) - 1, 0))})

      {:delete, {:past, id}} ->
        State.change_db(state, Core.remove_past_alarm(state.db, id))

      {{:alt, "a"}, {:current, id}} ->
        state |> State.change_db(Core.cancel_alarm(state.db, id)) |> State.info("Alarm cancelled")

      _ ->
        State.put_mode(state, mode)
    end
  end
end
