defmodule Agenda.TUI.DevToolsTest do
  @moduledoc """
  The hidden developer screen (ESC ? or ALT-?): what the program knows
  right now, for debugging. Not in the menus or the F1 help.
  """
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.TUI.State

  setup do
    %{state: start(Agenda.Sample.build(~D[2026-10-08]))}
  end

  # the whole screen, scrolled through
  defp all_text(state),
    do: Enum.map_join(0..3, "\n", &screen(press(state, List.duplicate(:pgdn, &1))))

  test "ESC ? opens it from the view, and ESC closes it", %{state: state} do
    state = press(state, {:alt, "?"})
    assert %{type: :devtools} = State.mode(state)
    assert screen(state) =~ "Developer tools"
    assert press(state, :esc).modes == []
  end

  test "it opens on top of any box, and shows the mode stack", %{state: state} do
    state = press(state, [{:f, 10}, "f", "p", {:alt, "?"}])
    assert %{type: :devtools} = State.mode(state)
    text = screen(state)
    assert text =~ ~r/Modes +: devtools > file_props/

    state = press(state, :esc)
    assert %{type: :file_props} = State.mode(state)
  end

  test "it shows the program, the file and the session", %{state: state} do
    text = all_text(press(state, {:alt, "?"}))
    assert text =~ ~r/Wol's Agendum +: 0\.\d+\.\d+/
    assert text =~ ~r/Elixir \/ OTP +: \d+\.\d+/
    assert text =~ ~r/File format +: version #{Agenda.Store.format_version()}/
    assert text =~ ~r/Items +: \d+/
    assert text =~ ~r/Categories +: \d+ \(\d+ standard, \d+ date, \d+ numeric\)/
    assert text =~ ~r/Views +: \d+/
    assert text =~ ~r/Undo \/ redo +: 0 \/ 0/
    assert text =~ ~r/Now +: 2026-10-08 09:00/
    assert text =~ ~r/Languages +: english/
    assert text =~ ~r/Terminal +: \d+×\d+/
  end

  test "the last key is at the top", %{state: state} do
    assert screen(press(state, {:alt, "?"})) =~ ~r/Last key +: \(press a key; ESC closes\)/
  end

  test "it shows each key as decoded, to debug terminals", %{state: state} do
    state = press(state, [{:alt, "?"}, {:ctrl, "e"}])
    assert %{type: :devtools} = State.mode(state)
    assert screen(state) =~ ~r/Last key +: \{:ctrl, "e"\}/

    state = press(state, {:alt_f, 3})
    assert screen(state) =~ ~r/Last key +: \{:alt_f, 3\}/
  end

  test "keys are not passed on: no undo, no quit", %{state: state} do
    state = press(state, [{:alt, "?"}, {:ctrl, "q"}, {:ctrl, "z"}, "x"])
    assert %{type: :devtools} = State.mode(state)
    assert state.effects == []
    assert screen(state) =~ ~r/Last key +: \{:char, "x"\}/
  end

  test "it scrolls when the screen is short", %{state: state} do
    state = %{state | height: 12} |> press({:alt, "?"})
    refute screen(state) =~ "Program"
    state = press(state, List.duplicate(:pgdn, 9))
    assert screen(state) =~ ~r/Elixir \/ OTP/
    state = press(state, List.duplicate(:pgup, 9))
    assert State.mode(state).top == 0
  end

  test "it is not in the F1 help or the menus" do
    refute Agenda.TUI.Render.Help.text() =~ "Developer"
    refute inspect(Agenda.TUI.Menu.tree()) =~ "devtools"
  end
end
