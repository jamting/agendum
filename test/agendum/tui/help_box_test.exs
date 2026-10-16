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

  test "a box of about four fifths of the screen, centred", %{state: state} do
    help = press(state, {:f, 1})
    {width, height} = HelpScreen.size(help)
    assert width in 76..80
    assert height in 25..30

    lines = Enum.map(Render.render(help), &text/1)
    top = Enum.find_index(lines, &String.contains?(&1, "┌"))
    left = lines |> Enum.at(top) |> String.split("┌") |> hd() |> String.length()
    assert left in 9..11
    assert top in 4..7
    assert Enum.at(lines, top + height + 1) =~ "└"
  end

  test "the help is inside it, with its heading", %{state: state} do
    screen = screen(press(state, {:f, 1}))
    assert screen =~ ~r/│ HELP IN A VIEW/u
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
    listed = press(state, [{:f, 1}, "c"])
    {_width, height} = HelpScreen.size(listed)
    assert length(HelpScreen.lines(listed, State.mode(listed))) == height
  end

  test "opened from the category manager, the manager shows beneath", %{state: state} do
    help = press(state, [{:f, 9}, {:f, 1}])
    assert Enum.at(Render.render(help), 2) |> text() =~ "MAIN"
  end

  test "a small screen: the box takes what there is", %{state: state} do
    small = %{state | width: 30, height: 10}
    help = press(small, [{:f, 1}, "c"])
    {width, height} = HelpScreen.size(help)
    assert width <= 28 and height <= 7
    assert Enum.all?(Render.render(help), &(String.length(text(&1)) <= 30))
  end
end
