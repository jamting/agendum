defmodule Agendum.Core.TextConditionsTest do
  @moduledoc """
  Text conditions ("Also match", R15d; User's Guide 19-2 to 19-5) and text
  matches as conditional assignments (R15c; User's Guide 18-3).
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.{Database, TextCondition}

  @today ~D[2026-10-08]

  describe "the Also match syntax" do
    defp m?(condition, text), do: TextCondition.matches?(condition, text)

    test "words and phrases, as whole words, ignoring case" do
      assert m?("meet", "Meet with John")
      refute m?("meet", "Meetup with John")
      assert m?("(meet with)", "We meet  with John")
      refute m?("(meet with)", "We meet John with")
      assert m?("talk to", "Talk to Sue")
    end

    test "; means any, , means all" do
      assert m?("calls;phone", "Phone the bank")
      assert m?("expenses,sales", "Sales expenses for May")
      refute m?("expenses,sales", "Sales figures")
    end

    test "! means the item must not contain the text" do
      assert m?("Cost,!Deduction", "Cost of the trip")
      refute m?("Cost,!Deduction", "Cost deduction")
    end

    test "~ matches case exactly" do
      assert m?("~LOTS", "Buy LOTS today")
      refute m?("~LOTS", "lots of work")
    end

    test "? is any one character, * any characters within a word" do
      assert m?("Budget??", "Budget90 review")
      refute m?("Budget??", "Budget9 review")
      assert m?("sl*", "Sales slump")
      refute m?("sl*", "Island")
    end

    test "\\ makes the next character plain text" do
      assert m?("Surprise\\!", "Surprise! party")
      assert m?("a\\;b", "a;b")
    end

    test "an empty condition matches nothing" do
      refute m?("", "anything")
      refute m?(" ; ", "anything")
    end
  end

  describe "categories with text conditions" do
    setup do
      db = Core.new_file()
      {:ok, db, meetings} = Core.add_category(db, db.main_id, "Meetings")
      {:ok, db} = Core.set_also_match(db, meetings, "meet;(talk to)")
      %{db: db, meetings: meetings}
    end

    test "an item matching the text condition is assigned, conditionally",
         %{db: db, meetings: meetings} do
      {db, id} = Core.add_item(db, "Talk to Bob about the budget", @today)
      assert Database.member?(db, id, meetings)
      assert Database.conditional?(db, id, meetings)
    end

    test "the assignment breaks when the text stops matching (R15c)", %{
      db: db,
      meetings: meetings
    } do
      {db, id} = Core.add_item(db, "Meet with John next Thursday", @today)
      assert Database.member?(db, id, meetings)
      db = Core.edit_item(db, id, "Telephone John next Thursday", @today)
      refute Database.member?(db, id, meetings)
    end

    test "an assignment the user makes stays", %{db: db, meetings: meetings} do
      {db, id} = Core.add_item(db, "Meet with John", @today)
      db = Core.assign(db, id, meetings)
      refute Database.conditional?(db, id, meetings)
      db = Core.edit_item(db, id, "Telephone John", @today)
      assert Database.member?(db, id, meetings)
    end
  end

  describe "category names (R15c)" do
    test "an assignment made because the name appeared breaks when it goes" do
      db = Core.new_file()
      {:ok, db, anna} = Core.add_category(db, db.main_id, "Anna")
      {db, id} = Core.add_item(db, "Call Anna", @today)
      assert Database.conditional?(db, id, anna)

      db = Core.edit_item(db, id, "Call Bob", @today)
      refute Database.member?(db, id, anna)
    end

    test "a match kept by other conditions stays" do
      db = Core.new_file()
      {:ok, db, urgent} = Core.add_category(db, db.main_id, "Urgent")
      {:ok, db, taxes} = Core.add_category(db, db.main_id, "Taxes")
      {:ok, db} = Core.add_condition(db, urgent, taxes, :assigned)
      {db, id} = Core.add_item(db, "Urgent: taxes", @today)
      assert Database.member?(db, id, urgent)

      # the word is gone but the item is still in Taxes by its own text
      db = Core.edit_item(db, id, "File the taxes", @today)
      assert Database.member?(db, id, urgent)
    end
  end
end
