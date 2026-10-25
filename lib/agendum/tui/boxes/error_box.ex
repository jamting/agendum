defmodule Agendum.TUI.Boxes.ErrorBox do
  @moduledoc """
  Agenda's Error box: an error said in a box titled Error, with "Press any
  key to continue" in its bottom edge, and the error beep (checked in
  Agenda 2.0, 2026-10-26: a search that finds nothing). Any key closes it.
  Most of Agendum's errors are said on the control panel; this box is for
  those Agenda put in one. Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :any_key

  alias Agendum.TUI.Boxes.Box
  alias Agendum.TUI.{State, Terminal.Draw}

  @doc "Opens the box with `text`, and the error beep."
  def open(state, text) do
    state
    |> State.push(%Agendum.TUI.Modes.ErrorBox{text: text})
    |> State.effect({:sound, :error})
  end

  # any key closes it, as Agenda's "Press any key to continue"
  @impl Box
  def handle(state, _mode, _key), do: State.pop(state)

  # R65
  @impl Box
  def keymap(_mode), do: %{:enter => :close, :esc => :close}

  @impl Box
  def commands(_mode), do: [{:close, "Return", "Close the box"}]

  @impl Box
  def run(state, _mode, :close), do: State.pop(state)

  @impl Box
  def title(_state, _mode), do: "Error"

  # as wide as the text needs, as Agenda's
  @impl Box
  def width(state, mode), do: (String.length(mode.text) + 4) |> max(40) |> min(state.width - 8)

  @impl Box
  def content(_state, mode, inner, _max_rows) do
    lines = Draw.wrap(mode.text, inner - 2)
    [[]] ++ Enum.map(lines, &[{:box, " " <> &1}]) ++ [[]]
  end

  @impl Box
  def keys(_state, _mode), do: [{"any key", "Continue"}]

  @impl Box
  def help, do: nil
end
