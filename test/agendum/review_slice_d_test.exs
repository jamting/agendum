# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.ReviewSliceDTest do
  @moduledoc """
  The findings of the local review of group d, dates and views in the core
  (docs/CODE_REVIEW_SLICES.md § The rest; 2026-10-30), each as the case
  that showed it.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.{Command, DateParser, NumberFormat, Recurrence}

  @now ~N[2026-10-30 12:00:00]
  @today ~D[2026-10-30]

  # runs `fun` with a time budget: a hang fails the test instead of the run
  defp within(fun, ms \\ 2_000) do
    task = Task.async(fun)
    assert {:ok, result} = Task.yield(task, ms) || Task.shutdown(task, :brutal_kill)
    result
  end

  # 1. a repeat of 0 is no repeat, and a stored one does not hang the views
  test "every 0 days is not a repeat, and a stored every 0 counts as every 1" do
    assert DateParser.parse_recurring("every 0 days", @now) == :error

    rule = %Recurrence{every: 0, unit: :day}
    assert within(fn -> Recurrence.first(rule, @today, ~D[2026-11-02]) end) == ~D[2026-11-02]

    assert within(fn -> Recurrence.occurrences(rule, @today, ~D[2026-10-01], ~D[2026-11-01]) end) ==
             [@today, ~D[2026-10-31], ~D[2026-11-01]]
  end

  # 2. a word the regex matches but the language does not list is no date
  test "a long s in a weekday is text, not a crash" do
    assert within(fn -> DateParser.extract("Meet next Tueſday", @today) end) == :none
    assert within(fn -> DateParser.extract("in 3 dayſ", @today) end) == :none
  end

  # 3. an added item is added, not also changed
  test "an item added with numbers and suggestions is not also changed" do
    db = Core.new_file()
    {after_, id} = Core.add_item(db, "x", @today)
    after_ = %{after_ | numbers: Map.put(after_.numbers, {id, db.main_id}, 1)}
    after_ = %{after_ | suggestions: Map.put(after_.suggestions, id, %{})}

    changes = Command.Changes.between(db, after_)
    assert changes.items.added == [id]
    assert changes.items.changed == []
  end

  # 4. a file can ask for up to 31 decimals; a float holds 15
  test "more than 15 decimals shows 15, not a crash" do
    assert NumberFormat.format(1.5, %NumberFormat{decimals: 31}) =~ ~r/^1\.50{14}$/
  end

  # 5. working days counted by whole weeks: a huge count does not freeze
  test "a huge number of working days is worked out at once" do
    assert {:ok, %Date{}, _} =
             within(fn -> DateParser.extract("in 50000000 working days", @today) end)
  end

  test "working days by whole weeks give the same date as day by day" do
    # 2026-10-30 is a Friday; Monday to Friday by default
    for {n, date} <- [
          {1, ~D[2026-11-02]},
          {5, ~D[2026-11-06]},
          {15, ~D[2026-11-20]},
          {16, ~D[2026-11-23]},
          {23, ~D[2026-12-02]}
        ] do
      assert {:ok, ^date, _} = DateParser.extract("in #{n} working days", @today)
    end
  end

  # 6. the width is counted in characters, not bytes
  test "a two-byte currency symbol fits the same width as $" do
    assert NumberFormat.format(12.5, %NumberFormat{symbol: "£"}, width: 6) == "£12.50"
    assert NumberFormat.format(12.5, %NumberFormat{symbol: "$"}, width: 6) == "$12.50"
  end
end
