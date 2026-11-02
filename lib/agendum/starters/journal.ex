# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Starters.Journal do
  @moduledoc """
  The Journal starter file (R60b; meeting 2026-11-02-1043, §§ 6–7 and the
  addition; `docs/plans/STARTERS.md`): Dreams, Mood, Training, Gym and
  Health as collections of one book, as the Bullet Journal has them, made
  of Agenda's own parts (ADR 0049). Agenda shipped no such file; ours.

  Every line lives in the exclusive **Journal** family. A line typed in
  Today is filed into its collection by its words: "Ran by the river"
  matches Running, under Training ▸ Sport, so it is in Training too, as a
  child's items are its parent's (subsumption, R7). Its numbers (Distance,
  Minutes …) are typed in their columns, as Agenda reads no numbers out of
  text. A line no word files stays in the Journal itself; the Journal
  column in Today gives it a collection.

  Each collection has a datebook view on the Entry date: this month in
  weeks (Dreams and Health: this quarter in months), ALT-B for earlier
  ones, each week summed under it (a Total, an Average or a Maximum per
  column, R29). Empty weeks are hidden, so a missed day or an unused
  collection shows nothing (the three-days-away test). The Index lists
  this month's lines by collection.

  How the file works is the Journal category's note, shown by ♪ on the
  Today view's section head (R59); there are no items. Built through
  `Agendum.Core` like any file a person makes; `mix agendum.starters`
  writes it to `starters/journal.agendum`. Pure.
  """

  alias Agendum.Core
  alias Agendum.Core.{Database, Datebook, NumberFormat}

  # Any fixed day: setting a date filter only checks that its phrases read
  @check_day ~D[2026-01-01]

  # Names that are not words of a typed line are not matched (R16)
  @off [match_name: false]

  # The collections: {name, Also match words, its own family}. A family is
  # {name, exclusive?, [{child, Also match words}]}; a child's own name is
  # matched too ("Squat" files "Squat"). Words are separated by ";", a
  # phrase in quotes is matched whole.
  @collections [
    {"Dreams", "dream;dreamt;dreamed", nil},
    {"Mood", "mood", nil},
    {"Training", nil,
     {"Sport", true,
      [
        {"Running", "run;ran;jog;jogged"},
        {"Swimming", "swim;swam"},
        {"Cycling", "cycle;cycled;bike;biked"},
        {"Walking", "walk;walked;hike;hiked"}
      ]}},
    {"Gym", nil,
     {"Exercises", true,
      [
        {"Bench press", "bench"},
        {"Squat", "squats"},
        {"Deadlift", "deadlifts"},
        {"Pull-up", "pull-ups;pullups;chin-ups"},
        {"Shoulder press", ~s("overhead press")}
      ]}},
    {"Health", nil,
     {"Symptoms", false,
      [
        {"Headache", "migraine"},
        {"Cold", ~s(cough;sniffles;"sore throat")},
        {"Fever", "temperature"},
        {"Stomach", "nausea;stomachache"},
        {"Other", nil}
      ]}}
  ]

  # Families beside the Journal that the Dreams view shows; a name or a
  # feeling in a dream files it (not exclusive: a dream has many)
  @beside [
    {"People", [{"Sample Person", nil}]},
    {"Feelings",
     [
       {"Happy", "glad;joy"},
       {"Calm", "peaceful"},
       {"Sad", "sadness"},
       {"Afraid", "scared;fear"},
       {"Angry", "anger"}
     ]}
  ]

  # The numbers, {name, decimals}: typed in a column, never read from text
  @numbers [
    {"Vividness", 1},
    {"Mood 1-10", 1},
    {"Sleep", 1},
    {"Exercise", 0},
    {"Distance", 1},
    {"Minutes", 0},
    {"Sets", 0},
    {"Reps", 0},
    {"Weight", 1},
    {"Volume", 0},
    {"Severity", 1}
  ]

  # A datebook per collection: {collection, period, base, columns}; a
  # column is {head, calculations under each week or month}, and a family
  # head's column shows its child (Running, Squat …)
  @datebooks [
    {"Dreams", :quarter, "beginning of this quarter",
     [{"Vividness", [:average]}, {"People", nil}, {"Feelings", nil}]},
    {"Mood", :month, "beginning of this month",
     [{"Mood 1-10", [:average]}, {"Sleep", [:average]}, {"Exercise", [:total]}]},
    {"Training", :month, "beginning of this month",
     [{"Sport", nil}, {"Distance", [:total]}, {"Minutes", [:total]}]},
    {"Gym", :month, "beginning of this month",
     [
       {"Exercises", nil},
       {"Sets", [:total]},
       {"Reps", [:total]},
       {"Weight", [:maximum]},
       {"Volume", [:total]}
     ]},
    {"Health", :quarter, "beginning of this quarter",
     [{"Symptoms", nil}, {"Severity", [:count, :average]}]}
  ]

  @note """
  A journal in one file: Dreams, Mood, Training, Gym and Health.

  Today: type one line for each thing, as it happens. Some words file a line by themselves: "Ran by the river" goes to Training (Running), "Bench press" to Gym, "Headache after lunch" to Health, "Dreamt of …" to Dreams, "Mood: calm" to Mood. Type a line's numbers in its collection's view (Distance, Sets, Mood 1-10 …). A line no word files: type its collection in the Journal column.

  Each collection's view shows this month week by week (Dreams and Health: this quarter month by month), with the week's totals, averages or best under it. ALT-B goes back to earlier weeks and months. A week with nothing logged is not shown.

  Index: this month's lines, by collection.

  Gym: one line for each exercise. Sets and Reps are the exercise's in all; Weight shows the week's heaviest; Volume is sets x reps x weight, worked out by you (3 x 10 x 40 = 1200).

  F8 lists the views. People in your dreams: add them under People in the category manager (F9, INS).
  """

  @doc "The Journal file."
  @spec build() :: Database.t()
  def build do
    Core.new_file(view_name: "Today", section_name: "Journal")
    |> whole_weeks()
    |> categories()
    |> views()
  end

  # A journal is kept at weekends too: the file's week runs Monday to
  # Sunday (File Properties, R14e), and so do a month's weeks in the
  # datebooks, which follow it (the default week is Monday to Friday)
  defp whole_weeks(db),
    do: Core.set_date_settings(db, %{db.date_settings | week_start: 1, week_end: 7})

  # --- categories ---

  defp categories(db) do
    journal = id(db, "Journal")
    db = Enum.reduce(@collections, db, &collection(&2, journal, &1))

    db =
      Enum.reduce(@beside, db, fn {name, children}, db ->
        {:ok, db, family} = Core.add_category(db, db.main_id, name, @off)
        children(db, family, children)
      end)

    db =
      Enum.reduce(@numbers, db, fn {name, _}, db ->
        {:ok, db, _} = Core.add_category(db, db.main_id, name, [kind: :numeric] ++ @off)
        db
      end)

    # one collection for each line; nothing is assigned yet, so there are
    # no conflicts to resolve
    {:ok, db} = Core.make_exclusive(db, journal)
    Core.set_category_note(db, journal, String.trim_trailing(@note))
  end

  defp collection(db, journal, {name, words, family}) do
    {:ok, db, id} = Core.add_category(db, journal, name, @off)
    db = if words, do: also_match(db, id, words), else: db

    case family do
      nil ->
        db

      {family, exclusive, children} ->
        {:ok, db, fid} = Core.add_category(db, id, family, @off)
        db = children(db, fid, children)

        if exclusive do
          {:ok, db} = Core.make_exclusive(db, fid)
          db
        else
          db
        end
    end
  end

  defp children(db, parent, children) do
    Enum.reduce(children, db, fn {name, words}, db ->
      {:ok, db, id} = Core.add_category(db, parent, name)
      if words, do: also_match(db, id, words), else: db
    end)
  end

  defp also_match(db, id, words) do
    {:ok, db} = Core.set_also_match(db, id, words)
    db
  end

  # --- views ---

  defp views(db) do
    today = hd(db.view_order)
    collections = Enum.map(@collections, &elem(&1, 0))

    db =
      db
      |> column(today, 0, {"Journal", nil})
      |> range(today, "Entry", "today", "today")

    # the Index: this month's lines by collection, unused ones hidden
    {db, index} = Core.add_view(db, "Index", Enum.map(collections, &id(db, &1)))

    db =
      db
      |> range(index, "Entry", "beginning of this month", "today")
      |> Core.toggle_view_option(index, :hide_empty)
      |> Core.toggle_view_option(index, :section_separators)

    Enum.reduce(@datebooks, db, &datebook(&2, &1))
  end

  defp datebook(db, {name, period, base, columns}) do
    book = %Datebook{
      date_category: db.special.entry,
      section_category: id(db, name),
      period: period,
      base: base
    }

    {:ok, db, view} = Core.add_datebook_view(db, name, book)

    columns
    |> Enum.with_index()
    |> Enum.reduce(db, fn {col, index}, db -> column(db, view, index, col) end)
    |> Core.toggle_view_option(view, :hide_empty)
    |> Core.toggle_view_option(view, :section_separators)
  end

  # a column in every section; a numeric one with its decimals and the
  # calculations shown under each section
  defp column(db, view, index, {head, calcs}) do
    id = id(db, head)
    kind = db.categories[id].kind
    {:ok, db} = Core.add_column_as(db, view, id, kind, {0, index}, insert_in: :all)

    case List.keyfind(@numbers, head, 0) do
      {_, decimals} ->
        Core.set_column_format(db, view, {0, index}, %NumberFormat{
          decimals: decimals,
          calcs: calcs
        })

      nil ->
        db
    end
  end

  # a date filter whose phrases are read again each day (R28a)
  defp range(db, view, name, from, to) do
    {:ok, db} =
      Core.set_range_filter(
        db,
        view,
        :view,
        id(db, name),
        {:assigned, from, to, :inside},
        @check_day
      )

    db
  end

  # the file's names are unique, so a name is enough to find one
  defp id(db, name) do
    [id] = Database.find_categories(db, name)
    id
  end
end
