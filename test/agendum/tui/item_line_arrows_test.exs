# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.ItemLineArrowsTest do
  # ↑ and ↓ stay in an item's line while it is typed, as Agenda's (R21,
  # checked in Agenda, 2026-10-31): only ENTER or TAB take the text, ESC
  # throws it away. Agenda's ↑/↓ move between the lines of a long, wrapped
  # text; ours edits on one line, so they do nothing (ROADMAP: wrapped
  # editing).
  use ExUnit.Case, async: true
  import Agendum.TUIHelpers

  alias Agendum.Core
  alias Agendum.TUI.Layout

  @today ~D[2026-10-31]

  # a section Errands with "Call Anna" and "Buy milk", the first highlighted
  defp errands do
    db = Core.new_file()
    {:ok, db, errands} = Core.add_category(db, db.main_id, "Errands")
    db = Core.set_section_category(db, hd(db.view_order), 0, errands)
    {db, call} = Core.add_item(db, "Call Anna", @today, section: errands)
    {db, milk} = Core.add_item(db, "Buy milk", @today, section: errands, after: call)

    state = db |> start(today: @today) |> press(:down)
    %{state: state, call: call, milk: milk}
  end

  for key <- [:up, :down] do
    test "#{key} while F2 edits an item keeps the line open, the text untaken" do
      %{state: state, call: call} = errands()
      done = press(state, [{:f, 2}, :end, " soon", unquote(key)])

      assert %{target: {:edit_item, ^call}} = done.edit
      assert done.db.items[call].text == "Call Anna"
      assert Layout.current_row(done).item.id == call

      # typing goes on where it was, and ENTER takes it all
      taken = press(done, ["!", :enter])
      assert taken.db.items[call].text == "Call Anna soon!"
    end

    test "#{key} while a new item is typed keeps the line open, no item made" do
      %{state: state} = errands()
      done = press(state, [:insert, "Post letter", unquote(key)])

      assert %{target: {:new_item, _, _}} = done.edit
      assert map_size(done.db.items) == map_size(state.db.items)
    end
  end

  # Agenda's F2 starts at the beginning of the text (checked in Agenda,
  # 2026-10-31); END goes to its end
  test "F2 puts the cursor at the start of the item's text" do
    %{state: state, call: call} = errands()
    done = press(state, [{:f, 2}, "Do: ", :enter])
    assert done.db.items[call].text == "Do: Call Anna"

    ended = press(state, [{:f, 2}, :end, " soon", :enter])
    assert ended.db.items[call].text == "Call Anna soon"
  end

  test "TAB still takes the text and moves on" do
    %{state: state, call: call} = errands()
    done = press(state, [{:f, 2}, :end, " soon", :tab])

    assert done.edit == nil
    assert done.db.items[call].text == "Call Anna soon"
  end
end
