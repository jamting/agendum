# SPDX-License-Identifier: AGPL-3.0-only
# Pictures of the TUI, for comparing its look with Agenda 2.0 (e.g. with
# screenshots from DOSBox): drives the real TUI with key presses, as the
# tests do, and draws each screen as a PNG with the theme's colours. macOS
# only (the drawing is done by render.swift, with AppKit).
#
#     MIX_ENV=test mix run tools/screenshots/screenshots.exs [--theme NAME] [--out DIR] [--only NAME,...]
#
# The pictures go to tmp/screenshots (by default), 720x400 for 80x25 like a
# VGA text screen. Add a screen by adding a line to `shots/1`; --only NAME,...
# draws only those. (The README's picture is the manual's first screen,
# captured by docs/manual/src/capture_screens.exs.)

Code.require_file("test/support/tui_helpers.ex")
Code.require_file("tools/screenshots/png.ex")

defmodule Screenshots do
  @moduledoc false
  import Agendum.TUIHelpers
  alias Agendum.TUI.{Render, Terminal.Theme}

  @today ~D[2026-10-12]

  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [theme: :string, out: :string, only: :string])
    {:ok, theme} = Theme.parse(opts[:theme] || "classic")
    out = opts[:out] || "tmp/screenshots"
    File.mkdir_p!(out)

    state = start(Agendum.Sample.build(@today), width: 80, height: 25)

    state = %{
      state
      | now: ~N[2026-10-12 20:52:00],
        today: @today,
        path: "/home/me/planner.agendum"
    }

    # --only "a,b" keeps the shots of those names; without it, all of them
    only = if opts[:only], do: String.split(opts[:only], ","), else: nil
    shots = for {name, _} = shot <- shots(state), only == nil or name in only, do: shot

    for {name, screen} <- shots,
        do: ScreenPNG.write(Render.render(screen), theme, Path.join(out, name <> ".png"))

    IO.puts("Wrote #{length(shots)} screens to #{out}")
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
      {"16-nested-box",
       press(s, [{:f, 9}, :down, :down, :down, :down, {:f, 6}, :down, :down, :enter])}
    ]
  end
end

Screenshots.run(System.argv())
