# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TestLogTest do
  @moduledoc "The test runs' logs in tmp/check/ (Agendum.TestLog), and `mix agendum.hooks`."
  use ExUnit.Case, async: true

  alias Agendum.TestLog
  alias Mix.Tasks.Agendum.Hooks

  test "log names sort by time, and a failed run's say so" do
    assert TestLog.log_name(~N[2026-10-26 23:05:09.123], false) == "test-2026-10-26T23-05-09.log"

    assert TestLog.log_name(~N[2026-10-26 23:05:09], true) ==
             "test-2026-10-26T23-05-09-failed.log"
  end

  test "all but the newest 29 go, so the new run makes 30" do
    names =
      for h <- 1..32 do
        TestLog.log_name(NaiveDateTime.add(~N[2026-10-01 00:00:00], h, :hour), rem(h, 2) == 0)
      end

    assert TestLog.old_logs(Enum.shuffle(["fuzz-x.log" | names])) == Enum.take(names, 3)
  end

  test "the log starts with the seed and how to repeat it, then the failures in order" do
    text = TestLog.text(%{seed: 5196, tests: 3, failures: ["  2) second\n", "  1) first\n"]})
    assert text =~ ~r/\Aseed: 5196\nrepeat: mix test --seed 5196\ntests: 3, failures: 2\n/
    assert :binary.match(text, "1) first") < :binary.match(text, "2) second")
  end

  test "the hooks warning: only in a checkout, outside CI, when no pre-push hook is found" do
    assert Hooks.warning(".githooks", true, true, nil) == nil
    assert Hooks.warning("/here/agendum/.githooks", true, true, nil) == nil

    assert Hooks.warning("/old/place/.githooks", false, true, nil) =~
             "/old/place/.githooks, which has no pre-push hook"

    assert Hooks.warning("", false, true, nil) =~ "not set"
    assert Hooks.warning("/old", false, true, "true") == nil
    assert Hooks.warning("/old", false, false, nil) == nil
    assert Hooks.warning(nil, false, true, nil) == nil
  end
end
