defmodule Agenda.TUI.InputFormatBoxTest do
  @moduledoc """
  File Properties ▸ Input format: the person's number order, input date
  separator and input clock (R41b), saved in their preferences, not in
  the file.
  """
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.Core.InputFormat
  alias Agenda.TUI.{State, Update}

  setup do
    state = start(Agenda.Sample.build(~D[2026-10-08]))
    %{state: %{state | prefs: %Agenda.Preferences{path: "/prefs"}}}
  end

  # File Properties, then down to Input format (after the 7 display rows)
  defp open_box(state),
    do: press(state, [{:f, 10}, "f", "p"] ++ List.duplicate(:down, 7) ++ [" "])

  test "File Properties has an Input format row that opens the box", %{state: state} do
    assert screen(press(state, [{:f, 10}, "f", "p"])) =~ ~r/Input format +: \(yours; SPACE\)/
    state = open_box(state)
    assert %{type: :input_format} = State.mode(state)
    text = screen(state)
    assert text =~ "Input format (yours, for every file)"
    assert text =~ ~r/Number order +: Language \(MDY\)/
    assert text =~ ~r/Input date separator *: Language \(\/\)/
    assert text =~ ~r/Input clock +: Language \(12 hr\)/
  end

  test "a change is the person's, saved to their preferences, not the file", %{state: state} do
    state = open_box(state)
    db = state.db
    {state, effects} = Update.handle(state, {:char, " "})
    {state, _} = Update.handle(state, :left)
    {state, effects2} = Update.handle(state, :left)

    assert state.input.number_order == :ymd
    assert state.db == db

    assert [{:save_preferences, "/prefs", %Agenda.Preferences{input: %{number_order: :mdy}}}] =
             effects

    assert [{:save_preferences, "/prefs", _}] = effects2
    assert screen(state) =~ ~r/Number order +: YMD/
  end

  test "dates are then read the person's way", %{state: state} do
    state = %{state | input: %InputFormat{number_order: :dmy, separator: "."}}

    state =
      press(
        state,
        [:down, {:alt_f, 2}, {:ctrl, "u"}] ++ String.graphemes("12.11.2026") ++ [:enter]
      )

    assert screen(state) =~ "2026-11-12"
  end

  test "without a preferences file the change lasts the session", %{state: state} do
    state = open_box(%{state | prefs: %Agenda.Preferences{}})
    {state, effects} = Update.handle(state, :down) |> elem(0) |> Update.handle(:right)
    assert state.input.separator == "/"
    assert effects == []
  end
end
