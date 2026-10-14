defmodule Agendum.Core.TextSearchTest do
  @moduledoc "Finding and replacing text in a note (R39)."
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Agendum.Core.TextSearch

  @lines ["Call the Personnel Division", "personnel division meets", "PERSONNEL DIVISION"]

  describe "find/5" do
    test "forward finds the first occurrence at or after the position" do
      assert TextSearch.find(@lines, "personnel division", {0, 0}, :forward, true) == {0, 9}
      assert TextSearch.find(@lines, "personnel division", {0, 9}, :forward, true) == {0, 9}
      assert TextSearch.find(@lines, "personnel division", {0, 10}, :forward, true) == {1, 0}
      assert TextSearch.find(@lines, "personnel division", {2, 1}, :forward, true) == nil
    end

    test "backward finds the last occurrence before the position" do
      assert TextSearch.find(@lines, "personnel division", {2, 18}, :backward, true) == {2, 0}
      assert TextSearch.find(@lines, "personnel division", {2, 0}, :backward, true) == {1, 0}
      assert TextSearch.find(@lines, "personnel division", {0, 9}, :backward, true) == nil
    end

    test "case matters unless ignored" do
      assert TextSearch.find(@lines, "PERSONNEL", {0, 0}, :forward, false) == {2, 0}
      assert TextSearch.find(@lines, "Personnel", {0, 0}, :forward, false) == {0, 9}
    end

    test "matches any characters, not only whole words" do
      assert TextSearch.find(["Personnel"], "son", {0, 0}, :forward, true) == {0, 3}
    end

    test "an empty pattern finds nothing" do
      assert TextSearch.find(@lines, "", {0, 0}, :forward, true) == nil
    end

    test "positions count characters, not bytes" do
      assert TextSearch.find(["Café Öl öl"], "öl", {0, 0}, :forward, true) == {0, 5}
      assert TextSearch.find(["Café Öl öl"], "öl", {0, 6}, :forward, false) == {0, 8}
    end
  end

  describe "replace_at/4" do
    test "replaces the pattern's length at a position" do
      assert TextSearch.replace_at(@lines, {1, 0}, "personnel division", "HR") ==
               ["Call the Personnel Division", "HR meets", "PERSONNEL DIVISION"]
    end
  end

  describe "replace_all/4" do
    test "replaces every occurrence and counts them" do
      assert TextSearch.replace_all(@lines, "personnel division", "Human Resources", true) ==
               {["Call the Human Resources", "Human Resources meets", "Human Resources"], 3}
    end

    test "respects case when asked" do
      assert {_, 1} = TextSearch.replace_all(@lines, "PERSONNEL", "x", false)
    end

    test "occurrences do not overlap, and the replacement is not searched again" do
      assert TextSearch.replace_all(["aaaa"], "aa", "a", true) == {["aa"], 2}
      assert TextSearch.replace_all(["a b"], "a", "aa", true) == {["aa b"], 1}
    end

    property "replacing with the pattern itself changes nothing" do
      check all(
              lines <- list_of(string([?a, ?b, ?A, ?\s], max_length: 12), min_length: 1),
              pattern <- string([?a, ?b], min_length: 1, max_length: 3)
            ) do
        {result, _} = TextSearch.replace_all(lines, pattern, pattern, false)
        assert result == lines
      end
    end

    property "after replacing, the pattern is gone when the replacement cannot form it" do
      check all(
              lines <- list_of(string([?a, ?b, ?\s], max_length: 12), min_length: 1),
              pattern <- string([?a, ?b], min_length: 1, max_length: 3)
            ) do
        {result, count} = TextSearch.replace_all(lines, pattern, "#", true)
        assert TextSearch.find(result, pattern, {0, 0}, :forward, true) == nil
        assert count == result |> Enum.join() |> String.graphemes() |> Enum.count(&(&1 == "#"))
      end
    end
  end
end
