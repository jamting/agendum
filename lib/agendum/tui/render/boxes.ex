defmodule Agendum.TUI.Render.Boxes do
  @moduledoc """
  The boxes drawn over the screen: their place, title and content; the
  boxes with a module of their own (`Agendum.TUI.Boxes.Box`) give theirs.
  Pure.
  """

  alias Agendum.TUI.{Boxes.Box, Terminal.Draw, State}

  # boxes with a module of their own (`Agendum.TUI.Boxes.Box`) draw themselves
  @boxes Box.registry()

  # A box opened from another box (`depth` 1, 2 …) sits a line lower and
  # two columns right of the box beneath (`beneath`, that box's left
  # column; nil for the first box, which is centred), so the one beneath
  # still shows, whatever their widths; the titles of the boxes beneath
  # are dimmed, the active box's is not.
  @doc "Draws the box of `mode` over `body`; also returns the column it starts at."
  def overlay(state, mode, depth, active?, body, beneath \\ nil) do
    inner = box_width(state, mode)
    top = 1 + depth
    max_rows = max(State.body_height(state) - 4 - depth, 3)
    content = box_content(state, mode, inner, max_rows)
    box = Draw.box(box_title(state, mode), content, inner, footer(mode, inner))
    box = if active?, do: box, else: Enum.map(box, &Draw.paint(&1, %{box_title: :box_title_dim}))
    wanted = if beneath, do: beneath + 2, else: div(state.width - inner - 2, 2)
    left = min(wanted, max(state.width - inner - 2, 0))

    body =
      body
      |> Draw.overlay(box, top, left)
      |> Draw.shadow(top, left, length(box), inner + 2)

    {body, left}
  end

  @doc """
  The highlighted value of the box on top, as shown: `Agendum.TUI.Boxes.BoxChoices`
  reads a setting's choices with it.
  """
  @spec selected_value(State.t()) :: String.t()
  def selected_value(state) do
    state
    |> selected_line()
    |> Enum.filter(&(elem(&1, 0) == :box_selected))
    |> Enum.map_join(&elem(&1, 1))
    |> String.trim()
  end

  @doc """
  The name of the highlighted setting: the words before its value on its
  line ("Date format" in " Date format : YYYYMMDD"), after anything to the
  left of it in a box of two columns.
  """
  @spec selected_name(State.t()) :: String.t()
  def selected_name(state) do
    before =
      state
      |> selected_line()
      |> Enum.take_while(&(elem(&1, 0) != :box_selected))
      |> Enum.map_join(&elem(&1, 1))

    # without its colon, the last piece after a gap of two spaces or more
    before
    |> String.trim_trailing()
    |> String.trim_trailing(":")
    |> String.split(~r/\s{2,}/, trim: true)
    |> List.last("")
    |> String.trim()
  end

  defp selected_line(state) do
    mode = State.mode(state)

    state
    |> box_content(mode, box_width(state, mode), State.body_height(state))
    |> Enum.find([], fn line -> Enum.any?(line, &(elem(&1, 0) == :box_selected)) end)
  end

  # Agenda's words in the bottom edge (screenshots 130, 138, 144): how to
  # finish the box. A short form when the long one does not fit.
  @done {"Press ENTER when done, ESC to cancel", "ENTER done · ESC cancel"}
  @accept {"Press ENTER to accept, ESC to cancel", "ENTER accept · ESC cancel"}
  @esc_done {"Press ESC when done", "ESC when done"}

  # boxes that only show something
  @return {"Press ENTER or ESC to return", "ENTER/ESC return"}

  defp footer(mode, inner) do
    {long, short} =
      cond do
        box = Box.module(mode) ->
          %{done: @done, accept: @accept, esc_done: @esc_done, return: @return, none: {"", ""}}[
            box.finish(mode)
          ]

        Agendum.TUI.Boxes.BoxCancel.cancels?(mode.type) ->
          @done

        true ->
          {"", ""}
      end

    if String.length(long) + 2 <= inner - 2, do: long, else: short
  end

  defp box_width(state, %{type: type} = mode) when is_map_key(@boxes, type),
    do: @boxes[type].width(state, mode)

  defp box_width(state, _mode), do: min(state.width - 8, 60)

  defp box_title(state, %{type: type} = mode) when is_map_key(@boxes, type),
    do: @boxes[type].title(state, mode)

  defp box_content(state, %{type: type} = mode, inner, max_rows) when is_map_key(@boxes, type),
    do: @boxes[type].content(state, mode, inner, max_rows)
end
