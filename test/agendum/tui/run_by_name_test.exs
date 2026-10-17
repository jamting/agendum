defmodule Agendum.TUI.RunByNameTest do
  @moduledoc """
  CTRL-X runs a command by its name (R65d, ADR 0040): a small box with an
  input line, the best matches with their keys, and the highlighted one's
  summary at the bottom.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Starters.Planner
  alias Agendum.TUI.State

  @today ~D[2026-10-12]

  setup do
    db = Planner.build() |> Planner.with_samples(@today)
    %{state: start(db, today: @today, height: 40, width: 100)}
  end

  # the highlighted item, after ↓ from a section head
  defp on_item(state), do: press(state, :down)

  test "CTRL-X opens the box; typing azi finds Attach Zettel id, ENTER runs it",
       %{state: state} do
    state = on_item(state)
    box = press(state, {:ctrl, "x"})
    assert State.mode(box).type == :run_by_name
    assert screen(box) =~ "Run a command"

    typed = press(box, "azi")
    text = screen(typed)
    assert text =~ ~r/Attach Zettel id +CTRL-T/
    assert text =~ "Give the item(s) the next Zettel id"

    ran = press(typed, :enter)
    assert ran.modes == []
    assert {_kind, message} = ran.message
    assert message =~ "given"
    # one change, one undo step
    assert press(ran, {:ctrl, "z"}).db == state.db
  end

  test "only the commands that can run now are shown", %{state: state} do
    # nothing has been removed, so Yank cannot run
    text = screen(press(state, [{:ctrl, "x"}, "yank"]))
    refute text =~ ~r/Yank +ALT-Y/
  end

  test "with nothing typed, the recently used come first", %{state: state} do
    state = on_item(state)
    ran = press(state, [{:ctrl, "x"}, "azi", :enter])
    again = press(ran, {:ctrl, "x"})
    [first | _] = rows(again)
    assert first =~ "Attach Zettel id"
  end

  test "BACKSPACE takes a letter back, ESC closes and changes nothing", %{state: state} do
    typed = press(state, [{:ctrl, "x"}, "aziq"])
    refute screen(typed) =~ "Attach Zettel id"
    assert screen(press(typed, :backspace)) =~ "Attach Zettel id"
    closed = press(typed, :esc)
    assert closed.modes == [] and closed.db == state.db
  end

  test "↑ ↓ choose among the matches", %{state: state} do
    box = press(state, [{:ctrl, "x"}, "s"])
    [_first, second | _] = rows(box)
    moved = press(box, :down)
    assert String.starts_with?(String.trim(second), highlighted(moved))
  end

  test "in the category manager it lists the manager's commands", %{state: state} do
    # on Entry, a date category: it can have no children, so Add child is
    # not offered
    text = screen(press(state, [{:f, 9}, :down, {:ctrl, "x"}, "prop"]))
    assert text =~ ~r/Properties +F6/
    refute screen(press(state, [{:f, 9}, :down, {:ctrl, "x"}, "add child"])) =~ "Add child  "
  end

  test "in a note it lists the note's commands", %{state: state} do
    text = screen(press(state, [:down, {:f, 5}, {:ctrl, "x"}, "date"]))
    assert text =~ ~r/Date +ALT-D/
    assert text =~ "Type today's date"
  end

  test "CTRL-X in the box does not open another", %{state: state} do
    box = press(state, [{:ctrl, "x"}, {:ctrl, "x"}])
    assert length(box.modes) == 1
  end

  test "F1 c narrows fuzzily too: azi finds Attach Zettel id", %{state: state} do
    assert screen(press(state, [{:f, 1}, "c", "azi"])) =~ ~r/Attach Zettel id +CTRL-T/
  end

  # the rows of matches in the box: the lines between its input line and
  # its summary that name a command and a key
  defp rows(state) do
    mode = State.mode(state)
    box = Agendum.TUI.Boxes.Box.module!(mode)

    state
    |> box.content(mode, 60, 20)
    |> Enum.drop(2)
    |> Enum.map(fn line -> Enum.map_join(line, "", &elem(&1, 1)) end)
    |> Enum.take_while(&(String.trim(&1) != ""))
  end

  defp highlighted(state) do
    mode = State.mode(state)
    box = Agendum.TUI.Boxes.Box.module!(mode)

    state
    |> box.content(mode, 60, 20)
    |> Enum.find_value(fn line ->
      Enum.find_value(line, fn {style, text} -> style == :box_selected && text end)
    end)
  end

  test "F1 in the box says how it works", %{state: state} do
    text = screen(press(state, [{:ctrl, "x"}, {:f, 1}]))
    assert text =~ "HELP IN THIS BOX"
    assert text =~ "initials"
  end
end
