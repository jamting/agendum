defmodule Agenda.TUI.CustomizeBoxTest do
  @moduledoc """
  File ▸ Customize: the person's theme and date languages (R40, R14c) and
  the way to their Input format (R41b), saved as preferences (ADR 0008).
  """
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.Core.DateLanguage.{English, Swedish}
  alias Agenda.Core.InputFormat
  alias Agenda.Preferences
  alias Agenda.TUI.{State, Update}

  setup do
    state = start(Agenda.Sample.build(~D[2026-10-08]))
    %{state: %{state | preferences: "/prefs"}}
  end

  defp open_box(state), do: press(state, [{:f, 10}, "f", "c"])

  defp key(state, key) do
    {state, effects} = Update.handle(state, key)
    {state, effects}
  end

  test "File ▸ Customize shows the person's settings", %{state: state} do
    state = open_box(state)
    assert %{type: :customize} = State.mode(state)
    text = screen(state)
    assert text =~ "Customize (yours, for every file)"
    assert text =~ ~r/Theme +: Classic/
    assert text =~ ~r/Date language +: English/
    assert text =~ ~r/Fallback language +: None/
    assert text =~ ~r/Input format +: \(SPACE\)/
  end

  test "the theme changes at once and is saved", %{state: state} do
    {state, effects} = state |> open_box() |> key({:char, " "})
    assert state.theme == :mono
    assert [{:save_preferences, "/prefs", %Preferences{theme: :mono}}] = effects
    assert screen(state) =~ ~r/Theme +: Mono/
  end

  test "the date languages change how dates are read", %{state: state} do
    state = open_box(state)
    {state, _} = key(state, :down)
    {state, effects} = key(state, {:char, " "})
    assert state.languages == [Swedish]
    assert [{:save_preferences, _, %Preferences{languages: [Swedish]}}] = effects

    {state, _} = key(state, :down)
    {state, _} = key(state, {:char, " "})
    assert state.languages == [Swedish, English]
    assert screen(state) =~ ~r/Fallback language +: English/
    assert Agenda.TUI.State.context(state).languages == [Swedish, English]
  end

  test "the fallback is never the main language", %{state: state} do
    state = open_box(state) |> press([:down, :down, " "])
    assert state.languages == [English, Swedish]
    state = press(state, " ")
    assert state.languages == [English]
  end

  test "Input format opens the person's Input format box", %{state: state} do
    state = open_box(state) |> press([:down, :down, :down, " "])
    assert %{type: :input_format} = State.mode(state)
    state = press(state, :esc)
    assert %{type: :customize} = State.mode(state)
  end

  test "only the changed setting is saved, not one a flag gave", %{state: state} do
    # this session: a flag set the clock; the stored preferences say mono
    state = %{
      state
      | input: %InputFormat{clock: 24},
        theme: :mono,
        prefs: %Preferences{theme: :mono}
    }

    {state, [{:save_preferences, _, saved}]} =
      state |> open_box() |> press(:down) |> key({:char, " "})

    assert saved == %Preferences{theme: :mono, languages: [Swedish]}
    assert state.input.clock == 24
  end
end
