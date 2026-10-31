# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Starters.Planner.Samples do
  @moduledoc """
  Sample data for the Activities Planner, for trying it out and testing
  (`mix agendum.starters --samples`): five people with phone numbers and
  companies in their notes (and a blank item each in Contacts), three
  projects, a business trip, sections for them in People and Expense
  Reports, and about forty items. There are tasks, calls, meetings, mail, reading,
  follow-ups, issues and ideas, and the trip's expenses. Some items are
  overdue, some due today at a time, some done, and a few are left for the
  catch-alls (Unassigned, No Priority Assigned, No Type, No Purpose).

  Every date is a number of days from `today`, so the same day always
  gives the same file, and the datebooks (Today, This Week …) have
  something in them on any day. Item texts hold no date words, so
  nothing depends on reading them. Pure.
  """

  alias Agendum.Core
  alias Agendum.Core.Database

  @people [
    {"Anna Berg", "555-0101", "Nordvik Consulting"},
    {"Johan Lind", "555-0102", "Lind Removals"},
    {"Maria Svensson", "555-0103", "Svensson & Co Accounting"},
    {"David Chen", "555-0104", "Pixelworks Design"},
    {"Sarah Miller", "555-0105", "Miller Legal"}
  ]

  @projects ["Website redesign", "Annual report", "Office move"]
  @trip "Berlin conference"

  # {text, section, details}. Details, all optional:
  #   in:     more categories to assign (by name)
  #   when:   days from today, or {days, ~T[time]}
  #   done:   done this many days ago
  #   amount: a number in Amount (which makes it an expense)
  #   note:   the item's note
  # Every item was entered a few days before its When date, or before today.
  # Texts avoid words that text matching would take further than wanted:
  # "phone" is Calls' short name, and "project" or "person" alone matches
  # Sample Project or Sample Person, which are read as people's names (R16c).
  @items [
    # --- tasks ---
    {"Draft the plan for the website redesign", "Tasks",
     in: ["Website redesign", "Anna Berg", "High"],
     when: 2,
     note: "Scope, milestones and budget.\nAsk Anna about the hosting costs."},
    {"Review the wireframes from the agency", "Tasks",
     in: ["Website redesign", "David Chen", "Medium"], when: 5},
    {"Collect the figures for the annual report", "Tasks",
     in: ["Annual report", "Maria Svensson", "High"], when: -3},
    {"Write the chairman's letter", "Tasks", in: ["Annual report", "Medium"], when: 12},
    {"Proofread the annual report", "Tasks", in: ["Annual report", "Low"], when: 20},
    {"Order moving boxes", "Tasks", in: ["Office move", "Low"], when: 1},
    {"Book the movers", "Tasks", in: ["Office move", "Johan Lind", "High"], when: -1, done: 0},
    {"Update the staff contact list", "Tasks",
     in: ["Miscellaneous Project", "Low"], when: -2, done: 1},
    {"Renew the software licences", "Tasks", in: ["High"], when: 0},
    {"Clean up the shared drive", "Tasks", []},
    {"Plan the team offsite", "Tasks", in: ["Ideas", "Medium"], when: 30},
    {"Prepare the slides for the Berlin talk", "Tasks",
     in: ["Sample Project", "High"], when: -12, done: 11},

    # --- calls ---
    {"Call Anna Berg about the hosting contract", "Tasks",
     in: ["Calls", "Anna Berg", "High"], when: {0, ~T[10:00:00]}},
    {"Phone the bank about the new account", "Tasks", in: ["Calls", "Medium"], when: 1},
    {"Return Sarah Miller's call", "Tasks",
     in: ["Calls", "Sarah Miller"], when: {0, ~T[14:30:00]}},
    {"Call Johan Lind to confirm the moving date", "Tasks",
     in: ["Calls", "Johan Lind", "Office move", "Medium"], when: -4, done: 4},
    {"Ring Maria Svensson about the audit", "Tasks",
     in: ["Calls", "Maria Svensson", "Annual report", "High"], when: -1},

    # --- meetings ---
    {"Design review with David Chen", "Tasks",
     in: ["Meetings", "David Chen", "Website redesign", "High"], when: {1, ~T[09:00:00]}},
    {"Weekly status meeting", "Tasks",
     in: ["Meetings", "Anna Berg", "Maria Svensson", "Medium"], when: {7, ~T[13:00:00]}},
    {"Coffee with Sarah Miller", "Tasks",
     in: ["Meetings", "Sarah Miller", "Low"], when: {3, ~T[15:00:00]}},
    {"Kick-off for the office move", "Tasks",
     in: ["Meetings", "Johan Lind", "Office move"], when: {-6, ~T[11:00:00]}, done: 6},

    # --- mail, reading, follow up, issues, ideas ---
    {"Mail the signed contract to Nordvik Consulting", "Tasks",
     in: ["Mail", "Anna Berg", "High"], when: 1},
    {"Send the board the draft accounts", "Tasks",
     in: ["Mail", "Annual report", "Medium"], when: 8},
    {"Read the market report", "Tasks", in: ["Reading", "Low"]},
    {"Read the new data protection guidelines", "Tasks",
     in: ["Reading", "Sarah Miller", "Medium"], when: 14},
    {"Follow up on the unpaid invoice from Pixelworks", "Tasks",
     in: ["Follow up", "David Chen", "High"], when: -2},
    {"Follow up the quote from Lind Removals", "Tasks",
     in: ["Follow up", "Johan Lind", "Office move"], when: 4},
    {"The printer on the second floor keeps jamming", "Tasks", in: ["Issues", "Medium"]},
    {"The meeting room projector has no HDMI cable", "Tasks", in: ["Issues"], when: -5},
    {"A shared calendar for the meeting rooms", "Tasks", in: ["Ideas"]},
    {"Newsletter for our clients", "Tasks", in: ["Ideas", "Anna Berg", "Low"]},

    # --- the trip's expenses ---
    {"Flight to Berlin", "Expenses",
     in: ["Air", @trip], when: -13, amount: 245.0, note: "Booking ref. QX7H2L, seat 14C."},
    {"Hotel in Berlin, three nights", "Expenses",
     in: ["Lodging", @trip], when: -13, amount: 389.5},
    {"Taxi from the airport", "Expenses", in: ["Transportation", @trip], when: -13, amount: 32.4},
    {"Breakfast at the station", "Expenses", in: ["Breakfast", @trip], when: -12, amount: 9.8},
    {"Dinner with the conference speakers", "Expenses",
     in: ["Dinner", @trip], when: -12, amount: 86.0},
    {"Conference fee", "Expenses", in: [@trip], when: -30, amount: 450.0},
    {"Flight home from Berlin", "Expenses", in: ["Air", @trip], when: -10, amount: 212.0},

    # --- other expenses ---
    {"Train tickets to the client in Uppsala", "Expenses",
     in: ["Transportation", "No Purpose"], when: -7, amount: 54.0},
    {"Lunch with Anna Berg", "Expenses",
     in: ["Lunch", "Anna Berg", "No Purpose"], when: -4, amount: 38.5},
    {"Printer paper and toner", "Expenses", in: ["Miscellaneous"], when: -9, amount: 64.9}
  ]

  @doc "Adds the sample categories and items to the Planner `db`, dated from `today`."
  @spec add(Database.t(), Date.t()) :: Database.t()
  def add(db, today) do
    db
    |> add_children("People", Enum.map(@people, fn {name, _, _} -> name end))
    |> notes()
    |> add_children("Project", @projects)
    |> add_children("Report ID", [@trip])
    |> items(today)
    |> contacts(today)
    |> sections()
  end

  # Contacts lists one blank item per person, as Agenda's "Create/Update
  # contact list" macro made them: the person's name, phone and company
  # are in the columns (shot 110)
  defp contacts(db, today) do
    Enum.reduce(@people, db, fn {name, _, _}, db ->
      {db, item} = Core.add_item(db, "", Date.add(today, -20), section: id(db, "Contact List"))
      Core.assign(db, item, id(db, name), today)
    end)
  end

  # sections a person would add for the new categories: one per person in
  # People, and the trip in Expense Reports
  defp sections(db) do
    db
    |> add_sections("People", Enum.map(@people, fn {name, _, _} -> name end))
    |> add_sections("Expense Reports", [@trip])
  end

  defp add_sections(db, view_name, names) do
    view = Enum.find(Database.views(db), &(&1.name == view_name))

    names
    |> Enum.with_index(length(view.sections))
    |> Enum.reduce(db, fn {name, index}, db ->
      Core.add_section(db, view.id, id(db, name), index)
    end)
  end

  defp add_children(db, parent, names) do
    Enum.reduce(names, db, fn name, db ->
      {:ok, db, _} = Core.add_category(db, id(db, parent), name)
      db
    end)
  end

  defp notes(db) do
    Enum.reduce(@people, db, fn {name, phone, company}, db ->
      Core.set_category_note(db, id(db, name), "Phone: #{phone}\nCompany: #{company}")
    end)
  end

  defp items(db, today) do
    @items
    |> Enum.with_index()
    |> Enum.reduce(db, fn {{text, section, details}, index}, db ->
      add_item(db, today, text, section, details, index)
    end)
  end

  defp add_item(db, today, text, section, details, index) do
    days = details |> Keyword.get(:when) |> days()
    # entered a little before it was due (or before today), varied by the
    # item's place in the list so that the Entry dates differ
    entered = Date.add(today, min(days || 0, 0) - 1 - rem(index, 5))
    {db, item} = Core.add_item(db, text, entered, section: id(db, section))

    db =
      Enum.reduce(Keyword.get(details, :in, []), db, &Core.assign(&2, item, id(&2, &1), today))

    db
    |> set_when(item, Keyword.get(details, :when), today)
    |> set_amount(item, Keyword.get(details, :amount), today)
    |> set_note(item, Keyword.get(details, :note), today)
    |> set_done(item, Keyword.get(details, :done), today)
  end

  defp days({days, %Time{}}), do: days
  defp days(days), do: days

  defp set_when(db, _item, nil, _today), do: db

  defp set_when(db, item, {days, time}, today),
    do: Core.set_date_time(db, item, db.special.when, Date.add(today, days), time, today)

  defp set_when(db, item, days, today),
    do: Core.set_date(db, item, db.special.when, Date.add(today, days), today)

  defp set_amount(db, _item, nil, _today), do: db

  defp set_amount(db, item, amount, today) do
    {:ok, db} = Core.set_number(db, item, id(db, "Amount"), amount, today)
    db
  end

  defp set_note(db, _item, nil, _today), do: db
  defp set_note(db, item, note, today), do: Core.set_note(db, item, note, today)

  # marked done on the day it was done, as if F4 were pressed then
  defp set_done(db, _item, nil, _today), do: db

  defp set_done(db, item, days_ago, today),
    do: Core.toggle_done(db, item, Date.add(today, -days_ago))

  defp id(db, name) do
    [id] = Database.find_categories(db, name)
    id
  end
end
