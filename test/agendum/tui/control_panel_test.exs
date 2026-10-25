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
