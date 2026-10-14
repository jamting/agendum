defmodule Agenda.TUI.WordingTest do
  @moduledoc "Small things the manual's screens showed: counts in messages, and the title bar."
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.TUI.{Draw, State}

  setup do
    %{state: start(Agenda.Sample.build(~D[2026-10-08]))}
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

  test "a long filter never runs the control panel's parts together", %{state: state} do
    view = hd(state.db.view_order)
    when_id = state.db.special.when

    db =
      Agenda.Core.Database.update_view(
        state.db,
        view,
        &%{&1 | filter: [{when_id, {:range, "today", "end of next month", :inside}}]}
      )

    state = %{state | db: db, path: "/home/rabbit/rabbit.agenda", dirty: true, width: 80}
    [file, view | _] = String.split(screen(state), "\n")
    assert file =~ ~r/File: \/home\/rabbit\/rabbit\.agenda \*\s{2,}READY/
    assert view =~ "View: Activities [When 2026-10-08..2026-11-30]"
    assert state |> Agenda.TUI.Render.render() |> hd() |> Agenda.TUI.Draw.width() == state.width

    # narrower, the path loses its beginning and the filter its end
    [file, view | _] = String.split(screen(%{state | width: 40}), "\n")
    assert file =~ ~r/File: …\S+ \*\s{2,}READY/
    assert view =~ ~r/View: Activities \[When 2026-10-08\.\.2…$/
    assert file =~ ~r/2026-10-08 09:00$/
    assert %{} = State.view(state)
  end
end
