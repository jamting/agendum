# SPDX-License-Identifier: AGPL-3.0-only
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

  test "File Properties says what its highlighted setting does", %{state: state} do
    state = press(state, [{:f, 10}, "f", "p"])
    assert panel(state) =~ "Enter a short description of the file."
    # the file's name gives way to the help
    refute panel(state) =~ "File:"

    state = state |> to_setting("Insert new columns in")
    assert panel(state) =~ "Choose to insert new columns in one or all sections"

    state = press(state, :down)
    assert panel(state) =~ "remove discarded items from the trash"
    state = press(state, :down)
    assert panel(state) =~ "characters between tab stops"
    refute panel(state) =~ "insert new columns"
    assert panel(press(state, :down)) =~ "date and time formats"
  end

  test "the help follows the box on top, and goes when the box closes", %{state: state} do
    state = press(state, [{:f, 10}, "f", "p", :down, :down, :down, :down, :down, :down, " "])
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
    # where it breaks depends on the room; the time no longer takes any
    assert second =~ "next."
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

  # every field of every settings box in the registry: the 1.9 test in
  # box_guidelines_test.exs, which walks them all

  test "every module named for a box tells its field" do
    for {_type, module} <- FieldHelp.boxes() do
      Code.ensure_loaded!(module)
      assert function_exported?(module, :field, 2), "#{inspect(module)} has no field/2"
    end
  end

  test "every help fits the control panel's two lines at 80 columns" do
    # a box has both lines to itself, but for LEARN at the right (v0.42.0)
    for text <- FieldHelp.all() do
      [first | rest] = Draw.wrap(text, 72)
      assert String.length(first) <= 72
      assert String.length(" " <> Enum.join(rest, " ")) <= 80, "too long: #{text}"
    end
  end
end
