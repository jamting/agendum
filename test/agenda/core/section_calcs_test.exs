defmodule Agenda.Core.SectionCalcsTest do
  @moduledoc """
  Select numeric functions (R61, R29; User's Guide 8-10): the calculations
  of every numeric column in a section, set at once. They are the
  columns' own settings, so a linked column changes in every section.
  """
  use ExUnit.Case, async: true

  import Agenda.Fixtures, only: [cat: 2, with_categories: 2]

  alias Agenda.Core
  alias Agenda.Core.View

  # sections Calls and Meetings; Cost (numeric) linked in both, Hours
  # (numeric) and People in Calls only
  setup do
    db = Core.new_file(view_name: "Work", section_name: "Calls")
    db = with_categories(db, ["Meetings", "People", "Cost", "Hours"])
    {:ok, db} = Core.make_numeric(db, cat(db, "Cost"))
    {:ok, db} = Core.make_numeric(db, cat(db, "Hours"))
    view = hd(db.view_order)
    db = Core.add_section(db, view, cat(db, "Meetings"), 1)
    db = Core.add_column(db, view, cat(db, "Cost"), {0, 0}, 10, :all)
    db = Core.add_column(db, view, cat(db, "Hours"), {0, 1}, 8, :section)
    db = Core.add_column(db, view, cat(db, "People"), {0, 2}, 12, :section)
    %{db: db, view: view}
  end

  defp calcs(db, view, sidx) do
    for c <- View.columns(db.views[view], sidx),
        db.categories[c.category_id].kind == :numeric,
        do: {db.categories[c.category_id].name, c.number.calcs}
  end

  test "every numeric column of the section, in Agenda's order; the others untouched",
       %{db: db, view: v} do
    db = Core.set_section_calcs(db, v, 0, [:maximum, :count])
    assert calcs(db, v, 0) == [{"Cost", [:count, :maximum]}, {"Hours", [:count, :maximum]}]

    people =
      Enum.find(View.columns(db.views[v], 0), &(db.categories[&1.category_id].name == "People"))

    assert people.number.calcs == [:total]
  end

  test "a linked column changes in its other sections too", %{db: db, view: v} do
    db = Core.set_section_calcs(db, v, 0, [:average])
    assert calcs(db, v, 1) == [{"Cost", [:average]}]
  end

  test "what the section has: a function every numeric column has; nil without one",
       %{db: db, view: v} do
    assert Core.section_calcs(db, v, 0) == [:total]
    # Hours alone gets Count: not every column has it
    db = Core.set_column_format(db, v, {0, 1}, %Agenda.Core.NumberFormat{calcs: [:count, :total]})
    assert Core.section_calcs(db, v, 0) == [:total]

    # a section with no numeric column (whatever columns it was given)
    db = Core.add_section(db, v, cat(db, "People"), 2)
    n = length(View.columns(db.views[v], 2))
    db = Enum.reduce((n - 1)..0//-1, db, &Core.remove_column(&2, v, {2, &1}, :section))
    assert Core.section_calcs(db, v, 2) == nil
  end
end
