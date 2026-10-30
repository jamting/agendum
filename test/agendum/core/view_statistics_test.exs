# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.ViewStatisticsTest do
  @moduledoc """
  View Properties ▸ View statistics (R78; Help "View Statistics Box"): the
  marked items in the view, its sections (empty ones too) and the items
  its sections show.
  """
  use ExUnit.Case, async: true

  import Agendum.Fixtures, only: [cat: 2, with_categories: 2]

  alias Agendum.Core

  @today ~D[2026-10-23]

  # sections Calls (two items, one marked) and Meetings (one item), and an
  # empty Mail; an item in no section
  setup do
    db = Core.new_file(view_name: "Work", section_name: "Calls")
    db = with_categories(db, ["Meetings", "Mail"])
    view = hd(db.view_order)
    db = Core.add_section(db, view, cat(db, "Meetings"), 1)
    db = Core.add_section(db, view, cat(db, "Mail"), 2)
    {db, [a, b, c, d]} = items(db, ["Ring Anna", "Ring Johan", "Plan the week", "Elsewhere"])
    db = Core.assign(db, a, cat(db, "Calls"))
    db = Core.assign(db, b, cat(db, "Calls"))
    db = Core.assign(db, c, cat(db, "Meetings"))
    db = Core.set_marked(db, [a, d], true)
    %{db: db, view: view}
  end

  defp items(db, texts) do
    Enum.reduce(texts, {db, []}, fn text, {db, ids} ->
      {db, id} = Core.add_item(db, text, @today)
      {db, ids ++ [id]}
    end)
  end

  test "marked items the view shows, every section, the items shown", %{db: db, view: v} do
    # the marked item outside the view does not count
    assert Core.view_statistics(db, v, @today) == %{marked: 1, sections: 3, items: 3}
  end

  test "an item in two sections counts in each, as the view shows it twice", %{db: db, view: v} do
    [ring_anna | _] = Core.marked_items(db)
    db = Core.assign(db, ring_anna, cat(db, "Mail"))
    assert %{marked: 1, items: 4} = Core.view_statistics(db, v, @today)
  end
end
