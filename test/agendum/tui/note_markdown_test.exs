# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.NoteMarkdownTest do
  @moduledoc """
  The note editor for Markdown (R64h, an extra; plans/PUBLISHER.md step 6,
  meeting 2026-11-02-1255, § 5): ENTER continues a list or leaves it,
  CTRL-T ticks a task box, and headings, list markers and task boxes are
  coloured; with the extras off, and in a macro's keystrokes, none of it.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.TUI.State

  defp note_open(extras) do
    Agendum.Sample.build(~D[2026-10-08])
    |> start(height: 30, extras: extras)
    |> press([:down, {:f, 5}])
  end

  defp lines(state), do: Enum.find(state.modes, &(&1.type == :note)).edit.lines

  describe "with the extras on" do
    setup do: %{state: note_open(true)}

    test "ENTER at the end of a list item starts the next", %{state: state} do
      assert lines(press(state, ["- milk", :enter, "eggs"])) == ["- milk", "- eggs"]
      assert lines(press(state, ["- [x] bread", :enter])) == ["- [x] bread", "- [ ] "]
      assert lines(press(state, ["9. nine", :enter])) == ["9. nine", "10. "]
    end

    test "ENTER on an empty item leaves the list", %{state: state} do
      state = press(state, ["- milk", :enter, :enter, "after"])
      assert lines(state) == ["- milk", "after"]
    end

    test "ENTER inside a line, or on plain text, is a plain new line", %{state: state} do
      assert lines(press(state, ["- milk", :left, :left, :enter])) == ["- mi", "lk"]
      assert lines(press(state, ["plain", :enter])) == ["plain", ""]
    end

    test "CTRL-T ticks, unticks, and gives a list item a box", %{state: state} do
      state = press(state, ["- call Kanga", {:ctrl, "t"}])
      assert lines(state) == ["- [ ] call Kanga"]
      assert lines(press(state, {:ctrl, "t"})) == ["- [x] call Kanga"]
      assert lines(press(state, [{:ctrl, "t"}, {:ctrl, "t"}])) == ["- [ ] call Kanga"]
    end

    test "CTRL-T elsewhere says what it is for, and changes nothing", %{state: state} do
      state = press(state, ["plain", {:ctrl, "t"}])
      assert lines(state) == ["plain"]
      assert panel(state) =~ "CTRL-T ticks a task box"
    end

    test "headings, markers and done tasks are coloured on the other lines", %{state: state} do
      state = press(state, ["# Plans", :enter, "- [x] done", :enter, "- [ ] open", :enter, "x"])
      screen = Agendum.TUI.Render.render(state)
      row = fn text -> Enum.find(screen, &Enum.any?(&1, fn {_, t} -> t =~ text end)) end
      heading = row.("Plans")
      done = row.("done")
      open = row.("open")
      assert {:section, "# "} in heading
      assert {:link, "- [x] "} in done
      assert {:item_done, "done"} in done
      assert {:link, "- [ ] "} in open
    end
  end

  describe "found in review" do
    setup do: %{state: note_open(true)}

    test "in a code block a list is only text: ENTER, CTRL-T", %{state: state} do
      state = press(state, ["```", :enter, "- a", :enter])
      assert lines(state) == ["```", "- a", ""]
      state = press(state, [:up, {:ctrl, "t"}])
      assert lines(state) == ["```", "- a", ""]
    end

    test "CTRL-T with the cursor before the box leaves it there", %{state: state} do
      state = press(state, ["- milk", :home, {:ctrl, "t"}])
      note = Enum.find(state.modes, &(&1.type == :note))
      assert {note.edit.lines, note.edit.col} == {["- [ ] milk"], 0}
    end

    test "a list's ENTER is an undo step of its own", %{state: state} do
      state = press(state, ["- milk", :enter])
      assert lines(press(state, {:ctrl, "z"})) == ["- milk"]
    end

    test "ENTER on an empty nested item keeps its indent", %{state: state} do
      state = press(state, ["  - a", :enter, :enter])
      assert lines(state) == ["  - a", "  "]
    end
  end

  test "in a macro's keystrokes, CTRL-T changes nothing" do
    db = Agendum.Sample.build(~D[2026-10-08])
    {:ok, db, id} = Agendum.Core.add_macro(db, "Water")
    db = Agendum.Core.set_macro_keys(db, id, "")
    state = db |> start(extras: true) |> press([{:alt_f, 3}, {:f, 2}, "- a", {:ctrl, "t"}])
    assert lines(state) == ["- a"]
  end

  test "with the extras off, ENTER and CTRL-T are as before" do
    state = note_open(false)
    assert lines(press(state, ["- milk", :enter])) == ["- milk", ""]
    assert lines(press(state, ["- milk", {:ctrl, "t"}])) == ["- milk"]
  end

  test "in a macro's keystrokes, a list is only text" do
    db = Agendum.Sample.build(~D[2026-10-08])
    {:ok, db, id} = Agendum.Core.add_macro(db, "Water")
    db = Agendum.Core.set_macro_keys(db, id, "")
    state = db |> start(extras: true) |> press([{:alt_f, 3}, {:f, 2}])
    assert %{type: :note, target: {:macro, _}} = State.mode(state)
    assert lines(press(state, ["- a", :enter])) |> List.last() == ""
  end
end
