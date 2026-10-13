defmodule Agenda.TUI.Render.Note do
  @moduledoc """
  The full-screen note editor (F5). Pure.
  """

  alias Agenda.TUI.{Draw, State}

  @doc "The note's lines, scrolled to the cursor, a search match highlighted."
  def lines(state, mode) do
    edit = mode.edit
    visible = State.body_height(state)
    top = max(edit.row - visible + 1, 0)

    lines =
      edit.lines
      |> Enum.with_index()
      |> Enum.map(fn {text, row} ->
        case Map.get(mode, :match) do
          {^row, col, len} ->
            {before, rest} = String.split_at(text, col)
            {found, after_} = String.split_at(rest, len)
            [{:normal, " " <> before}, {:edit_cursor, found}, {:normal, after_}]

          _ when row == edit.row ->
            [{:normal, " "}] ++ Draw.field(text, edit.col, :normal)

          _ ->
            [{:normal, " " <> text}]
        end
      end)
      |> Enum.drop(top)

    lines
  end
end
