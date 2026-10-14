defmodule Agendum.Core.CategoryMatchingTest do
  @moduledoc """
  Text matching settings for one category (R16b; User's Guide 19-14 to
  19-15): each is Global (the file's, R16a) unless the category sets it.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.Database

  @today ~D[2026-10-08]

  defp category(db, name, overrides \\ []) do
    {:ok, db, id} = Core.add_category(db, db.main_id, name)

    db =
      Enum.reduce(overrides, db, fn {field, value}, db ->
        {:ok, db} = Core.set_match_override(db, id, field, value)
        db
      end)

    {db, id}
  end

  defp member?(db, text, cat) do
    {db, id} = Core.add_item(db, text, @today)
    Database.member?(db, id, cat)
  end

  test "Match on the note for one category; the others keep the item text" do
    {db, budget} = category(Core.new_file(), "Budget", match_on: :note)
    {db, calls} = category(db, "Calls")
    {db, id} = Core.add_item(db, "Budget calls", @today)
    refute Database.member?(db, id, budget)
    assert Database.member?(db, id, calls)

    db = Core.set_note(db, id, "the budget", @today)
    assert Database.member?(db, id, budget)
  end

  test "ignore suffixes, text matching and strength for one category" do
    {db, show} = category(Core.new_file(), "Show", ignore_suffixes: false)
    {db, meet} = category(db, "Meet")
    refute member?(db, "Two shows", show)
    assert member?(db, "Meeting at two", meet)

    {db, off} = category(db, "Budget", enabled: false)
    refute member?(db, "Budget review", off)

    {db, design} = category(db, "Suggestions for design", strength: :partial)
    assert member?(db, "Get suggestions for sales", design)
  end

  test "Confirm assignments for one category" do
    {db, budget} = category(Core.new_file(), "Budget", confirm: :always)
    {db, calls} = category(db, "Calls")
    {db, id} = Core.add_item(db, "Budget calls", @today)
    assert Database.member?(db, id, calls)
    refute Database.member?(db, id, budget)
    assert Core.questions(db) == [{id, [budget]}]
  end

  test "Global takes the file's setting again; the effective settings are the file's merged" do
    {db, show} = category(Core.new_file(), "Show", ignore_suffixes: false)
    {:ok, db} = Core.set_match_override(db, show, :ignore_suffixes, :global)
    assert db.categories[show].match_overrides == %{}
    assert member?(db, "Two shows", show)

    {:ok, db} = Core.set_match_override(db, show, :match_on, :both)
    assert Core.match_settings(db, show).match_on == :both
    assert Core.match_settings(db, show).ignore_suffixes
  end

  test "only standard categories; enclosed text is the file's only" do
    db = Core.new_file()

    assert Core.set_match_override(db, db.special.when, :enabled, false) ==
             {:error, :not_standard}

    {db, cat} = category(db, "Budget")
    assert Core.set_match_override(db, cat, :enclosed_by, :braces) == {:error, :not_allowed}
  end
end
