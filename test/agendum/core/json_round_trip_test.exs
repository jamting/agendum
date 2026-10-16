defmodule Agendum.Core.JSONRoundTripTest do
  @moduledoc """
  Whatever a person does to a file, writing it as JSON and reading it back
  gives the same file (R44): random key sequences on the sample file, as in
  `Agendum.TUI.Fuzz`, make the files.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Agendum.Core.JSONFile
  alias Agendum.TUI.Update
  import Agendum.TUIHelpers, only: [start: 2]

  @keys [:up, :down, :left, :right, :enter, :esc, :tab, :insert, :delete, :backspace] ++
          [{:alt, "d"}, {:alt, "r"}, {:alt, "m"}, {:alt, "o"}, {:alt, "a"}, {:alt, "x"}] ++
          [{:alt, "-"}, {:alt_f, 2}, {:alt_f, 4}, {:alt_f, 7}, {:alt_f, 10}, {:ctrl, "z"}] ++
          [{:ctrl, "y"}, {:ctrl, "u"}, :tick]

  defp key do
    one_of([
      member_of(@keys),
      map(integer(1..10), &{:f, &1}),
      map(
        member_of(~w(a b y n x 1 5 / m t ö) ++ [" ", "tomorrow ", "$9 ", "every friday "]),
        &{:char, &1}
      )
    ])
  end

  property "a file survives a round trip through JSON" do
    check all(keys <- list_of(key(), max_length: 80), max_runs: 60) do
      state = start(Agendum.Sample.build(~D[2026-10-08]), width: 100)

      db =
        Enum.reduce(keys, state, fn
          :tick, state -> elem(Update.tick(state, NaiveDateTime.add(state.now, 600)), 0)
          key, state -> elem(Update.handle(state, key), 0)
        end).db

      assert Agendum.Core.Invariants.violations(db) == []
      assert JSONFile.decode(JSONFile.encode(db)) == {:ok, db}
    end
  end
end
