defmodule Agenda.Core.TextMatchingSettingsTest do
  @moduledoc """
  Text matching settings (R16a; User's Guide 19-7 to 19-12): on or off,
  match on item text, note or both, required match strength, confirm
  Sometimes, ignore text enclosed by, ignore suffixes, ignore accents.
  """
  use ExUnit.Case, async: true

  alias Agenda.Core
  alias Agenda.Core.{Database, TextMatch}

  @today ~D[2026-10-08]

  defp file(settings \\ []) do
    db = Core.new_file()
    Core.set_match_settings(db, struct(TextMatch, settings))
  end

  defp category(db, name) do
    {:ok, db, id} = Core.add_category(db, db.main_id, name)
    {db, id}
  end

  defp matched?(db, cat, text) do
    {db, id} = Core.add_item(db, text, @today)
    Database.member?(db, id, cat)
  end

  test "Agenda's defaults" do
    assert %TextMatch{} == %TextMatch{
             enabled: true,
             match_on: :item,
             strength: :exact,
             enclosed_by: :quotes,
             ignore_suffixes: true,
             ignore_accents: false
           }
  end

  describe "ignore suffixes (Yes by default)" do
    test "Show matches shows, showing and showed" do
      {db, show} = category(file(), "Show")

      for text <- ["Two shows tonight", "Showing the house", "Showed it to Anna"],
          do: assert(matched?(db, show, text), text)
    end

    test "words of three letters or fewer must match exactly" do
      {db, buy} = category(file(), "Buy")
      refute matched?(db, buy, "Buying a car")
      assert matched?(db, buy, "Buy a car")
    end

    test "with No, only the word itself" do
      {db, show} = category(file(ignore_suffixes: false), "Show")
      refute matched?(db, show, "Two shows tonight")
      assert matched?(db, show, "One show tonight")
    end

    test "a caret before a text condition matches that word only" do
      {db, meal} = category(file(), "Food")
      {:ok, db} = Core.set_also_match(db, meal, "^meal")
      assert matched?(db, meal, "A meal at six")
      refute matched?(db, meal, "Meals at six")
    end
  end

  describe "required match strength (the manual's Suggestions for design)" do
    setup do
      %{
        all: "Remember to ask Mary for her latest design suggestions",
        two: "Get suggestions for increasing sales in the Northeast",
        one: "Ask Jacques about lunch suggestions"
      }
    end

    test "exact: every word, in any order", texts do
      {db, cat} = category(file(), "Suggestions for design")
      assert matched?(db, cat, texts.all)
      refute matched?(db, cat, texts.two)
    end

    test "partial: at least half of the words", texts do
      {db, cat} = category(file(strength: :partial), "Suggestions for design")
      assert matched?(db, cat, texts.two)
      refute matched?(db, cat, texts.one)
    end

    test "minimal: one word", texts do
      {db, cat} = category(file(strength: :minimal), "Suggestions for design")
      assert matched?(db, cat, texts.one)
    end
  end

  test "text in quotation marks is ignored; other marks can be chosen" do
    {db, margin} = category(file(), "Margin")
    refute matched?(db, margin, ~s(How do you set a "margin" command?))
    refute matched?(db, margin, "How do you set a “margin” command?")
    assert matched?(db, margin, "Set the (margin) command")

    {db, margin} = category(file(enclosed_by: :parentheses), "Margin")
    assert matched?(db, margin, ~s(How do you set a "margin" command?))
    refute matched?(db, margin, "Set the (margin) command")
  end

  test "ignore accents: résumé matches resume" do
    {db, cat} = category(file(), "Résumé")
    refute matched?(db, cat, "Send my resume")
    {db, cat} = category(file(ignore_accents: true), "Résumé")
    assert matched?(db, cat, "Send my resume")
  end

  describe "match on" do
    test "the note: a note's words assign the item when it is saved" do
      {db, budget} = category(file(match_on: :note), "Budget")
      {db, id} = Core.add_item(db, "Budget meeting", @today)
      refute Database.member?(db, id, budget)
      db = Core.set_note(db, id, "about the budget", @today)
      assert Database.member?(db, id, budget)

      # a match from the note breaks when the note stops matching (R15c)
      db = Core.set_note(db, id, "nothing", @today)
      refute Database.member?(db, id, budget)
    end

    test "both item and note" do
      {db, budget} = category(file(match_on: :both), "Budget")
      {db, id} = Core.add_item(db, "Call Anna", @today)
      db = Core.set_note(db, id, "about the budget", @today)
      assert Database.member?(db, id, budget)
      assert matched?(db, budget, "Budget review")
    end
  end

  test "text matching off: no names or text conditions match" do
    {db, cat} = category(file(enabled: false), "Budget")
    {:ok, db} = Core.set_also_match(db, cat, "money")
    refute matched?(db, cat, "Budget money")
  end

  test "Confirm Sometimes: partial matches are suggested, full ones made" do
    {db, cat} = category(file(strength: :partial), "Suggestions for design")
    db = Core.set_confirm_assignments(db, :sometimes)
    {db, partial} = Core.add_item(db, "Get suggestions for increasing sales", @today)
    {db, full} = Core.add_item(db, "Design suggestions for Mary", @today)
    assert Core.questions(db) == [{partial, [cat]}]
    assert Database.member?(db, full, cat)
    refute Database.member?(db, partial, cat)
  end
end
