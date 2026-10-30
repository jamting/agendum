# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Starters.Clinic.Views do
  @moduledoc """
  The clinic's views (`Agendum.Starters.Clinic`): To Do first, then the
  rest A-Z, as the Planner's (`Agendum.Starters.Planner.Views`, whose
  settings these follow). Pure.
  """

  alias Agendum.Core
  alias Agendum.Core.{Database, Datebook, View}
  alias Agendum.Starters.Clinic

  # Any fixed day: setting a date filter only checks that its phrases read.
  @check_day ~D[2026-01-01]

  @clients ~w(Pooh Piglet Eeyore Owl Rabbit Tigger Kanga Roo)

  # wide enough for a family session's three names
  @clients_column {"Clients", width: 22}

  # {name, sections, settings}. Settings, all optional:
  #   columns:  in every section, one linked column each, left to right:
  #             {head, options as `Core.add_column_as/6` takes them}
  #   filter:   [{category, :assigned | :not_assigned}]
  #   range:    {date category, from, to}: a date filter, read each day
  #   calcs:    numeric functions under every section (`Core.set_section_calcs/4`)
  #   sort:     the items' order: by these categories' values in turn (a
  #             date category sorts by date)
  #   options:  view options switched on (`Core.toggle_view_option/3`)
  @views [
    {"Billing", ["Fees", "Paid in kind"],
     columns: [@clients_column, {"Fee", []}, {"When", []}],
     calcs: [:count, :total],
     sort: ["When"],
     options: [:section_separators]},
    {"Caseload", @clients ++ ["No client"],
     columns: [{"Activity", width: 16}, {"When", []}],
     filter: [{"Treatment plans", :not_assigned}],
     sort: ["When"],
     options: [:section_separators, :hide_done]},
    {"Done Since Last Week", ["To Do"],
     columns: [@clients_column, {"Done", []}],
     range: {"Done", "beginning of last week", "today"},
     sort: ["Done"]},
    {"Diagnoses",
     ["Honey use disorder", "ADHD, inattentive type", "ADHD, hyperactive-impulsive type"] ++
       ["Generalized anxiety", "Dysthymia", "Reading difficulty", "Need for control"] ++
       ["Parenting stress", "Housing problems", "No diagnosis"],
     columns: [{"Clients", width: 14}, {"Treatment", width: 30}], options: [:section_separators]},
    {"Overdue", ["To Do"],
     columns: [@clients_column, {"Priority", width: 8}, {"When", []}],
     range: {"When", nil, "yesterday"},
     sort: ["When"],
     options: [:hide_done]},
    {"Progress", ["Improving", "Holding steady", "Setback"],
     columns: [@clients_column, {"When", []}], sort: ["When"], options: [:section_separators]},
    {"Sessions", ["Sessions"],
     columns: [@clients_column, {"Location", width: 16}, {"When", []}],
     sort: ["When"],
     options: [:hide_done]},
    {"Treatment Plans", ["Treatment plans"],
     columns: [{"Diagnosis", width: 34}, {"Treatment", width: 30}]}
  ]

  # {name, datebook settings}: on To Do by When, as the Planner's
  @datebooks [
    {"Today",
     period: :day, interval: 30, start_time: ~T[08:30:00], end_time: ~T[17:00:00], base: "today"},
    {"This Week", period: :week, base: "beginning of this week"}
  ]

  @doc "Adds the views to the clinic's `db`, whose first view is To Do."
  @spec add(Database.t()) :: Database.t()
  def add(db) do
    db = to_do(db)

    db =
      Enum.reduce(@views, db, fn {name, sections, settings}, db ->
        view(db, name, sections, settings)
      end)

    db = Enum.reduce(@datebooks, db, fn {name, settings}, db -> datebook(db, name, settings) end)
    order(db)
  end

  # the new file's first view: To Do, with a When column already; by date,
  # so overdue items come first, then today's
  defp to_do(db) do
    view = hd(db.view_order)

    db =
      [{"Clients", width: 18}, {"Activity", width: 10}, {"Priority", width: 8}]
      |> Enum.with_index()
      |> Enum.reduce(db, fn {column, index}, db -> column(db, view, index, column) end)

    # done items hidden (the macro Hide/Display done items shows them)
    db |> sort(view, ["When"]) |> options(view, [:hide_done])
  end

  defp view(db, name, sections, settings) do
    {db, view} = Core.add_view(db, name, Enum.map(sections, &Clinic.id(db, &1)))

    db =
      settings
      |> Keyword.get(:columns, [])
      |> Enum.with_index()
      |> Enum.reduce(db, fn {column, index}, db -> column(db, view, index, column) end)

    db
    |> filter(view, Keyword.get(settings, :filter, []))
    |> range(view, settings[:range])
    |> calcs(view, length(sections), settings[:calcs])
    |> sort(view, settings[:sort])
    |> options(view, Keyword.get(settings, :options, []))
  end

  # a column in every section, linked (`insert_in: :all`)
  defp column(db, view, index, {head, opts}) do
    id = Clinic.id(db, head)
    kind = db.categories[id].kind
    {:ok, db} = Core.add_column_as(db, view, id, kind, {0, index}, [insert_in: :all] ++ opts)
    db
  end

  defp filter(db, _view, []), do: db

  defp filter(db, view, terms),
    do:
      Core.set_filters(
        db,
        view,
        :view,
        Enum.map(terms, fn {name, term} -> {Clinic.id(db, name), term} end)
      )

  defp range(db, _view, nil), do: db

  defp range(db, view, {name, from, to}) do
    {:ok, db} =
      Core.set_range_filter(
        db,
        view,
        :view,
        Clinic.id(db, name),
        {:assigned, from, to, :inside},
        @check_day
      )

    db
  end

  defp calcs(db, _view, _count, nil), do: db

  defp calcs(db, view, count, calcs),
    do: Enum.reduce(0..(count - 1)//1, db, &Core.set_section_calcs(&2, view, &1, calcs))

  defp sort(db, _view, nil), do: db

  defp sort(db, view, names) do
    keys = Enum.map(names, &%View.SortKey{on: {:category, Clinic.id(db, &1)}})
    Core.set_sort(db, view, :view, keys)
  end

  defp options(db, view, options),
    do: Enum.reduce(options, db, &Core.toggle_view_option(&2, view, &1))

  defp datebook(db, name, settings) do
    book = struct(Datebook, [section_category: Clinic.id(db, "To Do")] ++ settings)
    {:ok, db, view} = Core.add_datebook_view(db, name, book)
    db = if book.period == :day, do: column(db, view, 0, @clients_column), else: db
    options(db, view, [:hide_column_heads, :section_separators])
  end

  # To Do first, the rest A-Z
  defp order(db) do
    db = Core.sort_views(db)
    [to_do] = for v <- Database.views(db), v.name == "To Do", do: v.id
    Core.move_view(db, to_do, 0)
  end
end
