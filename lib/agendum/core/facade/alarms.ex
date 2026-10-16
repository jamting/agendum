defmodule Agendum.Core.Facade.Alarms do
  @moduledoc """
  Times and alarms (R14b, R38): an item's When moment, setting and
  cancelling alarms, ringing them, and the alarm list.

  Called through `Agendum.Core`.
  """

  alias Agendum.Core.Database

  @typep db :: Agendum.Core.db()
  @typep id :: Agendum.Core.id()

  @doc "An item's When date and time (midnight when it has no time), or nil."
  @spec when_at(Agendum.Core.Item.t()) :: NaiveDateTime.t() | nil
  # Matching on a map pattern in the head picks a clause by the item's
  # fields. `time || ~T[00:00:00]`: `||` returns the left side unless it is
  # nil or false; `~T[...]` is a sigil, a literal `Time`.
  def when_at(%{when: nil}), do: nil
  def when_at(%{when: date, when_time: time}), do: NaiveDateTime.new!(date, time || ~T[00:00:00])

  @doc """
  Sets an alarm to ring `minutes` (0 to 60) before the item's When date and
  time (Item Alarm, ALT-A; User's Guide 10-17).
  """
  @spec set_alarm(db, id, integer) :: {:ok, db} | {:error, :no_when | :minutes}
  def set_alarm(db, id, minutes) do
    # `cond` runs the first branch whose condition is truthy; `true` is the
    # else. Returning `{:ok, value} | {:error, reason}` instead of raising is
    # the convention for failures the caller should handle (here the UI
    # turns the atom into a message).
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
  join the past alarms, each with the time it was due (not when it rang,
  which differs for alarms that came due while the file was closed; R38,
  R70). Returns the items that rang.
  """
  @spec ring_alarms(db, NaiveDateTime.t()) :: {db, [id]}
  def ring_alarms(db, %NaiveDateTime{} = now) do
    # `%NaiveDateTime{} = now` in the head only accepts that struct: calling
    # with a `Date` fails at once with a FunctionClauseError instead of
    # somewhere deeper. In the `for`, `at = when_at(item)` binds a value
    # for the filters after it.
    due =
      for item <- Database.items(db),
          item.alarm_minutes != nil,
          at = when_at(item),
          at != nil,
          NaiveDateTime.compare(NaiveDateTime.add(at, -item.alarm_minutes * 60), now) != :gt,
          do: item.id

    db =
      Enum.reduce(due, db, fn id, db ->
        Database.update_item(db, id, &%{&1 | alarm_minutes: nil, alarm_rung_at: due_at(&1)})
      end)

    {db, due}
  end

  # when an item's alarm is due: its minutes before the When moment
  defp due_at(item), do: NaiveDateTime.add(when_at(item), -item.alarm_minutes * 60)

  @doc """
  Current alarms (in When order) and past alarms (latest first): those
  rung since the date last changed (`clear_old_alarms/2` forgets older
  ones as the date changes and as the file is opened), which may have
  been due before today when they came due while the file was closed.
  """
  @spec alarm_list(db) :: %{current: [id], past: [id]}
  def alarm_list(db) do
    items = Database.items(db)

    current =
      items
      |> Enum.filter(&(&1.alarm_minutes != nil))
      # `&when_at/1` captures a named function as a value. Passing the module
      # `NaiveDateTime` as the sorter makes `sort_by` use its `compare/2`:
      # `<` on structs would compare their fields, not the moment.
      |> Enum.sort_by(&when_at/1, NaiveDateTime)
      |> Enum.map(& &1.id)

    past =
      items
      |> Enum.filter(& &1.alarm_rung_at)
      |> Enum.sort_by(& &1.alarm_rung_at, {:desc, NaiveDateTime})
      |> Enum.map(& &1.id)

    %{current: current, past: past}
  end

  @doc """
  Alarms that rang together, for showing at once ("While you were away",
  R70): those with the same text in one group, with how many and when the
  latest was due, the group due latest first. `ids` are rung alarms (their
  items have `alarm_rung_at`); each group's ids are the latest first.
  """
  @spec group_alarms(db, [id]) :: [
          %{text: String.t(), count: pos_integer, at: NaiveDateTime.t(), ids: [id]}
        ]
  def group_alarms(db, ids) do
    # `Enum.group_by/2` gives a map from text to the items with it; each
    # list is sorted latest first, and the groups by their latest
    ids
    |> Enum.map(&db.items[&1])
    |> Enum.group_by(& &1.text)
    |> Enum.map(fn {text, items} ->
      items = Enum.sort_by(items, & &1.alarm_rung_at, {:desc, NaiveDateTime})
      at = hd(items).alarm_rung_at
      %{text: text, count: length(items), at: at, ids: Enum.map(items, & &1.id)}
    end)
    |> Enum.sort_by(& &1.at, {:desc, NaiveDateTime})
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
