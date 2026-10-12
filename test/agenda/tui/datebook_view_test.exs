defmodule Agenda.TUI.DatebookViewTest do
  @moduledoc "A datebook view in the TUI (R47): its slots, typing into one, and its restrictions."
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.Core
  alias Agenda.Core.Datebook
  alias Agenda.TUI.{Layout, State}

  # Monday 12 October 2026
  setup do
    db = Agenda.Sample.build(~D[2026-10-12])
    {:ok, db, view} = Core.add_datebook_view(db, "This week", %Datebook{})
    state = start(db, width: 80, height: 25, today: ~D[2026-10-12])
    state = %{state | now: ~N[2026-10-12 10:00:00]}
    %{state: state |> State.switch_view(view) |> Layout.settle()}
  end

  test "each slot is a section, named by its date", %{state: state} do
    text = screen(state)
    for day <- ~w(Mon Tue Wed Thu Fri), do: assert(text =~ day <> " 2026-10-")
    assert text =~ "Mon 2026-10-12"
    assert text =~ "Fri 2026-10-16"
  end

  test "an item typed into a slot gets the slot's date", %{state: state} do
    # Wednesday's slot is the third section; its head is the third row
    wednesday =
      Enum.find_index(Layout.rows(state), &(&1[:slot] && &1.slot.from == ~D[2026-10-14]))

    state = state |> Layout.move_to(wednesday) |> press(["Picnic with Pooh", :enter])

    item = state.db.items |> Map.values() |> Enum.find(&(&1.text == "Picnic with Pooh"))
    assert item.when == ~D[2026-10-14]
    assert screen(state) =~ ~r/── Wed 2026-10-14 ─+\n • Picnic with Pooh/u
  end

  test "its sections cannot be added, removed, changed or collapsed", %{state: state} do
    for keys <- [{:alt, "d"}, {:alt, "u"}, :delete, {:f, 3}, {:alt, "-"}] do
      after_ = press(state, keys)
      assert after_.db == state.db
      assert screen(after_) =~ "A datebook view's sections are its dates"
    end
  end

  describe "creating and changing one" do
    setup %{state: state} do
      %{plain: state |> State.switch_view(hd(state.db.view_order)) |> Layout.settle()}
    end

    defp datebook(state), do: State.view(state).datebook
    defp settings(state), do: press(state, [{:f, 10}, "v", "p"])

    test "View ▸ Add asks the type; Datebook makes one and opens its settings", %{plain: state} do
      state = press(state, [{:f, 10}, "v", "a", "Mornings", :enter])
      assert screen(state) =~ "Type of view:"

      state = press(state, "d")
      assert State.view(state).name == "Mornings"
      assert %Datebook{period: :week} = datebook(state)
      assert %{type: :datebook_props} = State.mode(state)
      assert screen(state) =~ ~r/Period +: Week/
      assert screen(state) =~ ~r/Base date on +: today \(2026-10-12\)/
    end

    test "the settings change the slots at once, one undo step each", %{state: state} do
      # Period: Week -> Month -> Quarter -> Day
      state = settings(state) |> press([:down, :down, :down, " ", " ", " "])
      assert datebook(state).period == :day
      assert screen(state) =~ ~r/Interval +: Hourly/
      assert screen(state) =~ ~r/Start at +: 08:00/

      state = press(state, [:down, " "])
      assert datebook(state).interval == 15

      # a time without am/pm falls between 8:00 and 19:59, as everywhere (R14b)
      state = press(state, [:down, :enter, {:ctrl, "u"}, "7:30am", :enter])
      assert datebook(state).start_time == ~T[07:30:00]

      state = press(state, [:down, :down, :enter, {:ctrl, "u"}, "next week", :enter])
      assert datebook(state).base == "next week"
      assert screen(state) =~ "(2026-10-19)"

      state = press(state, [:enter, {:ctrl, "u"}, "zebra", :enter])
      assert screen(state) =~ "Not a date: zebra"
      assert datebook(state).base == "next week"

      assert Agenda.TUI.History.undo(state) |> datebook() |> Map.get(:base) == "today"
    end

    test "a week's days cycle; categories are picked, End cleared with DEL", %{state: state} do
      state = settings(state) |> press([:down, :down, :down, :down, :down, " "])
      assert datebook(state).start_day == 2

      # End category: a standard category is refused
      state = press(state, [:up, :up, :up, :up, :enter, "Calls", :enter])
      assert screen(state) =~ "Pick a date category"
      assert datebook(state).end_category == nil

      state = press(state, [:enter, "Done", :enter])
      assert datebook(state).end_category == state.db.special.done
      state = press(state, :delete)
      assert datebook(state).end_category == nil
    end

    test "a standard view has no datebook settings", %{plain: state} do
      assert panel(settings(state)) =~
               "A standard view's settings are in View ▸ Hide, Filter and Order"
    end

    test "the control panel names the Section; the view manager marks it with *", %{state: state} do
      assert screen(state) =~ ~r/View: This week +Datebook for: When/
      assert screen(press(state, {:f, 8})) =~ ~r/\*This week +Datebook: week, When/
    end
  end

  describe "browsing (ALT-B)" do
    defp first_slot(state), do: Layout.rows(state) |> hd() |> Map.get(:slot) |> Map.get(:from)

    test "← → flip through the weeks; ESC goes back, the file unchanged", %{state: state} do
      db = state.db
      state = press(state, {:alt, "b"})
      assert %{type: :browse} = State.mode(state)
      assert screen(state) =~ "BROWSE"

      state = press(state, [:right, :right])
      assert first_slot(state) == ~D[2026-10-26]
      assert screen(state) =~ "Mon 2026-10-26"
      assert state.db == db

      state = press(state, :esc)
      assert state.modes == []
      assert first_slot(state) == ~D[2026-10-12]
    end

    test "ENTER keeps the period: the base date becomes its date, one undo step", %{state: state} do
      state = press(state, [{:alt, "b"}, :left, :enter])
      assert state.modes == []
      assert State.view(state).datebook.base == "2026-10-05"
      assert first_slot(state) == ~D[2026-10-05]

      undone = Agenda.TUI.History.undo(state)
      assert State.view(undone).datebook.base == "today"
    end

    test "ALT-F5 goes to the period of a typed date", %{state: state} do
      state = press(state, [{:alt, "b"}, {:alt_f, 5}, "2026-12-24", :enter])
      assert %{type: :browse} = State.mode(state)
      assert first_slot(state) == ~D[2026-12-21]
    end

    test "while browsing, nothing else can be done", %{state: state} do
      db = state.db
      state = press(state, [{:alt, "b"}, "x", :enter])
      assert state.db == db
    end

    test "a month view moves by months; a standard view cannot be browsed", %{state: state} do
      state = press(state, [{:f, 10}, "v", "p", :down, :down, :down, " ", :esc])
      state = press(state, [{:alt, "b"}, :right])
      assert State.view(state).datebook.period == :month
      assert screen(state) =~ "Mon 2026-10-26 → Fri 2026-10-30"
      assert screen(state) =~ "Mon 2026-11-02"

      plain =
        state |> press(:esc) |> State.switch_view(hd(state.db.view_order)) |> Layout.settle()

      assert panel(press(plain, {:alt, "b"})) =~ "Browse needs a datebook view"
    end
  end
end
