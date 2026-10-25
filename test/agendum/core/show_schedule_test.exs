defmodule Agendum.Core.ShowScheduleTest do
  @moduledoc "Show Schedule (R49; User's Guide 10-14 to 10-16): one date's items in the Show View."
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.{Search, ViewModel}

  @now ~N[2026-10-12 10:00:00]

  setup do
    db = Core.new_file()
    {:ok, db, calls} = Core.add_category(db, db.main_id, "Calls")
    {db, _} = Core.add_item(db, "Call Pooh on Wednesday", @now)
    {db, _} = Core.add_item(db, "Tea on Wednesday", @now)
    {db, _} = Core.add_item(db, "Picnic on Thursday", @now)
    %{db: db, calls: calls, when: db.special.when}
  end

  defp texts(db, view_id),
    do:
      db
      |> ViewModel.build(db.views[view_id], @now)
      |> Enum.flat_map(& &1.rows)
      |> Enum.map(& &1.item.text)

  test "shows the items of one date, under the section head", %{db: db, when: w} do
    {:ok, db, view} = Core.show_schedule(db, w, w, ~D[2026-10-14], [])
    view_struct = db.views[view]
    assert view_struct.name == "*Show View*"
    assert Enum.map(view_struct.sections, & &1.category_id) == [w]
    assert texts(db, view) == ["Call Pooh on Wednesday", "Tea on Wednesday"]
  end

  test "a filter narrows it to items in (or not in) categories", %{db: db, when: w, calls: calls} do
    {:ok, db, view} = Core.show_schedule(db, w, w, ~D[2026-10-14], [{calls, :assigned}])
    assert texts(db, view) == ["Call Pooh on Wednesday"]

    {:ok, db, view} = Core.show_schedule(db, w, w, ~D[2026-10-14], [{calls, :not_assigned}])
    assert texts(db, view) == ["Tea on Wednesday"]
  end

  test "the date category must be one", %{db: db, calls: calls} do
    assert Core.show_schedule(db, calls, calls, ~D[2026-10-14], []) ==
             {:error, :not_a_date_category}
  end

  test "the Show View starts afresh: a search after a schedule is not filtered", %{
    db: db,
    when: w
  } do
    {:ok, db, _} = Core.show_schedule(db, w, w, ~D[2026-10-14], [])
    {db, view} = Core.show_match(db, %Search{text: "picnic"})
    assert db.views[view].filter == []
    assert texts(db, view) == ["Picnic on Thursday"]
  end
end
