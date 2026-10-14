defmodule Agendum.TUI.Boxes.InputFormatBox do
  @moduledoc """
  The Input Format box (Global date settings ▸ Input format; User's Guide 7-17,
  SPEC R41b): how this person types dates and times: Number order, Input
  date separator and Input clock, each "Language (…)" until set. These
  are the person's, not the file's (ADR 0008): a change applies at once,
  is saved to their preferences file (`{:save_preferences, path, prefs}`)
  and is not part of undo.

  The arrows choose a setting (`Agendum.TUI.Boxes.BoxNav`); SPACE shows the next choice.
  ENTER closes the box; ESC closes it and cancels its changes
  (`Agendum.TUI.Boxes.BoxCancel`). Drawn from `@layout`
  (`Agendum.TUI.Boxes.Template`). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, indicator: "PROPS", cancels: true

  import Agendum.TUI.Boxes.BoxNav, only: [is_move: 1]
  alias Agendum.TUI.Boxes.{Box, BoxNav, Template}

  alias Agendum.Core.InputFormat
  alias Agendum.TUI.State

  @layout """
   Number order         : [number_order                    ]
   Input date separator : [separator                       ]
   Input clock          : [clock                           ]

   Saved in your preferences, not in this file.
  """

  @rows Template.fields(@layout)
  @grid Template.grid(@layout, @rows)

  @help %{
    number_order:
      "Choose the order in which you enter day, month, and year, so Agendum can read " <>
        "dates such as 3/2. SPACE for the next.",
    separator: "The character you type between the numbers of a date. SPACE for the next choice.",
    clock: "Choose whether you type times on a 12-hour or a 24-hour clock. SPACE switches."
  }

  def open(state), do: State.push(state, %{type: :input_format, cursor: 0})

  @impl Box
  def handle(state, mode, key) do
    row = Enum.at(@rows, mode.cursor)

    case key do
      k when k in [:esc, :enter] -> State.pop(state)
      k when is_move(k) -> BoxNav.move(state, mode, @grid, k)
      {:char, " "} -> change(state, row, 1)
      _ -> state
    end
  end

  defp change(state, row, step) do
    input = InputFormat.cycle(state.input, row, step)
    value = Map.fetch!(input, row)

    State.change_preference(
      state,
      &%{&1 | input: input},
      &%{&1 | input: Map.put(&1.input, row, value)}
    )
  end

  @impl Box
  def title(_state, _mode), do: "Input format (yours, for every file)"

  @impl Box
  def content(state, mode, inner, _max_rows) do
    values = Map.new(@rows, &{&1, InputFormat.label(state.input, &1, state.languages)})

    Template.render(@layout, values, selected: field(state, mode)) ++
      [Box.hint(keys(state, mode), inner)]
  end

  @impl Box
  def keys(_state, _mode), do: Box.settings_keys()

  @impl Box
  def help, do: @help

  @impl Box
  def field(_state, mode), do: Enum.at(@rows, mode.cursor)
end
