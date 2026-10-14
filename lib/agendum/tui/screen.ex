defmodule Agendum.TUI.Screen do
  @moduledoc """
  Converts rendered screens to terminal output. Pure: `frame/4` compares
  the previous and next screen and emits ANSI output only for changed
  lines, which keeps redraws flicker-free.
  """

  alias Agendum.TUI.Theme

  @spec frame(
          [Agendum.TUI.Draw.line()] | nil,
          [Agendum.TUI.Draw.line()],
          Theme.name(),
          Theme.depth()
        ) :: iodata
  def frame(previous, next, theme \\ :classic, depth \\ :ansi16) do
    previous = previous || []

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
