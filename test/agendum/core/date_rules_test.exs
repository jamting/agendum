# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.DateRulesTest do
  @moduledoc """
  How date categories get dates (R6b; User's Guide 7-5 to 7-8): Assign
  item date, Which one, and the Done and When keys.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.{Database, DateParser, DateRule}

  # A Thursday
  @today ~D[2026-10-08]
  @now ~N[2026-10-08 10:00:00]
  @later ~N[2026-10-10 09:30:00]

  defp new_date_category(db, name, rule) do
    {:ok, db, id} = Core.add_category(db, db.main_id, name)
    {:ok, db} = Core.make_date(db, id, @now)
    {:ok, db} = Core.set_date_rule(db, id, struct(DateRule, rule))
    {db, id}
  end

  defp date(db, item, cat),
    do: {Database.item_date(db, item, cat), Database.item_time(db, item, cat)}

  describe "defaults (User's Guide 7-7)" do
    test "Entry when entered, When from the item text, Done never; the keys set theirs" do
      db = Core.new_file()
      rule = &db.categories[&1].date_rule
      assert rule.(db.special.entry) == %DateRule{assign: :entered}
      assert rule.(db.special.when) == %DateRule{assign: :item_text, when_key: true}
      assert rule.(db.special.done) == %DateRule{assign: :never, done_key: true}
    end

    test "a new date category: never; standard categories have none" do
      db = Core.new_file()
      {:ok, db, due} = Core.add_category(db, db.main_id, "Due")
      assert db.categories[due].date_rule == nil
      {:ok, db} = Core.make_date(db, due, @now)
      assert db.categories[due].date_rule == %DateRule{}

      assert Core.set_date_rule(db, db.main_id, %DateRule{}) == {:error, :not_a_date_category}
    end
  end

  describe "dates from the clock" do
    test "when entered: on adding only" do
      {db, cat} = new_date_category(Core.new_file(), "Logged", assign: :entered)
      {db, id} = Core.add_item(db, "Call Bob", @now)
      assert date(db, id, cat) == {@today, ~T[10:00:00]}
      db = Core.edit_item(db, id, "Call Bob back", @later)
      assert date(db, id, cat) == {@today, ~T[10:00:00]}
    end

    test "when item text is edited: on adding and on every change of the text" do
      {db, cat} = new_date_category(Core.new_file(), "Changed", assign: :item_edited)
      {db, id} = Core.add_item(db, "Call Bob", @now)
      db = Core.edit_item(db, id, "Call Bob back", @later)
      assert date(db, id, cat) == {~D[2026-10-10], ~T[09:30:00]}

      # the same text is no edit
      db = Core.edit_item(db, id, "Call Bob back", ~N[2026-10-12 08:00:00])
      assert date(db, id, cat) == {~D[2026-10-10], ~T[09:30:00]}
    end

    test "when note text is edited: on a changed note" do
      {db, cat} = new_date_category(Core.new_file(), "Noted", assign: :note_edited)
      {db, id} = Core.add_item(db, "Call Bob", @now)
      assert date(db, id, cat) == {nil, nil}
      db = Core.set_note(db, id, "He moved", @later)
      assert date(db, id, cat) == {~D[2026-10-10], ~T[09:30:00]}
    end

    test "when assigned: on adding and on joining another category" do
      {db, cat} = new_date_category(Core.new_file(), "Moved", assign: :assigned)
      {:ok, db, calls} = Core.add_category(db, db.main_id, "Calls")
      {db, id} = Core.add_item(db, "Ring Bob", @now)
      assert date(db, id, cat) == {@today, ~T[10:00:00]}
      db = Core.assign(db, id, calls, @later)
      assert date(db, id, cat) == {~D[2026-10-10], ~T[09:30:00]}
    end

    test "Entry can follow edits too" do
      db = Core.new_file()
      {:ok, db} = Core.set_date_rule(db, db.special.entry, %DateRule{assign: :item_edited})
      {db, id} = Core.add_item(db, "Call Bob", @now)
      db = Core.edit_item(db, id, "Call Bob back", @later)
      assert db.items[id].entry == ~D[2026-10-10]
    end
  end

  describe "dates from the text, and Which one" do
    test "the manual's example: End takes the second time, When the first" do
      {db, finish} = new_date_category(Core.new_file(), "End", assign: :item_text, which: 2)
      {db, id} = Core.add_item(db, "Status meeting from 10:00 to 2:30", @now)
      assert {db.items[id].when, db.items[id].when_time} == {@today, ~T[10:00:00]}
      assert date(db, id, finish) == {@today, ~T[14:30:00]}
    end

    test "a date and its time count as one; a missing nth date gives none" do
      {db, back} = new_date_category(Core.new_file(), "Back", assign: :item_text, which: 2)
      {db, id} = Core.add_item(db, "Fly out Monday, back Friday at 6pm", @now)
      assert date(db, id, back) == {~D[2026-10-09], ~T[18:00:00]}

      db = Core.edit_item(db, id, "Fly out Monday", @now)
      assert date(db, id, back) == {nil, nil}
    end

    test "from the note, and from the item or note text" do
      {db, due} = new_date_category(Core.new_file(), "Due", assign: :note_text)
      {db, id} = Core.add_item(db, "Pay rent on Friday", @now)
      assert date(db, id, due) == {nil, nil}
      db = Core.set_note(db, id, "due next Tuesday", @now)
      assert date(db, id, due) == {~D[2026-10-13], nil}

      {:ok, db} = Core.set_date_rule(db, due, %DateRule{assign: :item_or_note_text})
      {db, other} = Core.add_item(db, "Pay gas on Friday", @now)
      assert date(db, other, due) == {~D[2026-10-09], nil}
    end

    test "a date set by hand is kept when the text changes" do
      {db, due} = new_date_category(Core.new_file(), "Due", assign: :item_text)
      {db, id} = Core.add_item(db, "Pay rent on Friday", @now)
      db = Core.set_date(db, id, due, ~D[2026-12-01], @now)
      db = Core.edit_item(db, id, "Pay rent on Monday", @now)
      assert date(db, id, due) == {~D[2026-12-01], nil}
    end

    test "When reads nothing when its rule is Never (Utilities Dating)" do
      db = Core.toggle_auto_date(Core.new_file())
      assert db.categories[db.special.when].date_rule.assign == :never
      {db, id} = Core.add_item(db, "Pay rent on Friday", @now)
      assert db.items[id].when == nil
      assert Core.toggle_auto_date(db).categories[db.special.when].date_rule.assign == :item_text
    end

    test "every date and time in text, in order" do
      dates = DateParser.extract_all("Status meeting from 10:00 to 2:30", @now)

      assert Enum.map(dates, &Tuple.delete_at(&1, 2)) == [
               {@today, ~T[10:00:00]},
               {@today, ~T[14:30:00]}
             ]

      dates = DateParser.extract_all("Fly out Monday, back Friday at 6pm", @now)

      assert Enum.map(dates, &Tuple.delete_at(&1, 2)) == [
               {~D[2026-10-12], nil},
               {~D[2026-10-09], ~T[18:00:00]}
             ]
    end
  end

  describe "the Done and When keys" do
    test "marking done also dates categories set from the Done key" do
      {db, closed} = new_date_category(Core.new_file(), "Closed", done_key: true)
      {db, id} = Core.add_item(db, "Call Bob", @now)
      db = Core.toggle_done(db, id, @later)
      assert db.items[id].done == ~D[2026-10-10]
      assert date(db, id, closed) == {~D[2026-10-10], ~T[09:30:00]}
    end

    test "the When key also dates categories set from it" do
      {db, follow} = new_date_category(Core.new_file(), "Follow-up", when_key: true)
      {db, id} = Core.add_item(db, "Call Bob", @now)
      {:ok, db} = Core.when_key(db, id, "friday 3pm", @now)
      assert {db.items[id].when, db.items[id].when_time} == {~D[2026-10-09], ~T[15:00:00]}
      assert date(db, id, follow) == {~D[2026-10-09], ~T[15:00:00]}
    end
  end
end
