defmodule Agendum.TUI.ControlPanelTest do
  @moduledoc """
  The control panel's two lines as Agenda's (checked in Agenda 2.0,
  2026-10-25): while a box is open they are its help and nothing else (no
  file, time or view), blank with EDIT at the right while a field is typed
  in; in a view the hide settings follow the view's name in one bracket,
  and a datebook's "Datebook For:" starts at column 40.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Core
  alias Agendum.Core.Datebook
  alias Agendum.Starters.Planner
  alias Agendum.TUI.{Layout, State}

  @today ~D[2026-10-12]

  setup do
    db = Planner.build() |> Planner.with_samples(@today)
    %{state: start(db, today: @today, height: 25, width: 80)}
  end

  defp line(state, n), do: state |> screen() |> String.split("\n") |> Enum.at(n)

  describe "while a box is open" do
    test "line 1 is the field's help only, without the time; line 2 is blank",
         %{state: state} do
      box = props(state, :view)
      assert line(box, 0) =~ ~r/^ Type a name for the view\./
      refute line(box, 0) =~ "2026-10-12"
      assert String.trim(line(box, 1)) == ""
      refute screen(box) =~ "View: "
    end

    test "a long help goes on into line 2, as Agenda's", %{state: state} do
      # 84 characters: one more line than the 78 the screen gives
      box = state |> props(:view) |> to_setting("Hide dependent items")
      assert line(box, 0) =~ ~r/^ Choose whether to display items you can't do until a/
      assert line(box, 1) =~ ~r/^ \S/
      refute line(box, 0) =~ "2026-10-12"

      # one that fits stays on line 1, the time no longer taking its room
      box = to_setting(box, "Hide done items")
      assert String.trim(line(box, 1)) == ""
    end

    test "typing in a field leaves line 1 blank but for EDIT at the right", %{state: state} do
      typing = state |> props(:view) |> press({:f, 2})
      assert line(typing, 0) =~ ~r/^ +EDIT *$/
      assert String.trim(line(typing, 1)) == ""

      # ENTER ends the typing, and the help comes back
      assert line(press(typing, :enter), 0) =~ "Type a name for the view."
    end

    test "the view manager has its help there too", %{state: state} do
      manager = press(state, {:f, 8})
      refute line(manager, 0) =~ "2026-10-12"
      refute line(manager, 0) =~ "File:"
    end
  end

  describe "in a view" do
    # Agenda's clock (checked in Agenda 2.0, 2026-10-25, its DOS clock set
    # by hand): the date, two spaces, the time right-aligned in seven
    # columns ("10/25/26   9:18pm", "10/25/26  10:30am"; "10/25/26    09:05"
    # on a 24-hour clock), at the end of the line
    test "the File line ends with the date and the time in a field of seven", %{state: state} do
      assert line(state, 0) =~ ~r/ 10\/12\/26   9:00am$/
      at_ten = %{state | now: ~N[2026-10-12 10:30:00]}
      assert line(at_ten, 0) =~ ~r/ 10\/12\/26  10:30am$/
      iso = %Core.DateFormat{}
      assert line(%{state | db: %{state.db | date_format: iso}}, 0) =~ ~r/ 2026-10-12    09:00$/
    end

    # Agenda's mark for marked items (checked in Agenda 2.0, 2026-10-25):
    # ♦ (CP437 0x04) in column 78 of the View line, after the # and ♪
    # marks; nothing beside the clock
    test "♦ on the View line while items are marked", %{state: state} do
      marked = press(state, [:down, {:f, 7}])
      assert String.at(line(marked, 1), 77) == "♦"
      refute line(marked, 0) =~ "♦"
      refute line(state, 1) =~ "♦"
    end
  end

  # Agenda's alarm mark (checked in Agenda 2.0, 2026-10-25): @ in column
  # 76 of the View line while the past alarms list an item, gone once
  # they are all removed (not when the list is opened)
  test "@ on the View line while there are past alarms", %{state: state} do
    refute line(state, 1) =~ "@"
    state = press(state, [:down, {:alt, "a"}, :enter])
    item = Layout.current_row(state).item
    {state, _} = Agendum.TUI.Update.tick(state, Core.alarm_at(state.db, item))
    assert String.at(line(state, 1), 75) == "@"
    refute line(state, 0) =~ "@"

    state = %{state | db: Core.remove_past_alarm(state.db, item.id)}
    refute line(state, 1) =~ "@"
  end

  # Agenda's o (Help, View Indicators: the file has a circular reference;
  # its column unchecked): worked out when a key changes the file, as the
  # owner chose
  test "o on the View line while an item is caught in a circular reference", %{state: state} do
    refute String.at(line(state, 1), 74) == "o"
    db = state.db
    {:ok, db, folk} = Core.add_category(db, db.main_id, "Folk")
    {:ok, db, ed} = Core.add_category(db, folk, "Ed")
    {:ok, db} = Core.add_condition(db, ed, folk, :not_assigned)
    state = %{state | db: db}

    # a key that changes the file (a new item) works it out
    state = press(state, [:down, "Lunch", :enter])
    assert MapSet.size(state.circular) == 1
    assert String.at(line(state, 1), 74) == "o"
  end

  describe "while an item is typed" do
    # Agenda's: the File line, the date and EDIT where the time was
    # (checked in Agenda 2.0, 2026-10-25: "File: C:\\APPS\\AGENDA\\SS  10/25/26 EDIT")
    test "a new item: the File line with EDIT in the time's place", %{state: state} do
      typing = press(state, [:down, "Call Bob"])
      assert line(typing, 0) =~ ~r/^ File: .* 10\/12\/26 EDIT *$/
      refute line(typing, 0) =~ "09:00"
      refute line(typing, 0) =~ "Type the new item"
      assert line(typing, 1) =~ ~r/^ View: /
    end

    test "editing an item's text (F2): the same", %{state: state} do
      typing = press(state, [:down, {:f, 2}])
      assert line(typing, 0) =~ ~r/^ File: .* 10\/12\/26 EDIT *$/
    end
  end

  describe "the view's hide settings" do
    test "one bracket after the view's name, Hide written once, in Agenda's order",
         %{state: state} do
      name = State.view(state).name
      state = switch_view_setting(state, "Hide done items")
      assert line(state, 1) =~ ~r/^ View: #{name} \[Hide done\] *$/

      state =
        state
        |> switch_view_setting("Hide dependent items")
        |> switch_view_setting("Hide empty sections")
        |> switch_view_setting("Hide inherited items")

      assert line(state, 1) =~
               ~r/^ View: #{name} \[Hide empty, done, inherited, dependent\]/
    end

    # the People view's filter, as in Agenda's PLANNER
    test "straight after a filter", %{state: state} do
      people = Enum.find(Map.values(state.db.views), &(&1.name == "People"))
      state = state |> State.switch_view(people.id) |> Layout.settle()
      state = switch_view_setting(state, "Hide done items")
      assert line(state, 1) =~ ~r/^ View: People \[-Contact List\]\[Hide done\]/
    end

    test "our [No Auto Dates] stays at the right", %{state: state} do
      state = State.run(state, :toggle_auto_date)
      assert line(state, 1) =~ ~r/^ View: \S+ +\[No Auto Dates\]/
    end
  end

  describe "a datebook view" do
    setup %{state: state} do
      {:ok, db, view} = Core.add_datebook_view(state.db, "Week", %Datebook{})
      %{datebook: %{state | db: db} |> State.switch_view(view) |> Layout.settle()}
    end

    test "Datebook For: starts at column 40", %{datebook: state} do
      assert line(state, 1) =~ ~r/^ View: Week {29}Datebook For: When/
    end

    test "the hide bracket is cut short before it with ..", %{state: state} do
      {:ok, db, view} = Core.add_datebook_view(state.db, "Tomorrow", %Datebook{})
      state = %{state | db: db} |> State.switch_view(view) |> Layout.settle()

      state =
        Enum.reduce(
          ["Hide empty sections", "Hide done items", "Hide inherited items"],
          state,
          &switch_view_setting(&2, &1)
        )

      assert line(state, 1) =~ ~r/^ View: Tomorrow\[Hide empty, done, in\.\.\] Datebook For: When/
    end
  end
end
