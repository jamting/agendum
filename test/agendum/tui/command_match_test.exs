# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.CommandMatchTest do
  @moduledoc """
  Fuzzy matching of command names (R65d, ADR 0040): one pure function
  over the command data, used by CTRL-X and by F1 `c`'s narrowing.
  """
  use ExUnit.Case, async: true

  alias Agendum.TUI.Commands

  defp names(entries, query, recent \\ []) do
    entries
    |> Commands.match(query, name: & &1, recent: recent)
    |> Enum.take(5)
  end

  @names [
    "Attach Zettel id",
    "Alarm",
    "Save",
    "Search",
    "Unmark all",
    "Next marked",
    "Execute all",
    "Down"
  ]

  test "initials find a command: azi is Attach Zettel id" do
    assert hd(names(@names, "azi")) == "Attach Zettel id"
  end

  test "letters in order find it too, case and spaces aside" do
    assert "Attach Zettel id" in names(@names, "ATzet")
    assert "Attach Zettel id" in names(@names, "zettel id")
    refute "Down" in names(@names, "azi")
  end

  test "a name that starts with what is typed comes before one that only holds its letters" do
    assert names(@names, "s") == ["Save", "Search"]
    assert hd(names(@names, "al")) == "Alarm"
    assert "Execute all" in names(@names, "al")
  end

  test "a word that starts with it comes before letters scattered" do
    # "ma" begins a word of Next marked, but is inside a word of Unmark
    # all, which comes first in the list
    assert names(@names, "ma") == ["Next marked", "Unmark all"]
  end

  test "among equal matches the recently used come first, then the list's order" do
    assert names(@names, "s") == ["Save", "Search"]
    assert names(@names, "s", ["Search"]) == ["Search", "Save"]
  end

  test "nothing typed keeps every name, the recently used first" do
    assert Commands.match(@names, "", name: & &1, recent: ["Down", "Save"]) ==
             ["Down", "Save"] ++ (@names -- ["Down", "Save"])
  end

  test "the summary is matched too, by what it holds, after every name" do
    entries = [{"Remove", "Take it out of the section"}, {"Section below", "Add one"}]
    found = Commands.match(entries, "section", name: &elem(&1, 0), summary: &elem(&1, 1))
    assert Enum.map(found, &elem(&1, 0)) == ["Section below", "Remove"]
  end

  test "what matches nothing finds nothing" do
    assert names(@names, "xyz") == []
  end
end
