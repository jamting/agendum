defmodule Agendum.TUI.FuzzTest do
  @moduledoc "Random key sequences must never crash the UI, and every frame must fill the screen."
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Agendum.TUI.{Draw, Render, Update}
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
    :tick
  ]

  defp key do
    one_of([
      member_of(@keys),
      map(integer(1..10), &{:f, &1}),
      map(member_of(~w(a b H h y n v c s m x 1 / ! å) ++ [" "]), &{:char, &1})
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

  property "the UI survives any key sequence" do
    check all(
            keys <- list_of(key(), max_length: 60),
            width <- integer(40..120),
            height <- integer(10..40),
            numeric <- boolean(),
            datebook <- member_of([nil, nil, :day, :week, :month, :quarter]),
            filtered <- boolean(),
            max_runs: 300
          ) do
      db =
        numeric |> sample() |> with_filter(filtered) |> with_datebook(datebook) |> with_macros()

      state = start(db, width: width, height: height)

      Enum.reduce(keys, state, fn key, state ->
        # :tick advances the clock ten minutes, as the shell's loop would;
        # a macro run's keys are played next, as the shell plays them
        state =
          if key == :tick,
            do: state |> Update.tick(NaiveDateTime.add(state.now, 600)) |> elem(0),
            else: handle(state, [key])

        assert state.macro.playing == 0

        screen = Render.render(state)

        assert length(screen) == height, "screen has #{length(screen)} lines, expected #{height}"

        for line <- screen,
            do: assert(Draw.width(line) == width, "line width #{Draw.width(line)} != #{width}")

        state
      end)
    end
  end
end
