# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.NumberItemsTest do
  @moduledoc """
  Number items on the screen (R79; checked in Agenda 2.0, 2026-10-23): the
  setting in View Properties on the row of Filter, and in a datebook's
  settings box; with Yes each item's number, left-aligned in four columns,
  comes between its marks and its text, which keeps its wrapped lines
  under it. File ▸ Print shows the numbers too, as Agenda printed them.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  import Agendum.Fixtures, only: [cat: 2]

  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.TUI.{History, State}

  @today ~D[2026-10-23]
  @long "Call Bob about the budget tomorrow, and ask about the meeting next week"

  setup do
    db = Core.new_file(view_name: "Tasks", section_name: "Tasks")
    [view] = Database.views(db)

    db =
      Enum.reduce([@long, "Write to the bank", "Throw this away"], db, fn text, db ->
        {db, _} = Core.add_item(db, text, @today, section: cat(db, "Tasks"))
        db
      end)

    %{state: start(db, today: @today, width: 80, height: 25), view: view.id}
  end

  defp props(state), do: press(state, [{:f, 10}, "v", "p"])
  defp number_on(state), do: state |> props() |> to_setting("Number items") |> press(" ")

  test "View Properties: Number items, No by default, on the row of Filter", %{state: state} do
    text = state |> props() |> screen()
    assert text =~ ~r/Number items: +No +Filter:/
  end

  test "SPACE switches it at once; one undo step", %{state: state, view: v} do
    state = number_on(state)
    assert state.db.views[v].number_items
    assert screen(state) =~ ~r/Number items: +Yes/
    refute History.undo(state).db.views[v].number_items
  end

  test "the view shows 1, 2, 3 before the item text, in four columns", %{state: state} do
    text = state |> number_on() |> press(:enter) |> screen()
    assert text =~ ~r/ 2   Write to the bank/
    assert text =~ ~r/ 3   Throw this away/
  end

  test "a wrapped line stays under the text, past the number", %{state: state} do
    lines = state |> number_on() |> press(:enter) |> screen() |> String.split("\n")
    first = Enum.find_index(lines, &(&1 =~ "1   Call Bob"))
    # counted in characters: the marks before it are several bytes each
    [before | _] = String.split(Enum.at(lines, first), "Call", parts: 2)
    column = String.length(before)
    next = Enum.at(lines, first + 1)
    assert String.slice(next, 0, column) |> String.trim() == ""
    assert String.at(next, column) != " "
  end

  test "off again: no numbers", %{state: state} do
    state = state |> number_on() |> press(" ") |> press(:enter)
    refute screen(state) =~ ~r/\b2   Write/
    assert screen(state) =~ "Write to the bank"
  end

  test "File ▸ Print shows the numbers", %{state: state} do
    state = state |> number_on() |> press(:enter)
    assert Agendum.TUI.Render.Export.text(state) =~ "  • 2 Write to the bank"
  end

  test "a datebook view's View Properties has Number items too", %{state: state} do
    datebook = %Core.Datebook{
      date_category: cat(state.db, "Entry"),
      section_category: cat(state.db, "Tasks")
    }

    {:ok, db, id} = Core.add_datebook_view(state.db, "Week", datebook)
    state = %{state | db: db} |> State.switch_view(id) |> props()
    assert %{type: :view_props} = State.mode(state)
    state = state |> to_setting("Number items") |> press(" ")
    assert state.db.views[id].number_items
    assert state |> press(:enter) |> screen() =~ ~r/ 2   Write to the bank/
  end
end
