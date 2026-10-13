defmodule Agenda.Core.Facade.Alarms do
  @moduledoc """
  Times and alarms (R14b, R38): an item's When moment, setting and
  cancelling alarms, ringing them, and the alarm list.

  Called through `Agenda.Core`.
  """

  alias Agenda.Core.Database

  @typep db :: Agenda.Core.db()
  @typep id :: Agenda.Core.id()

  @doc "An item's When date and time (midnight when it has no time), or nil."
  @spec when_at(Agenda.Core.Item.t()) :: NaiveDateTime.t() | nil
  def when_at(%{when: nil}), do: nil
  def when_at(%{when: date, when_time: time}), do: NaiveDateTime.new!(date, time || ~T[00:00:00])

  @doc """
  Sets an alarm to ring `minutes` (0 to 60) before the item's When date and
  time (Item Alarm, ALT-A; User's Guide 10-17).
  """
  @spec set_alarm(db, id, integer) :: {:ok, db} | {:error, :no_when | :minutes}
  def set_alarm(db, id, minutes) do
    cond do
      minutes not in 0..60 -> {:error, :minutes}
      db.items[id].when == nil -> {:error, :no_when}
      true -> {:ok, Database.update_item(db, id, &%{&1 | alarm_minutes: minutes})}
    end
  end

  @spec cancel_alarm(db, id) :: db
  def cancel_alarm(db, id), do: Database.update_item(db, id, &%{&1 | alarm_minutes: nil})

  @doc """
  Rings the alarms whose time has come: they leave the current alarms and
  join today's past alarms. Returns the items that rang.
  """
  @spec ring_alarms(db, NaiveDateTime.t()) :: {db, [id]}
  def ring_alarms(db, %NaiveDateTime{} = now) do
    due =
      for item <- Database.items(db),
          item.alarm_minutes != nil,
          at = when_at(item),
          at != nil,
          NaiveDateTime.compare(NaiveDateTime.add(at, -item.alarm_minutes * 60), now) != :gt,
          do: item.id

    db =
      Enum.reduce(
        due,
        db,
        &Database.update_item(&2, &1, fn i -> %{i | alarm_minutes: nil, alarm_rung_at: now} end)
      )

    {db, due}
  end

  @doc "Current alarms (in When order) and today's past alarms (latest first)."
  @spec alarm_list(db, Date.t()) :: %{current: [id], past: [id]}
  def alarm_list(db, %Date{} = today) do
    items = Database.items(db)

    current =
      items
      |> Enum.filter(&(&1.alarm_minutes != nil))
      |> Enum.sort_by(&when_at/1, NaiveDateTime)
      |> Enum.map(& &1.id)

    past =
      items
      |> Enum.filter(&(&1.alarm_rung_at && NaiveDateTime.to_date(&1.alarm_rung_at) == today))
      |> Enum.sort_by(& &1.alarm_rung_at, {:desc, NaiveDateTime})
      |> Enum.map(& &1.id)

    %{current: current, past: past}
  end

  @doc "Removes an item from the past alarms (DEL in the alarm list)."
  @spec remove_past_alarm(db, id) :: db
  def remove_past_alarm(db, id), do: Database.update_item(db, id, &%{&1 | alarm_rung_at: nil})

  @doc "Forgets past alarms from earlier days (Agenda clears them at the end of the day)."
  @spec clear_old_alarms(db, Date.t()) :: db
  def clear_old_alarms(db, %Date{} = today) do
    old =
      for i <- Database.items(db),
          i.alarm_rung_at && Date.compare(NaiveDateTime.to_date(i.alarm_rung_at), today) == :lt,
          do: i.id

    Enum.reduce(old, db, &remove_past_alarm(&2, &1))
  end
end
