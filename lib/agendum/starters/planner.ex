# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Starters.Planner do
  @moduledoc """
  The Activities Planner starter file (R60), as Agenda 2.0 shipped it in
  `apps\\planner` (Starter Applications; transcribed from screenshots in
  `docs/reference/screens/notes.md`, 37-144): categories for tasks,
  people, projects, priorities and expenses, with the rules that sort
  items into them. No items.

  Built through `Agendum.Core` like any file a person makes, so it is
  always in the current format. `mix agendum.starters` writes it to
  `starters/planner.agendum`, and with `--samples` a copy with sample
  data (`with_samples/2`). Our choices: the file's own date settings
  are Agendum's defaults, not Agenda's American ones; Sample Person has a
  note with a phone number and a company, for the Contacts view.

  Pure.
  """

  alias Agendum.Core
  alias Agendum.Core.Database

  @doc "The Planner file."
  @spec build() :: Database.t()
  def build do
    Core.new_file(view_name: "Tasks", section_name: "Tasks")
    |> categories()
    |> Agendum.Starters.Planner.Views.add()
    |> Agendum.Starters.Planner.Macros.add()
  end

  @doc """
  The Planner with sample data in it, for trying it out
  (`mix agendum.starters --samples`); dates are counted from `today`, so
  the same day always gives the same file. See `Agendum.Starters.Planner.Samples`.
  """
  @spec with_samples(Database.t(), Date.t()) :: Database.t()
  defdelegate with_samples(db, today), to: Agendum.Starters.Planner.Samples, as: :add

  # --- categories (shots 38-39, 111) ---

  # {name, options, children}; options as `Core.add_category/4` takes them.
  # The names a text should not assign an item to have `match_name: false`
  # (shots 74-77, 113-125); the others keep the default, true.
  @off [match_name: false]

  @before_tasks [
    {"People", @off, [{"Sample Person", [], []}]},
    {"Unassigned", @off, []},
    {"Project", @off, [{"Sample Project", [], []}]},
    {"Miscellaneous Project", @off, []}
  ]

  @after_tasks [
    {"Activity", @off,
     [
       {"Calls", [short_name: "Phone"], []},
       {"Meetings", [], []},
       {"Mail", [], []},
       {"Reading", [], []},
       {"Follow up", [], []},
       {"Issues", [], []},
       {"Ideas", [], []}
     ]},
    {"Miscellaneous Activity", @off, []},
    {"Expenses", @off, []},
    {"Priority", [exclusive: true] ++ @off,
     [
       {"High", [short_name: "Hi"] ++ @off, []},
       {"Medium", @off, []},
       {"Low", @off, []}
     ]},
    {"No Priority Assigned", @off, []},
    {"Contact List", @off, []},
    {"Type", [exclusive: true] ++ @off,
     [
       {"Lodging", [short_name: "Hotel"], []},
       {"Breakfast", [], []},
       {"Lunch", [], []},
       {"Dinner", [], []},
       {"Entertainment", [], []},
       {"Air", [], []},
       {"Transportation", [], []},
       {"Miscellaneous", [], []}
     ]},
    {"No Type", @off, []},
    {"Report ID", [exclusive: true] ++ @off, [{"Sample Trip", [], []}]},
    {"No Purpose", @off, []},
    {"Amount", [kind: :numeric] ++ @off, []}
  ]

  # Assignment conditions: {category, [{target, :assigned | :not_assigned}]}
  @conditions [
    {"No Priority Assigned", [{"Priority", :not_assigned}, {"Tasks", :assigned}]},
    {"Unassigned", [{"People", :not_assigned}, {"Tasks", :assigned}]},
    {"No Type", [{"Expenses", :assigned}, {"Type", :not_assigned}]}
  ]

  @also_match [
    {"Calls", "Telephone"},
    {"Lodging", "Motel;Inn"},
    # in quotes: the whole phrase
    {"No Type", ~s("Expenses with No Type")}
  ]

  defp categories(db) do
    db = add_tree(db, db.main_id, @before_tasks)
    # the new file made Tasks first: it goes after Miscellaneous Project
    {:ok, db} =
      Core.move_category(db, id(db, "Tasks"), db.main_id, id(db, "Miscellaneous Project"))

    db = add_tree(db, db.main_id, @after_tasks)

    db =
      for {name, conditions} <- @conditions, {target, kind} <- conditions, reduce: db do
        db ->
          {:ok, db} = Core.add_condition(db, id(db, name), id(db, target), kind)
          db
      end

    db =
      Enum.reduce(@also_match, db, fn {name, text}, db ->
        {:ok, db} = Core.set_also_match(db, id(db, name), text)
        db
      end)

    # an item with an amount is an expense (shot 125)
    {:ok, db} = Core.set_action(db, id(db, "Amount"), id(db, "Expenses"), :assign)

    Core.set_category_note(
      db,
      id(db, "Sample Person"),
      "Phone: 555-0100\nCompany: Sample Company"
    )
  end

  defp add_tree(db, parent, specs) do
    Enum.reduce(specs, db, fn {name, opts, children}, db ->
      {:ok, db, id} = Core.add_category(db, parent, name, opts)
      add_tree(db, id, children)
    end)
  end

  # the Planner's names are unique, so a name is enough to find one
  defp id(db, name) do
    [id] = Database.find_categories(db, name)
    id
  end
end
