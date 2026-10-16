defmodule Agendum.Starters.Golden do
  @moduledoc """
  The golden files of the file format: a file that uses every stored field,
  saved once by each format version (`mix agendum.golden`) and kept in
  `test/fixtures/formats/`. The tests load them all, so a change that breaks
  reading an older file fails at once, with a real file of that version
  rather than one rebuilt from today's structs.

  `build/0` is the Activities Planner with its sample data (R60), and on
  top of it, through `Agendum.Core`, whatever the Planner leaves unused:
  recurrence, alarms, dependencies, actions, user date categories, a
  datebook, a calendar subscription, the Show View and so on. A test checks
  that every field of every stored struct is set away from its default
  somewhere, so a new stored field has to be added here.

  `facts/1` is what a file says, in plain terms (item texts, category
  paths, view names, counts); a golden file's facts are saved beside it and
  must still come out of it after any later upgrade.
  """

  alias Agendum.Core
  alias Agendum.Core.{Database, DateFormat, DateRule, DateSettings, Datebook, ICal}
  alias Agendum.Core.{NumberFormat, Search, TextMatch}
  alias Agendum.Core.View.SortKey
  alias Agendum.Starters.Planner

  # A fixed day, so that building twice gives the same file.
  @today ~D[2026-10-16]
  @now ~N[2026-10-16 09:00:00]

  @calendar """
  BEGIN:VCALENDAR
  VERSION:2.0
  BEGIN:VEVENT
  UID:golden-1@agendum
  DTSTART:20261020T130000Z
  DTEND:20261020T140000Z
  SUMMARY:Owl's reading circle
  DESCRIPTION:Bring a book with long words
  RRULE:FREQ=WEEKLY;COUNT=4
  STATUS:CONFIRMED
  END:VEVENT
  END:VCALENDAR
  """

  @doc "The day the golden file is built on."
  @spec today() :: Date.t()
  def today, do: @today

  @doc "A file that uses every stored field (see the module doc)."
  @spec build() :: Database.t()
  def build do
    Planner.build()
    |> Planner.with_samples(@today)
    |> items()
    |> categories()
    |> views()
    |> calendar()
    |> file_settings()
  end

  # Items with what only items have: a note, recurring When dates (every
  # Friday, every 2 weeks, a day of the month) with a time and alarms, one
  # rung, a done date, a mark, a prerequisite.
  defp items(db) do
    {db, owl} = Core.add_item(db, "Owl's birthday every Friday at 3pm", @now)
    {db, honey} = Core.add_item(db, "Buy honey for Pooh", @now)
    {db, party} = Core.add_item(db, "Plan the party", @now)
    {db, smack} = Core.add_item(db, "Smackerel at 11am every 2 weeks", @now)
    {db, _} = Core.add_item(db, "Count the honey pots on the 15th of every month", @now)

    db = Core.set_note(db, owl, "Rabbit brings the cake.\nPiglet brings balloons.", @now)
    db = ok(Core.set_alarm(db, owl, 15))
    {db, _rung} = Core.ring_alarms(db, ~N[2026-10-23 14:50:00])
    db = ok(Core.set_alarm(db, smack, 5))
    db = Core.toggle_done(db, honey, @today)
    db = Core.toggle_mark(db, party)
    # Zettel ids (R73): Owl's birthday is bonalaku, the party pigavono
    {:ok, db, _given} = Core.attach_zettels(db, [owl, party])
    ok(Core.make_dependent(db, party, [honey]))
  end

  # Categories with every kind of setting: exclusion, links, conditions and
  # actions, a user date category with its own rule, a numeric category,
  # short names, notes, text matching of its own, a special action, and a
  # suggested assignment waiting to be confirmed.
  defp categories(db) do
    {:ok, db, wood} = Core.add_category(db, db.main_id, "Hundred Acre Wood")
    {:ok, db, owl} = Core.add_category(db, wood, "Owl's house")
    {:ok, db, tree} = Core.add_category(db, wood, "Pooh's tree")
    {:ok, db, visit} = Core.add_category(db, db.main_id, "Visit")
    {:ok, db, archive} = Core.add_category(db, db.main_id, "Archive")
    {:ok, db, pots} = Core.add_category(db, db.main_id, "Honey pots")

    db = ok(Core.make_exclusive(db, wood))
    db = ok(Core.toggle_exclude(db, owl, archive))
    db = ok(Core.toggle_also_assign(db, tree, visit))
    db = ok(Core.set_short_name(db, owl, "Owl"))
    db = ok(Core.set_category_note(db, wood, "Where everyone lives."))
    db = ok(Core.set_also_match(db, tree, "honey;hunny"))
    db = ok(Core.set_match_override(db, owl, :strength, :exact))
    db = ok(Core.add_condition(db, visit, owl, :assigned))
    db = ok(Core.set_action(db, tree, archive, :remove))
    db = ok(Core.set_special_action(db, archive, :done))

    db = ok(Core.make_date(db, visit, @now))
    rule = %DateRule{assign: :item_or_note_text, which: 2, done_key: true, when_key: true}
    db = ok(Core.set_date_rule(db, visit, rule))

    item = hd(db.item_order)
    db = ok(Core.set_date(db, item, visit, ~D[2026-11-01], @now))
    db = ok(Core.make_numeric(db, pots, @now))
    db = ok(Core.set_number(db, item, pots, 12.5, @now))

    # asked, not assigned: a suggestion waiting under Utilities Questions
    db = Core.set_confirm_assignments(db, :always)
    {db, _} = Core.add_item(db, "Take a pot to Pooh's tree", @now)
    Core.set_confirm_assignments(db, :sometimes)
  end

  # Views: sorting and filters in a view and a section, sections sorted,
  # a section collapsed, the hide options, a date column with its own
  # format and a title, a numeric column with its format, the item column
  # set by hand and moved, a datebook, the Show View of a search, and a
  # macro attached to a key.
  defp views(db) do
    view = hd(db.view_order)
    when_id = db.special.when
    pots = db |> Database.find_categories("Honey pots") |> hd()
    visit = db |> Database.find_categories("Visit") |> hd()

    keys = [%SortKey{on: :text, order: :desc, na: :top, sequence: :alpha, line: 2}]
    db = Core.set_sort(db, view, {:section, 0}, keys)
    db = Core.set_section_sort(db, view, :alpha, :desc)
    db = ok(Core.cycle_filter(db, view, {:section, 0}, db.special.done))

    db = ok(Core.add_column_as(db, view, when_id, :date, {0, 0}))
    format = %DateFormat{order: :mmddyy, separator: "/", clock: 24}
    db = Core.set_column_date_format(db, view, {0, 0}, format)
    db = Core.set_column_display(db, view, {0, 0}, title: "Due", note_line: 3)

    db = ok(Core.add_column_as(db, view, pots, :numeric, {0, 1}))

    number = %NumberFormat{
      symbol: "$",
      decimals: 0,
      thousands: true,
      negative: :parens,
      calcs: [:count, :average],
      percent: true
    }

    db = Core.set_column_format(db, view, {0, 1}, number)
    db = Core.set_item_column(db, view, 0, set: :manual, width: 30, minimum: 12)
    db = Core.set_item_column_linked(db, view, 0, false)
    db = Core.move_column(db, view, 0, 0, 1)
    db = Core.set_section_collapsed(db, view, 0, true)

    db =
      Enum.reduce([:hide_empty, :hide_inherited, :hide_dependent], db, fn option, db ->
        Core.toggle_view_option(db, view, option)
      end)

    datebook = %Datebook{
      date_category: when_id,
      end_category: visit,
      period: :week,
      interval: 60,
      start_time: ~T[08:00:00],
      end_time: ~T[18:00:00],
      start_day: 1,
      end_day: 5,
      base: "next monday"
    }

    {:ok, db, _} = Core.add_datebook_view(db, "Golden week", datebook)
    db = Core.attach_macro(db, hd(db.macro_order), "{ShfF4}")
    {db, _} = Core.show_match(db, %Search{text: "honey", on: :both, ignore_case: false})
    db
  end

  # A calendar subscription that read its events once, then failed.
  defp calendar(db) do
    {:ok, db, cal} = Core.subscribe_calendar(db, "Wood events", "https://example.org/wood.ics")
    db = ok(Core.cycle_calendar_setting(db, cal, :ahead_days, 1))
    db = ok(Core.cycle_calendar_setting(db, cal, :refresh_minutes, 1))
    {:ok, events} = ICal.parse(@calendar)
    {:ok, db, _counts} = Core.sync_calendar(db, cal, events, @now)
    Core.calendar_failed(db, cal, "The wood's network is down", ~N[2026-10-16 10:00:00])
  end

  # The file's own settings: date display, date reading, text matching and
  # where new columns go. Last, so that text matching worked while the
  # items above were typed.
  defp file_settings(db) do
    db
    |> Core.set_date_format(%DateFormat{
      order: :ddmmmyy,
      separator: ".",
      clock: 12,
      day_of_week: true,
      show: :time_date,
      am_pm: false,
      time_separator: "hm"
    })
    |> Core.set_date_settings(%DateSettings{
      week_start: 7,
      week_end: 6,
      quarter_start: 2,
      year_start: 7,
      month_alone: :last,
      morning: ~T[07:30:00],
      afternoon: ~T[13:30:00],
      evening: ~T[19:00:00]
    })
    |> Core.set_match_settings(%TextMatch{
      enabled: false,
      match_on: :both,
      strength: :partial,
      enclosed_by: :brackets,
      ignore_suffixes: false,
      ignore_accents: true
    })
    |> Core.set_insert_columns(:section)
  end

  # The facade's functions answer in a few shapes; here only the file
  # matters, and an error is a mistake in this module, so it crashes.
  defp ok({:ok, db}), do: db
  defp ok(%Database{} = db), do: db

  @doc """
  What a file says, in plain terms that any later version must still read
  out of it: item texts, category paths, view and macro names, and counts
  of what hangs off them.
  """
  @spec facts(Database.t()) :: map
  def facts(%Database{} = db) do
    %{
      items: db |> Database.items() |> Enum.map(& &1.text) |> Enum.sort(),
      notes: Enum.count(Database.items(db), &(&1.note not in [nil, ""])),
      categories: db.categories |> Map.keys() |> Enum.map(&path(db, &1)) |> Enum.sort(),
      views: db.views |> Map.values() |> Enum.map(& &1.name) |> Enum.sort(),
      macros: db.macros |> Map.values() |> Enum.map(& &1.name) |> Enum.sort(),
      links: Agendum.Core.Links.size(db.links),
      dependencies: Agendum.Core.Links.size(db.dependencies),
      dates: map_size(db.dates),
      numbers: map_size(db.numbers),
      calendars: map_size(db.calendars)
    }
  end

  # "MAIN/Hundred Acre Wood/Owl's house"
  defp path(db, id) do
    [id | Database.ancestors(db, id)]
    |> Enum.reverse()
    |> Enum.map_join("/", &db.categories[&1].name)
  end
end
