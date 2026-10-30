# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TestLog do
  @moduledoc """
  An ExUnit formatter that keeps every test run's seed and failures in
  `tmp/check/`, one dated file a run, the last 30 kept, beside the usual
  output on the screen (`test/test_helper.exs`). A failure that does not
  come back on the next run can still be repeated with its seed
  (`mix test --seed N`): on 2026-10-26 a fuzz failure during v0.68.1 was
  lost, as plain `mix test` and `mix check` kept nothing. The same pattern
  as `mix agendum.fuzz`'s `tmp/fuzz/`.

  A formatter is a process ExUnit sends its events to (`GenServer.cast/2`):
  the suite starting (with the seed), each test and module finishing, and
  the suite finishing. This one only collects the failures and writes the
  file at the end.
  """
  use GenServer

  @dir "tmp/check"
  @keep 30

  @impl GenServer
  def init(_opts), do: {:ok, %{seed: nil, tests: 0, failures: [], started: nil}}

  @impl GenServer
  def handle_cast({:suite_started, opts}, state),
    do: {:noreply, %{state | seed: opts[:seed], started: NaiveDateTime.local_now()}}

  # a failed test: its failure text as ExUnit prints it, without colours
  # (the last argument formats each part; here it keeps the text as it is)
  def handle_cast({:test_finished, %ExUnit.Test{state: {:failed, failures}} = test}, state) do
    n = length(state.failures) + 1
    text = ExUnit.Formatter.format_test_failure(test, failures, n, 100, fn _, msg -> msg end)
    {:noreply, %{state | tests: state.tests + 1, failures: [text | state.failures]}}
  end

  def handle_cast({:test_finished, _test}, state),
    do: {:noreply, %{state | tests: state.tests + 1}}

  # setup_all failed: the module's tests did not run
  def handle_cast(
        {:module_finished, %ExUnit.TestModule{state: {:failed, failures}} = module},
        state
      ) do
    n = length(state.failures) + 1

    text =
      ExUnit.Formatter.format_test_all_failure(module, failures, n, 100, fn _, msg -> msg end)

    {:noreply, %{state | failures: [text | state.failures]}}
  end

  def handle_cast({:suite_finished, _times}, state) do
    write(state)
    {:noreply, state}
  end

  def handle_cast(_event, state), do: {:noreply, state}

  # the log never stops a run: a file that cannot be written is left off
  defp write(state) do
    File.mkdir_p!(@dir)
    Enum.each(old_logs(File.ls!(@dir)), &File.rm(Path.join(@dir, &1)))
    name = log_name(state.started || NaiveDateTime.local_now(), state.failures != [])
    File.write!(Path.join(@dir, name), text(state))
  rescue
    File.Error -> :ok
  end

  @doc "A run's log file name; names sort by time, a failed run's say so."
  @spec log_name(NaiveDateTime.t(), boolean) :: String.t()
  def log_name(time, failed?) do
    stamp = time |> NaiveDateTime.truncate(:second) |> NaiveDateTime.to_iso8601()
    "test-" <> String.replace(stamp, ":", "-") <> if(failed?, do: "-failed", else: "") <> ".log"
  end

  @doc "The logs among `names` to delete before a new run: all but the newest #{@keep - 1}."
  @spec old_logs([String.t()]) :: [String.t()]
  def old_logs(names) do
    names |> Enum.filter(&(&1 =~ ~r/^test-.*\.log$/)) |> Enum.sort() |> Enum.drop(-(@keep - 1))
  end

  @doc "A run's log: the seed and how to repeat it first, then the failures in order."
  @spec text(map) :: String.t()
  def text(state) do
    head = """
    seed: #{state.seed}
    repeat: mix test --seed #{state.seed}
    tests: #{state.tests}, failures: #{length(state.failures)}
    """

    # the failures were collected newest first
    Enum.join([head | Enum.reverse(state.failures)], "\n")
  end
end
