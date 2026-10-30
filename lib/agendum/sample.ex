# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Sample do
  @moduledoc """
  The built-in files. `build/1` (`--demo`, and the tests): a small file
  based on the example view in US patent 5,115,504, a "Calls" section with
  Priority and Contact columns. `rabbit/1` (`--rabbit`): Rabbit's file
  from the manual.
  """

  alias Agendum.Core
  alias Agendum.Core.Database

  @spec build(Date.t()) :: Database.t()
  def build(%Date{} = today) do
    db = Core.new_file(view_name: "Activities", section_name: "Calls")
    main = db.main_id
    [calls] = Database.find_categories(db, "Calls")
    db = Database.update_category(db, calls, &%{&1 | match_name: true})

    {:ok, db, priority} =
      Core.add_category(db, main, "Priority", exclusive: true, match_name: false)

    {:ok, db, _} = Core.add_category(db, priority, "High")
    {:ok, db, _} = Core.add_category(db, priority, "Medium")
    {:ok, db, _} = Core.add_category(db, priority, "Low")

    {:ok, db, contact} = Core.add_category(db, main, "Contact", match_name: false)
    {:ok, db, _} = Core.add_category(db, contact, "Anna Lasky", short_name: "Anna")
    {:ok, db, _} = Core.add_category(db, contact, "Abigail Scheer", short_name: "Abigail")
    {:ok, db, _} = Core.add_category(db, contact, "Daniel Fiske", short_name: "Daniel")

    {:ok, db, _} = Core.add_category(db, main, "Meetings", match_name: true)

    [view] = Database.views(db)
    db = Core.add_column(db, view.id, priority, {0, 1}, 8)
    db = Core.add_column(db, view.id, contact, {0, 2}, 16)

    entries = [
      {"Set up meeting at Terracotta Corp to discuss CopyCat before the end of the month.",
       "Medium"},
      {"Don't forget to call Anna Lasky with the information she requested.", "High"},
      {"Call Marketing to arrange a Rapidfire demo for Abigail Scheer this Tuesday.", "Low"},
      {"Check with Abigail Scheer on meeting times.", "Medium"},
      {"Contact Daniel Fiske, get feedback!", "Medium"}
    ]

    Enum.reduce(entries, db, fn {text, prio}, db ->
      {db, item} = Core.add_item(db, text, today, section: calls)
      {:ok, db, _} = Core.assign_by_name(db, item, priority, prio, today)
      db
    end)
  end

  @doc """
  Rabbit's file, from the manual (`--rabbit`): his week in three sections
  (Garden, Notices, Friends and Relations), with Priority and Friends
  columns and six items. Dates in the items ("tomorrow morning", "on
  Friday") are read from `today`; the manual's screens use Monday
  2026-10-12.
  """
  @spec rabbit(Date.t()) :: Database.t()
  def rabbit(%Date{} = today) do
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
    db = Core.add_column(db, view.id, priority, {0, 1}, 8)
    db = Core.add_column(db, view.id, people, {0, 2}, 12)
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
      {db, item} = Core.add_item(db, text, today, section: section)
      {:ok, db, _} = Core.assign_by_name(db, item, priority, prio, today)
      db
    end)
  end
end
