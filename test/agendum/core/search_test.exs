# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.SearchTest do
  @moduledoc "Searching item and note text (SPEC R37; User's Guide 15-1 to 15-6)."
  use ExUnit.Case, async: true

  import Agendum.Fixtures
  alias Agendum.Core
  alias Agendum.Core.{Database, Search, ViewModel}

  defp item(text, note \\ ""), do: %Agendum.Core.Item{text: text, note: note}
  defp q(text, opts \\ []), do: struct(Search, [text: text] ++ opts)

  test "words match whole words, ignoring case by default" do
    assert Search.matches?(item("Call the Budget office"), q("budget"))
    refute Search.matches?(item("budgetary review"), q("budget"))
    refute Search.matches?(item("Call the Budget office"), q("budget", ignore_case: false))
  end

  test "every word must appear" do
    assert Search.matches?(item("phone Anna about the budget"), q("budget phone"))
    refute Search.matches?(item("phone Anna"), q("budget phone"))
  end

  test "an asterisk matches any ending (the manual's Pat* example)" do
    for text <- ["Pat", "Patty", "call Patricia"],
        do: assert(Search.matches?(item(text), q("Pat*")))

    refute Search.matches?(item("spat"), q("Pat*"))
  end

  test "parentheses group a phrase" do
    assert Search.matches?(
             item("the Human Resources Department"),
             q("(human resources department)")
           )

    refute Search.matches?(
             item("Human Department of Resources"),
             q("(human resources department)")
           )
  end

  test "match on item text, note text or both" do
    i = item("Call Anna", "about the budget")
    refute Search.matches?(i, q("budget"))
    assert Search.matches?(i, q("budget", on: :note))
    assert Search.matches?(i, q("budget", on: :both))
    refute Search.matches?(i, q("anna", on: :note))
  end

  test "an empty search matches nothing" do
    refute Search.matches?(item("anything"), q("  "))
  end

  test "show_match makes a Show View with every matching item, and updates it" do
    db = Core.new_file()
    {db, _} = Core.add_item(db, "check the budget", today())
    {db, _} = Core.add_item(db, "buy milk", today())
    {db, _} = Core.add_item(db, "budget meeting", today())

    {db, view_id} = Core.show_match(db, q("budget"))
    view = Database.view(db, view_id)
    assert view.name == "*Show View*"
    [section] = ViewModel.build(db, view)
    assert Enum.map(section.rows, & &1.item.text) == ["check the budget", "budget meeting"]

    {db2, same_id} = Core.show_match(db, q("milk"))
    assert same_id == view_id
    assert length(db2.view_order) == length(db.view_order)
  end

  test "a matcher answers as matches? does, its patterns compiled once" do
    items = [item("Call the Budget office"), item("Patty", "(human resources)"), item("")]

    for search <- [q("budget"), q("Pat*", on: :both), q(""), q("(human resources)", on: :note)] do
      matcher = Search.matcher(search)
      assert Enum.map(items, matcher) == Enum.map(items, &Search.matches?(&1, search))
    end
  end
end
