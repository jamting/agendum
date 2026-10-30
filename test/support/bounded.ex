# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Bounded do
  @moduledoc """
  Runs a function with a time budget, for the tests that feed parsers
  random and hostile input (the parser property tests, the hostile
  files): the answer, or what went wrong, never a test that hangs.

  The function runs in a process of its own, so a loop is killed when the
  budget runs out and an exception comes back as a value, not as a crash
  of the test.
  """

  @type outcome ::
          {:value, term} | {:raised, Exception.t(), list} | {:thrown, atom, term} | :timeout

  @doc "Runs `fun` for at most `ms` milliseconds."
  @spec run((-> term), pos_integer) :: outcome
  def run(fun, ms) do
    parent = self()
    # A reference is a value unique in the whole system: the reply is
    # matched on it, so no other message can be taken for the answer.
    ref = make_ref()

    # spawn_monitor starts the process and watches it in one step; unlike
    # spawn_link, its death does not take the test down with it.
    {pid, monitor} =
      spawn_monitor(fn ->
        outcome =
          try do
            {:value, fun.()}
          rescue
            # __STACKTRACE__ is only readable inside rescue and catch
            error -> {:raised, error, __STACKTRACE__}
          catch
            kind, reason -> {:thrown, kind, reason}
          end

        send(parent, {ref, outcome})
      end)

    receive do
      # ^ref pins the variable: the message must hold this very reference
      {^ref, outcome} ->
        Process.demonitor(monitor, [:flush])
        outcome
    after
      ms ->
        Process.exit(pid, :kill)
        # :flush drops the :DOWN message the kill sends, if it came already
        Process.demonitor(monitor, [:flush])
        :timeout
    end
  end

  @doc """
  The value of `fun`, or a failure that names the input: an exception, a
  throw or running past the budget.
  """
  @spec value!((-> term), term, pos_integer) :: term
  def value!(fun, input, ms \\ 2_000) do
    # a plain raise fails the test with its message, as flunk/1 would;
    # ExUnit is not among the modules Dialyzer knows, so it is not called
    case run(fun, ms) do
      {:value, value} ->
        value

      {:raised, error, stack} ->
        raise(
          "raised on #{inspect(input, limit: 200, printable_limit: 400)}:\n" <>
            Exception.format(:error, error, stack)
        )

      {:thrown, kind, reason} ->
        raise("#{kind} #{inspect(reason)} on #{inspect(input, limit: 200)}")

      :timeout ->
        raise("no answer within #{ms} ms on #{inspect(input, limit: 200, printable_limit: 400)}")
    end
  end
end
