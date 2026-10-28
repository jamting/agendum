# Draws a rendered TUI screen (`Agendum.TUI.Render.render/1`) as a PNG with a
# theme's colours, by way of render.swift (macOS only, AppKit). Shared by
# screenshots.exs and the manual's capture_screens.exs, so every picture of
# the program is drawn the same way.
#
#     Code.require_file("tools/screenshots/png.ex")
#     ScreenPNG.write(Render.render(state), theme, "out.png", 2)
#
# Scale 1 draws a 9x16 cell per character (80x25 = 720x400, a VGA text
# screen); scale 2 draws it twice as large, for sharp text on a high-density
# display when the page shows it at 720x400.

defmodule ScreenPNG do
  @moduledoc false
  alias Agendum.TUI.Terminal.Theme

  @renderer "tmp/render-screen"

  def write(lines, theme, path, scale \\ 1) do
    build_renderer()
    cells = path <> ".cells"
    File.write!(cells, cells(lines, theme))
    {_, 0} = System.cmd(Path.expand(@renderer), [cells, path, Integer.to_string(scale)])
    File.rm!(cells)
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
    codes =
      rest |> String.trim_trailing("m") |> String.split(";") |> Enum.map(&String.to_integer/1)

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

  defp rgb(n),
    do:
      @ansi
      |> Enum.at(n)
      |> Base.decode16!(case: :lower)
      |> :binary.bin_to_list()
      |> List.to_tuple()

  defp mix({r1, g1, b1}, {r2, g2, b2}), do: {div(r1 + r2, 2), div(g1 + g2, 2), div(b1 + b2, 2)}

  defp hex({r, g, b}),
    do: Enum.map_join([r, g, b], &String.pad_leading(Integer.to_string(&1, 16), 2, "0"))
end
