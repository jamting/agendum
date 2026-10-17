defmodule Agendum.TUI.Speaker do
  @moduledoc """
  Plays Agenda's sounds (R76, ADR 0042): the shell's side of a
  `{:sound, name}` effect. The tones are `Agendum.TUI.Sound`'s, written
  once as WAV files to the system's temporary folder and played by the
  computer's own player, `afplay` on a Mac, `paplay` or `aplay` on Linux,
  in the background, so the keys go on at once.

  Where there is no player, or Agendum runs over ssh (the sound would play
  on the far computer, not the person's), the terminal's bell rings
  instead: one sound for all of them, as the terminal makes it.
  """

  alias Agendum.TUI.{Sound, Terminal}

  @doc "Plays the sound, or rings the terminal's bell."
  @spec play(Sound.name()) :: :ok
  def play(name) do
    case player() do
      nil ->
        Terminal.write("\a")

      {command, args} ->
        path = wav_file(name)
        # the player's own output is kept from the screen (raw mode)
        Task.start(fn -> System.cmd(command, args ++ [path], stderr_to_stdout: true) end)
        :ok
    end
  rescue
    # a sound is never worth a crash: the bell instead
    _ -> Terminal.write("\a")
  end

  # the first player found, unless the person sits at another computer
  defp player do
    if System.get_env("SSH_CONNECTION") in [nil, ""] do
      Enum.find_value([{"afplay", []}, {"paplay", []}, {"aplay", ["-q"]}], fn {name, args} ->
        if path = System.find_executable(name), do: {path, args}
      end)
    end
  end

  # Named by a hash of its bytes, so a file left by another version of
  # Agendum is never played for a sound that has since changed.
  defp wav_file(name) do
    wav = Sound.wav(name)
    dir = Path.join(System.tmp_dir!(), "agendum-sounds")
    path = Path.join(dir, "#{name}-#{:erlang.phash2(wav)}.wav")

    unless File.exists?(path) do
      File.mkdir_p!(dir)
      File.write!(path, wav)
    end

    path
  end
end
