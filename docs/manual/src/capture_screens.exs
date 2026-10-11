# Captures the screens shown in the Agenda manual (docs/manual/index.html)
# from the program itself: it builds Rabbit's file, drives the real TUI with
# key presses, and writes each screen as text to docs/manual/src/screens/.
#
#     MIX_ENV=test mix run docs/manual/src/capture_screens.exs
#     python3 docs/manual/src/build.py
#
# Every capture is checked: if a key sequence no longer reaches the screen it
# should, the script stops with the name of the capture.

Code.require_file("test/support/tui_helpers.ex")

defmodule ManualScreens do
  @moduledoc false
  alias Agenda.Core
  alias Agenda.Core.Database
  alias Agenda.TUI.{CategoryScreens, Layout, State}
  import Agenda.TUIHelpers

  @out "docs/manual/src/screens"
  @today ~D[2026-10-12]

  def run do
    File.mkdir_p!(@out)
    state = start(rabbits_file(), width: 80, height: 25)

    state = %{
      state
      | now: ~N[2026-10-12 10:15:00],
        today: @today,
        path: "/home/rabbit/rabbit.agenda"
    }

    view(state)
    boxes(state)
    typing(state)
    date_category(state)
    filters_and_questions(state)
    waiting_and_numbers(state)
    calendars(state)
  end

  # Rabbit's file: a Monday, three sections, Priority and Friends columns.
  defp rabbits_file do
    db = Core.new_file(view_name: "Rabbit's Week", section_name: "Garden")
    main = db.main_id
    [garden] = Database.find_categories(db, "Garden")
    db = Database.update_category(db, garden, &%{&1 | match_name: true})
    {:ok, db, notices} = Core.add_category(db, main, "Notices", match_name: true)

    {:ok, db, people} =
      Core.add_category(db, main, "Friends and Relations",
        short_name: "Friends",
        match_name: false
      )

    db =
      Enum.reduce(~w(Pooh Piglet Owl Eeyore Kanga Roo Tigger), db, fn name, db ->
        {:ok, db, _} = Core.add_category(db, people, name)
        db
      end)

    {:ok, db, _} = Core.add_category(db, people, "Christopher Robin", short_name: "CR")
    {:ok, db, _} = Core.add_category(db, people, "Small")

    {:ok, db, priority} =
      Core.add_category(db, main, "Priority", exclusive: true, match_name: false)

    db =
      Enum.reduce(~w(High Medium Low), db, fn name, db ->
        {:ok, db, _} = Core.add_category(db, priority, name)
        db
      end)

    [view] = Database.views(db)
    db = Core.add_column(db, view.id, priority, 1, 8)
    db = Core.add_column(db, view.id, people, 2, 12)
    db = Core.add_section(db, view.id, notices, 1)
    db = Core.add_section(db, view.id, people, 2)

    [
      {"Weed the carrot bed tomorrow morning", garden, "High"},
      {"Count the lettuces before Tigger bounces on them", garden, "Medium"},
      {"Put up a Notice about the Organising Meeting on Friday", notices, "High"},
      {"Ask Owl how to spell Organising", people, "Low"},
      {"Find Small, who is lost again", people, "High"},
      {"Visit Kanga and Roo on Thursday at 3pm", people, "Medium"}
    ]
    |> Enum.reduce(db, fn {text, section, prio}, db ->
      {db, item} = Core.add_item(db, text, @today, section: section)
      {:ok, db, _} = Core.assign_by_name(db, item, priority, prio, @today)
      db
    end)
  end

  defp view(state) do
    shot("01-view", state, nil)
    shot("02-catmgr", press(state, {:f, 9}), :catmgr)
    shot("03-itemprops", press(state, [:down, {:f, 6}]), :item_props)
    shot("04-profile", press(state, [:down, {:f, 3}]), :profile)
    shot("05-catprops", press(state, [{:f, 9} | List.duplicate(:down, 6)] ++ [{:f, 6}]), :props)
    shot("06-menu", press(state, {:f, 10}), :menu)
  end

  defp boxes(state) do
    auto = [{:f, 10}, "f", "p"] ++ List.duplicate(:down, 16) ++ [" "]
    shot("08-autoassign", press(state, auto), :auto_assign)
    shot("10-sort", press(state, [{:f, 10}, "v", "o"]), :sort)
    shot("14-execute", press(state, [{:f, 10}, "c", "e"]), :execute)
    shot("15-customize", press(state, [{:f, 10}, "f", "c"]), :customize)
  end

  defp typing(state) do
    s = press(state, [:down, :down] ++ String.graphemes("Plant the lettuce seeds next Tuesday"))
    shot("20-typing", s, nil)
    shot("21-typed", press(s, :enter), nil)
    shot("22-complete", press(state, [:down, :right, :right] ++ String.graphemes("Lo")), nil)

    garden_props = [{:f, 9}, :down, :down, :down, :down, {:f, 6}] ++ List.duplicate(:down, 5)
    words = String.graphemes("carrot*;lettuce*;(vegetable patch)")
    shot("24-alsomatch", press(state, garden_props ++ [:enter] ++ words ++ [:enter]), :props)
  end

  defp date_category(state) do
    s = press(state, [{:f, 10}, "c", "a"] ++ String.graphemes("Harvest") ++ [:enter, {:f, 9}])
    index = Enum.find_index(CategoryScreens.rows(s, State.mode(s)), &(name(s, &1) == "Harvest"))
    s = press(s, List.duplicate(:down, index) ++ [{:f, 6}, :down, :down, :enter])
    shot("30-type-choice", s, :choice)
    s = press(s, [:down, :down, :enter] ++ List.duplicate(:down, 8) ++ [:enter])
    shot("32-daterule", s, :date_rule)
  end

  defp filters_and_questions(state) do
    range = [:down | String.graphemes("today")] ++ [:down | String.graphemes("end of this week")]

    shot(
      "33-datefilter",
      press(state, [{:f, 10}, "v", "f", :down, :enter] ++ range),
      :range_filter
    )

    confirm =
      [{:f, 10}, "f", "p"] ++
        List.duplicate(:down, 16) ++ [" ", :down, :down, :down, " ", :esc, :esc]

    item = [:down, :down] ++ String.graphemes("Ask Piglet and Pooh to help dig") ++ [:enter]
    shot("36-questions", press(state, confirm ++ item ++ [{:f, 10}, "c", "q"]), :questions)
    shot("38-alarm", press(state, [:ctrl_end, {:alt, "a"}, :enter]), nil)
  end

  defp waiting_and_numbers(state) do
    s = state |> Layout.move_to(row(state, "Ask Owl")) |> press({:f, 7})
    s = s |> Layout.move_to(row(s, "Put up")) |> press([{:alt, "o"}, "y"])
    shot("41-depend", s, nil)

    db = state.db
    {:ok, db, cost} = Core.add_category(db, db.main_id, "Cost")
    {:ok, db} = Core.make_numeric(db, cost)
    view = hd(db.view_order)
    db = db |> Core.remove_column(view, 2) |> Core.add_column(view, cost, 2, 9)
    garden = hd(Database.find_categories(db, "Garden"))
    {db, seeds} = Core.add_item(db, "Buy carrot seeds", @today, section: garden)
    {:ok, db} = Core.set_number(db, seeds, cost, 2.4)
    {:ok, db} = Core.set_number(db, hd(db.item_order), cost, 0.5)
    shot("42-numeric", Layout.settle(%{state | db: db}), nil)
  end

  # A calendar on the web: the shell would download it; here its events are
  # given to the TUI as if read.
  defp calendars(state) do
    address = String.graphemes("webcal://example.org/expotitions.ics")
    s = press(state, [{:f, 10}, "f", "t", "c", :insert] ++ address ++ [:enter])
    s = press(s, String.graphemes("Expotitions") ++ [:enter])
    [id] = Map.keys(s.db.calendars)

    weekly = %{
      freq: :weekly,
      interval: 1,
      byday: ["WE"],
      bymonthday: [],
      count: nil,
      until: nil,
      other: []
    }

    events = [
      %Agenda.Core.ICal.Event{
        uid: "north-pole",
        summary: "Expotition to the North Pole",
        start: {:local, ~N[2026-10-16 10:00:00]}
      },
      %Agenda.Core.ICal.Event{
        uid: "poohsticks",
        summary: "Poohsticks at the bridge",
        start: {:local, ~N[2026-10-14 16:00:00]},
        rrule: weekly
      }
    ]

    s = Agenda.TUI.Update.calendar_read(s, id, {:ok, events})
    shot("45-calendars", s, :calendars)
  end

  defp name(state, {id, _depth}), do: state.db.categories[id].name

  defp row(state, start),
    do:
      Enum.find_index(
        Layout.rows(state),
        &(&1[:item] && String.starts_with?(&1.item.text, start))
      )

  # Writes the screen, after checking the expected box is on top (nil: none).
  defp shot(name, state, type) do
    top = State.mode(state) && State.mode(state).type
    if top != type, do: raise("#{name}: expected #{inspect(type)} on top, got #{inspect(top)}")
    File.write!(Path.join(@out, name <> ".txt"), screen(state))
  end
end

ManualScreens.run()
IO.puts("Captured the manual's screens in docs/manual/src/screens")
