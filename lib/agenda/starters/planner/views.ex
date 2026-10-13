defmodule Agenda.Starters.Planner.Views do
  @moduledoc """
  The Activities Planner's views (R60; screenshots 37-73, 110, 127, 143
  in `docs/reference/screens/notes.md`): the sixteen of Agenda's View
  Manager, and Contacts, which Agenda's "Create/Update contact list"
  macro made (we have no macro command language, so it is in the file).

  Tasks comes first, as the file opens in the first view (Agenda opened
  it in the last one used); the others follow A-Z, as Agenda's View
  Manager listed them. Date phrases are English and read again each time,
  in any language (R14c). Column widths the shots do not show are
  Agendum's defaults. Pure.
  """

  alias Agenda.Core
  alias Agenda.Core.{Database, Datebook, View}

  # Any fixed day: setting a date filter only checks that its phrases read.
  @check_day ~D[2026-01-01]

  # A column is {head, options}; options as `Core.add_column_as/6` takes
  # them (width:, format:, note_line:, title:).
  @phone {"People", format: :note, note_line: 1, width: 14, title: "Phone #"}

  # A view is {name, sections, settings}. Settings, all optional:
  #   columns:   in every section, one linked column each, left to right
  #   only:      %{section index => columns} in that section alone, left
  #              of the shared ones
  #   section_sort:  {:none | :category | :alpha, :asc | :desc}
  #   filter:    [{category, :assigned | :not_assigned}]
  #   range:     {date category, from, to}: a date filter, phrases read each day
  #   sort:      the items' sort: [{:category, name, :alpha}]
  #   options:   view options switched on (`Core.toggle_view_option/3`)
  @views [
    {"Activities",
     ["Calls", "Follow up", "Ideas", "Issues", "Mail", "Meetings"] ++
       ["Miscellaneous Activity", "Reading"],
     columns: [{"When", []}], only: %{0 => [{"People", []}, @phone]}, section_sort: {:alpha, :asc}},
    {"Calls", ["Calls"], columns: [{"People", []}, @phone, {"When", []}]},
    {"Completed This Week", ["Tasks"],
     columns: [{"Done", []}], range: {"Done", "beginning of this week", "end of this week"}},
    {"Contacts", ["Contact List"],
     columns: [
       {"People", width: 20},
       @phone,
       {"People", format: :note, note_line: 2, width: 16, title: "Company"}
     ],
     sort: [{:category, "People", :alpha}],
     options: [:section_separators]},
    {"Expense Analysis - Type",
     ~w(Air Breakfast Dinner Entertainment Lodging Lunch Miscellaneous) ++
       ["No Type", "Transportation"],
     columns: [{"Amount", []}, {"Report ID", []}, {"When", []}],
     filter: [{"Expenses", :assigned}],
     section_sort: {:alpha, :asc},
     options: [:section_separators]},
    {"Expense Entry", ["Expenses"],
     columns: [{"Amount", []}, {"Report ID", []}, {"Type", []}, {"When", []}],
     options: [:section_separators]},
    {"Expense Reports", ["No Purpose", "Sample Trip"],
     columns: [{"Amount", []}, {"Type", []}, {"When", []}],
     filter: [{"Expenses", :assigned}],
     section_sort: {:alpha, :asc},
     options: [:section_separators]},
    {"Overdue", ["Tasks"],
     columns: [{"People", []}, {"Project", []}, {"When", []}],
     range: {"When", nil, "yesterday"},
     options: [:hide_done]},
    {"People", ["Sample Person", "Unassigned"],
     columns: [{"Priority", []}, {"When", []}],
     filter: [{"Contact List", :not_assigned}],
     section_sort: {:alpha, :asc}},
    {"Priorities", ["High", "Medium", "Low", "No Priority Assigned"],
     columns: [{"When", []}], only: %{3 => [{"Priority", []}]}, section_sort: {:category, :asc}},
    {"Projects", ["Miscellaneous Project", "Sample Project"],
     columns: [{"When", []}, {"Done", []}], section_sort: {:alpha, :asc}}
  ]

  # {name, datebook settings}: all on Tasks by When, column heads hidden,
  # lines between the slots (shots 54-55, 66-73). The week's first and
  # last days are the file's (Agenda's Sun and Sat were its own settings).
  @datebooks [
    {"Next Week", period: :week, base: "beginning of next week"},
    {"This Month", period: :month, interval: :week, base: "beginning of this month"},
    {"This Week", period: :week, base: "beginning of this week"},
    {"Today",
     period: :day, interval: 60, start_time: ~T[08:00:00], end_time: ~T[18:00:00], base: "today"},
    {"Tomorrow",
     period: :day,
     interval: 60,
     start_time: ~T[08:00:00],
     end_time: ~T[18:00:00],
     base: "tomorrow"}
  ]

  @doc "Adds the views to the Planner `db`, whose first view is Tasks."
  @spec add(Database.t()) :: Database.t()
  def add(db) do
    db = tasks(db)

    db =
      Enum.reduce(@views, db, fn {name, sections, settings}, db ->
        view(db, name, sections, settings)
      end)

    db = Enum.reduce(@datebooks, db, fn {name, settings}, db -> datebook(db, name, settings) end)
    order(db)
  end

  # the new file's first view: Tasks, with a When column already
  defp tasks(db) do
    tasks = hd(db.view_order)

    [{"Activity", []}, {"People", []}, {"Project", []}]
    |> Enum.with_index()
    |> Enum.reduce(db, fn {column, index}, db -> column(db, tasks, {0, index}, column, :all) end)
  end

  defp view(db, name, sections, settings) do
    {db, view} = Core.add_view(db, name, Enum.map(sections, &id(db, &1)))

    db
    |> shared_columns(view, Keyword.get(settings, :columns, []))
    |> section_columns(view, Keyword.get(settings, :only, %{}))
    |> section_sort(view, settings[:section_sort])
    |> filter(view, Keyword.get(settings, :filter, []))
    |> range(view, settings[:range])
    |> sort(view, settings[:sort])
    |> options(view, Keyword.get(settings, :options, []))
  end

  defp shared_columns(db, view, columns) do
    columns
    |> Enum.with_index()
    |> Enum.reduce(db, fn {column, index}, db -> column(db, view, {0, index}, column, :all) end)
  end

  # put left of the shared ones, which move right
  defp section_columns(db, view, only) do
    for {sidx, columns} <- only, {column, index} <- Enum.with_index(columns), reduce: db do
      db -> column(db, view, {sidx, index}, column, :section)
    end
  end

  defp column(db, view, at, {head, opts}, insert_in) do
    id = id(db, head)
    kind = db.categories[id].kind
    {:ok, db} = Core.add_column_as(db, view, id, kind, at, [insert_in: insert_in] ++ opts)
    db
  end

  defp section_sort(db, _view, nil), do: db
  defp section_sort(db, view, {sort, order}), do: Core.set_section_sort(db, view, sort, order)

  defp filter(db, _view, []), do: db

  defp filter(db, view, terms),
    do:
      Core.set_filters(
        db,
        view,
        :view,
        Enum.map(terms, fn {name, term} -> {id(db, name), term} end)
      )

  defp range(db, _view, nil), do: db

  defp range(db, view, {name, from, to}) do
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

  defp sort(db, _view, nil), do: db

  defp sort(db, view, keys) do
    keys =
      for {:category, name, sequence} <- keys,
          do: %View.SortKey{on: {:category, id(db, name)}, sequence: sequence}

    Core.set_sort(db, view, :view, keys)
  end

  defp options(db, view, options),
    do: Enum.reduce(options, db, &Core.toggle_view_option(&2, view, &1))

  defp datebook(db, name, settings) do
    book = struct(Datebook, [section_category: id(db, "Tasks")] ++ settings)
    {:ok, db, view} = Core.add_datebook_view(db, name, book)
    # Today and Tomorrow show the time in a When column (shot 70)
    db = if book.period == :day, do: column(db, view, {0, 0}, {"When", []}, :all), else: db
    options(db, view, [:hide_column_heads, :section_separators])
  end

  # Tasks first, the rest A-Z
  defp order(db) do
    db = Core.sort_views(db)
    [tasks] = for v <- Database.views(db), v.name == "Tasks", do: v.id
    Core.move_view(db, tasks, 0)
  end

  defp id(db, name) do
    [id] = Database.find_categories(db, name)
    id
  end
end
