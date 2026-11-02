# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.MarkdownLinesTest do
  @moduledoc """
  One line of a note as Markdown, for the note editor (R64h; plans/archive/PUBLISHER.md
  step 6, meeting 2026-11-02-1255, § 5): what it is, what ENTER continues
  it with, and what CTRL-T makes of its task box. The rules are the
  site's own, so editor and site agree.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core

  describe "what a line is" do
    test "a heading, its marker apart" do
      assert Core.markdown_line("## Plans") == {:heading, "## ", "Plans"}
      assert Core.markdown_line("#Plans") == :text
      assert Core.markdown_line("####### seven") == :text
      # as the site reads it: an indented heading is one, a bare # is not
      assert Core.markdown_line("  # Plans") == {:heading, "  # ", "Plans"}
      assert Core.markdown_line("# ") == :text
    end

    test "a list item, its indent, marker and box apart" do
      assert Core.markdown_line("- milk") == {:item, "", "- ", nil, "milk"}
      assert Core.markdown_line("  * [x] eggs") == {:item, "  ", "* ", "x", "eggs"}
      assert Core.markdown_line("12. [ ] call") == {:item, "", "12. ", " ", "call"}
      assert Core.markdown_line("3) [-] skip") == {:item, "", "3) ", "-", "skip"}
      assert Core.markdown_line("-milk") == :text
      assert Core.markdown_line("plain") == :text
    end
  end

  describe "ENTER" do
    test "continues a list: the same marker, a numbered one counted on, a box empty" do
      assert Core.markdown_continue("- milk") == {:continue, "- "}
      assert Core.markdown_continue("  * [x] eggs") == {:continue, "  * [ ] "}
      assert Core.markdown_continue("9. nine") == {:continue, "10. "}
      assert Core.markdown_continue("1) [ ] a") == {:continue, "2) [ ] "}
    end

    test "on an item with nothing after its marker, ends the list" do
      assert Core.markdown_continue("- ") == {:end, ""}
      assert Core.markdown_continue("- [ ] ") == {:end, ""}
      assert Core.markdown_continue("3. ") == {:end, ""}
      # a nested item keeps its indent
      assert Core.markdown_continue("    - ") == {:end, "    "}
    end

    test "anything else is a plain new line" do
      assert Core.markdown_continue("plain") == :none
      assert Core.markdown_continue("# Heading") == :none
    end
  end

  describe "CTRL-T" do
    test "ticks and unticks a box; a cancelled one opens again" do
      assert Core.markdown_toggle("- [ ] call") == {"- [x] call", 2}
      assert Core.markdown_toggle("- [x] call") == {"- [ ] call", 2}
      assert Core.markdown_toggle("- [X] call") == {"- [ ] call", 2}
      assert Core.markdown_toggle("- [-] call") == {"- [ ] call", 2}
      # a box with nothing after it is a box too
      assert Core.markdown_toggle("- [ ]") == {"- [x] ", 2}
    end

    test "adds a box to a list item without one" do
      assert Core.markdown_toggle("  - milk") == {"  - [ ] milk", 4}
      assert Core.markdown_toggle("2. milk") == {"2. [ ] milk", 3}
    end

    test "leaves any other line alone" do
      assert Core.markdown_toggle("plain") == nil
      assert Core.markdown_toggle("# Heading") == nil
    end
  end

  test "a code block's rows, between ``` lines, those included" do
    lines = ["- a", "```", "- b", "```", "- c"]
    assert Core.markdown_code_rows(lines) == MapSet.new([1, 2, 3])
  end

  # the editor and the site read a line alike (code review 2026-11-02)
  test "a line the editor calls a list item or a heading is one on the site" do
    for line <- [
          "- milk",
          "* milk",
          "12. x",
          "3) y",
          "  - nested",
          "# Plans",
          "  # Plans",
          "## Sub",
          "#tag",
          "# ",
          "-milk",
          "1234567890. long",
          "plain"
        ] do
      html = Agendum.Core.Extras.Markdown.to_html(line)

      case Core.markdown_line(line) do
        {:heading, _, _} -> assert html =~ ~r/^<h\d>/, line
        {:item, _, _, _, _} -> assert html =~ ~r/^<(ul|ol)/, line
        :text -> assert html =~ ~r/^<p>/, line
      end
    end
  end
end
