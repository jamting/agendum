# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Starters.GTD do
  @moduledoc """
  The Getting Things Done starter file (R60a; `docs/plans/STARTERS.md`):
  David Allen's method made of Agenda's own parts, as a person could have
  set it up in Agenda (ADR 0049). Agenda shipped no such file; ours.

  Every item lives in the exclusive **Inbox** family: an item not filed
  yet is in the Inbox itself, a filed one in one of its lists, a context
  (`Contexts`, exclusive too, Agendas among them), Waiting For or
  Someday/Maybe. Giving an
  item a list takes it out of the one it was in, as exclusive children
  do (R7a), and the Inbox view shows only the items in no list. So an
  item typed there that its words file ("Call Anna" in @Calls) leaves it
  by itself, and so does one filed by hand. A catch-all Inbox category
  filled by a condition would not work: an item typed under it is
  assigned by hand, and conditions never break that (R15).

  Agendas is GTD's list of what to bring up with each person: a context
  whose children are people, so a typed item that names one ("Ask Marie
  about the shelves") files itself by the name, as the Planner's People
  do. Projects are a family of their own beside the lists, and a project
  without a next action is an empty section of the Projects view.

  One item, a welcome whose note says how the file works; the person
  discards it. Built through `Agendum.Core` like any file a person makes,
  so it is always in the current format; `mix agendum.starters` writes it
  to `starters/gtd.agendum`. Pure.
  """

  alias Agendum.Core
  alias Agendum.Core.Database

  # The welcome item's entry date: a fixed day, so the same code always
  # builds the same file (the committed one is compared with it)
  @written ~D[2026-11-02]

  # Any fixed day: setting a date filter only checks that its phrases read
  @check_day ~D[2026-01-01]

  # {name, Also match}: words in an item's text that file it there (R16);
  # @Home and @Office have none, as no word says where a thing is done
  @contexts [
    {"@Anywhere", "read;think"},
    {"@Calls", "call;phone;ring"},
    {"@Computer", "email;online;website"},
    {"@Errands", ~s(buy;shop;"pick up")},
    {"@Home", nil},
    {"@Office", nil}
  ]

  @welcome "Welcome: type what's on your mind, one item each (F5 for how this file works)"

  @note """
  This file follows Getting Things Done (David Allen).

  Inbox: type everything here, one item each. Some words file an item by themselves: "Call Anna" goes to @Calls, "Buy milk" to @Errands, "Waiting for Bob's reply" to Waiting For.

  File the rest: type a context (@Home, @Office ...) in the Contexts column, or assign Waiting For or Someday/Maybe (ALT-M). Filed, an item leaves the Inbox; each item is in one list.

  Next Actions: what you can do, by context.
  Agendas: what to bring up with each person. "Ask Marie about the shelves" goes to Marie once Marie is a person under Agendas: add one in the category manager (F9, INS).
  Projects: a section per project; an empty one has no next action yet. Type a new name in a Projects column to start a project.
  Waiting For: what others owe you, with the day it was entered.
  Someday/Maybe: ideas for later, out of the other views.
  Weekly Review: once a week, top to bottom: empty the Inbox, chase what has waited a week, look over Someday/Maybe, see what got done.

  F8 lists the views. Discard this item (ALT-F4) once you have read it.
  """

  @doc "The GTD file."
  @spec build() :: Database.t()
  def build do
    Core.new_file(view_name: "Inbox", section_name: "Inbox")
    |> categories()
    |> views()
    |> welcome()
  end

  # --- categories ---

  defp categories(db) do
    inbox = id(db, "Inbox")
    # names that are not words of a typed item are not matched (R16)
    off = [match_name: false]

    {:ok, db, contexts} = Core.add_category(db, inbox, "Contexts", off)

    db =
      Enum.reduce(@contexts, db, fn {name, words}, db ->
        {:ok, db, id} = Core.add_category(db, contexts, name, off)
        if words, do: also_match(db, id, words), else: db
      end)

    # "Waiting for Bob's reply" files itself by the name
    {:ok, db, _} = Core.add_category(db, inbox, "Waiting For")
    {:ok, db, someday} = Core.add_category(db, inbox, "Someday/Maybe", off)
    db = also_match(db, someday, "someday")

    # a person's name files an item, so Sample Person keeps name matching
    {:ok, db, agendas} = Core.add_category(db, contexts, "Agendas", off)
    {:ok, db, _} = Core.add_category(db, agendas, "Sample Person")

    {:ok, db, projects} = Core.add_category(db, db.main_id, "Projects", off)
    {:ok, db, _} = Core.add_category(db, projects, "Sample Project", off)

    # one list for each item, and one context; nothing is assigned yet,
    # so there are no conflicts to resolve
    {:ok, db} = Core.make_exclusive(db, inbox)
    {:ok, db} = Core.make_exclusive(db, contexts)
    db
  end

  defp also_match(db, id, words) do
    {:ok, db} = Core.set_also_match(db, id, words)
    db
  end

  # --- views ---

  # the items in a list, so not in the Inbox itself any more
  @filed ["Contexts", "Waiting For", "Someday/Maybe"]

  defp views(db) do
    inbox = hd(db.view_order)

    db
    |> columns(inbox, ["Contexts", "Projects"])
    |> filter(inbox, :view, Enum.map(@filed, &{&1, :not_assigned}))
    |> option(inbox, :hide_done)
    |> view("Next Actions", Enum.map(@contexts, &elem(&1, 0)) ++ ["Agendas"], ["Projects", "When"])
    |> view("Agendas", ["Sample Person"], ["Projects", "When"])
    |> view("Projects", ["Sample Project"], ["Contexts", "When"])
    |> view("Waiting For", ["Waiting For"], ["Entry", "Projects"])
    |> view("Someday/Maybe", ["Someday/Maybe"], ["Projects"])
    |> weekly_review()
  end

  # a view with these sections and columns, done items hidden
  defp view(db, name, sections, columns) do
    {db, view} = Core.add_view(db, name, Enum.map(sections, &id(db, &1)))

    db
    |> columns(view, columns)
    |> option(view, :hide_done)
  end

  # Once a week, top to bottom: the Inbox to empty, what has waited a
  # week or more, Someday/Maybe to look over, and what got done in the
  # week. Done items are hidden by each section's filter, not the view's
  # option, as the last section shows only them.
  defp weekly_review(db) do
    sections = ["Inbox", "Waiting For", "Someday/Maybe", "Done"]
    {db, view} = Core.add_view(db, "Weekly Review", Enum.map(sections, &id(db, &1)))
    not_done = {"Done", :not_assigned}

    db
    |> filter(view, {:section, 0}, [not_done | Enum.map(@filed, &{&1, :not_assigned})])
    |> filter(view, {:section, 1}, [not_done])
    |> range(view, {:section, 1}, "Entry", nil, "7 days ago")
    |> filter(view, {:section, 2}, [not_done])
    |> range(view, {:section, 3}, "Done", "7 days ago", "today")
    |> option(view, :section_separators)
  end

  defp columns(db, view, heads) do
    heads
    |> Enum.with_index()
    |> Enum.reduce(db, fn {head, index}, db ->
      id = id(db, head)
      kind = db.categories[id].kind
      {:ok, db} = Core.add_column_as(db, view, id, kind, {0, index}, insert_in: :all)
      db
    end)
  end

  defp filter(db, view, scope, terms),
    do: Core.set_filters(db, view, scope, Enum.map(terms, fn {name, t} -> {id(db, name), t} end))

  # a date filter whose phrases are read again each day (R28a)
  defp range(db, view, scope, name, from, to) do
    {:ok, db} =
      Core.set_range_filter(
        db,
        view,
        scope,
        id(db, name),
        {:assigned, from, to, :inside},
        @check_day
      )

    db
  end

  defp option(db, view, option), do: Core.toggle_view_option(db, view, option)

  # --- the welcome item ---

  defp welcome(db) do
    {db, item} = Core.add_item(db, @welcome, @written, section: id(db, "Inbox"))
    Core.set_note(db, item, String.trim_trailing(@note), @written)
  end

  # the file's names are unique, so a name is enough to find one
  defp id(db, name) do
    [id] = Database.find_categories(db, name)
    id
  end
end
