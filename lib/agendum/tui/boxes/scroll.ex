# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Boxes.Scroll do
  @moduledoc """
  A list box whose entries take several lines each (a feed, a calendar)
  scrolls by whole entries: the highlighted one is always shown, as many as
  fit in `room` lines, and a line above or below says how many are out of
  sight ("▲ 3 more above", "▼ 230 more below"). Pure.
  """

  @doc """
  The lines to show of `groups` (each entry's lines, in order) with the
  entry at `cursor` highlighted, in at most `room` lines.
  """
  @spec window([[term]], non_neg_integer, pos_integer, (String.t() -> term)) :: [term]
  def window(groups, cursor, room, line) do
    if Enum.sum(Enum.map(groups, &length/1)) <= room do
      Enum.concat(groups)
    else
      # one line each kept for what is above and below
      room = max(room - 2, 1)
      cursor = min(cursor, length(groups) - 1)
      top = top(groups, cursor, room)
      shown = shown(Enum.drop(groups, top), room)
      below = length(groups) - top - length(shown)

      above_line = if top > 0, do: [line.("▲ #{top} more above")], else: [line.("")]
      below_line = if below > 0, do: [line.("▼ #{below} more below")], else: []

      above_line ++ Enum.concat(shown) ++ below_line
    end
  end

  # the first entry shown: as far back from the cursor as still fits with it
  defp top(groups, cursor, room) do
    Enum.reduce_while(cursor..0//-1, {cursor, 0}, fn i, {top, used} ->
      used = used + length(Enum.at(groups, i))
      if used <= room, do: {:cont, {i, used}}, else: {:halt, {top, used}}
    end)
    |> elem(0)
  end

  # the entries from the top that fit
  defp shown(groups, room) do
    Enum.reduce_while(groups, {[], 0}, fn group, {acc, used} ->
      used = used + length(group)
      if used <= room or acc == [], do: {:cont, {[group | acc], used}}, else: {:halt, {acc, used}}
    end)
    |> elem(0)
    |> Enum.reverse()
  end
end
