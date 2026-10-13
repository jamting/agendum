defmodule Agenda.Core.FitColumnTest do
  @moduledoc """
  Fit column to contents (R22a): a column's width set once to fit its head
  and the entries of the items the view shows.
  """
  use ExUnit.Case, async: true

  alias Agenda.Core
  alias Agenda.Core.Database

  @today ~D[2026-10-08]

  setup do
    db = Agenda.Sample.build(@today)
    [view] = Database.views(db)
    %{db: db, view: view}
  end

  defp width(db, view, index),
    do: db.views[view.id] |> Agenda.Core.View.columns(0) |> Enum.at(index) |> Map.fetch!(:width)

  test "the widest full name shown, though the column shows short names", %{db: db, view: view} do
    # narrowed to 3, Contact shows short names; its widest is "Abigail Scheer"
    db = Core.resize_column(db, view.id, {0, 2}, -100)
    assert width(db, view, 2) == 3
    assert Core.fit_column(db, view.id, {0, 2}, @today) |> width(view, 2) == 14
  end

  test "the head counts as well as the entries", %{db: db, view: view} do
    # Priority's entries are High, Medium, Low; its head is longer
    assert Core.fit_column(db, view.id, {0, 1}, @today) |> width(view, 1) ==
             String.length("Priority")
  end

  test "only items the view shows: collapsed sections do not count", %{db: db, view: view} do
    [contact] = Database.find_categories(db, "Contact")
    {:ok, db, long} = Core.add_category(db, contact, "Bartholomew Longbottom")
    section = hd(view.sections).category_id
    {db, item} = Core.add_item(db, "Lunch", @today, section: section)
    db = Core.assign(db, item, long)
    assert Core.fit_column(db, view.id, {0, 2}, @today) |> width(view, 2) == 22

    collapsed = Core.set_section_collapsed(db, view.id, 0, true)
    assert Core.fit_column(collapsed, view.id, {0, 2}, @today) |> width(view, 2) == 7
  end

  test "a date column fits its dates", %{db: db, view: view} do
    # When shows dates as 2026-10-08 (no times in the sample)
    assert Core.fit_column(db, view.id, {0, 0}, @today) |> width(view, 0) == 10
  end

  test "an empty column fits its head, and never less than 3", %{db: db, view: view} do
    {:ok, db, x} = Core.add_category(db, db.main_id, "X")
    db = Core.add_column(db, view.id, x, {0, 3}, 12)
    assert Core.fit_column(db, view.id, {0, 3}, @today) |> width(view, 3) == 3
  end
end
