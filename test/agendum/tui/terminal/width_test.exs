# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Terminal.WidthTest do
  @moduledoc "Characters two columns wide (CJK, emoji) on the screen (R40)."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.TUI.Render
  alias Agendum.TUI.Terminal.{Draw, Width}

  test "a wide character takes two columns, an accent none" do
    assert Width.of("abc") == 3
    assert Width.of("日本語") == 6
    assert Width.of("한국") == 4
    assert Width.of("🎉 party") == 8
    # e + a combining acute accent: one grapheme, one column
    assert Width.of("café") == 4
    # CR LF is one grapheme, drawn as one glyph (Draw.clean/1)
    assert Width.of("a\r\nb") == 3
    assert Width.take("a\r\nb", 2) == {"a\r\n", 2}
    assert Width.of("🇸🇪") == 2
    # Agenda's marks and box lines stay narrow
    assert Width.of("♪☼#⌂┌├└│─…") == 10
  end

  test "taking and dropping never cut a wide character in half" do
    assert Width.take("日本語", 3) == {"日", 2}
    assert Width.take("日本語", 4) == {"日本", 4}
    assert Width.take("abc", 0) == {"", 0}
    assert Width.drop("日本語", 2) == "本語"
    # its second half stays, blank, so the rest starts where it should
    assert Width.drop("日本語", 3) == " 語"
  end

  test "lines, fields and boxes measure columns" do
    assert "日本" |> List.wrap() |> Enum.map(&{:item, &1}) |> Draw.line(5) |> Draw.width() == 5
    assert Draw.pad("日本語", 5) == "日本 "
    assert Draw.rpad("日本", 6) == "  日本"
    assert Draw.truncate("日本語です", 6) == "日本…"
    assert Draw.wrap("日本語の文", 4) == ["日本", "語の", "文"]
    # a wide character cut by the line's end leaves its column blank, and
    # the next segment does not slide into it
    cut = Draw.line([{:a, "日日"}, {:b, "xyz"}], 3)
    assert cut == [{:a, "日 "}]
    assert Draw.width(cut) == 3
    # a box drawn over a wide character's second half starts in place
    line = Draw.take([{:item, "日本語"}], 3)
    assert Draw.width(line) == 3

    box = Draw.box("日本語の名前", [[{:box, "x"}]], 20, "完了")
    assert box |> Enum.map(&Draw.width/1) |> Enum.uniq() == [22]
  end

  test "an item of wide text is drawn whole, on the lines it takes" do
    state = start(Agendum.Sample.build(~D[2026-10-08]), width: 80, height: 25)
    state = press(state, ["会議の準備 🎉 Kaigi", :enter])
    assert screen(state) =~ "会議の準備 🎉 Kaigi"

    # a text wider than the item column wraps by columns
    long = String.duplicate("日本語", 12)
    state = press(state, [long, :enter])
    text = screen(state)
    assert text =~ String.duplicate("日本語", 4)
    assert String.replace(text, ~r/[^日本語]/u, "") =~ long
  end

  test "a long item of wide text is typed wrapped, nothing lost between its rows" do
    state = start(Agendum.Sample.build(~D[2026-10-08]), width: 80, height: 25)
    text = "会議の準備をする前に資料を読んで日本語の文章を確認する"
    typed = press(state, [text])
    rows = typed |> screen() |> String.split("\n") |> Enum.filter(&(&1 =~ ~r/[会議資料確認]/u))

    assert rows |> Enum.map_join(&String.trim/1) |> String.replace("•", "") |> String.trim() ==
             text
  end

  test "every line of a screen holding wide text is exactly the screen's width" do
    state = start(Agendum.Sample.build(~D[2026-10-08]), width: 80, height: 25)
    state = press(state, ["会議の準備をする 🎉 Kaigi no junbi", :enter])
    main = Enum.find(Map.values(state.db.categories), &(&1.parent_id == nil))
    {:ok, db, _id} = Core.add_category(state.db, main.id, "日本語のカテゴリ")
    state = %{state | db: db}

    for screen <- [state, press(state, {:f, 9}), press(state, [{:f, 9}, {:f, 6}])] do
      # measured here, not with Draw.width/1, which is under test too
      columns = fn line -> line |> Enum.map(fn {_, t} -> Width.of(t) end) |> Enum.sum() end
      widths = screen |> Render.render() |> Enum.map(columns) |> Enum.uniq()
      assert widths == [80]
    end
  end

  # typed text (left from v0.73.5): rows and the cursor's window by columns
  test "typed text wraps and scrolls by columns, the cursor kept in view" do
    alias Agendum.TUI.Typing.Wrap
    assert Wrap.rows("日本語の文", 4) == [{0, 2}, {2, 2}, {4, 1}]
    # a space after a full row still hangs there
    assert Wrap.rows("日本 語", 4) == [{0, 3}, {3, 1}]
    assert Wrap.in_columns("日本語の文", Wrap.rows("日本語の文", 4)) == [{0, 4}, {4, 4}, {8, 2}]
    assert Wrap.in_columns("abc", [{0, 2}, {2, 1}]) == [{0, 2}, {2, 1}]
    # one column: a wide character still makes its own row
    assert Wrap.rows("日本", 1) == [{0, 1}, {1, 1}]

    # a field 5 wide, the cursor after six wide characters: the end shows,
    # with the cursor's cell, and the field stays 5 columns
    field = Draw.input(%{text: "日本語日本語", pos: 6}, 5, :edit)
    assert Draw.width(field) == 5
    assert Draw.to_text([field]) =~ "本語"
    assert {:edit_cursor, " "} in field
    # the cursor on a wide character in the middle shows it highlighted
    field = Draw.input(%{text: "日本語日本語", pos: 3}, 5, :edit)
    assert {:edit_cursor, "日"} in field
    assert Draw.width(field) == 5
  end
end
