# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.TrashTest do
  @moduledoc """
  The trash (R24a; User's Guide 3-4 to 3-5, 13-18 to 13-19; checked in
  Agenda 2.0, 2026-10-26): a discarded item waits in the trash, Undisc
  brings it back with its section's category alone, Utilities ▸ Trash
  empties it, and File Properties ▸ Empty trash says when it empties by
  itself.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.Database

  @today ~D[2026-10-26]

  # Tasks with two items; Gym has a When date and Mail a condition on its
  # text's category, as in the file tried in Agenda
  defp file do
    db = Core.new_file()
    {:ok, db, tasks} = Core.add_category(db, db.main_id, "Tasks")
    {:ok, db, errands} = Core.add_category(db, db.main_id, "Errands")
    {db, gym} = Core.add_item(db, "Gym on Friday", @today)
    {db, bank} = Core.add_item(db, "Write to the bank", @today)
    db = db |> Core.assign(gym, tasks, @today) |> Core.assign(bank, tasks, @today)
    db = Core.assign(db, bank, errands, @today)
    %{db: db, tasks: tasks, errands: errands, gym: gym, bank: bank}
  end

  defp run!(db, command, clock \\ @today) do
    {:ok, db, _} = Core.run(db, command, clock)
    db
  end

  test "a discarded item leaves the file for the trash, without its assignments" do
    %{db: db, gym: gym, tasks: tasks} = file()
    assert db.items[gym].when != nil

    db = run!(db, {:discard_items, [gym]})
    refute Map.has_key?(db.items, gym)
    assert [%{id: ^gym, text: "Gym on Friday", when: nil, entry: @today}] = db.trash.items
    assert db.trash.day == @today
    refute Database.member?(db, gym, tasks)
    assert Database.file_statistics(db).items_in_trash == 1
  end

  test "Undisc brings the last one back into the section alone, after the highlighted item" do
    %{db: db, gym: gym, bank: bank, tasks: tasks, errands: errands} = file()
    db = run!(db, {:discard_items, [gym]})
    db = run!(db, {:discard_items, [bank]})

    {:ok, db, %{result: [^bank]}} = Core.run(db, {:undiscard, :last, tasks, nil}, @today)
    assert Database.member?(db, bank, tasks)
    # its other category went with the discard, as in Agenda
    refute Database.member?(db, bank, errands)
    assert [%{id: ^gym}] = db.trash.items
  end

  test "Undisc of all brings them back newest first, below the item" do
    %{db: db, gym: gym, bank: bank, tasks: tasks} = file()
    {db, first} = Core.add_item(db, "Call Bob", @today)
    db = Core.assign(db, first, tasks, @today)
    db = db |> run!({:discard_items, [gym]}) |> run!({:discard_items, [bank]})

    db = run!(db, {:undiscard, :all, tasks, first})
    assert db.trash.items == []
    assert db.trash.day == nil
    assert Enum.take(db.item_order, 3) == [first, bank, gym]
    # the When date stays gone: the text is not read again for dates
    assert db.items[gym].when == nil
  end

  test "an undiscarded item's conditions run again" do
    %{db: db, gym: gym, tasks: tasks} = file()
    {:ok, db, fit} = Core.add_category(db, db.main_id, "Fitness")
    {:ok, db} = Core.add_condition(db, fit, tasks, :assigned)
    db = run!(db, {:discard_items, [gym]})
    db = run!(db, {:undiscard, :last, tasks, nil})
    assert Database.member?(db, gym, fit)
  end

  test "Undisc and Utilities Trash with nothing in the trash are refused" do
    %{db: db, tasks: tasks} = file()
    assert Core.run(db, {:undiscard, :all, tasks, nil}, @today) == {:error, :empty_trash}
    assert Core.run(db, :empty_trash, @today) == {:error, :empty_trash}
  end

  test "Utilities Trash empties it for good" do
    %{db: db, gym: gym} = file()
    db = db |> run!({:discard_items, [gym]}) |> run!(:empty_trash)
    assert db.trash.items == []
    refute Map.has_key?(db.items, gym)
  end

  test "a category that discards puts the item in the trash" do
    %{db: db, gym: gym} = file()
    {:ok, db, bin} = Core.add_category(db, db.main_id, "Bin")
    {:ok, db} = Core.set_special_action(db, bin, :discard)
    db = Core.assign(db, gym, bin, @today)
    refute Map.has_key?(db.items, gym)
    assert [%{id: ^gym}] = db.trash.items
  end

  describe "File Properties ▸ Empty trash" do
    test "is End of day at first, and has Agenda's four choices" do
      assert Core.new_file().trash.empty == :end_of_day

      assert Core.empty_trash_choices() == [:on_demand, :file_closed, :end_of_day, :discarded]

      assert Core.run(Core.new_file(), {:set_empty_trash, :sometimes}, @today) ==
               {:error, :bad_arguments}
    end

    test "End of day: the next day the trash is empty, not the same day" do
      %{db: db, gym: gym} = file()
      db = run!(db, {:discard_items, [gym]})
      assert run!(db, {:tidy_trash, :clock}, ~N[2026-10-26 23:59:00]).trash.items != []
      assert run!(db, {:tidy_trash, :clock}, ~N[2026-10-27 00:00:00]).trash.items == []
      assert run!(db, {:tidy_trash, :open}, ~D[2026-10-28]).trash.items == []
    end

    test "When file is closed: opening it again finds the trash empty" do
      %{db: db, gym: gym} = file()
      db = db |> run!({:set_empty_trash, :file_closed}) |> run!({:discard_items, [gym]})
      assert run!(db, {:tidy_trash, :clock}, ~D[2026-10-30]).trash.items != []
      assert run!(db, {:tidy_trash, :open}).trash.items == []
    end

    test "On demand: only Utilities Trash empties it" do
      %{db: db, gym: gym} = file()
      db = db |> run!({:set_empty_trash, :on_demand}) |> run!({:discard_items, [gym]})
      assert run!(db, {:tidy_trash, :open}, ~D[2027-01-01]).trash.items != []
    end

    test "When item is discarded: no trash at all" do
      %{db: db, gym: gym} = file()
      db = db |> run!({:set_empty_trash, :discarded}) |> run!({:discard_items, [gym]})
      assert db.trash.items == []
      refute Map.has_key?(db.items, gym)
    end
  end

  test "a template has an empty trash" do
    %{db: db, gym: gym} = file()
    db = run!(db, {:discard_items, [gym]})
    assert Core.template(db).trash.items == []
  end
end
