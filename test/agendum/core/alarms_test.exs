defmodule Agendum.Core.AlarmsTest do
  @moduledoc """
  Times of day on When dates (SPEC R14b) and alarms (SPEC R38; User's
  Guide 10-16 to 10-20).
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.{Database, ViewModel}

  @now ~N[2026-10-08 10:00:00]

  setup do
    %{db: Core.new_file()}
  end

  describe "times of day" do
    test "a time in the item text sets the When date and time", %{db: db} do
      {db, id} = Core.add_item(db, "Call Marketing Tuesday at 3:00", @now)
      assert {db.items[id].when, db.items[id].when_time} == {~D[2026-10-13], ~T[15:00:00]}
      assert db.items[id].entry == ~D[2026-10-08]
    end

    test "a relative time uses the current time", %{db: db} do
      {db, id} = Core.add_item(db, "call Bob in 2 hours", @now)
      assert Core.when_at(db.items[id]) == ~N[2026-10-08 12:00:00]
    end

    test "typing a date and time into the When column", %{db: db} do
      {db, id} = Core.add_item(db, "x", @now)
      {:ok, db, :date} = Core.assign_by_name(db, id, db.special.when, "friday 4pm", @now)
      assert Core.when_at(db.items[id]) == ~N[2026-10-09 16:00:00]
      assert db.items[id].when_explicit
    end

    test "the When column shows the time; removing the date removes it", %{db: db} do
      {db, id} = Core.add_item(db, "standup tomorrow 9:30", @now)
      [view] = Database.views(db)
      [%{category_id: section}] = view.sections
      db = Core.assign(db, id, section)
      [%{rows: [row]}] = ViewModel.build(db, view)
      assert hd(row.cells) == "10/09/26 9:30am"

      db = Core.remove_from_category(db, id, db.special.when)
      assert {db.items[id].when, db.items[id].when_time} == {nil, nil}
    end
  end

  describe "alarms" do
    setup %{db: db} do
      {db, id} = Core.add_item(db, "Personnel meeting at 2:00", @now)
      %{db: db, id: id}
    end

    test "an alarm is set N minutes before the When time (0 to 60)", %{db: db, id: id} do
      assert {:ok, db} = Core.set_alarm(db, id, 5)
      assert db.items[id].alarm_minutes == 5
      assert Core.set_alarm(db, id, 61) == {:error, :minutes}
    end

    # Agenda 2.0 (checked 2026-10-25): an item without a date takes an
    # alarm too; it shows @ and waits among the current alarms
    test "an item without a date takes an alarm, which waits", %{db: db} do
      {db, plain} = Core.add_item(db, "no date here", @now)
      assert {:ok, db} = Core.set_alarm(db, plain, 5)
      assert Core.alarm_list(db).current == [plain]
      assert {^db, []} = Core.ring_alarms(db, ~N[2030-01-01 00:00:00])
    end

    # Set Alarm's Date category (User's Guide 10-18): When by default, or
    # another date category, whose date and time the alarm rings before
    test "an alarm can ring before the date of another date category", %{db: db} do
      {:ok, db, due} = Core.add_category(db, db.main_id, "Due")
      {:ok, db} = Core.make_date(db, due, ~D[2026-10-08])
      {db, bill} = Core.add_item(db, "Pay the bill", @now)
      db = Core.set_date_time(db, bill, due, ~D[2026-10-09], ~T[12:00:00], @now)

      assert {:ok, db} = Core.set_alarm(db, bill, 10, due)
      assert db.items[bill].alarm_category == due
      assert Core.alarm_at(db, db.items[bill]) == ~N[2026-10-09 12:00:00]
      assert {_, []} = Core.ring_alarms(db, ~N[2026-10-09 11:49:00])
      assert {_, [^bill]} = Core.ring_alarms(db, ~N[2026-10-09 11:50:00])

      {:ok, db, entry} = {:ok, db, db.special.entry}
      assert Core.set_alarm(db, bill, 5, db.main_id) == {:error, :not_a_date_category}
      assert {:ok, _} = Core.set_alarm(db, bill, 5, entry)

      # its category deleted, the alarm goes back to When
      {:ok, db} = Core.discard_category(db, due)
      assert db.items[bill].alarm_category == nil
      assert db.items[bill].alarm_minutes == 10
    end

    test "the alarm rings when its time comes, and moves to the past alarms", %{db: db, id: id} do
      {:ok, db} = Core.set_alarm(db, id, 5)
      assert {^db, []} = Core.ring_alarms(db, ~N[2026-10-08 13:54:00])

      {db, rung} = Core.ring_alarms(db, ~N[2026-10-08 13:55:00])
      assert rung == [id]
      assert db.items[id].alarm_minutes == nil
      assert Core.alarm_list(db) == %{current: [], past: [id]}
    end

    test "the alarm list shows current alarms; past ones are cleared the next day", %{
      db: db,
      id: id
    } do
      {:ok, db} = Core.set_alarm(db, id, 0)
      assert Core.alarm_list(db) == %{current: [id], past: []}

      {db, _} = Core.ring_alarms(db, ~N[2026-10-08 14:00:00])
      assert Core.alarm_list(Core.clear_old_alarms(db, ~D[2026-10-09])).past == []
    end

    # R70: an alarm that came due while the file was closed keeps when it was due
    test "a rung alarm records when it was due, not when it rang", %{db: db, id: id} do
      {:ok, db} = Core.set_alarm(db, id, 5)
      {db, [^id]} = Core.ring_alarms(db, ~N[2026-10-10 08:00:00])
      assert db.items[id].alarm_rung_at == ~N[2026-10-08 13:55:00]
      # still a past alarm until the date changes
      assert Core.alarm_list(db).past == [id]
      assert Core.alarm_list(Core.clear_old_alarms(db, ~D[2026-10-09])).past == []
    end

    test "alarms that rang together are grouped by text, the latest first", %{db: db, id: id} do
      {db, standup} = Core.add_item(db, "Stand-up at 9:00", @now)
      {db, standup2} = Core.add_item(db, "Stand-up tomorrow at 9:00", @now)
      db = Database.update_item(db, standup2, &%{&1 | text: "Stand-up at 9:00"})
      db = Enum.reduce([id, standup, standup2], db, &elem(Core.set_alarm(&2, &1, 0), 1))
      {db, rung} = Core.ring_alarms(db, ~N[2026-10-10 08:00:00])

      assert Core.group_alarms(db, rung) == [
               %{
                 text: "Stand-up at 9:00",
                 count: 2,
                 at: ~N[2026-10-09 09:00:00],
                 ids: [standup2, standup]
               },
               %{
                 text: "Personnel meeting at 2:00",
                 count: 1,
                 at: ~N[2026-10-08 14:00:00],
                 ids: [id]
               }
             ]
    end

    test "cancelling an alarm and removing a past one", %{db: db, id: id} do
      {:ok, db} = Core.set_alarm(db, id, 5)
      assert Core.cancel_alarm(db, id).items[id].alarm_minutes == nil

      {db, _} = Core.ring_alarms(db, ~N[2026-10-08 14:00:00])
      assert Core.alarm_list(Core.remove_past_alarm(db, id)).past == []
    end

    # Utilities Show Alarm (User's Guide 10-18 to 10-20; checked in Agenda
    # 2.0, 2026-10-25): the Show View with two sections, !Current Alarms!
    # and !Past Alarms!, the latest first
    test "the alarm list is the Show View's two sections", %{db: db, id: id} do
      {db, later} = Core.add_item(db, "Review at 4pm", @now)
      {:ok, db} = Core.set_alarm(db, id, 5)
      {:ok, db} = Core.set_alarm(db, later, 10)
      {db, [^id]} = Core.ring_alarms(db, ~N[2026-10-08 14:00:00])

      {db, view_id} = Core.show_alarms(db)
      [current, past] = ViewModel.build(db, db.views[view_id])
      assert {current.category.name, past.category.name} == {"!Current Alarms!", "!Past Alarms!"}
      assert {current.alarms, past.alarms} == {:current, :past}
      assert Enum.map(current.rows, & &1.item.id) == [later]
      assert Enum.map(past.rows, & &1.item.id) == [id]
    end
  end
end
