defmodule Agenda.TUI.ColumnBoxTest do
  @moduledoc """
  Column Properties of a standard column (View ▸ Column ▸ Properties;
  User's Guide 3-18 to 3-19, screenshots 127, 142, 144): its head, width,
  category type, and Link with other sections (R55), the part every
  column's box has.
  """
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  import Agenda.Fixtures, only: [cat: 2, with_categories: 2]

  alias Agenda.Core
  alias Agenda.Core.{Database, View}
  alias Agenda.TUI.{History, State}

  # Calls and Follow up, each with People (linked) and When; the cursor on
  # People in Calls, the box open.
  setup do
    db = Core.new_file(view_name: "Activities", section_name: "Calls")
    db = with_categories(db, ["Follow up", "People"])
    [view] = Database.views(db)
    db = Core.add_section(db, view.id, cat(db, "Follow up"), 1)
    db = Core.add_column(db, view.id, cat(db, "People"), {0, 0}, 12)
    {db, _} = Core.add_item(db, "Call the plumber", ~D[2026-10-08], section: cat(db, "Calls"))
    state = db |> start() |> press([:down, :right, {:f, 10}, "v", "c", "p"])
    %{state: state, view_id: view.id}
  end

  defp people(state, view_id, sidx),
    do: state.db.views[view_id] |> View.columns(sidx) |> hd()

  test "shows the column's settings, laid out as in Agenda", %{state: state} do
    assert %{type: :column_props} = State.mode(state)
    text = screen(state)
    assert text =~ "Column Properties"
    assert text =~ ~r/Column head: +People +Category type: +Standard/
    assert text =~ ~r/Width: +12 +Link with other sections: +Yes/
  end

  test "typing on Column head: another category, or a new one, in the linked sections too",
       %{state: state, view_id: v} do
    state = press(state, ["F", "o", "l", "l", "o", "w", " ", "u", "p", :enter])
    assert screen(state) =~ ~r/Column head: +Follow up/
    assert people(state, v, 1).category_id == cat(state.db, "Follow up")
    state = press(state, ["C", "o", "m", "p", "a", "n", "y", :enter])
    assert state.db.categories[people(state, v, 0).category_id].name == "Company"
    # one undo step each
    assert History.undo(state) |> people(v, 0) |> Map.fetch!(:category_id) ==
             cat(state.db, "Follow up")
  end

  describe "Format (R56; screenshot 127)" do
    test "SPACE goes through Agenda's formats, in every linked section", %{
      state: state,
      view_id: v
    } do
      # after Column head, Category type, Width and Link: Format
      state = press(state, [:down, :down, :down, :down])
      assert screen(state) =~ ~r/Format: +Name only/
      state = press(state, " ")
      assert screen(state) =~ ~r/Format: +Parent:Category/
      state = press(state, [" ", " ", " "])
      assert screen(state) =~ ~r/Format: +Yes\/No/
      assert {people(state, v, 0).format, people(state, v, 1).format} == {:yes_no, :yes_no}
      refute screen(state) =~ "Line number"
    end

    test "its value lines up with the values above it", %{state: state} do
      # Category note (the last format), with a title, so every row has a value
      state =
        press(state, [:down, :down] ++ List.duplicate(" ", 5) ++ [:down, :down, "P", :enter])

      lines = String.split(screen(state), "\n")

      # where the value after each label starts on the screen
      starts =
        for label <- ["Column head:", "Width:", "Format:", "Line number:", "Column title:"] do
          line = Enum.find(lines, &String.contains?(&1, label))
          [_, before] = Regex.run(~r/^(.*#{Regex.escape(label)} *)/u, line)
          String.length(before)
        end

      assert length(Enum.uniq(starts)) == 1
    end

    test "Category note: Line number and Column title, which heads the column",
         %{state: state, view_id: v} do
      # ↓ from Column head: Width, then Format; SPACE five times: Category note
      state = press(state, [:down, :down] ++ List.duplicate(" ", 5))
      assert screen(state) =~ ~r/Format: +Category note/
      assert screen(state) =~ ~r/Line number: +1/
      # a line number is typed
      state = press(state, [:down, "2", :enter, :down, "P", "h", "o", "n", "e", " ", "#", :enter])
      assert {people(state, v, 0).note_line, people(state, v, 0).title} == {2, "Phone #"}
      assert screen(state) =~ ~r/Column title: *Phone #/
      # in the view, Phone # heads the column instead of People
      assert state |> press(:enter) |> screen() =~ ~r/Calls +Phone #/
    end
  end

  test "Width: typed, in every linked section", %{state: state, view_id: v} do
    state = press(state, [:down, "1", "3", :enter])
    assert people(state, v, 0).width == 13
    assert people(state, v, 1).width == 13
    assert screen(state) =~ ~r/Width: +13/
  end

  test "Link with other sections: No, then the column changes alone, one undo step each",
       %{state: state, view_id: v} do
    # Column head | Category type, then Width | Link: ↓ then → is Link
    state = press(state, [:down, :right, " "])
    assert people(state, v, 0).link == nil
    assert screen(state) =~ ~r/Link with other sections: +No/
    state = press(state, [:left, "1", "3", :enter])
    assert {people(state, v, 0).width, people(state, v, 1).width} == {13, 12}
    state = History.undo(state)
    assert people(state, v, 0).width == 12
    assert History.undo(state) |> people(v, 0) |> Map.fetch!(:link)
  end

  test "Column head: F3 picks another category, in every linked section; the box shows its part",
       %{state: state, view_id: v} do
    state = press(state, {:f, 3})
    assert screen(state) =~ "Column Head"
    state = press(state, ["When", :enter])
    assert %{type: :column_props} = State.mode(state)
    assert people(state, v, 0).category_id == state.db.special.when
    assert people(state, v, 1).category_id == state.db.special.when
    assert screen(state) =~ "Date Column Properties"

    assert History.undo(state) |> people(v, 0) |> Map.fetch!(:category_id) ==
             cat(state.db, "People")
  end

  test "ENTER closes it; ESC goes back to the menu it came from", %{state: state} do
    assert %{type: :menu} = State.mode(press(state, :esc))
    assert press(state, :enter).modes == []
  end

  describe "moving between settings, as Agenda (User's Guide 2-16)" do
    defp at(state), do: Agenda.TUI.ColumnBox.field(state, State.mode(state))

    test "→ ← along a row, on to the next or back to the previous", %{state: state} do
      assert at(state) == :head
      assert at(press(state, :right)) == :type
      assert at(press(state, [:right, :right])) == :width
      assert at(press(state, [:right, :right, :left])) == :type
      assert at(press(state, [:tab, :tab, :shift_tab])) == :type
    end

    test "↓ ↑ keep to their side, to the left one when there is none", %{state: state} do
      # Category type is right of Column head; Link right of Width; Format alone
      assert at(press(state, [:right, :down])) == :linked
      assert at(press(state, [:right, :down, :down])) == :format
      assert at(press(state, [:right, :down, :down, :up])) == :width
      assert at(press(state, :end)) == :format
      assert at(press(state, [:end, :home])) == :head
    end
  end
end
