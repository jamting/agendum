defmodule Agenda.TUI.Screen do
  @moduledoc """
  Converts rendered screens to terminal output. Pure: `frame/2` compares
  the previous and next screen and emits ANSI output only for changed
  lines, which keeps redraws flicker-free.
  """

  alias Agenda.TUI.Theme

  @spec frame([Agenda.TUI.Draw.line()] | nil, [Agenda.TUI.Draw.line()]) :: iodata
  def frame(previous, next) do
    previous = previous || []

    next
    |> Enum.with_index()
    |> Enum.reject(fn {line, i} -> Enum.at(previous, i) == line end)
    |> Enum.map(fn {line, i} -> ["\e[#{i + 1};1H", encode(line)] end)
    |> case do
      [] -> []
      changes -> [changes, "\e[0m"]
    end
  end

  defp encode(line) do
    Enum.map(line, fn {style, text} -> [Theme.sgr(style), text] end)
  end
end
