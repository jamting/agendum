defmodule Agendum.TUI.CustomizeBoxTest do
  @moduledoc """
  File ▸ Customize: the person's theme and date languages (R40, R14c) and
  the way to their Input format (R41b), saved as preferences (ADR 0008).
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core.DateLanguage.{English, Swedish}
  alias Agendum.Core.InputFormat
  alias Agendum.Preferences
  alias Agendum.TUI.{State, Update}

  setup do
    state = start(Agendum.Sample.build(~D[2026-10-08]))
    %{state: %{state | prefs: %Agendum.Preferences{path: "/prefs"}}}
  end

  defp open_box(state), do: press(state, [{:f, 10}, "u", "c"])

  defp key(state, key) do
    {state, effects} = Update.handle(state, key)
    {state, effects}
  end

  test "File ▸ Customize shows the person's settings", %{state: state} do
    state = open_box(state)
    assert %{type: :customize} = State.mode(state)
    text = screen(state)
    assert text =~ "Utilities Customize"
    assert text =~ ~r/Theme +: Classic/
    assert text =~ ~r/Date language +: English/
    assert text =~ ~r/Fallback language +: None/
    assert text =~ ~r/Input format +: \(SPACE\)/
    assert text =~ ~r/Display key map +: Yes/
  end

  test "Display key map hides the key bar, and is saved; ALT-K changes it too", %{state: state} do
    {state, effects} = state |> open_box() |> to_setting("Display key map") |> key({:char, " "})
    refute state.key_map
    assert [{:save_preferences, "/prefs", %Preferences{key_map: false}}] = effects
    assert screen(state) =~ ~r/Display key map +: No/

    {state, effects} = state |> press(:enter) |> key({:alt, "k"})
    assert state.key_map
    assert [{:save_preferences, "/prefs", %Preferences{key_map: true}}] = effects
  end

  test "the key map starts as the preferences say" do
    state = start(Agendum.Sample.build(~D[2026-10-08]), prefs: %Preferences{key_map: false})
    refute state.key_map
  end

  test "the theme changes at once and is saved", %{state: state} do
    {state, effects} = state |> open_box() |> key({:char, " "})
    assert state.theme == :mono
    assert [{:save_preferences, "/prefs", %Preferences{theme: :mono}}] = effects
    assert screen(state) =~ ~r/Theme +: Mono/
  end

  test "a scheme's theme is shown by its name", %{state: state} do
    state = %{state | theme: :mono} |> open_box() |> press(" ")
    assert state.theme == :modus_operandi
    assert screen(state) =~ ~r/Theme +: Modus Operandi/
  end

  test "the date languages change how dates are read", %{state: state} do
    state = open_box(state)
    {state, _} = key(state, :down)
    {state, effects} = key(state, {:char, " "})
    assert Agendum.TUI.State.languages(state) == [Swedish]
    assert [{:save_preferences, _, %Preferences{languages: [Swedish]}}] = effects

    {state, _} = key(state, :down)
    {state, _} = key(state, {:char, " "})
    assert Agendum.TUI.State.languages(state) == [Swedish, English]
    assert screen(state) =~ ~r/Fallback language +: English/
    assert Agendum.TUI.State.context(state).languages == [Swedish, English]
  end

  test "the fallback is never the main language", %{state: state} do
    state = open_box(state) |> press([:down, :down, " "])
    assert Agendum.TUI.State.languages(state) == [English, Swedish]
    state = press(state, " ")
    assert Agendum.TUI.State.languages(state) == [English]
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
      Agendum.TUI.State.put_reader(state, input: %InputFormat{clock: 24})
      | theme: :mono,
        prefs: %Preferences{theme: :mono, path: "/prefs"}
    }

    {state, [{:save_preferences, _, saved}]} =
      state |> open_box() |> press(:down) |> key({:char, " "})

    assert saved == %Preferences{theme: :mono, languages: [Swedish], path: "/prefs"}
    assert Agendum.TUI.State.input(state).clock == 24
  end

  test "the decimal and thousands separators change how numbers show, and are saved",
       %{state: state} do
    state = open_box(state) |> to_setting("Decimal separator")
    assert screen(state) =~ ~r/Decimal separator +: \. \(Dot\)/
    assert screen(state) =~ ~r/Thousands separator +: , \(Comma\)/

    {state, [{:save_preferences, _, saved}]} = key(state, {:char, " "})
    assert saved.input.decimal == ","
    assert State.number_opts(state) == [decimal: ",", thousands: "."]
    assert screen(state) =~ ~r/Decimal separator +: , \(Comma\)/
    assert screen(state) =~ ~r/Thousands separator +: \. \(Dot\)/

    # the thousands separator skips the decimal one
    state = press(state, [:down, " "])
    assert screen(state) =~ ~r/Thousands separator +: +\(Space\)/
    state = press(state, " ")
    assert screen(state) =~ ~r/Thousands separator +: \. \(Dot\)/
  end
end
