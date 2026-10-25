defmodule Agendum.TUI.DatebookViewTest do
  @moduledoc "A datebook view in the TUI (R47): its slots, typing into one, and its restrictions."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.Core.Datebook
  alias Agendum.TUI.{Layout, State}

  # Monday 12 October 2026
  setup do
    db = Agendum.Sample.build(~D[2026-10-12])
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
    assert screen(state) =~ ~r/── Wed 2026-10-14 ─+\n    • Picnic with Pooh/u
  end

  test "its sections cannot be added, removed, changed or collapsed", %{state: state} do
    for keys <- [{:alt, "d"}, {:alt, "u"}, :delete, {:f, 3}, {:alt, "-"}] do
      after_ = press(state, keys)
      assert after_.db == state.db
      assert panel(after_) =~ message(:datebook_change)
    end
  end

  describe "creating and changing one" do
    setup %{state: state} do
      %{plain: state |> State.switch_view(hd(state.db.view_order)) |> Layout.settle()}
    end

    defp datebook(state), do: State.view(state).datebook
    defp settings(state), do: press(state, [{:f, 10}, "v", "p"])

    # its View Properties, with the datebook's settings in the right column,
    # as Agenda's (checked in Agenda 2.0, 2026-10-25)
    test "View ▸ Add asks the type; Datebook makes one and opens its View Properties",
         %{plain: state} do
      state = press(state, [{:f, 10}, "v", "a", "Mornings", :enter])
      assert screen(state) =~ "Type of view:"

      state = press(state, "d")
      assert State.view(state).name == "Mornings"
      assert %Datebook{period: :week} = datebook(state)
      assert %{type: :view_props} = State.mode(state)
      text = screen(state)
      assert text =~ ~r/Item sorting: +\.\.\. +Date category: +When/
      assert text =~ ~r/Period: +Week/
      assert text =~ ~r/Start at: +Mon/
      assert text =~ ~r/Base date on: +today/
      refute text =~ "Section sorting"
      refute text =~ "Interval"
    end

    test "the settings change the slots at once, one undo step each", %{state: state} do
      # Period: Week -> Month -> Quarter -> Day
      state = state |> settings() |> to_setting("Period") |> press([" ", " ", " "])
      assert datebook(state).period == :day
      assert screen(state) =~ ~r/Interval: +Hourly/
      assert screen(state) =~ ~r/Start at: +08:00/

      state = state |> to_setting("Interval") |> press(" ")
      assert datebook(state).interval == 15

      # a time without am/pm falls between 8:00 and 19:59, as everywhere (R14b)
      state = state |> to_setting("Start at") |> press([" ", {:ctrl, "u"}, "7:30am", :enter])
      assert datebook(state).start_time == ~T[07:30:00]

      state =
        state |> to_setting("Base date on") |> press([" ", {:ctrl, "u"}, "next week", :enter])

      assert datebook(state).base == "next week"
      assert screen(state) =~ ~r/Base date on: +next week/

      state = press(state, [" ", {:ctrl, "u"}, "zebra", :enter])
      assert panel(state) =~ message(:bad_date)
      assert datebook(state).base == "next week"

      assert Agendum.TUI.History.undo(state) |> datebook() |> Map.get(:base) == "today"
    end

    test "a week's days cycle; categories are picked, End cleared with DEL", %{state: state} do
      state = state |> settings() |> to_setting("Start at") |> press(" ")
      assert datebook(state).start_day == 2

      # End category: a standard category is refused
      state = state |> to_setting("End category") |> press([" ", "Calls", :enter])
      assert panel(state) =~ message(:select_date_category)
      assert datebook(state).end_category == nil

      state = press(state, [" ", "Done", :enter])
      assert datebook(state).end_category == state.db.special.done
      state = press(state, :delete)
      assert datebook(state).end_category == nil
    end

    test "Hide column heads and Section separators, as in any view (R57, R58; shot 55)",
         %{state: state} do
      state = settings(state)
      assert screen(state) =~ ~r/Hide column heads: +No/
      assert screen(state) =~ ~r/Section separators: +No/

      # SPACE switches each, one undo step
      state = state |> to_setting("Hide column heads") |> press(" ")
      assert State.view(state).hide_column_heads
      assert screen(state) =~ ~r/Hide column heads: +Yes/
      state = state |> to_setting("Section separators") |> press(" ")
      assert State.view(state).section_separators
      refute Agendum.TUI.History.undo(state) |> State.view() |> Map.get(:section_separators)
    end

    test "a standard view has no datebook settings: its View Properties (R78)",
         %{plain: state} do
      assert %{type: :view_props} = State.mode(settings(state))
    end

    test "the control panel names the Section; the view manager marks it with *", %{state: state} do
      assert screen(state) =~ ~r/View: This week +Datebook For: When/
      assert screen(press(state, {:f, 8})) =~ ~r/\* This week/
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

      undone = Agendum.TUI.History.undo(state)
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
      state = state |> press([{:f, 10}, "v", "p"]) |> to_setting("Period") |> press([" ", :enter])
      state = press(state, [{:alt, "b"}, :right])
      assert State.view(state).datebook.period == :month
      assert screen(state) =~ "Mon 2026-10-26 → Fri 2026-10-30"
      assert screen(state) =~ "Mon 2026-11-02"

      plain =
        state |> press(:esc) |> State.switch_view(hd(state.db.view_order)) |> Layout.settle()

      assert panel(press(plain, {:alt, "b"})) =~
               "Browse needs a date filter (View Properties ▸ Filter) or a datebook view"
    end
  end

  # R14a: a recurring item on every date it recurs (checked in Agenda 2.0,
  # 2026-10-15 and 2026-10-23)
  describe "a recurring item" do
    setup %{state: state} do
      {db, id} = Core.add_item(state.db, "Swim every Monday", ~D[2026-10-12])
      %{state: Layout.settle(%{state | db: db}), swim: id}
    end

    test "browsing to next week shows it on that Monday", %{state: state} do
      state = press(state, [{:alt, "b"}, :right, :enter])
      assert screen(state) =~ ~r/── Mon 2026-10-19 ─+\n    • Swim every Monday/u
    end

    test "F4 on a later occurrence marks it done and adds the next, as on its base date",
         %{state: state, swim: swim} do
      state = press(state, [{:alt, "b"}, :right, :enter])

      row =
        Enum.find_index(Layout.rows(state), &(&1[:item] && &1.item.text == "Swim every Monday"))

      state = state |> Layout.move_to(row) |> press({:f, 4})
      assert state.db.items[swim].done == ~D[2026-10-12]

      [copy] =
        for i <- Map.values(state.db.items), i.text == "Swim every Monday", i.done == nil, do: i

      assert copy.when == ~D[2026-10-19]
    end
  end
end
