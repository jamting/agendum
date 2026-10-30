# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.ProperNamesTest do
  @moduledoc """
  Proper names and titles in text matching (R16c; User's Guide 19-17):
  a name of two or more capitalized words matches its last name, alone
  or with its first name or a title, but not another person's.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.{Database, TextMatch}

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

  describe "the manual's examples" do
    test "Michael Schaeffer matches Michael, Schaeffer and Michael Schaeffer, not Michael Rowles" do
      {db, michael} = category(file(strength: :partial), "Michael")
      {db, schaeffer} = category(db, "Schaeffer")
      {db, full} = category(db, "Michael Schaeffer")
      {db, rowles} = category(db, "Michael Rowles")
      text = "Lunch with Michael Schaeffer"

      assert matched?(db, michael, text)
      assert matched?(db, schaeffer, text)
      assert matched?(db, full, text)
      refute matched?(db, rowles, text)
    end

    test "titles are ignored: Mrs. Wohl matches Nancy Wohl and Wohl" do
      {db, nancy} = category(file(), "Nancy Wohl")
      {db, wohl} = category(db, "Wohl")

      assert matched?(db, nancy, "Call Mrs. Wohl about the lease")
      assert matched?(db, wohl, "Call Mrs. Wohl about the lease")
    end
  end

  describe "a proper name" do
    setup do
      {db, nancy} = category(file(), "Nancy Wohl")
      %{db: db, nancy: nancy}
    end

    test "matches its last name alone", %{db: db, nancy: nancy} do
      assert matched?(db, nancy, "Send the contract to Wohl")
      assert matched?(db, nancy, "Wohl's contract")
      assert matched?(db, nancy, "Wohl called")
    end

    test "with any title, with or without a period", %{db: db, nancy: nancy} do
      for title <- ~w(Mr Ms. Dr. Miss Herr Fru Frau Mme Fröken Frk.),
          do: assert(matched?(db, nancy, "Meet #{title} Wohl"), title)
    end

    test "not its first name alone", %{db: db, nancy: nancy} do
      refute matched?(db, nancy, "Ask Nancy about it")
    end

    test "not someone else with the same last name", %{db: db, nancy: nancy} do
      refute matched?(db, nancy, "Lunch with John Wohl")
      refute matched?(db, nancy, "Lunch with Dr. John Wohl")
    end

    test "a capitalized word starting a sentence is not a first name", %{db: db, nancy: nancy} do
      assert matched?(db, nancy, "Call Wohl")
      assert matched?(db, nancy, "Done. Tell Wohl")
    end

    test "matches whatever the required strength", %{db: db, nancy: nancy} do
      db = Core.set_match_settings(db, %TextMatch{strength: :minimal})
      refute matched?(db, nancy, "Ask Nancy about it")
      assert matched?(db, nancy, "Ask Nancy Wohl about it")
    end

    test "ignores no suffixes on the last name", %{db: db, nancy: nancy} do
      refute matched?(db, nancy, "The Wohlers are coming")
    end
  end

  test "lower-case words around a proper name must match as usual" do
    {db, cat} = category(file(), "visit Nancy Wohl")
    assert matched?(db, cat, "Visiting Mrs. Wohl")
    refute matched?(db, cat, "Phone Mrs. Wohl")
  end

  test "names without two capitalized words match word by word" do
    {db, status} = category(file(), "Status report")
    assert matched?(db, status, "Report on status")
  end

  test "a short name can be a proper name too" do
    db = file()
    {db, cat} = category(db, "Legal")
    db = Core.set_short_name(db, cat, "Nancy Wohl")
    assert matched?(db, cat, "Ask Mrs Wohl")
  end
end
