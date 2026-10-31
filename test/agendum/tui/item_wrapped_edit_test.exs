# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.ItemWrappedEditTest do
  # A long item is typed wrapped, as Agenda's (R21, checked in Agenda,
  # 2026-10-31): the text shows on as many lines as it takes, ↑ ↓ move
  # between them keeping the column (nothing on the first or last), HOME
  # and END go to the line's start and end, CTRL-HOME and CTRL-END to the
  # text's.
  use ExUnit.Case, async: true
  import Agendum.TUIHelpers

  alias Agendum.Core
  alias Agendum.TUI.{Layout, Typing.Wrap}

  @today ~D[2026-10-31]
  @long Enum.map_join(?a..?v, " ", &String.duplicate(<<&1>>, 4))

  # "Errands" with a long item and "Buy milk" under it, the long one
  # highlighted, on a narrow screen so that it wraps
  defp errands(opts \\ []) do
    db = Core.new_file()
    {:ok, db, errands} = Core.add_category(db, db.main_id, "Errands")
    db = Core.set_section_category(db, hd(db.view_order), 0, errands)
    {db, long} = Core.add_item(db, @long, @today, section: errands)
    {db, milk} = Core.add_item(db, "Buy milk", @today, section: errands, after: long)

    state =
      db
      |> start(Keyword.merge([today: @today, width: 50, height: 24], opts))
      |> press(:down)

    %{state: state, long: long, milk: milk}
  end

  # the rows the text being typed is wrapped into
  defp rows(state) do
    width = Layout.text_width(state, Layout.current_row(state))
    Wrap.rows(state.edit.line.text, Wrap.item_width(width))
  end

  defp line_of(state, text),
    do: state |> screen() |> String.split("\n") |> Enum.find_index(&(&1 =~ text))

  test "F2 on a long item shows all of it, wrapped as it is drawn" do
    %{state: state} = errands()
    editing = press(state, {:f, 2})

    assert length(rows(editing)) >= 3
    for word <- ["aaaa", "kkkk", "vvvv"], do: assert(screen(editing) =~ word)
    assert line_of(editing, "Buy milk") == line_of(state, "Buy milk")
  end

  test "↓ and ↑ move a line down and up, keeping the column" do
    %{state: state} = errands()
    editing = press(state, [{:f, 2}, :right, :right, :right])
    [_first, {second, _}, {third, _} | _] = rows(editing)

    down = press(editing, :down)
    assert down.edit.line.pos == second + 3

    down2 = press(down, :down)
    assert down2.edit.line.pos == third + 3

    assert press(down2, :up).edit.line.pos == second + 3
  end

  test "↑ on the first line and ↓ on the last do nothing" do
    %{state: state} = errands()
    editing = press(state, [{:f, 2}, :right, :right])
    assert press(editing, :up).edit.line.pos == 2

    at_end = press(editing, :ctrl_end)
    assert press(at_end, :down).edit.line.pos == String.length(@long)
  end

  test "↓ onto a shorter line goes to its end" do
    %{state: state} = errands()
    editing = press(state, {:f, 2})
    count = length(rows(editing))
    {last, _} = List.last(rows(editing))
    {above, len} = Enum.at(rows(editing), count - 2)

    # to the end of the line above the last, then ↓: the same column, or
    # the text's end when the last line is shorter
    above_last = press(editing, List.duplicate(:down, count - 2) ++ [:end])
    assert above_last.edit.line.pos == above + len - 1

    assert press(above_last, :down).edit.line.pos ==
             min(last + len - 1, String.length(@long))
  end

  test "HOME and END go to the start and end of the line; CTRL-A and CTRL-E too" do
    %{state: state} = errands()
    editing = press(state, [{:f, 2}, :down, :right, :right])
    [_, {second, len} | _] = rows(editing)

    assert press(editing, :home).edit.line.pos == second
    assert press(editing, {:ctrl, "a"}).edit.line.pos == second
    # the line's last character is the space it wraps at: typing goes before it
    assert press(editing, :end).edit.line.pos == second + len - 1
    assert press(editing, {:ctrl, "e"}).edit.line.pos == second + len - 1
  end

  test "CTRL-HOME and CTRL-END go to the start and end of the text" do
    %{state: state} = errands()
    editing = press(state, [{:f, 2}, :down, :right])

    assert press(editing, :ctrl_home).edit.line.pos == 0
    assert press(editing, :ctrl_end).edit.line.pos == String.length(@long)
  end

  test "END then typing adds at the end of that line, as Agenda's" do
    %{state: state, long: long} = errands()
    done = press(state, [{:f, 2}, :down, :end, "1", :enter])

    assert done.db.items[long].text =~ ~r/\w1 /
  end

  test "a new item wraps as it is typed, and the rows below move down" do
    %{state: state} = errands()
    before = line_of(state, "Buy milk")
    typing = press(state, [:insert, @long])

    assert length(rows(typing)) >= 3
    assert screen(typing) =~ "vvvv"
    assert line_of(typing, "Buy milk") >= before + length(rows(typing))
  end

  test "an item typed near the bottom of a short screen keeps its cursor in sight" do
    %{state: state} = errands(height: 8)
    typing = press(state, [:ctrl_end, :insert, @long, " zzzz"])

    assert screen(typing) =~ "zzzz"
  end

  # under a section head that is not the first, a blank line comes before
  # the head: the typed lines start two lines into the row
  test "a new item typed under a later section head keeps its cursor in sight" do
    %{state: state} = errands(height: 8)
    {:ok, db, later} = Core.add_category(state.db, state.db.main_id, "Later")
    db = Core.add_section(db, state.view_id, later, 1)
    state = %{state | db: db} |> Layout.settle() |> press(:ctrl_end)
    assert Layout.current_row(state).kind == :section

    typing = press(state, [:insert, @long, " zzzz"])
    assert screen(typing) =~ "zzzz"
  end
end
