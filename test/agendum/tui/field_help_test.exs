defmodule Agendum.TUI.FieldHelpTest do
  @moduledoc "Help for a box's highlighted field in the control panel (SPEC §5)."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.TUI.{Terminal.Draw, Boxes.FieldHelp, State}

  setup do
    %{state: start(Agendum.Sample.build(~D[2026-10-08]), width: 80, height: 25)}
  end

  # the control panel's two lines as drawn
  defp panel_lines(state), do: state |> screen() |> String.split("\n") |> Enum.take(2)

  # the help of every field of the box on top, moving down until the
  # cursor stops
  defp walk(state, seen \\ []) do
    help = FieldHelp.text(state)
    next = press(state, :down)

    if State.mode(next).cursor == State.mode(state).cursor,
      do: Enum.reverse([help | seen]),
      else: walk(next, [help | seen])
  end

  test "File Properties says what its highlighted setting does", %{state: state} do
    state = press(state, [{:f, 10}, "f", "p"])
    assert panel(state) =~ "Choose to insert new columns in one or all sections"
    # the file's name gives way to the help
    refute panel(state) =~ "File:"

    state = press(state, :down)
    assert panel(state) =~ "characters between tab stops"
    refute panel(state) =~ "insert new columns"
    assert panel(press(state, :down)) =~ "date and time formats"
  end

  test "the help follows the box on top, and goes when the box closes", %{state: state} do
    state = press(state, [{:f, 10}, "f", "p", :down, :down, " "])
    assert %{type: :date_settings} = State.mode(state)
    assert panel(state) =~ "how dates and times are displayed"

    # back to the File menu, then to the view
    state = press(state, [:esc, :esc])
    assert %{type: :menu} = State.mode(state)
    assert panel(press(state, [:esc, :esc])) =~ "File:"
  end

  test "a long help goes on into the second line", %{state: state} do
    state = press(state, [{:f, 10}, "u", "c", :down])
    [first, second] = panel_lines(state)
    assert first =~ "The language you type dates in"
    assert second =~ "SPACE for the next"
  end

  test "a message comes before the help", %{state: state} do
    state = press(state, [{:f, 10}, "u", "c"])
    state = %{state | message: {:error, "Something went wrong"}}
    assert panel(state) =~ "Something went wrong"
    refute panel(state) =~ "The colours Agendum draws with"
  end

  test "list boxes have one help for the whole box", %{state: state} do
    state = press(state, {:alt_f, 5})
    assert panel(state) =~ "Highlight the section to go to"
  end

  test "every field of the settings boxes has help", %{state: state} do
    boxes = [
      press(state, [{:f, 10}, "u", "c"]),
      press(state, [{:f, 10}, "f", "p"]),
      press(state, [{:f, 10}, "f", "p", :down, :down, " "]),
      press(state, [{:f, 10}, "f", "p", :down, :down, " ", " "]),
      press(state, [{:f, 10}, "f", "p", :down, :down, :right, " "]),
      press(state, [{:f, 9}, :down, :down, {:f, 6}]),
      press(state, [:down, {:f, 6}]),
      press(state, [:down, {:f, 10}, "v", "s", "p"]),
      press(state, [:down, :right, {:f, 10}, "v", "c", "p"]),
      press(state, [:down, :right, {:f, 10}, "v", "c", "a"]),
      state |> press(:down) |> sort_box(:section),
      press(state, [{:f, 10}, "u", "s", "s"]),
      press(state, {:alt_f, 6}),
      press(state, [{:f, 10}, "u", "e"])
    ]

    for box <- boxes do
      %{type: type} = State.mode(box)
      assert Map.has_key?(FieldHelp.boxes(), type), "#{type} is not a settings box"
      refute nil in walk(box), "#{type}: a field without help"
    end
  end

  test "every module named for a box tells its field" do
    for {_type, module} <- FieldHelp.boxes() do
      Code.ensure_loaded!(module)
      assert function_exported?(module, :field, 2), "#{inspect(module)} has no field/2"
    end
  end

  test "every help fits the control panel's two lines at 80 columns" do
    # line 1 shares its room with the indicators ("  ♦ ? PROPS  2026-10-08 13:02 ")
    for text <- FieldHelp.all() do
      [first | rest] = Draw.wrap(text, 48)
      assert String.length(first) <= 48
      assert String.length(" " <> Enum.join(rest, " ")) <= 80, "too long: #{text}"
    end
  end
end
