# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.QuestionsTest do
  @moduledoc """
  Confirming suggested assignments (R16; User's Guide 19-9, 19-12): with
  Confirm assignments set to Always, text matches become suggestions that
  Utilities Questions confirms.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.Database

  @today ~D[2026-10-08]

  setup do
    db = Core.new_file()
    {:ok, db, anna} = Core.add_category(db, db.main_id, "Anna")
    {:ok, db, budget} = Core.add_category(db, db.main_id, "Budget")
    db = Core.set_confirm_assignments(db, :always)
    %{db: db, anna: anna, budget: budget}
  end

  test "text matches are suggested instead of made", %{db: db, anna: anna, budget: budget} do
    {db, id} = Core.add_item(db, "Ask Anna about the budget", @today)
    refute Database.member?(db, id, anna)
    assert Core.questions(db) == [{id, [anna, budget]}]
  end

  test "confirming makes explicit assignments and clears the question",
       %{db: db, anna: anna, budget: budget} do
    {db, id} = Core.add_item(db, "Ask Anna about the budget", @today)
    db = Core.answer_question(db, id, [anna], @today)
    assert Database.member?(db, id, anna)
    refute Database.conditional?(db, id, anna)
    refute Database.member?(db, id, budget)
    assert Core.questions(db) == []

    # explicit: an edit does not take it away
    db = Core.edit_item(db, id, "Ask about the budget", @today)
    assert Database.member?(db, id, anna)
  end

  test "an edit asks again about what the new text matches", %{db: db, budget: budget} do
    {db, id} = Core.add_item(db, "Ask Anna", @today)
    db = Core.edit_item(db, id, "Check the budget", @today)
    assert Core.questions(db) == [{id, [budget]}]

    db = Core.edit_item(db, id, "Nothing here", @today)
    assert Core.questions(db) == []
  end

  test "discarding the item or the category forgets the question",
       %{db: db, anna: anna} do
    {db, id} = Core.add_item(db, "Ask Anna", @today)
    assert Core.questions(Core.discard_item(db, id)) == []
    {:ok, db} = Core.discard_category(db, anna)
    assert Core.questions(db) == []
  end

  test "with Never (the default) matches are made at once", %{db: db, anna: anna} do
    db = Core.set_confirm_assignments(db, :never)
    {db, id} = Core.add_item(db, "Ask Anna", @today)
    assert Database.member?(db, id, anna)
    assert Core.questions(db) == []
  end

  test "questions are listed in item order", %{db: db} do
    {db, a} = Core.add_item(db, "Ask Anna", @today)
    {db, b} = Core.add_item(db, "Budget meeting", @today)
    assert Enum.map(Core.questions(db), &elem(&1, 0)) == [a, b]
  end
end
