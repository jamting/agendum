defmodule Agendum.FuzzTaskTest do
  @moduledoc "`mix agendum.fuzz`: the long fuzz run's logs, named by time, the last 30 kept."
  use ExUnit.Case, async: true

  alias Mix.Tasks.Agendum.Fuzz

  test "log names sort by time" do
    assert Fuzz.log_name(~N[2026-10-26 16:05:09]) == "fuzz-2026-10-26T16-05-09.log"
  end

  test "all but the newest 29 go, so the new run makes 30" do
    names =
      for d <- 1..32, do: Fuzz.log_name(NaiveDateTime.add(~N[2026-10-01 00:00:00], d, :hour))

    assert Fuzz.old_logs(Enum.shuffle(["notes.txt" | names])) == Enum.take(names, 3)
    assert Fuzz.old_logs(Enum.take(names, 29)) == []
  end
end
