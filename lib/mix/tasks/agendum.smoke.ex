# SPDX-License-Identifier: AGPL-3.0-only
defmodule Mix.Tasks.Agendum.Smoke do
  @shortdoc "The real-terminal scenarios (tools/smoke/scenarios.py)"
  @moduledoc """
  Runs the real-terminal scenarios: the program in a pseudo-terminal,
  sandboxed from the person's preferences, keys sent and the screen
  checked (`tools/smoke/scenarios.py`). They reach what the unit tests
  cannot: the key decoder, raw mode, UTF-8 cut between reads.

      mix agendum.smoke             # every scenario, about a minute
      mix agendum.smoke cjk f9      # those whose name holds a word given

  Each scenario starts the program with `mix run`, so never beside
  `mix check` or another compile. Fails when a scenario fails (each is
  tried twice first, as timing can make one flaky). Needs `python3`.
  """
  use Mix.Task

  @impl Mix.Task
  def run(args) do
    # `into: IO.stream()` shows each scenario's line as it finishes
    {_, status} =
      System.cmd("python3", ["tools/smoke/scenarios.py" | args],
        stderr_to_stdout: true,
        into: IO.stream()
      )

    if status != 0, do: Mix.raise("A real-terminal scenario failed (above)")
  end
end
