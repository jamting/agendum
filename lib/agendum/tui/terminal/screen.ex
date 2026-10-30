# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Terminal.Screen do
  @moduledoc """
  Converts rendered screens to terminal output. Pure: `frame/4` compares
  the previous and next screen and emits ANSI output only for changed
  lines, which keeps redraws flicker-free.
  """

  alias Agendum.TUI.Terminal.Theme

  @spec frame(
          [Agendum.TUI.Terminal.Draw.line()] | nil,
          [Agendum.TUI.Terminal.Draw.line()],
          Theme.name(),
          Theme.depth()
        ) :: iodata
  def frame(previous, next, theme \\ :classic, depth \\ :ansi16) do
    # `||` gives its right side when the left is nil or false: no previous
    # screen (the first frame, or after a resize) means every line is new.
    previous = previous || []

    # The result is iodata: nested lists of strings that `IO.write/1` sends
    # as they are, without first copying them into one string. `"\e[row;1H"`
    # moves the terminal's cursor to a line, so only changed lines are sent.
    # (`Enum.at/2` walks the list from the start each time: fine for 25 to
    # 60 lines.)
    next
    |> Enum.with_index()
    |> Enum.reject(fn {line, i} -> Enum.at(previous, i) == line end)
    |> Enum.map(fn {line, i} -> ["\e[#{i + 1};1H", encode(line, theme, depth)] end)
    |> case do
      [] -> []
      changes -> [changes, "\e[0m"]
    end
  end

  defp encode(line, theme, depth) do
    Enum.map(line, fn {style, text} -> [Theme.sgr(style, theme, depth), text] end)
  end
end
