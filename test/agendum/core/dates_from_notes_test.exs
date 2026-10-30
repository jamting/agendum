# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.DatesFromNotesTest do
  @moduledoc """
  Fixed relative dates and When dates from notes (R14f; User's Guide 6-7,
  7-6 to 7-7, 7-11); where When reads dates is its date rule (R6b).
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.RangeFilter

  # A Thursday
  @today ~D[2026-10-08]

  defp item(db, id), do: db.items[id]

  # When's Assign item date (R6b), where R14f's setting now lives
  defp when_from(db, assign) do
    rule = db.categories[db.special.when].date_rule
    {:ok, db} = Core.set_date_rule(db, db.special.when, %{rule | assign: assign})
    db
  end

  defp when_assign(db), do: db.categories[db.special.when].date_rule.assign

  describe "When dates from the note" do
    setup do
      %{db: when_from(Core.new_file(), :note_text)}
    end

    test "the note's date is the When date; the item text's is not", %{db: db} do
      {db, id} = Core.add_item(db, "Dentist on Friday", @today)
      assert item(db, id).when == nil

      db = Core.set_note(db, id, "Booked for next Tuesday at 3pm", @today)
      assert {item(db, id).when, item(db, id).when_time} == {~D[2026-10-13], ~T[15:00:00]}
    end

    test "editing the note's date changes it; removing it clears it", %{db: db} do
      {db, id} = Core.add_item(db, "Dentist", @today)
      db = Core.set_note(db, id, "next Tuesday", @today)
      db = Core.set_note(db, id, "next Wednesday", @today)
      assert item(db, id).when == ~D[2026-10-14]

      db = Core.set_note(db, id, "no date after all", @today)
      assert item(db, id).when == nil
    end

    test "a relative date is read once: an unchanged phrase keeps its date", %{db: db} do
      {db, id} = Core.add_item(db, "Dentist", @today)
      db = Core.set_note(db, id, "tomorrow", @today)
      db = Core.set_note(db, id, "tomorrow, bring the card", ~D[2026-10-20])
      assert item(db, id).when == ~D[2026-10-09]
    end

    test "a When date set by hand is kept", %{db: db} do
      {db, id} = Core.add_item(db, "Dentist", @today)
      {:ok, db, :date} = Core.assign_by_name(db, id, db.special.when, "2026-12-01", @today)
      db = Core.set_note(db, id, "next Tuesday", @today)
      assert item(db, id).when == ~D[2026-12-01]
    end
  end

  test "from the item or the note: the item text first, then the note" do
    db = when_from(Core.new_file(), :item_or_note_text)
    {db, a} = Core.add_item(db, "Dentist on Friday", @today)
    db = Core.set_note(db, a, "or next Tuesday", @today)
    assert item(db, a).when == ~D[2026-10-09]

    {db, b} = Core.add_item(db, "Dentist", @today)
    db = Core.set_note(db, b, "next Tuesday", @today)
    assert item(db, b).when == ~D[2026-10-13]

    db = Core.edit_item(db, b, "Dentist on Friday", @today)
    assert item(db, b).when == ~D[2026-10-09]
  end

  test "from the item text (the default), a note's date is ignored" do
    db = Core.new_file()
    assert db.categories[db.special.when].date_rule.assign == :item_text
    {db, id} = Core.add_item(db, "Dentist", @today)
    db = Core.set_note(db, id, "next Tuesday", @today)
    assert item(db, id).when == nil
  end

  test "Dating toggles between never and the item text" do
    db = Core.toggle_auto_date(Core.new_file())
    refute Core.auto_dating?(db)
    assert Core.toggle_auto_date(db) |> when_assign() == :item_text
    assert db |> when_from(:note_text) |> Core.toggle_auto_date() |> when_assign() == :never
  end

  describe "a $ before a relative date in a range keeps the date it was first read as" do
    setup do
      db = Core.new_file()
      %{db: db, when_id: db.special.when}
    end

    test "$monday is stored as the date it means today", %{db: db, when_id: w} do
      assert RangeFilter.build(db, w, "$monday", "$ end of next week", :inside, @today) ==
               {:ok, {:range, "2026-10-12", "2026-10-16", :inside}}

      # without $ the words stay, to be read again each day
      assert RangeFilter.build(db, w, "monday", nil, :inside, @today) ==
               {:ok, {:range, "monday", nil, :inside}}
    end

    test "a $ before something that is not a date is an invalid date", %{db: db, when_id: w} do
      assert RangeFilter.build(db, w, "$someday", nil, :inside, @today) == {:error, :invalid_date}
    end
  end
end
