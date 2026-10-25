defmodule Agendum.TUI.SoundTest do
  @moduledoc """
  Agenda's sounds (R76): which keys ask for which tone, the two settings
  that silence them, and the tones themselves.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.TUI.{Sound, Update}

  setup do
    %{state: start(Agendum.Sample.build(~D[2026-10-08]), now: ~N[2026-10-08 10:00:00])}
  end

  # the sounds the keys asked for, and only theirs
  defp sounds(state, keys) do
    Process.put(:effects_seen, [])
    state = press(state, keys)
    {state, for({:sound, name} <- effects(), do: name)}
  end

  describe "automatic completion beeps (R32)" do
    setup %{state: state} do
      priority = hd(Database.find_categories(state.db, "Priority"))
      {:ok, db, _} = Core.add_category(state.db, priority, "Lowest")
      # the Priority column of the second item; High Medium Low Lowest
      %{state: %{state | db: db} |> press([:down, :down, :right, :right])}
    end

    test "high when one category is left, low when none is, once each", %{state: state} do
      # L, Lo, Low: two match (Low, Lowest)
      {state, []} = sounds(state, "Low")
      {state, [:high]} = sounds(state, "e")
      {state, []} = sounds(state, "s")
      {state, [:low]} = sounds(state, "z")
      {state, []} = sounds(state, "z")
      # back to one match
      {_state, [:high]} = sounds(state, [:backspace, :backspace])
    end

    test "Beep on auto-completion No keeps them quiet", %{state: state} do
      state = %{state | prefs: %{state.prefs | beep_completion: false}}
      {_state, []} = sounds(state, "Lowez")
    end
  end

  test "an error beeps", %{state: state} do
    # an item with no When date cannot get an alarm
    {state, _} = sounds(state, ["Buy milk", :enter])
    {state, [:error]} = sounds(state, {:alt, "a"})
    assert panel(state) =~ message(:needs_date)
  end

  test "each key recorded in Learn mode clicks", %{state: state} do
    {state, _} = sounds(state, [{:alt_f, 3}, "Weed", :enter, {:f, 7}])
    {state, [:click, :click]} = sounds(state, [:down, :down])
    # stopping is not recorded
    {_state, []} = sounds(state, {:alt_f, 3})
  end

  test "an alarm plays its tune", %{state: state} do
    state = press(state, ["Personnel meeting at 2:00", :enter, {:alt, "a"}, :enter])
    {_state, effects} = Update.tick(state, ~N[2026-10-08 13:55:00])
    assert effects == [{:sound, :alarm}]
  end

  test "Sound No silences everything", %{state: state} do
    state = %{state | prefs: %{state.prefs | sound: false}}
    {state, []} = sounds(state, ["Buy milk", :enter, {:alt, "a"}])
    state = press(state, ["Personnel meeting at 2:00", :enter, {:alt, "a"}, :enter])
    assert {_state, []} = Update.tick(state, ~N[2026-10-08 13:55:00])
  end

  test "the Customize box switches both settings", %{state: state} do
    state = state |> press([{:f, 10}, "u", "c"]) |> to_setting("Sound")
    assert screen(state) =~ ~r/Sound +: Yes/
    state = press(state, " ")
    refute state.prefs.sound
    state = state |> to_setting("Beep on auto-completion") |> press(" ")
    refute state.prefs.beep_completion
  end

  describe "the tones" do
    test "are Agenda's: frequency and length in timer ticks of about 3.43 ms" do
      assert Sound.tones(:high) == [{1200, 6}]
      assert Sound.tones(:low) == [{140, 6}]
      assert Sound.tones(:error) == [{225, 30}]
      assert Sound.tones(:click) == [{75, 6}]
      # three low, then three high, each with a pause after it
      assert Sound.tones(:alarm) ==
               [{520, 50}, {0, 33}, {520, 50}, {0, 33}, {520, 50}, {0, 33}] ++
                 [{1040, 50}, {0, 33}, {1040, 50}, {0, 33}, {1040, 50}, {0, 33}]
    end

    test "become WAV files of the right length" do
      for {name, ticks} <- [error: 30, alarm: 6 * 83] do
        wav = Sound.wav(name)
        <<"RIFF", _size::little-32, "WAVE", _rest::binary>> = wav
        # 8-bit mono: one byte a sample, after a 44-byte header
        samples = byte_size(wav) - 44
        assert_in_delta samples / Sound.rate() * 1000, ticks * Sound.tick_ms(), 6
      end
    end

    test "every sound can be made" do
      for name <- Sound.names(), do: assert(byte_size(Sound.wav(name)) > 44)
    end
  end
end
