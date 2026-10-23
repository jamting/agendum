defmodule Agendum.Core.NumberItemsTest do
  @moduledoc """
  Number items (R79; User's Guide 5-13, 9-11; Help "View Properties/Add/Copy
  Box"; checked in Agenda 2.0, 2026-10-23): a view setting, No by default;
  with Yes each item a section shows has its place in the section, 1, 2,
  3 …, counting only the items shown.
  """
  use ExUnit.Case, async: true

  import Agendum.Fixtures, only: [cat: 2, with_categories: 2]

  alias Agendum.Core
  alias Agendum.Core.{Database, Datebook, ViewModel}

  @today ~D[2026-10-23]

  # Calls with three items, Errands with two
  setup do
    db = Core.new_file(view_name: "Activities", section_name: "Calls")
    db = with_categories(db, ["Errands"])
    [view] = Database.views(db)
    db = Core.add_section(db, view.id, cat(db, "Errands"), 1)

    db =
      Enum.reduce(
        [{"Calls", "Bob"}, {"Calls", "Anna"}, {"Calls", "Carl"}, {"Errands", "Bank"}] ++
          [{"Errands", "Post"}],
        db,
        fn {section, text}, db ->
          {db, _} = Core.add_item(db, text, @today, section: cat(db, section))
          db
        end
      )

    %{db: db, view: view.id}
  end

  defp numbers(db, view_id) do
    db
    |> ViewModel.build(db.views[view_id], @today)
    |> Enum.map(fn section -> Enum.map(section.rows, &{&1.item.text, &1.number}) end)
  end

  test "off by default: no numbers", %{db: db, view: v} do
    refute db.views[v].number_items
    assert db |> numbers(v) |> List.flatten() |> Enum.all?(&(elem(&1, 1) == nil))
  end

  test "on: each section counts its own items from 1", %{db: db, view: v} do
    db = Core.toggle_view_option(db, v, :number_items)

    assert numbers(db, v) == [
             [{"Bob", 1}, {"Anna", 2}, {"Carl", 3}],
             [{"Bank", 1}, {"Post", 2}]
           ]
  end

  test "only the items shown are counted: a hidden done item leaves no gap",
       %{db: db, view: v} do
    anna = Enum.find(Map.values(db.items), &(&1.text == "Anna"))

    db =
      db
      |> Core.toggle_view_option(v, :number_items)
      |> Core.toggle_view_option(v, :hide_done)
      |> Core.toggle_done(anna.id, @today)

    assert hd(numbers(db, v)) == [{"Bob", 1}, {"Carl", 2}]
  end

  test "a datebook view numbers the items of each slot", %{db: db} do
    datebook = %Datebook{date_category: cat(db, "Entry"), section_category: cat(db, "Calls")}
    {:ok, db, id} = Core.add_datebook_view(db, "Week", datebook)
    db = Core.toggle_view_option(db, id, :number_items)

    slot = db |> numbers(id) |> Enum.find(&(&1 != []))
    assert Enum.map(slot, &elem(&1, 1)) == [1, 2, 3]
  end
end
