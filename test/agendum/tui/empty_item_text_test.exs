# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.EmptyItemTextTest do
  # An item with no text, as Agenda takes it (R21, checked in Agenda,
  # 2026-10-31): an emptied text keeps the item, blank, and ENTER on an empty
  # new line makes a blank item.
  use ExUnit.Case, async: true
  import Agendum.TUIHelpers

  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.TUI.Layout

  @today ~D[2026-10-31]

  # a file with a section Errands holding "Call Anna", highlighted
  defp errands do
    db = Core.new_file()
    {:ok, db, errands} = Core.add_category(db, db.main_id, "Errands")
    db = Core.set_section_category(db, hd(db.view_order), 0, errands)
    {db, call} = Core.add_item(db, "Call Anna", @today, section: errands)

    state = db |> start(today: @today) |> press(:down)
    %{state: state, errands: errands, call: call}
  end

  defp new_ids(before, done), do: Map.keys(done.db.items) -- Map.keys(before.db.items)

  describe "an item's text emptied" do
    test "F2, the text erased, ENTER: the item stays, blank, in its section" do
      %{state: state, errands: errands, call: call} = errands()
      done = press(state, [{:f, 2}, {:ctrl, "u"}, :enter])

      assert done.edit == nil
      assert done.db.items[call].text == ""
      assert Database.member?(done.db, call, errands)
      assert Layout.current_row(done).item.id == call
    end

    test "↓ on an emptied text takes it and moves on" do
      %{state: state, call: call} = errands()
      done = press(state, [{:f, 2}, {:ctrl, "u"}, :down])

      assert done.edit == nil
      assert done.db.items[call].text == ""
    end

    test "one undo gives the text back" do
      %{state: state, call: call} = errands()
      done = press(state, [{:f, 2}, {:ctrl, "u"}, :enter, {:ctrl, "z"}])

      assert done.db.items[call].text == "Call Anna"
    end

    test "Item Properties takes an emptied text too" do
      %{state: state, call: call} = errands()
      done = press(state, [{:f, 6}, {:f, 2}, {:ctrl, "u"}, :enter])

      assert done.db.items[call].text == ""
      refute panel(done) =~ "cannot be empty"

      closed = press(done, :enter)
      assert closed.db.items[call].text == ""
    end
  end

  describe "ENTER on an empty new line" do
    test "after INS makes a blank item in the section" do
      %{state: state, errands: errands} = errands()
      done = press(state, [:insert, :enter])

      assert [id] = new_ids(state, done)
      assert done.db.items[id].text == ""
      assert Database.member?(done.db, id, errands)
      assert Layout.current_row(done).item.id == id
    end

    test "with the typing erased makes a blank item too" do
      %{state: state} = errands()
      done = press(state, ["x", :backspace, :enter])

      assert [id] = new_ids(state, done)
      assert done.db.items[id].text == ""
    end

    test "TAB makes a blank item too, as Agenda's" do
      %{state: state} = errands()
      done = press(state, [:insert, :tab])

      assert [id] = new_ids(state, done)
      assert done.db.items[id].text == ""
    end

    test "ESC, ↑ or ↓ make nothing (Agenda's ↓ makes none)" do
      %{state: state} = errands()

      for key <- [:esc, :up, :down] do
        assert new_ids(state, press(state, [:insert, key])) == []
      end
    end
  end
end
