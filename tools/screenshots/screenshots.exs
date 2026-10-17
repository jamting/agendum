# Pictures of the TUI, for comparing its look with Agenda 2.0 (e.g. with
# screenshots from DOSBox): drives the real TUI with key presses, as the
# tests do, and draws each screen as a PNG with the theme's colours. macOS
# only (the drawing is done by render.swift, with AppKit).
#
#     MIX_ENV=test mix run tools/screenshots/screenshots.exs [--theme NAME] [--out DIR]
#
# The pictures go to tmp/screenshots (by default), 720x400 for 80x25 like a
# VGA text screen. Add a screen by adding a line to `shots/1`.

Code.require_file("test/support/tui_helpers.ex")

defmodule Screenshots do
  @moduledoc false
  import Agendum.TUIHelpers
  alias Agendum.TUI.{Render, Terminal.Theme}

  @renderer "tmp/render-screen"
  @today ~D[2026-10-12]

  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [theme: :string, out: :string])
    {:ok, theme} = Theme.parse(opts[:theme] || "classic")
    out = opts[:out] || "tmp/screenshots"
    File.mkdir_p!(out)
    build_renderer()

    state = start(Agendum.Sample.build(@today), width: 80, height: 25)
    state = %{state | now: ~N[2026-10-12 20:52:00], today: @today, path: "/home/me/planner.agendum"}

    for {name, screen} <- shots(state) do
      cells = Path.join(out, name <> ".cells")
      File.write!(cells, cells(Render.render(screen), theme))
      {_, 0} = System.cmd(Path.expand(@renderer), [cells, Path.join(out, name <> ".png")])
      File.rm!(cells)
    end

    IO.puts("Wrote #{length(shots(state))} screens to #{out}")
  end

  defp shots(s) do
    [
      {"00-splash", Agendum.TUI.Update.start(%{s | prefs: %{s.prefs | user: "rabbit"}}, true)},
      {"01-view", s},
      {"02-view-column", press(s, [:down, :right])},
      {"03-menu", press(s, {:f, 10})},
      {"04-view-menu", press(s, [{:f, 10}, "v", "c"])},
      {"05-column-props", press(s, [:down, :right, {:f, 10}, "v", "c", "p"])},
      {"06-choices", press(s, [:down, :right, :right, {:f, 3}])},
      {"07-profile", press(s, [:down, {:f, 3}])},
      {"08-item-props", press(s, [:down, {:f, 6}])},
      {"09-typing", press(s, [:down, :right, :right, "Hi"])},
      {"10-note", press(s, [:down, {:f, 5}, "hello there"])},
      {"11-help", press(s, {:f, 1})},
      {"11a-help-commands", press(s, [:down, {:f, 1}, "c"] ++ List.duplicate(:down, 25))},
      {"11b-help-not-now", press(s, [:down, {:f, 1}, "c", "yank"])},
      {"11c-run-by-name", press(s, [:down, {:ctrl, "x"}, "a"])},
      {"12-view-manager", press(s, {:f, 8})},
      {"13-category-manager", press(s, [{:f, 9}, :down, :down])},
      {"14-category-props", press(s, [{:f, 9}, :down, :down, :down, :down, {:f, 6}])},
      {"15-question", press(s, [:down, {:alt_f, 4}])},
      {"19-datebook-week", press(s, [{:f, 10}, "v", "a", "This Week", :enter, "d", :esc])},
      {"20-datebook-month",
       press(s, [{:f, 10}, "v", "a", "This Month", :enter, "d", :down, :down, :down, " ", :esc])},
      {"21-datebook-settings", press(s, [{:f, 10}, "v", "a", "This Week", :enter, "d"])},
      {"18-calendar", press(s, [:down, :right, {:f, 3}])},
      {"17-file-props", press(s, [{:f, 10}, "f", "p", " ", " "])},
      {"16-nested-box", press(s, [{:f, 9}, :down, :down, :down, :down, {:f, 6}, :down, :down, :enter])}
    ]
  end

  defp build_renderer do
    source = Path.join(__DIR__, "render.swift")

    unless File.exists?(@renderer) and mtime(@renderer) >= mtime(source) do
      File.mkdir_p!(Path.dirname(@renderer))
      {_, 0} = System.cmd("swiftc", ["-O", source, "-o", @renderer], stderr_to_stdout: true)
    end
  end

  defp mtime(path), do: File.stat!(path, time: :posix).mtime

  # one line per row: "FG\tBG\tTEXT" segments separated by U+001F
  defp cells(lines, theme) do
    Enum.map_join(lines, "\n", fn line ->
      Enum.map_join(line, "\u001F", fn {style, text} ->
        {fg, bg} = colours(Theme.sgr(style, theme, :truecolor))
        fg <> "\t" <> bg <> "\t" <> text
      end)
    end)
  end

  # The colours an SGR sequence sets, as hex. Bold brightens like a VGA
  # screen, dim mixes the text colour halfway into the background, and
  # underline is marked by a "_" after the text colour.
  @ansi ~w(000000 aa0000 00aa00 aa5500 0000aa aa00aa 00aaaa aaaaaa
           555555 ff5555 55ff55 ffff55 5555ff ff55ff 55ffff ffffff)

  @plain %{fg: 7, bg: 0, bold: false, dim: false, underline: false, reverse: false}

  defp colours("\e[" <> rest) do
    codes = rest |> String.trim_trailing("m") |> String.split(";") |> Enum.map(&String.to_integer/1)
    a = sgr(codes, @plain)
    fg = if a.bold and is_integer(a.fg) and a.fg < 8, do: a.fg + 8, else: a.fg
    {fg, bg} = if a.reverse, do: {rgb(a.bg), rgb(fg)}, else: {rgb(fg), rgb(a.bg)}
    fg = if a.dim, do: mix(fg, bg), else: fg
    {hex(fg) <> if(a.underline, do: "_", else: ""), hex(bg)}
  end

  defp sgr([], a), do: a
  defp sgr([0 | rest], _), do: sgr(rest, @plain)
  defp sgr([1 | rest], a), do: sgr(rest, %{a | bold: true})
  defp sgr([2 | rest], a), do: sgr(rest, %{a | dim: true})
  defp sgr([4 | rest], a), do: sgr(rest, %{a | underline: true})
  defp sgr([7 | rest], a), do: sgr(rest, %{a | reverse: true})
  defp sgr([38, 2, r, g, b | rest], a), do: sgr(rest, %{a | fg: {r, g, b}})
  defp sgr([48, 2, r, g, b | rest], a), do: sgr(rest, %{a | bg: {r, g, b}})
  defp sgr([n | rest], a) when n in 30..37, do: sgr(rest, %{a | fg: n - 30})
  defp sgr([n | rest], a) when n in 90..97, do: sgr(rest, %{a | fg: n - 82})
  defp sgr([n | rest], a) when n in 40..47, do: sgr(rest, %{a | bg: n - 40})
  defp sgr([n | rest], a) when n in 100..107, do: sgr(rest, %{a | bg: n - 92})
  defp sgr([_ | rest], a), do: sgr(rest, a)

  defp rgb({_, _, _} = rgb), do: rgb
  defp rgb(n), do: @ansi |> Enum.at(n) |> Base.decode16!(case: :lower) |> :binary.bin_to_list() |> List.to_tuple()

  defp mix({r1, g1, b1}, {r2, g2, b2}), do: {div(r1 + r2, 2), div(g1 + g2, 2), div(b1 + b2, 2)}

  defp hex({r, g, b}), do: Enum.map_join([r, g, b], &String.pad_leading(Integer.to_string(&1, 16), 2, "0"))
end

Screenshots.run(System.argv())
