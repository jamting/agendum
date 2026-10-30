# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.HelpBoxTest do
  @moduledoc """
  The help is drawn as a box over the screen it was opened from (R65c):
  about four fifths of the width and height, centred, framed and with a
  shadow; the screen beneath is faded, as behind any box, so that opening
  the help changes less of what is seen.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Starters.Planner
  alias Agendum.TUI.{HelpScreen, Render, State}

  @today ~D[2026-10-12]

  setup do
    db = Planner.build() |> Planner.with_samples(@today)
    %{state: start(db, today: @today, height: 40, width: 100)}
  end

  defp text(line), do: Enum.map_join(line, &elem(&1, 1))

  defp share(state) do
    {width, height} = HelpScreen.size(press(state, {:f, 1}))
    {(width + 2) / state.width, (height + 2) / State.body_height(state)}
  end

  test "a box over most of the screen, centred, the faded screen around it",
       %{state: state} do
    help = press(state, {:f, 1})
    {width, height} = HelpScreen.size(help)

    lines = Enum.map(Render.render(help), &text/1)
    top = Enum.find_index(lines, &String.contains?(&1, "┌"))
    left = lines |> Enum.at(top) |> String.split("┌") |> hd() |> String.length()
    # as much room on the left as on the right, above as below
    assert left == state.width - left - width - 2
    assert top - 2 == State.body_height(help) - (top - 2) - height - 2
    assert left > 0 and top > 2
    assert Enum.at(lines, top + height + 1) =~ "└"
  end

  test "the smaller the screen, the more of it the box takes", %{state: state} do
    {w80, h80} = share(%{state | width: 80, height: 25})
    {w100, h100} = share(state)
    {w200, h200} = share(%{state | width: 200, height: 60})
    assert w80 > 0.9 and h80 > 0.9
    assert w80 > w100 and w100 > w200 and w200 >= 0.8
    assert h80 > h100 and h100 > h200 and h200 >= 0.8
  end

  test "the help is inside it, with its heading", %{state: state} do
    screen = screen(press(state, {:f, 1}))
    assert screen =~ ~r/│ Views/u
  end

  test "the view beneath still shows around it, faded", %{state: state} do
    help = press(state, {:f, 1})
    rendered = Render.render(help)
    # the body's first row is above the box: the view's, faded
    view_row = Enum.at(rendered, 2)
    assert text(view_row) =~ "Tasks"
    assert Enum.all?(view_row, fn {style, _} -> style == :backdrop end)
  end

  test "its pages fit the box: the pane is at the box's foot", %{state: state} do
    listed = press(state, [{:f, 1}, {:f, 6}, :enter])
    {_width, height} = HelpScreen.size(listed)
    assert length(HelpScreen.lines(listed, State.mode(listed))) == height
  end

  test "opened from the category manager, the manager shows beneath", %{state: state} do
    help = press(state, [{:f, 9}, {:f, 1}])
    assert Enum.at(Render.render(help), 2) |> text() =~ "MAIN"
  end

  test "a small screen: the box takes what there is", %{state: state} do
    small = %{state | width: 30, height: 10}
    help = press(small, [{:f, 1}, {:f, 6}, :enter])
    {width, height} = HelpScreen.size(help)
    assert width == 28 and height == 4
    assert Enum.all?(Render.render(help), &(String.length(text(&1)) <= 30))
  end
end
