defmodule Agendum.Core.BrowseTest do
  @moduledoc """
  Browsing dates in the core (R47, R48): where browsing starts, a move,
  going to a date, the view as browsed, and the command that keeps it.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.{Database, Datebook}

  @now ~N[2026-10-12 10:00:00]

  setup do
    db = Core.new_file()
    [view] = Database.views(db)
    %{db: db, view: view}
  end

  describe "a date filter" do
    setup %{db: db, view: view} do
      filter = {:assigned, "today", "today", :inside}
      {:ok, db} = Core.set_range_filter(db, view.id, :view, db.special.when, filter, @now)
      %{db: db, view: Database.view(db, view.id)}
    end

    test "moves by days, weeks and months, shown but not kept", %{db: db, view: view} do
      place = Core.browse_start(db, view, nil, @now)
      assert place == %{scope: :view, shift: %{days: 0, months: 0}}

      place =
        place
        |> then(&Core.browse_move(view, &1, :later))
        |> then(&Core.browse_move(view, &1, :week_later))

      assert place.shift == %{days: 8, months: 0}

      shown = Core.browsed_view(db, view, place, @now)
      assert [{_, {:range, "2026-10-20", "2026-10-20", :inside}}] = shown.filter
      assert Database.view(db, view.id) == view
    end

    test "goes to a date, and keeps it as a command", %{db: db, view: view} do
      place = Core.browse_start(db, view, nil, @now)
      place = Core.browse_to(db, view, place, ~D[2026-11-02], @now)
      assert place.shift.days == 21

      assert {:set_filters, _, :view, [{_, {:range, "2026-11-02", "2026-11-02", :inside}}]} =
               Core.browse_keep(db, view, place, @now)

      assert Core.browse_keep(db, view, Core.browse_start(db, view, nil, @now), @now) == nil
    end
  end

  test "a datebook goes a period at a time; a quarter is three months", %{db: db} do
    {:ok, db, id} = Core.add_datebook_view(db, "Plan", %Datebook{period: :quarter})
    view = Database.view(db, id)
    place = Core.browse_start(db, view, nil, @now)

    later = Core.browse_move(view, place, :later)
    assert later.date == Date.shift(place.date, month: 3)
    assert {:set_datebook, ^id, %Datebook{}} = Core.browse_keep(db, view, later, @now)
    assert Core.browse_keep(db, view, place, @now) == nil
  end

  test "nothing to browse without a date filter or a datebook", %{db: db, view: view} do
    assert Core.browse_start(db, view, nil, @now) == nil
  end
end
