# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.WordingTest do
  @moduledoc "Small things the manual's screens showed: counts in messages, and the title bar."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.TUI.{Terminal.Draw, State}

  setup do
    %{state: start(Agendum.Sample.build(~D[2026-10-08]))}
  end

  test "counts are singular for one" do
    assert Draw.count(1, "item") == "1 item"
    assert Draw.count(2, "item") == "2 items"
    assert Draw.count(0, "item") == "0 items"
    assert Draw.count(1, "category", "categories") == "1 category"
    assert Draw.count(3, "category", "categories") == "3 categories"
  end

  test "depending on one marked item says so in the singular", %{state: state} do
    # mark the first item, then ALT-O on the second
    state = press(state, [:down, {:f, 7}, :down, {:alt, "o"}])
    assert screen(state) =~ "Make this item depend on the 1 marked item?"
    assert screen(press(state, "y")) =~ "Depends on 1 item"
    refute screen(press(state, "y")) =~ "1 items"
  end

  test "one marked item done", %{state: state} do
    state = press(state, [:down, {:f, 7}, :down, {:f, 4}, "m"])
    assert screen(state) =~ "1 marked item done"
  end

  # Agenda's mode words only (checked in Agenda 2.0, 2026-10-25; the owner's
  # choice): none when ready, none of ours in boxes, menus and managers;
  # EDIT while typing; the category manager has no time either
  test "the top right shows Agenda's mode words only", %{state: state} do
    top = fn state -> state |> screen() |> String.split("\n") |> hd() end
    assert top.(state) =~ ~r/\s{2,}10\/08\/26   9:00am *$/

    for keys <- [[{:f, 10}], [{:f, 10}, "v", "v", "p"], [{:f, 8}], [{:alt_f, 6}]] do
      refute top.(press(state, keys)) =~ ~r/READY|PROPS|MENU|VW MGR|SEARCH|CHOICES/
    end

    # typing an item: the date, then EDIT in the time's place, as Agenda's
    assert top.(press(state, [:down, {:f, 2}])) =~ ~r/10\/08\/26 EDIT *$/

    catmgr = top.(press(state, {:f, 9}))
    refute catmgr =~ "CAT MGR"
    refute catmgr =~ "10/08/26"
  end

  # Agenda's marks at the right of the View line (checked in Agenda 2.0,
  # 2026-10-25): ☼ on a date value or a date column's head; WRKG at the
  # top right while a calendar or feed is read in the background
  test "☼ on a date column; WRKG while something is fetched", %{state: state} do
    second = fn state -> state |> screen() |> String.split("\n") |> Enum.at(1) end
    on_date = press(state, [:down, :right])
    assert second.(on_date) =~ ~r/☼ *$/
    refute second.(state) =~ "☼"

    top = fn state -> state |> screen() |> String.split("\n") |> hd() end
    refute top.(state) =~ "WRKG"

    assert top.(%{state | fetching: %{1 => {:auto, "https://owl.example/rss"}}}) =~
             ~r/WRKG +10\/08\/26   9:00am/
  end

  test "a long filter never runs the control panel's parts together", %{state: state} do
    view = hd(state.db.view_order)
    when_id = state.db.special.when

    db =
      Agendum.Core.Database.update_view(
        state.db,
        view,
        &%{&1 | filter: [{when_id, {:range, "today", "end of next month", :inside}}]}
      )

    state = %{state | db: db, path: "/home/rabbit/rabbit.agenda", dirty: true, width: 80}
    [file, view | _] = String.split(screen(state), "\n")
    assert file =~ ~r/File: \/home\/rabbit\/rabbit\.agenda \*\s{2,}10\/08\/26   9:00am/
    assert view =~ "View: Activities [When 10/08/26..11/30/26]"

    assert state |> Agendum.TUI.Render.render() |> hd() |> Agendum.TUI.Terminal.Draw.width() ==
             state.width

    # narrower, the path loses its beginning and the filter its end
    [file, view | _] = String.split(screen(%{state | width: 40}), "\n")
    assert file =~ ~r/File: …\S+ \*\s{2,}10\/08\/26/
    assert view =~ ~r/View: Activities \[When 10\/08\/26\.\.11\/…$/
    assert file =~ ~r/10\/08\/26   9:00am$/
    assert %{} = State.view(state)
  end
end
