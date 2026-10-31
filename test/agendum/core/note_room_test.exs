# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.NoteRoomTest do
  @moduledoc """
  How much of a note's text fits when it becomes an item, a category or
  the end of one (R64f; User's Guide 12-8 to 12-10): Agenda's 350
  characters for an item text, 69 for a category name.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core

  setup do
    db = Agendum.Sample.build(~D[2026-10-08])
    item = hd(db.item_order)
    calls = Enum.find(Map.values(db.categories), &(&1.name == "Calls"))
    %{db: db, item: item, calls: calls.id}
  end

  test "a text made into an item is one line of at most 350 characters" do
    assert Core.fit_item_text("  Call Bob\nabout the budget ") ==
             {"Call Bob about the budget", ""}

    long = String.duplicate("a", 360)
    assert Core.fit_item_text(long) == {String.duplicate("a", 350), String.duplicate("a", 10)}
  end

  test "a category name made from a note is at most 69 characters" do
    assert Core.fit_category_name("Garden") == {"Garden", ""}
    assert Core.fit_category_name(String.duplicate("b", 70)) == {String.duplicate("b", 69), "b"}
  end

  test "appended text fits after a space, the rest stays", %{db: db, item: item, calls: calls} do
    text = db.items[item].text
    room = 350 - String.length(text) - 1
    words = String.duplicate("w", room + 5)
    assert Core.fit_appended(db, {:item, item}, words) == String.split_at(words, room)

    # Calls is 5 characters: 63 more fit after its space
    assert Core.fit_appended(db, {:category, calls}, String.duplicate("c", 64)) ==
             {String.duplicate("c", 63), "c"}

    full = put_in(db.items[item].text, String.duplicate("x", 350))
    assert Core.fit_appended(full, {:item, item}, "more") == {"", "more"}
  end
end
