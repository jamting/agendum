defmodule Agenda.Sample do
  @moduledoc """
  A small demo file based on the example view in US patent 5,115,504:
  a "Calls" section with Priority and Contact columns.
  """

  alias Agenda.Core
  alias Agenda.Core.Database

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
    db = Core.add_column(db, view.id, priority, 1, 8)
    db = Core.add_column(db, view.id, contact, 2, 16)

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
end
