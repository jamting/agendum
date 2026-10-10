defmodule Agenda.Core.ShortNamesTest do
  @moduledoc "Short names in columns too narrow for full names (User's Guide 19-2)."
  use ExUnit.Case, async: true

  import Agenda.Fixtures
  alias Agenda.Core
  alias Agenda.Core.ViewModel

  setup do
    db =
      with_categories(Core.new_file(), [
        {"Contact person", [match_name: false, short_name: "Who"], ["Anna Lasky", "Bo"]}
      ])

    db =
      Agenda.Core.Database.update_category(db, cat(db, "Anna Lasky"), &%{&1 | short_name: "Anna"})

    {db, id} = Core.add_item(db, "x", today())
    %{db: db, item: db.items[id], head: cat(db, "Contact person")}
  end

  test "a full name that fits is shown as it is", %{db: db, item: item, head: head} do
    db = Core.assign(db, item.id, cat(db, "Anna Lasky"))
    assert ViewModel.cell(db, db.items[item.id], head, 12) == "Anna Lasky"
  end

  test "a name too long for the column gives way to its short name", %{
    db: db,
    item: item,
    head: head
  } do
    db = Core.assign(db, item.id, cat(db, "Anna Lasky"))
    assert ViewModel.cell(db, db.items[item.id], head, 6) == "Anna"
  end

  test "several entries that do not fit use short names where they have them", %{
    db: db,
    item: item,
    head: head
  } do
    db = db |> Core.assign(item.id, cat(db, "Anna Lasky")) |> Core.assign(item.id, cat(db, "Bo"))
    assert ViewModel.cell(db, db.items[item.id], head, 20) == "Anna Lasky, Bo"
    assert ViewModel.cell(db, db.items[item.id], head, 10) == "Anna, Bo"
  end

  test "a column head too long for its column shows its short name", %{db: db, head: head} do
    assert ViewModel.column_label(db, head, 16) == "Contact person"
    assert ViewModel.column_label(db, head, 8) == "Who"
  end

  test "without a short name, the full name is kept (and cut off by the screen)", %{
    db: db,
    item: item,
    head: head
  } do
    db = Core.assign(db, item.id, cat(db, "Bo"))
    assert ViewModel.cell(db, db.items[item.id], head, 1) == "Bo"
    assert ViewModel.column_label(db, cat(db, "Anna Lasky"), 3) == "Anna"
  end
end
