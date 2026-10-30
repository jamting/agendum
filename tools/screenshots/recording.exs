# SPDX-License-Identifier: AGPL-3.0-only
# The front page's recording (meeting 2026-10-30-2020, § 5): Agenda's
# classic moment, an item typed into one section and filed by itself under
# a person and a date. Drives the real TUI on Rabbit's file, as the manual's
# captures do, draws each step as a PNG (tools/screenshots/png.ex, macOS
# only) and stitches them into a looping animated WebP with img2webp
# (`brew install webp`).
#
#     MIX_ENV=test mix run tools/screenshots/recording.exs [--out FILE]
#
# The default FILE is pages/filing.webp (pages/ holds the GitHub Pages site;
# site/ is the blog extra's own Publish folder, git-ignored). Run it again
# whenever the screen changes; the frames are the same every time, as the
# clock is fixed.

Code.require_file("test/support/tui_helpers.ex")
Code.require_file("tools/screenshots/png.ex")

defmodule Recording do
  @moduledoc false
  import Agendum.TUIHelpers
  alias Agendum.TUI.{Render, Terminal.Theme}

  @today ~D[2026-10-12]
  @sentence "Take Kanga some lettuces on Friday"

  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [out: :string])
    out = opts[:out] || "pages/filing.webp"
    {:ok, theme} = Theme.parse("classic")

    state = start(Agendum.Sample.rabbit(@today), width: 80, height: 25)

    state = %{
      state
      | now: ~N[2026-10-12 10:15:00],
        today: @today,
        path: "/home/rabbit/rabbit.agendum"
    }

    frames = Path.join(System.tmp_dir!(), "agendum-recording")
    File.rm_rf!(frames)
    File.mkdir_p!(frames)

    # each step is a screen and how long it stays, in milliseconds
    steps =
      state
      |> steps()
      |> Enum.with_index()
      |> Enum.map(fn {{screen, ms}, i} ->
        path = Path.join(frames, "#{String.pad_leading("#{i}", 3, "0")}.png")
        ScreenPNG.write(Render.render(screen), theme, path, 2)
        {path, ms}
      end)

    # img2webp takes "-d MS" before each frame; -lossy keeps it small, and
    # -mixed lets it choose per frame
    args =
      ["-loop", "0", "-mixed", "-q", "80"] ++
        Enum.flat_map(steps, fn {path, ms} -> ["-d", "#{ms}", path] end) ++ ["-o", out]

    File.mkdir_p!(Path.dirname(out))
    {_, 0} = System.cmd("img2webp", args, stderr_to_stdout: true)
    File.rm_rf!(frames)
    IO.puts("Wrote #{out}: #{length(steps)} frames, #{div(File.stat!(out).size, 1024)} KB")
  end

  # The view, the cursor moved to a new item in Garden, the sentence typed
  # one letter at a time, then ENTER: the item now also stands under Friends
  # and Relations (Kanga) with Friday's date, which nobody typed in a column.
  defp steps(state) do
    at_new = press(state, [:down])
    at_blank = press(at_new, [:down])

    typed =
      @sentence
      |> String.graphemes()
      |> Enum.scan(at_blank, fn letter, s -> press(s, letter) end)

    filed = press(List.last(typed), :enter)

    [{state, 1800}, {at_new, 350}, {at_blank, 500}] ++
      Enum.map(typed, &{&1, 75}) ++
      [{List.last(typed), 700}, {filed, 4500}]
  end
end

Recording.run(System.argv())
