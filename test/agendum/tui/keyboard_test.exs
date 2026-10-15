defmodule Agendum.TUI.KeyboardTest do
  @moduledoc "CTRL alternatives for keyboards without INS and for mapped ⌘ shortcuts."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core.Database
  alias Agendum.TUI.{Layout, Typing.LineEdit, State}

  setup do
    Process.delete(:effects_seen)
    %{state: start(Agendum.Sample.build(~D[2026-10-08]))}
  end

  test "CTRL-N starts a new item (INS)", %{state: state} do
    state = press(state, [{:ctrl, "n"}, "From ctrl-n", :enter])
    assert Enum.any?(Database.items(state.db), &(&1.text == "From ctrl-n"))
  end

  test "CTRL-N in a column adds another entry", %{state: state} do
    state = press(state, [:down, :down, :right, :right, :right, {:ctrl, "n"}, "Daniel", :enter])
    # both, by their short names in the narrow column
    assert screen(state) =~ "Anna, Daniel"
  end

  test "CTRL-N in the category manager adds a category", %{state: state} do
    state = press(state, [{:f, 9}, :ctrl_end, {:ctrl, "n"}, "Errands", :enter])
    assert Database.find_categories(state.db, "Errands") != []
  end

  test "CTRL-E edits (F2) and CTRL-K marks done (F4)", %{state: state} do
    state = press(state, [:down, {:ctrl, "e"}, {:ctrl, "u"}, "Edited", :enter])
    assert Layout.current_row(state).item.text == "Edited"

    state = press(state, {:ctrl, "k"})
    assert Layout.current_row(state).item.done
  end

  test "CTRL-O opens, CTRL-P prints, CTRL-S saves", %{state: state} do
    assert screen(press(state, {:ctrl, "o"})) =~ "File to retrieve:"
    assert screen(press(state, {:ctrl, "p"})) =~ "Print view to text file:"
    assert screen(press(%{state | path: "/tmp/a.agenda"}, {:ctrl, "s"})) =~ ""
    assert {:save, "/tmp/a.agenda"} in effects()
  end

  test "CTRL-S also works from the category manager", %{state: state} do
    press(%{state | path: "/tmp/b.agenda"}, [{:f, 9}, {:ctrl, "s"}])
    assert {:save, "/tmp/b.agenda"} in effects()
  end

  test "⌥↑ / ⌥↓ jump between sections in a view" do
    db = Agendum.Sample.build(~D[2026-10-08])
    [view] = Database.views(db)
    db = Agendum.Core.add_section(db, view.id, hd(Database.find_categories(db, "Meetings")), 1)
    state = start(db) |> press({:alt, :down})
    assert State.mode(state) == nil
    assert {:section, 1} = state.cursor_key
  end

  test "help scrolls and closes", %{state: state} do
    state = press(state, [{:f, 1}, "a", :pgdn])
    assert %{type: :help, top: top} = State.mode(state)
    assert top > 0
    assert press(state, :esc).modes == []
  end

  describe "editing keys" do
    defp edit(text, keys),
      do: Enum.reduce(keys, LineEdit.new(text), &elem(LineEdit.handle(&2, &1), 1))

    test "CTRL-A / CTRL-E go to start / end" do
      assert edit("hello", [{:ctrl, "a"}, {:char, ">"}]).text == ">hello"
      assert edit("hello", [:home, {:ctrl, "e"}, {:char, "!"}]).text == "hello!"
    end

    test "⌥← / ⌥→ move by word" do
      assert edit("one two three", [{:alt, "b"}, {:char, "_"}]).text == "one two _three"

      assert edit("one two three", [{:alt, :left}, {:alt, :left}, {:char, "_"}]).text ==
               "one _two three"

      assert edit("one two", [:home, {:alt, "f"}, {:char, "_"}]).text == "one_ two"
    end

    test "CTRL-K deletes to end, CTRL-W and ⌥⌫ delete the previous word" do
      assert edit("one two", [{:ctrl, "a"}, {:alt, "f"}, {:ctrl, "k"}]).text == "one"
      assert edit("one two", [{:ctrl, "w"}]).text == "one "
      assert edit("one two", [{:alt, :backspace}]).text == "one "
    end
  end
end
