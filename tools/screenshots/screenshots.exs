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
  import Agenda.TUIHelpers
  alias Agenda.TUI.{Render, Theme}

  @renderer "tmp/render-screen"
  @today ~D[2026-10-12]

  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [theme: :string, out: :string])
    {:ok, theme} = Theme.parse(opts[:theme] || "classic")
    out = opts[:out] || "tmp/screenshots"
    File.mkdir_p!(out)
    build_renderer()

    state = start(Agenda.Sample.build(@today), width: 80, height: 25)
    state = %{state | now: ~N[2026-10-12 20:52:00], today: @today, path: "/home/me/planner.agenda"}

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
      {"12-view-manager", press(s, {:f, 8})},
      {"13-category-manager", press(s, [{:f, 9}, :down, :down])},
      {"14-category-props", press(s, [{:f, 9}, :down, :down, :down, :down, {:f, 6}])},
      {"15-question", press(s, [:down, {:alt_f, 4}])}
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

  # The colours an SGR sequence sets, as hex; bold brightens like a VGA screen.
  @ansi ~w(000000 aa0000 00aa00 aa5500 0000aa aa00aa 00aaaa aaaaaa
           555555 ff5555 55ff55 ffff55 5555ff ff55ff 55ffff ffffff)

  defp colours("\e[" <> rest) do
    codes = rest |> String.trim_trailing("m") |> String.split(";") |> Enum.map(&String.to_integer/1)
    {fg, bg, bold, reverse} = sgr(codes, {7, 0, false, false})
    fg = if bold and is_integer(fg) and fg < 8, do: fg + 8, else: fg
    {fg, bg} = if reverse, do: {bg, fg}, else: {fg, bg}
    {hex(fg), hex(bg)}
  end

  defp sgr([], acc), do: acc
  defp sgr([0 | rest], _), do: sgr(rest, {7, 0, false, false})
  defp sgr([1 | rest], {f, b, _, r}), do: sgr(rest, {f, b, true, r})
  defp sgr([7 | rest], {f, b, bo, _}), do: sgr(rest, {f, b, bo, true})
  defp sgr([38, 2, r, g, b | rest], {_, bg, bo, rv}), do: sgr(rest, {{r, g, b}, bg, bo, rv})
  defp sgr([48, 2, r, g, b | rest], {fg, _, bo, rv}), do: sgr(rest, {fg, {r, g, b}, bo, rv})
  defp sgr([n | rest], {_, b, bo, r}) when n in 30..37, do: sgr(rest, {n - 30, b, bo, r})
  defp sgr([n | rest], {_, b, bo, r}) when n in 90..97, do: sgr(rest, {n - 82, b, bo, r})
  defp sgr([n | rest], {f, _, bo, r}) when n in 40..47, do: sgr(rest, {f, n - 40, bo, r})
  defp sgr([n | rest], {f, _, bo, r}) when n in 100..107, do: sgr(rest, {f, n - 92, bo, r})
  defp sgr([_ | rest], acc), do: sgr(rest, acc)

  defp hex({r, g, b}), do: Enum.map_join([r, g, b], &String.pad_leading(Integer.to_string(&1, 16), 2, "0"))
  defp hex(n), do: Enum.at(@ansi, n)
end

Screenshots.run(System.argv())
