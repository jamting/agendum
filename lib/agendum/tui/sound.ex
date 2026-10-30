# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Sound do
  @moduledoc """
  Agenda's sounds (R76), as Agenda made them: square waves on the PC
  speaker, each a list of tones. A tone is a frequency in Hz (0 for a
  pause) and a length in ticks of the PC's timer, about 3.43 ms each.

  The numbers are Agenda's own, read from its program (A.EXE pushes them
  before calling its speaker routine) and checked against recordings of
  Agenda in DOSBox (ADR 0042):

  - `:high`, a high beep: typing a category, exactly one name matches
  - `:low`, a low beep: nothing matches, so a new category will be made
  - `:error`: a key that cannot do its work (an error message)
  - `:click`: each key recorded in Learn mode
  - `:alarm`: an alarm rings, three low notes and three high ones

  Agenda had one more, a shorter error beep (225 Hz, 12 ticks); which of
  its refusals used which cannot be told apart in Agendum, so `:error`
  serves for both.

  `wav/1` turns a sound into a WAV file's bytes, for the shell to play
  (`Agendum.TUI.Speaker`). Pure.
  """

  @typedoc "One of Agenda's sounds."
  @type name :: :high | :low | :error | :click | :alarm

  @typedoc "A frequency in Hz (0: silence) and a length in timer ticks."
  @type tone :: {non_neg_integer, pos_integer}

  # Domain: Agenda waited for bit 13 of the PC timer's counter to change.
  # The timer counts down by two at 1,193,182 Hz, so the bit changes every
  # 4096 of its steps.
  @tick_ms 4096 / 1_193_182 * 1000

  @rate 22_050

  # a quarter of full scale: a square wave is loud
  @amplitude 32

  # each note followed by a pause, three times
  @alarm_low List.flatten(List.duplicate([{520, 50}, {0, 33}], 3))
  @alarm_high List.flatten(List.duplicate([{1040, 50}, {0, 33}], 3))

  @doc "The sounds there are."
  @spec names() :: [name]
  def names, do: [:high, :low, :error, :click, :alarm]

  @doc "A sound's tones, in the order they are played."
  @spec tones(name) :: [tone]
  def tones(:high), do: [{1200, 6}]
  def tones(:low), do: [{140, 6}]
  def tones(:error), do: [{225, 30}]
  def tones(:click), do: [{75, 6}]
  def tones(:alarm), do: @alarm_low ++ @alarm_high

  @doc "How long one timer tick is, in milliseconds."
  @spec tick_ms() :: float
  def tick_ms, do: @tick_ms

  @doc "The samples a second in `wav/1`."
  @spec rate() :: pos_integer
  def rate, do: @rate

  @doc """
  The sound as a WAV file: 8-bit mono PCM at `rate/0` samples a second,
  a square wave for each tone.
  """
  @spec wav(name) :: binary
  def wav(name) do
    data = name |> tones() |> Enum.map_join(&samples/1)
    header(byte_size(data)) <> data
  end

  # One tone's samples. An 8-bit WAV sample is unsigned, silence at 128;
  # the wave is high for the first half of each period, low for the second.
  defp samples({frequency, ticks}) do
    count = round(ticks * @tick_ms * @rate / 1000)

    if frequency == 0 do
      :binary.copy(<<128>>, count)
    else
      period = @rate / frequency

      # `for … into: <<>>` builds a binary directly; `<<x>>` is one byte
      for i <- 0..(count - 1)//1, into: <<>> do
        high? = :math.fmod(i, period) < period / 2
        <<if(high?, do: 128 + @amplitude, else: 128 - @amplitude)>>
      end
    end
  end

  # The 44-byte header of a PCM WAV file. `::little-32` writes a number as
  # four bytes, least significant first, as the format wants.
  defp header(data_size) do
    <<"RIFF", 36 + data_size::little-32, "WAVE", "fmt ", 16::little-32, 1::little-16,
      1::little-16, @rate::little-32, @rate::little-32, 1::little-16, 8::little-16, "data",
      data_size::little-32>>
  end
end
