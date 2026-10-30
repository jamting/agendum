# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.WrapTest do
  @moduledoc "Word wrap in the note editor: rows of a line, on the screen only."
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Agendum.TUI.Typing.Wrap

  # the text of each row
  defp texts(line, width),
    do: for({start, len} <- Wrap.rows(line, width), do: String.slice(line, start, len))

  test "a line that fits is one row" do
    assert Wrap.rows("short", 10) == [{0, 5}]
    assert Wrap.rows("", 10) == [{0, 0}]
  end

  test "a row ends after the rightmost space that fits; the space stays with it" do
    assert texts("the quick brown fox", 10) == ["the quick ", "brown fox"]
  end

  test "a line can wrap many times" do
    assert texts("aa bb cc dd ee ff", 5) == ["aa bb ", "cc dd ", "ee ff"]
  end

  test "a word wider than the screen is broken at its edge" do
    assert texts("abcdefghij kl", 4) == ["abcd", "efgh", "ij ", "kl"]
  end

  test "a column is on the row it starts; a boundary is the start of the next row" do
    rows = Wrap.rows("the quick brown fox", 10)
    assert Wrap.locate(rows, 0) == 0
    assert Wrap.locate(rows, 9) == 0
    assert Wrap.locate(rows, 10) == 1
    assert Wrap.locate(rows, 19) == 1
  end

  test "a row's last cursor column: its last character, or the line's end on the last row" do
    rows = Wrap.rows("the quick brown fox", 10)
    assert Wrap.row_end(rows, 0) == 9
    assert Wrap.row_end(rows, 1) == 19
    assert Wrap.column(rows, 1, 3) == 13
    assert Wrap.column(rows, 1, 30) == 19
  end

  test "a line ending in the space it wraps at gets an empty last row, for the cursor at its end" do
    assert Wrap.rows("abcd ", 4) == [{0, 5}, {5, 0}]
  end

  property "the rows cover the line in order, each fits, and only the last can be empty" do
    check all(
            line <- StreamData.string([?a, ?b, ?\s], max_length: 60),
            width <- StreamData.integer(1..12)
          ) do
      rows = Wrap.rows(line, width)
      assert Enum.map_join(rows, fn {s, l} -> String.slice(line, s, l) end) == line
      assert hd(rows) |> elem(0) == 0

      for {{s, l}, i} <- Enum.with_index(rows) do
        text = String.slice(line, s, l)
        assert l <= width or (l == width + 1 and String.ends_with?(text, " "))
        assert l > 0 or i == length(rows) - 1
        if i < length(rows) - 1, do: assert(elem(Enum.at(rows, i + 1), 0) == s + l)
      end
    end
  end
end
