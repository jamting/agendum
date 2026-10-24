# Captures the screens shown in the Agenda manual (docs/manual/index.html)
# from the program itself: it opens Rabbit's file (`Agendum.Sample.rabbit/1`,
# also `agendum --rabbit`), drives the real TUI with key presses, and writes
# each screen as text to docs/manual/src/screens/.
#
#     MIX_ENV=test mix run docs/manual/src/capture_screens.exs
#     python3 docs/manual/src/build.py
#
# Every capture is checked: if a key sequence no longer reaches the screen it
# should, the script stops with the name of the capture.

Code.require_file("test/support/tui_helpers.ex")

defmodule ManualScreens do
  @moduledoc false
  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.TUI.{CategoryScreens, Layout, State}
  import Agendum.TUIHelpers

  @out "docs/manual/src/screens"
  @today ~D[2026-10-12]

  def run do
    File.mkdir_p!(@out)
    state = start(Agendum.Sample.rabbit(@today), width: 80, height: 25)

    state = %{
      state
      | now: ~N[2026-10-12 10:15:00],
        today: @today,
        path: "/home/rabbit/rabbit.agendum"
    }

    view(state)
    boxes(state)
    typing(state)
    date_category(state)
    filters_and_questions(state)
    waiting_and_numbers(state)
    calendars(state)
    datebook(state)
    macros(state)
    columns(state)
    help_and_views(state)
    away(state)
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
    auto = state |> press([{:f, 10}, "f", "p"]) |> to_setting("Auto-assign settings")
    shot("08-autoassign", press(auto, " "), :auto_assign)
    view_props = press(state, [{:f, 10}, "v", "p"])
    shot("54-viewprops", view_props, :view_props)
    shot("10-sort", view_props |> to_setting("Item sorting") |> press(" "), :sort)
    shot("14-execute", press(state, [{:f, 10}, "u", "e"]), :execute)
    shot("15-customize", press(state, [{:f, 10}, "u", "c"]), :customize)
  end

  defp typing(state) do
    s = press(state, [:down, :down] ++ String.graphemes("Plant the lettuce seeds next Tuesday"))
    shot("20-typing", s, nil)
    shot("21-typed", press(s, :enter), nil)
    shot("22-complete", press(state, [:down, :right, :right] ++ String.graphemes("Lo")), nil)

    also_match =
      state
      |> press([{:f, 9}, :down, :down, :down, :down, {:f, 6}])
      |> to_setting("Also match")

    words = String.graphemes("carrot*;lettuce*;(vegetable patch)")
    shot("24-alsomatch", press(also_match, [" "] ++ words ++ [:enter]), :props)
  end

  defp date_category(state) do
    s = press(state, [{:f, 10}, "c", "a"] ++ String.graphemes("Harvest") ++ [:enter, {:f, 9}])
    index = Enum.find_index(CategoryScreens.rows(s, State.mode(s)), &(name(s, &1) == "Harvest"))
    s = s |> press(List.duplicate(:down, index) ++ [{:f, 6}]) |> to_setting("Type") |> press(" ")
    shot("30-type-choice", s, :choice)
    s = s |> press([:down, :enter]) |> to_setting("Advanced settings") |> press(" ")
    shot("32-daterule", s, :date_rule)
  end

  defp filters_and_questions(state) do
    range = [:down | String.graphemes("today")] ++ [:down | String.graphemes("end of this week")]

    # View Properties ▸ Filter lists the categories; SPACE on When (a date
    # category) opens its range
    filter = state |> press([{:f, 10}, "v", "p"]) |> to_setting("Filter") |> press(" ")
    shot("33-datefilter", press(filter, [:down, " "] ++ range), :range_filter)

    item = [:down, :down] ++ String.graphemes("Ask Piglet and Pooh to help dig") ++ [:enter]
    # Auto-assign settings ▸ Confirm assignments: Always; ENTER keeps it (ESC would cancel)
    confirm =
      state
      |> press([{:f, 10}, "f", "p"])
      |> to_setting("Auto-assign settings")
      |> press(" ")
      |> to_setting("Confirm assignments")
      |> press([" ", :enter, :enter])

    shot("36-questions", press(confirm, item ++ [{:f, 10}, "u", "q"]), :questions)
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
    db = db |> Core.remove_column(view, {0, 2}) |> Core.add_column(view, cost, {0, 2}, 9)
    garden = hd(Database.find_categories(db, "Garden"))
    {db, seeds} = Core.add_item(db, "Buy carrot seeds", @today, section: garden)
    {:ok, db} = Core.set_number(db, seeds, cost, 2.4)
    {:ok, db} = Core.set_number(db, hd(db.item_order), cost, 0.5)
    shot("42-numeric", Layout.settle(%{state | db: db}), nil)
  end

  # A calendar on the web: the shell would download it; here its events are
  # given to the TUI as if read. Calendars are an extra (R77): on for this.
  defp calendars(state) do
    state = put_in(state.prefs.extras, true)
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
      %Agendum.Core.Extras.ICal.Event{
        uid: "north-pole",
        summary: "Expotition to the North Pole",
        start: {:local, ~N[2026-10-16 10:00:00]}
      },
      %Agendum.Core.Extras.ICal.Event{
        uid: "poohsticks",
        summary: "Poohsticks at the bridge",
        start: {:local, ~N[2026-10-14 16:00:00]},
        rrule: weekly
      }
    ]

    s = Agendum.TUI.Update.calendar_read(s, id, {:ok, events})
    shot("45-calendars", s, :calendars)
  end

  # The pop-up calendar on the carrot bed's When date, and a datebook view
  # of Rabbit's week with its settings.
  defp datebook(state) do
    shot("39-popup-calendar", press(state, [:down, :right, {:f, 3}]), :calendar)

    add = [{:f, 10}, "v", "a"] ++ String.graphemes("Rabbit's Calendar") ++ [:enter, "d"]
    shot("47-datebook-props", press(state, add), :datebook_props)
    shot("46-datebook-week", press(state, add ++ [:enter]), nil)
  end

  # A macro Rabbit learns: it adds "Water the carrots" under Garden.
  defp macros(state) do
    learn =
      [{:alt_f, 3}, :insert] ++
        String.graphemes("Water") ++
        [:enter, {:f, 7}, :down] ++ String.graphemes("Water the carrots") ++ [:enter, {:alt_f, 3}]

    shot("48-macros", press(state, learn ++ [{:alt_f, 3}]), :macros)
  end

  # The Column Add box, and Column Properties on the Friends column.
  defp columns(state) do
    shot("49-column-add", press(state, [{:f, 10}, "v", "c", "a"]), :column_add)
    friends = [:down, :right, :right, :right, {:f, 10}, "v", "c", "p"]
    shot("50-column-props", press(state, friends), :column_props)
  end

  # F1 then c: the commands of a view; the view manager; the Section Add
  # box; the ALT key bar (ALT-K once); a note in the note editor.
  defp help_and_views(state) do
    shot("51-help-commands", press(state, [{:f, 1}, "c"]), :help)
    shot("52-viewmgr", press(state, {:f, 8}), :viewmgr)
    shot("56-section-add", press(state, [{:f, 10}, "v", "s", "a"]), :section_props)
    shot("57-alt-keys", press(state, {:alt, "k"}), nil)
    note =
      String.graphemes("Carrots in the first row, lettuces in the second.") ++
        [:enter] ++ String.graphemes("Keep Tigger out of both.")

    shot("58-note", press(state, [:down, {:f, 5}] ++ note), :note)
  end

  # "While you were away": Rabbit set two alarms at 8 o'clock, left the
  # file, and opens it again at 10:15, when both have come due. Opening a
  # file is `Update.arrive/1`; the file as saved is the one with the alarms.
  # The box is an extra (R77): on for this.
  defp away(state) do
    state = put_in(state.prefs.extras, true)
    early = %{state | now: ~N[2026-10-12 08:00:00]}

    alarm = fn s, text ->
      press(s, [:ctrl_end] ++ String.graphemes(text) ++ [:enter, {:alt, "a"}, :enter])
    end

    s =
      early
      |> alarm.("Remind Tigger about the lettuces at 9am")
      |> alarm.("Ask Piglet to bring a basket at 9:30am")

    s = %{s | saved: %{s.saved | db: s.db}, now: state.now, message: nil}
    shot("53-away", Agendum.TUI.Update.arrive(s), :away)
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
