# SPDX-License-Identifier: AGPL-3.0-only
defmodule Mix.Tasks.Agendum.Fuzz do
  @shortdoc "The long fuzz run, its output kept in a dated log file"
  @moduledoc """
  The long fuzz run (the TUI fuzz property with 3000 runs instead of the
  suite's 300), with its whole output kept in `tmp/fuzz/`, one dated file
  a run, the last 30 kept, so a failure can always be read and repeated
  afterwards (meeting 2026-10-26-1524, § 8; one failure on 2026-10-26 was lost
  with its seed):

      mix agendum.fuzz              # 3000 runs
      mix agendum.fuzz 10000        # more
      mix agendum.fuzz --seed 112   # repeat a run: the seed is the log's first line

  It runs `mix test test/agendum/tui/fuzz_test.exs` in the test
  environment, so never beside `mix check` or another compile (both use
  `_build/test`). Fails, naming the log, when the run fails.
  """
  use Mix.Task

  @dir "tmp/fuzz"
  @keep 30

  @impl Mix.Task
  def run(args) do
    {opts, rest} = OptionParser.parse!(args, strict: [seed: :integer])
    runs = List.first(rest, "3000")
    File.mkdir_p!(@dir)
    Enum.each(old_logs(File.ls!(@dir)), &File.rm(Path.join(@dir, &1)))

    log = Path.join(@dir, log_name(NaiveDateTime.local_now()))
    seed = if opts[:seed], do: ["--seed", Integer.to_string(opts[:seed])], else: []
    Mix.shell().info("Fuzzing (#{runs} runs); the output goes to #{log}")

    # `into: ""` collects the output as one string: the run takes about
    # half a minute, then it is written and its result shown
    {output, status} =
      System.cmd("mix", ["test", "test/agendum/tui/fuzz_test.exs" | seed],
        env: [{"MIX_ENV", "test"}, {"FUZZ_RUNS", runs}],
        stderr_to_stdout: true,
        into: ""
      )

    File.write!(log, output)
    Mix.shell().info(output |> String.split("\n") |> Enum.take(-4) |> Enum.join("\n"))

    if status != 0, do: Mix.raise("The fuzz run failed; read #{log}")
  end

  @doc "A run's log file name; names sort by time."
  @spec log_name(NaiveDateTime.t()) :: String.t()
  def log_name(time),
    do: "fuzz-" <> String.replace(NaiveDateTime.to_iso8601(time), ":", "-") <> ".log"

  @doc "The logs among `names` to delete before a new run: all but the newest #{@keep - 1}."
  @spec old_logs([String.t()]) :: [String.t()]
  def old_logs(names) do
    names |> Enum.filter(&(&1 =~ ~r/^fuzz-.*\.log$/)) |> Enum.sort() |> Enum.drop(-(@keep - 1))
  end
end
