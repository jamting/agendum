defmodule Agenda.TUI.FuzzTest do
  @moduledoc "Random key sequences must never crash the UI, and every frame must fill the screen."
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Agenda.TUI.{Draw, Render, Update}
  import Agenda.TUIHelpers, only: [start: 2]

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
    :tick
  ]

  defp key do
    one_of([
      member_of(@keys),
      map(integer(1..10), &{:f, &1}),
      map(member_of(~w(a b H h y n v c s m x 1 / ! å) ++ [" "]), &{:char, &1})
    ])
  end

  property "the UI survives any key sequence" do
    check all(
            keys <- list_of(key(), max_length: 60),
            width <- integer(40..120),
            height <- integer(10..40),
            max_runs: 300
          ) do
      state = start(Agenda.Sample.build(~D[2026-10-08]), width: width, height: height)

      Enum.reduce(keys, state, fn key, state ->
        # :tick advances the clock ten minutes, as the shell's loop would
        {state, _effects} =
          if key == :tick,
            do: Update.tick(state, NaiveDateTime.add(state.now, 600)),
            else: Update.handle(state, key)

        screen = Render.render(state)

        assert length(screen) == height, "screen has #{length(screen)} lines, expected #{height}"

        for line <- screen,
            do: assert(Draw.width(line) == width, "line width #{Draw.width(line)} != #{width}")

        state
      end)
    end
  end
end
