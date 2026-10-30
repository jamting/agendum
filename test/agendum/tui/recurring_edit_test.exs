# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.RecurringEditTest do
  @moduledoc """
  Editing a recurring item's When date (R14a; checked in Agenda 2.0,
  2026-10-23): ALT-F2 and F2 in the When column offer its rule with the
  base date, `every Monday (starting 2026-10-12)`, as Agenda offers
  `every Mon (strtng 10/12/2026)`, so ENTER keeps the rule and an edit
  changes rule and base date together.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Core
  alias Agendum.Core.{Database, Recurrence}
  alias Agendum.Core.DateLanguage.Swedish

  # Thursday 8 October: "every Monday" starts on the 12th
  @today ~D[2026-10-08]

  defp state(opts \\ []) do
    # a new file's view has a When column
    db = Core.new_file()
    [view] = Database.views(db)
    section = hd(view.sections).category_id
    {db, _} = Core.add_item(db, "Gym every Monday", @today, section: section)
    {db, _} = Core.add_item(db, "Post the letter on 2026-10-20", @today, section: section)
    # the cursor on the first item
    db |> start([today: @today] ++ opts) |> press(:down)
  end

  defp gym(state), do: Enum.find(Database.items(state.db), &(&1.text == "Gym every Monday"))

  test "ALT-F2 offers the rule with its base date" do
    assert state() |> press({:alt_f, 2}) |> screen() =~ "every Monday (starting 2026-10-12)"
  end

  test "ENTER on it keeps the rule and the base date" do
    state = state() |> press([{:alt_f, 2}, :enter])
    assert gym(state).recurrence == %Recurrence{unit: :week, weekday: 1}
    assert gym(state).when == ~D[2026-10-12]
  end

  test "an edited phrase changes the rule and the base date" do
    state =
      state() |> press([{:alt_f, 2}, {:ctrl, "u"}, "every Wed (starting 2026-11-04)", :enter])

    assert gym(state).recurrence == %Recurrence{unit: :week, weekday: 3}
    assert gym(state).when == ~D[2026-11-04]
  end

  test "F2 in the When column offers it too" do
    state = state() |> press([:right, {:f, 2}])
    # the column is narrower than the phrase: the line being edited has it
    assert state.edit.line.text == "every Monday (starting 2026-10-12)"
    state = press(state, :enter)
    assert gym(state).recurrence == %Recurrence{unit: :week, weekday: 1}
  end

  test "in the reader's language" do
    text = [languages: [Swedish]] |> state() |> press({:alt_f, 2}) |> screen()
    assert text =~ "varje måndag (från 2026-10-12)"
  end

  test "a date that does not recur is offered as a date, as before" do
    assert state() |> press([:down, {:alt_f, 2}]) |> screen() =~ "2026-10-20"
  end
end
