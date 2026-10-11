defmodule Agenda.TUI.ViewTest do
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.Core
  alias Agenda.Core.Database

  setup do
    Process.delete(:effects_seen)
    %{state: start(Agenda.Sample.build(~D[2026-10-08]))}
  end

  test "the screen resembles Agenda", %{state: state} do
    screen = screen(state)
    assert screen =~ "View: Activities"
    assert screen =~ ~r/Calls\s+When\s+Priority\s+Contact/
    assert screen =~ ~r/Don't forget to call Anna Lasky.*High\s+Anna Lasky/
    assert screen =~ "F9 CatMgr F10 Menu"
  end

  test "typing under a section adds an item and assigns it", %{state: state} do
    state = press(state, ["Ring Anna about the budget", :enter])
    id = Enum.find(Database.items(state.db), &(&1.text == "Ring Anna about the budget")).id

    names =
      state.db
      |> Database.explicit_categories(id)
      |> Enum.map(&state.db.categories[&1].name)
      |> Enum.sort()

    assert names == ["Anna Lasky", "Calls"]
    assert screen(state) =~ "Also assigned to: Anna Lasky"
    assert state.cursor_key == {:item, 0, id}
  end

  test "ESC cancels a new item", %{state: state} do
    count = length(Database.items(state.db))
    state = press(state, ["Never mind", :esc])
    assert length(Database.items(state.db)) == count
  end

  test "typing in a column assigns a category, creating it when new", %{state: state} do
    # the second item is assigned to Anna Lasky; typing over the entry replaces it
    state = press(state, [:down, :down, :right, :right, :right, "Zoe", :enter])
    item = Agenda.TUI.Layout.current_row(state).item
    [zoe] = Database.find_categories(state.db, "Zoe")

    assert state.db.categories[zoe].parent_id == hd(Database.find_categories(state.db, "Contact"))
    assert Database.member?(state.db, item.id, zoe)

    refute Database.member?(
             state.db,
             item.id,
             hd(Database.find_categories(state.db, "Anna Lasky"))
           )
  end

  test "INS in a column adds another entry", %{state: state} do
    state = press(state, [:down, :down, :right, :right, :right, :insert, "Daniel", :enter])
    assert screen(state) =~ "Anna Lasky, Daniel"
  end

  test "typing in the When column parses dates", %{state: state} do
    state = press(state, [:down, :right, "tomorrow", :enter])
    assert Agenda.TUI.Layout.current_row(state).item.when == ~D[2026-10-09]
    assert screen(state) =~ "2026-10-09"
  end

  test "F2 edits an item's text", %{state: state} do
    state = press(state, [:down, {:f, 2}, {:ctrl, "u"}, "Rewritten", :enter])
    assert Agenda.TUI.Layout.current_row(state).item.text == "Rewritten"
  end

  test "F2 on a section head renames the category", %{state: state} do
    state = press(state, [{:f, 2}, {:ctrl, "u"}, "Phone calls", :enter])
    assert screen(state) =~ "Phone calls"
  end

  test "F4 marks done, DEL removes from the section, ALT-F4 discards", %{state: state} do
    state = press(state, [:down, {:f, 4}])
    assert Agenda.TUI.Layout.current_row(state).item.done == ~D[2026-10-08]

    count = length(Database.items(state.db))
    state = press(state, [:delete])
    assert length(Database.items(state.db)) == count
    assert length(Agenda.TUI.Layout.rows(state)) == count

    state = press(state, [:down, {:alt_f, 4}, "y"])
    assert length(Database.items(state.db)) == count - 1
  end

  test "ALT-D adds a section via the category picker", %{state: state} do
    state = press(state, [{:alt, "d"}, "Meet", :enter])
    assert [_, %{category_id: meetings}] = Agenda.TUI.State.view(state).sections
    assert state.db.categories[meetings].name == "Meetings"
  end

  test "the picker can create a new category with INS", %{state: state} do
    state = press(state, [{:alt, "d"}, :insert, "Errands", :enter])
    assert screen(state) =~ "Errands"
  end

  test "F10 opens the menu; letters select commands", %{state: state} do
    state = press(state, [{:f, 10}])

    assert screen(state) =~
             ~r/File\s+Item\s+Category\s+View\s+Search\s+Undo\s+Redo\s+Print\s+Quit/

    state = press(state, ["v", "h", "d"])
    assert Agenda.TUI.State.view(state).hide_done
    assert state.modes == []
  end

  test "saving without a path prompts for one", %{state: state} do
    state = press(state, [{:ctrl, "s"}])
    assert screen(state) =~ "Save file as:"
    _state = press(state, ["/tmp/x", :enter])
    assert [{:save, "/tmp/x.agenda"}] = effects()
  end

  test "quitting with unsaved changes asks first", %{state: state} do
    state = press(state, ["dirty", :enter, {:ctrl, "q"}])
    assert screen(state) =~ "Save changes before quitting?"
    press(state, ["n"])
    assert :quit in effects()
  end

  test "ALT-F10 moves an item to another section" do
    db = Agenda.Sample.build(~D[2026-10-08])
    [view] = Database.views(db)
    meetings = hd(Database.find_categories(db, "Meetings"))
    db = Core.add_section(db, view.id, meetings, 1)
    state = start(db)

    state = press(state, [:down, {:alt_f, 10}, :end, :enter])
    item = Agenda.TUI.Layout.current_row(state).item
    assert Database.member?(state.db, item.id, meetings)
    refute Database.member?(state.db, item.id, hd(Database.find_categories(db, "Calls")))
  end

  describe "When dates from item text (R14)" do
    test "typing an item with a date fills the When column and says so", %{state: state} do
      state = press(state, ["Call Bob next Tuesday", :enter])
      screen = screen(state)
      assert screen =~ "When: 2026-10-13"
      assert screen =~ ~r/Call Bob next Tuesday\s+2026-10-13/
    end

    test "editing the date words updates the When date", %{state: state} do
      state = press(state, ["Call Bob next Tuesday", :enter])
      state = press(state, [{:f, 2}, {:ctrl, "u"}, "Call Bob next Wednesday", :enter])
      assert Agenda.TUI.Layout.current_row(state).item.when == ~D[2026-10-14]
    end

    test "ALT-F2 sets an explicit When date that later edits keep", %{state: state} do
      state = press(state, ["Call Bob next Tuesday", :enter, {:alt_f, 2}])
      assert screen(state) =~ "When date (overrides dates in the text):"

      state = press(state, [{:ctrl, "u"}, "December 24", :enter])
      item = Agenda.TUI.Layout.current_row(state).item
      assert item.when == ~D[2026-12-24]
      assert item.when_explicit

      state = press(state, [{:f, 2}, {:ctrl, "u"}, "Call Bob next Friday", :enter])
      assert Agenda.TUI.Layout.current_row(state).item.when == ~D[2026-12-24]
    end

    test "an invalid When date is reported", %{state: state} do
      state = press(state, [:down, {:alt_f, 2}, {:ctrl, "u"}, "someday", :enter])
      assert screen(state) =~ "Not a date: someday"
    end

    test "File Dating turns automatic dating off, shown in the title bar", %{state: state} do
      state = press(state, [{:f, 10}, "f", "d"])
      refute Agenda.Core.auto_dating?(state.db)
      assert screen(state) =~ "[No Auto Dates]"

      state = press(state, ["Call Bob next Tuesday", :enter])
      assert Agenda.TUI.Layout.current_row(state).item.when == nil
    end
  end

  describe "automatic completion in columns (R32)" do
    setup %{state: state} do
      priority = hd(Database.find_categories(state.db, "Priority"))
      {:ok, db, _} = Core.add_category(state.db, priority, "Lowest")
      # the second item ("Don't forget to call Anna Lasky...") is High
      state = %{state | db: db} |> press([:down, :down, :right, :right])
      %{state: state}
    end

    defp priority_of(state) do
      item = Agenda.TUI.Layout.current_row(state).item

      [cell] =
        Agenda.Core.ViewModel.build(state.db, Agenda.TUI.State.view(state))
        |> hd()
        |> Map.get(:rows)
        |> Enum.filter(&(&1.item.id == item.id))
        |> Enum.map(&Enum.at(&1.cells, 1))

      cell
    end

    test "shows the first match, how many match, and AUTOC", %{state: state} do
      state = press(state, "L")
      screen = screen(state)
      assert screen =~ "AUTOC"
      assert screen =~ ~s(2 categories begin with "L")
      assert screen =~ "Low"
    end

    test "ENTER accepts the shown match", %{state: state} do
      state = press(state, ["me", :enter])
      assert priority_of(state) == "Medium"
    end

    test "F8 / ALT-N and F7 / ALT-P cycle through the matches", %{state: state} do
      assert priority_of(press(state, ["L", {:f, 8}, :enter])) == "Lowest"
      assert priority_of(press(state, ["L", {:alt, "n"}, {:alt, "p"}, :enter])) == "Low"
      # cycling wraps around
      assert priority_of(press(state, ["L", {:f, 7}, :enter])) == "Lowest"
    end

    test "typing more starts again at the first match", %{state: state} do
      assert priority_of(press(state, ["L", {:f, 8}, "o", :enter])) == "Low"
    end

    test "INS creates exactly what was typed (the manual's Low/Lowest override)", %{state: state} do
      db = state.db
      {:ok, db} = Core.discard_category(db, hd(Database.find_categories(db, "Low")))
      state = %{state | db: db}

      state = press(state, ["Low", :insert])
      assert priority_of(state) == "Low"
      assert length(Database.find_categories(state.db, "Lowest")) == 1
    end

    test "with no match, ENTER creates the new category", %{state: state} do
      state = press(state, "Urgent")
      assert screen(state) =~ "New category: Urgent"
      assert priority_of(press(state, :enter)) == "Urgent"
    end

    test "date columns do not autocomplete", %{state: state} do
      state = press(state, [:left, "fri"])
      refute screen(state) =~ "AUTOC"
      assert screen(state) =~ "Enter a date"
    end
  end

  test "a narrow column shows short names (User's Guide 19-2)", %{state: state} do
    # the Contact column is 16 wide: "Abigail Scheer" fits
    assert screen(state) =~ "Abigail Scheer"

    # highlight the Contact column and narrow it to 10 (three steps of 2)
    narrower = [{:f, 10}, "v", "c", "n"]
    state = press(state, [:down, :right, :right, :right] ++ narrower ++ narrower ++ narrower)
    screen = screen(state)
    # the column ends right after the short names
    assert screen =~ ~r/Low\s+Abigail\n/
    assert screen =~ ~r/Medium\s+Daniel\n/
  end
end
