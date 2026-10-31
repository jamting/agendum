# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.ReviewSliceETest do
  @moduledoc """
  The findings of the local review of group e, the keys (`tui/update/`,
  the keymaps, the moves and typing; docs/CODE_REVIEW_SLICES.md § The
  rest; 2026-10-30), each as the case that showed it.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Core
  alias Agendum.Core.Database

  @today ~D[2026-10-31]

  # An Expenses section with the columns When, Amount (numeric) and
  # Address (unindexed), and the item heat; the cursor on heat's text.
  defp columns do
    db = Core.new_file()
    {:ok, db, expenses} = Core.add_category(db, db.main_id, "Expenses")
    {:ok, db, amount} = Core.add_category(db, db.main_id, "Amount")
    {:ok, db} = Core.make_numeric(db, amount)
    {:ok, db, address} = Core.add_category(db, db.main_id, "Address")
    view = hd(db.view_order)
    db = Core.set_section_category(db, view, 0, expenses)
    db = Core.add_column(db, view, amount, {0, 1})
    {:ok, db} = Core.add_column_as(db, view, address, :unindexed, {0, 2})
    {db, heat} = Core.add_item(db, "heat", @today, section: expenses)

    state = db |> start(today: @today) |> press(:down)
    %{state: state, amount: amount, address: address, heat: heat}
  end

  # Item Properties' F4 on the assignment to `cat_id`, found among the
  # box's rows
  defp values_prompt(state, cat_id) do
    alias Agendum.TUI.Boxes.ItemProperties
    box = press(state, {:f, 6})
    rows = ItemProperties.rows(box, Agendum.TUI.State.mode(box))
    at = Enum.find_index(rows, &match?({:assigned, %{category: ^cat_id}}, &1))
    press(box, List.duplicate(:down, at) ++ [{:f, 4}])
  end

  describe "1. an empty answer in Item Properties' F4 (checked in Agenda, 2026-10-31)" do
    # Agenda's column: an empty number is refused with its message, the
    # number kept; an empty text takes the text out
    test "an empty number is refused, as Agenda's, and the number kept" do
      %{state: state, amount: amount, heat: heat} = columns()
      state = press(state, [:right, :right, "150", :enter, :left, :left])
      asked = values_prompt(state, amount)
      done = press(asked, [{:ctrl, "u"}, :enter])

      assert panel(done) =~ message(:bad_number)
      assert Database.number(done.db, heat, amount) == 150.0
    end

    test "an empty text takes the unindexed text out" do
      %{state: state, address: address, heat: heat} = columns()
      state = press(state, [:right, :right, :right, "12 Grant Ave", :enter, :left, :left, :left])
      asked = values_prompt(state, address)
      done = press(asked, [{:ctrl, "u"}, :enter])

      assert Database.text(done.db, heat, address) == nil
    end

    test "an empty text typed in the unindexed column takes it out too (R29b)" do
      %{state: state, address: address, heat: heat} = columns()
      state = press(state, [:right, :right, :right, "12 Grant Ave", :enter])
      done = press(state, [{:f, 2}, {:ctrl, "u"}, :enter])

      assert Database.text(done.db, heat, address) == nil
    end

    test "an empty number typed in the numeric column is refused, as Agenda's" do
      %{state: state, amount: amount, heat: heat} = columns()
      state = press(state, [:right, :right, "150", :enter])
      done = press(state, [{:f, 2}, {:ctrl, "u"}, :enter])

      assert panel(done) =~ message(:bad_number)
      assert Database.number(done.db, heat, amount) == 150.0
    end
  end

  describe "2. ALT-F9 APPEND to a name that cannot change" do
    test "in MAIN's note the word stays in the note" do
      state = start(Core.new_file(), today: @today)
      # the category manager opens on MAIN; F5 its note
      note = press(state, [{:f, 9}, {:f, 5}, "Web", {:alt_f, 9}, :enter])

      assert note.db.categories[note.db.main_id].name == "MAIN"
      assert Agendum.TUI.State.mode(note).edit.lines == ["Web"]
      refute panel(note) =~ "Appended"
    end
  end

  describe "3. a When date whose category discards the item (R15b)" do
    test "the date is set, the item goes, and no crash" do
      db = Core.new_file()
      {:ok, db, bills} = Core.add_category(db, db.main_id, "Bills")
      db = Core.set_section_category(db, hd(db.view_order), 0, bills)
      {db, heat} = Core.add_item(db, "heat", @today, section: bills)
      {:ok, db} = Core.set_special_action(db, db.special.when, :discard)
      state = db |> start(today: @today) |> press(:down)

      done = press(state, [{:alt_f, 2}, {:ctrl, "u"}, "2026-11-05", :enter])
      refute Map.has_key?(done.db.items, heat)
      assert panel(done) =~ message(:discarded_by_action)
    end
  end

  describe "4. ALT-F8 GETITMS discarding the item whose note is open" do
    # Agenda discards it too, its note saved with it, what was typed and
    # pasted included (checked in Agenda, 2026-10-31)
    test "the item goes to the trash with its note, the pasted text kept" do
      db = Agendum.Starters.Planner.build() |> Agendum.Starters.Planner.with_samples(@today)
      state = start(db, today: @today, height: 25, width: 80)
      marked = press(state, [:down, {:f, 7}])
      [id] = Core.marked_items(marked.db)
      text = marked.db.items[id].text

      done = press(marked, [{:f, 5}, :ctrl_end, " typed", {:alt_f, 8}, :enter])
      refute Map.has_key?(done.db.items, id)
      assert [%{id: ^id, note: note}] = done.db.trash.items
      assert note =~ "typed"
      assert note =~ text
      refute Enum.any?(done.modes, &(&1.type == :note))
    end
  end

  describe "6. an item's text emptied" do
    # Agenda takes an empty text (checked in Agenda, 2026-10-31); ours
    # refuses it, and the refusal now shows over the line still open
    test "ENTER says it cannot be empty, and the line stays open to retype" do
      %{state: state, heat: heat} = columns()
      done = press(state, [{:f, 2}, {:ctrl, "u"}, :enter])

      assert done.edit != nil
      assert panel(done) =~ "Item text cannot be empty"
      assert done.db.items[heat].text == "heat"

      typed = press(done, ["coal", :enter])
      assert typed.db.items[heat].text == "coal"
    end

    test "↓ on an emptied text stays in the line too" do
      %{state: state, heat: heat} = columns()
      done = press(state, [{:f, 2}, {:ctrl, "u"}, :down])

      assert done.edit != nil
      assert done.db.items[heat].text == "heat"
    end
  end

  # an item of the sample file, its note "Ask the Personnel Division" open
  defp note_open do
    state = start(Agendum.Sample.build(@today)) |> press(:down)
    item = Agendum.TUI.Layout.current_row(state).item
    state = %{state | db: Core.set_note(state.db, item.id, "Ask the Personnel Division", @today)}
    press(state, {:f, 5})
  end

  defp note_mode(state), do: Enum.find(state.modes, &(&1.type == :note))

  describe "7. OVR in a note (R64e)" do
    test "stays on after a Search/Replace replacement" do
      over = press(note_open(), :insert)
      assert note_mode(over).edit.overwrite

      # rows with Replace text = Yes: text, replace, replace with, direction,
      # ignore case, global, confirm
      replaced =
        press(
          over,
          [{:alt_f, 6}, "Personnel", :down, " ", :down, "HR", :down, :down, :down] ++
            [:down, " ", :enter]
        )

      assert note_mode(replaced).edit.lines == ["Ask the HR Division"]
      assert note_mode(replaced).edit.overwrite
    end

    test "stays on after File ▸ Clear" do
      cleared = press(note_open(), [:insert, {:f, 10}, "c", :enter])
      assert note_mode(cleared).edit.lines == [""]
      assert note_mode(cleared).edit.overwrite
    end
  end

  describe "8. a search match in a note" do
    # the match's highlight goes once the text moves under it
    for key <- [{:alt, "d"}, {:alt, "t"}, :tab] do
      test "goes after #{inspect(key)}" do
        found = press(note_open(), [{:alt_f, 6}, "Personnel", :enter])
        assert note_mode(found).match != nil

        typed = press(found, unquote(Macro.escape(key)))
        assert note_mode(typed).match == nil
      end
    end
  end
end
