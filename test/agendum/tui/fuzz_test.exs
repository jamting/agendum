defmodule Agendum.TUI.Fuzz do
  @moduledoc """
  Random key sequences must never crash the UI, and every frame must fill the
  screen. The runs are shared among `@parts` test modules (defined at the end
  of this file) so that ExUnit runs them side by side (`async: true` runs
  modules in parallel, never the tests inside one module); one module alone
  set the length of the whole suite.
  """
  use ExUnitProperties
  import ExUnit.Assertions

  alias Agendum.Core.Invariants
  alias Agendum.TUI.{History, Terminal.Draw, Render, Update}
  import Agendum.TUIHelpers, only: [start: 2]

  @keys [
    :up,
    :down,
    :left,
    :right,
    :home,
    :end,
    :pgup,
    :pgdn,
    :enter,
    :esc,
    :tab,
    :shift_tab,
    :insert,
    :delete,
    :backspace,
    :ctrl_pgup,
    :ctrl_pgdn,
    :ctrl_home,
    :ctrl_end,
    {:alt, :up},
    {:alt, :down},
    {:alt, "d"},
    {:alt, "u"},
    {:alt, "r"},
    {:alt, "l"},
    {:alt_f, 4},
    {:alt_f, 10},
    {:ctrl, "u"},
    {:ctrl, "d"},
    {:ctrl, "z"},
    {:ctrl, "z"},
    {:ctrl, "y"},
    {:ctrl, "n"},
    {:ctrl, "e"},
    {:ctrl, "k"},
    {:ctrl, "a"},
    {:ctrl, "w"},
    {:alt, "b"},
    {:alt, :backspace},
    {:alt, "n"},
    {:alt, "p"},
    {:alt, "-"},
    {:alt, "="},
    {:alt_f, 7},
    {:alt, "j"},
    {:alt, "m"},
    {:alt_f, 5},
    {:alt_f, 6},
    {:alt_f, 8},
    {:alt, "a"},
    {:alt, "s"},
    {:alt, "k"},
    {:alt, "v"},
    {:alt, "w"},
    {:alt, "g"},
    {:alt, "i"},
    {:alt, "t"},
    {:alt, "q"},
    {:alt, "o"},
    {:alt, "x"},
    {:alt, "e"},
    {:alt_f, 3},
    {:alt_f, 3},
    {:alt, "z"},
    # a count (R65)
    {:alt, "1"},
    {:alt, "3"},
    :tick
  ]

  defp key do
    one_of([
      member_of(@keys),
      map(integer(1..10), &{:f, &1}),
      map(member_of(~w(a b H h y n v c d s m x 1 / ! å) ++ [" "]), &{:char, &1})
    ])
  end

  # The patent's sample, optionally with a numeric Amount column (R29) whose
  # first item has a number.
  defp sample(false), do: Agendum.Sample.build(~D[2026-10-08])

  defp sample(true) do
    db = sample(false)
    {:ok, db, amount} = Agendum.Core.add_category(db, db.main_id, "Amount")
    {:ok, db} = Agendum.Core.make_numeric(db, amount)
    db = Agendum.Core.add_column(db, hd(db.view_order), amount, {0, 0})
    {:ok, db} = Agendum.Core.set_number(db, hd(db.item_order), amount, 12.5)
    db
  end

  # With a date filter on the view, to browse (R48).
  defp with_filter(db, false), do: db

  defp with_filter(db, true) do
    range = {:assigned, "today", "end of this week", :inside}

    {:ok, db} =
      Agendum.Core.set_range_filter(
        db,
        hd(db.view_order),
        :view,
        db.special.when,
        range,
        ~D[2026-10-08]
      )

    db
  end

  # With a datebook view of that period (R47), shown first.
  defp with_datebook(db, nil), do: db

  defp with_datebook(db, period) do
    datebook = %Agendum.Core.Datebook{period: period}
    {:ok, db, view} = Agendum.Core.add_datebook_view(db, "Datebook", datebook)
    Agendum.Core.move_view(db, view, 0)
  end

  # A key that changed the file recorded undo steps, and undoing them gives
  # the file back as it was (R30): one user action, one database change.
  # Undo takes a step off the stack (redo puts one on, which undo takes
  # back like any other); a new file starts without history; a full
  # history (100 steps) has dropped its oldest.
  defp assert_undoable(before, state, key) do
    steps = length(state.history.undo) - length(before.history.undo)
    new_file = state.saved.db != before.saved.db
    full = length(state.history.undo) >= 100

    if state.db != before.db and steps >= 0 and not new_file and not full do
      assert steps >= 1, "#{inspect(key)} changed the file but recorded no undo step"
      undone = Enum.reduce(1..steps, state, fn _, s -> History.undo(s) end)
      assert undone.db == before.db, "undoing #{inspect(key)} did not give the file back"
    end
  end

  defp handle(state, []), do: state

  defp handle(state, [key | keys]) do
    {state, effects} = Update.handle(state, key)
    played = for {:play, played} <- effects, k <- played ++ [:macro_done], do: k
    handle(state, played ++ keys)
  end

  # With macros (R50): one on F4 that types and calls the other, which runs
  # the manager's first macro from inside itself.
  defp with_macros(db) do
    {:ok, db, water} = Agendum.Core.add_macro(db, "Water")
    db = Agendum.Core.set_macro_keys(db, water, "Water the lettuces{ENTER}{DOWN}{CALL Again}")
    db = Agendum.Core.attach_macro(db, water, "{F4}")
    {:ok, db, again} = Agendum.Core.add_macro(db, "Again")
    Agendum.Core.set_macro_keys(db, again, "{AltF3}{ENTER}x{AltZ}")
  end

  # 300 runs in the suite; FUZZ_RUNS sets more for a longer search after a
  # large TUI change: FUZZ_RUNS=3000 mix test test/agendum/tui/fuzz_test.exs
  @runs String.to_integer(System.get_env("FUZZ_RUNS", "300"))
  @parts 4

  @doc "How many test modules share the runs."
  def parts, do: @parts

  @doc "ExUnit's timeout for one part: its 60 seconds for every 300 runs."
  def timeout, do: 60_000 * max(1, div(@runs, 300))

  @doc """
  Runs part `part` (1..parts) of the property. Each part starts from its own
  seed, ExUnit's plus the part, so the parts try different sequences and
  `mix test --seed N` still repeats a failure.
  """
  def run(part) do
    check all(
            keys <- list_of(key(), max_length: 60),
            width <- integer(40..120),
            height <- integer(10..40),
            numeric <- boolean(),
            datebook <- member_of([nil, nil, :day, :week, :month, :quarter]),
            filtered <- boolean(),
            max_runs: div(@runs + @parts - 1, @parts),
            initial_seed: ExUnit.configuration()[:seed] + part
          ) do
      db =
        numeric |> sample() |> with_filter(filtered) |> with_datebook(datebook) |> with_macros()

      state = start(db, width: width, height: height)

      Enum.reduce(keys, state, fn key, state ->
        # :tick advances the clock ten minutes, as the shell's loop would;
        # a macro run's keys are played next, as the shell plays them
        before = state

        state =
          if key == :tick,
            do: state |> Update.tick(NaiveDateTime.add(state.now, 600)) |> elem(0),
            else: handle(state, [key])

        assert state.macro.playing == 0

        # the file stays sound (docs/DATA_MODEL.md, "Invariants")
        assert Invariants.violations(state.db) == [], "after #{inspect(key)}"
        # every mode on the stack is its struct, none a bare map (Agendum.TUI.Modes)
        assert Enum.all?(state.modes, &is_struct/1), "a bare map mode after #{inspect(key)}"

        if key != :tick, do: assert_undoable(before, state, key)

        screen = Render.render(state)

        assert length(screen) == height, "screen has #{length(screen)} lines, expected #{height}"

        for line <- screen,
            do: assert(Draw.width(line) == width, "line width #{Draw.width(line)} != #{width}")

        state
      end)
    end
  end
end

# One test module per part; `for` at the top level defines them when the file
# is loaded, and a module body sees the variables around it, so `@part` keeps
# each one's number.
for part <- 1..Agendum.TUI.Fuzz.parts() do
  defmodule Module.concat(Agendum.TUI.FuzzTest, "Part#{part}") do
    @moduledoc "Part #{part} of the fuzz property (`Agendum.TUI.Fuzz`)."
    use ExUnit.Case, async: true
    @part part

    @tag timeout: Agendum.TUI.Fuzz.timeout()
    test "the UI survives any key sequence (part #{@part})" do
      Agendum.TUI.Fuzz.run(@part)
    end
  end
end
