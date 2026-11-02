# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Terminal.Theme do
  @moduledoc """
  Maps symbolic styles to ANSI SGR codes (SPEC R40). `Render` only names
  styles; the theme decides how they look.

    * `:classic` imitates Agenda 2.0 on a colour VGA screen (the default):
      black text on a grey screen, blue section heads and column entries,
      white-on-red highlights, cyan boxes in a solid blue frame with a
      shadow, a white-on-cyan category manager and yellow-on-blue help
    * `:mono` uses only bold, dim, underline and reverse video, for
      monochrome terminals, screen readers and NO_COLOR: the control panel
      in reverse video like the title bar, the highlighted line in bold
    * `:modus_operandi`, `:modus_vivendi`, `:alabaster`, `:zenburn`,
      `:ayu`, `:borland` and `:amber` take the colours of those terminal schemes (`docs/THEMES.md`),
      all laid out alike by `Agendum.TUI.Terminal.Theme.Palettes`: the screen in the
      scheme's colours, the control panel and menus in its selection
      colours, the highlight in its cursor colours, boxes on a tint

  A `:classic` style is a pair of the 16 VGA colours (plus `:tint`, the
  background of the highlighted line); a scheme's style is a pair of its
  colour roles, perhaps with attributes (`{fg, bg, [:bold]}`). Terminals
  that say they take 24-bit colour (`COLORTERM=truecolor`) get the colours
  exactly; others get the nearest of their 16 ANSI colours, whose shades
  depend on the terminal.

  Like Agenda, where Utilities Customize chose colour or monochrome for all
  files, the theme is the person's: Utilities ▸ Customize, saved in their
  preferences (`Agendum.Preferences`), or `--theme` for a session; never
  in the file.
  """

  alias Agendum.TUI.Terminal.Theme.Palettes

  @type name ::
          :classic
          | :mono
          | :modus_operandi
          | :modus_vivendi
          | :alabaster
          | :zenburn
          | :ayu
          | :borland
          | :amber
  @type depth :: :ansi16 | :truecolor
  @type colour :: atom
  @type attribute :: :bold | :dim | :reverse
  @type spec :: String.t() | {colour, colour} | {colour, colour, [attribute]}

  # The VGA text-mode palette: {24-bit colour, ANSI foreground code}. An ANSI
  # background code is the foreground's plus 10.
  @colours %{
    black: {"0;0;0", 30},
    blue: {"0;0;170", 34},
    green: {"0;170;0", 32},
    cyan: {"0;170;170", 36},
    red: {"170;0;0", 31},
    magenta: {"170;0;170", 35},
    brown: {"170;85;0", 33},
    grey: {"170;170;170", 37},
    dark_grey: {"85;85;85", 90},
    light_blue: {"85;85;255", 94},
    light_green: {"85;255;85", 92},
    light_cyan: {"85;255;255", 96},
    light_red: {"255;85;85", 91},
    light_magenta: {"255;85;255", 95},
    yellow: {"255;255;85", 93},
    white: {"255;255;255", 97},
    # not VGA: the highlighted line, a lighter grey than the screen
    tint: {"200;200;200", 97}
  }

  # Each scheme's colours, in the same {24-bit colour, ANSI code} form
  @palettes Map.new(Palettes.names(), &{&1, Palettes.palette(&1)})

  @attributes %{bold: 1, dim: 2, reverse: 7}

  # SGR: 0 reset, 1 bold, 2 dim, 4 underline, 7 reverse; 30-37 fg, 40-47 bg, 90-97 bright fg
  @themes %{
    classic: %{
      normal: {:black, :grey},
      title: {:white, :blue},
      indicator: {:white, :blue},
      section: {:blue, :grey},
      column_head: {:blue, :grey},
      item: {:black, :grey},
      item_done: {:dark_grey, :grey},
      cell: {:blue, :grey},
      row: {:black, :tint},
      row_done: {:dark_grey, :tint},
      row_cell: {:blue, :tint},
      cursor: {:white, :red},
      cursor_cell: {:white, :red},
      edit: {:black, :cyan},
      edit_cursor: {:white, :red},
      note_match: {:white, :red},
      # Zettel links (R73b): a link, a broken one, on the highlighted line
      link: {:magenta, :grey},
      link_broken: {:red, :grey},
      row_link: {:magenta, :tint},
      row_link_broken: {:red, :tint},
      edit_hint: {:blue, :cyan},
      symbol: {:black, :grey},
      menu: {:white, :blue},
      menu_selected: {:white, :red},
      menu_help: {:white, :blue},
      panel: {:white, :blue},
      panel_hint: {:yellow, :blue},
      prompt: {:white, :blue},
      message: {:yellow, :blue},
      error: {:white, :red},
      keybar: {:grey, :blue},
      keybar_key: {:white, :blue},
      box: {:black, :cyan},
      box_selected: {:white, :red},
      box_frame: {:blue, :blue},
      box_title: {:light_cyan, :blue},
      box_title_dim: {:cyan, :blue},
      shadow: {:dark_grey, :black},
      backdrop: {:dark_grey, :grey},
      dim: {:dark_grey, :grey},
      calc: {:blue, :grey},
      catmgr: {:white, :cyan},
      catmgr_head: {:blue, :cyan},
      catmgr_note: {:blue, :cyan},
      help: {:yellow, :blue},
      # a command F1 c lists that cannot run now (R65a)
      help_dim: {:grey, :blue},
      # the help's frame (R65c): its headings, rules and the pane at its foot
      help_title: {:white, :blue},
      help_rule: {:cyan, :blue},
      help_pane: {:black, :cyan},
      help_pane_title: {:blue, :cyan},
      help_frame: {:white, :blue},
      # a topic's links, and the highlighted one, as Agenda's help (bright
      # white on blue, white on red; checked in Agenda 2.0, 2026-10-26)
      help_link: {:white, :blue},
      help_link_selected: {:white, :red},
      splash_title: {:white, :cyan},
      splash_value: {:blue, :cyan}
    },
    mono: %{
      normal: "0",
      title: "0;7",
      indicator: "0;1;7",
      section: "0;1",
      column_head: "0;1;4",
      item: "0",
      item_done: "0;2",
      cell: "0",
      row: "0;1",
      row_done: "0;1",
      row_cell: "0;1",
      cursor: "0;7",
      cursor_cell: "0;1;7",
      edit: "0;4",
      edit_cursor: "0;7",
      note_match: "0;7",
      link: "0;4",
      link_broken: "0;2;4",
      row_link: "0;1;4",
      row_link_broken: "0;1;2;4",
      edit_hint: "0;2;4",
      symbol: "0;1",
      menu: "0;7",
      menu_selected: "0;1",
      menu_help: "0;7",
      panel: "0;7",
      panel_hint: "0;2;7",
      prompt: "0;1;7",
      message: "0;1;7",
      error: "0;1;4",
      keybar: "0;7",
      keybar_key: "0;1;7",
      box: "0;7",
      box_selected: "0;1",
      box_frame: "0;7",
      box_title: "0;1;7",
      box_title_dim: "0;2;7",
      shadow: "0;2",
      backdrop: "0;2",
      dim: "0;2",
      calc: "0;1",
      catmgr: "0",
      catmgr_head: "0;1",
      catmgr_note: "0;2",
      help: "0",
      help_dim: "0;2",
      help_title: "0;1",
      help_rule: "0;2",
      help_pane: "0;7",
      help_pane_title: "0;1;7",
      help_frame: "0",
      help_link: "0;1",
      help_link_selected: "0;1;7",
      splash_title: "0;1;7",
      splash_value: "0;4;7"
    }
  }

  # the schemes share one layout (Palettes.styles/0), in their own colours
  @themes Map.merge(@themes, Map.new(Palettes.names(), &{&1, Palettes.styles()}))

  @doc "The theme names, default first."
  @spec names() :: [name]
  def names, do: [:classic, :mono | Palettes.names()]

  @doc "The style → spec map of a theme: SGR codes, or a pair of VGA colours."
  @spec styles(name) :: %{atom => spec}
  def styles(theme), do: Map.fetch!(@themes, theme)

  @doc "A theme's name as the user sees it: `:modus_operandi` → \"Modus Operandi\"."
  @spec label(name) :: String.t()
  def label(theme),
    do: theme |> Atom.to_string() |> String.split("_") |> Enum.map_join(" ", &String.capitalize/1)

  @doc ~S'A theme name typed by the user: "modus_operandi", "modus-operandi" or "Modus Operandi".'
  @spec parse(String.t()) :: {:ok, name} | :error
  def parse(text) do
    typed = text |> String.downcase() |> String.replace(["-", " "], "_")

    case Enum.find(names(), &(Atom.to_string(&1) == typed)) do
      nil -> :error
      name -> {:ok, name}
    end
  end

  @doc "How many colours a terminal takes, from its COLORTERM variable."
  @spec depth(String.t() | nil) :: depth
  def depth(colorterm) when colorterm in ["truecolor", "24bit"], do: :truecolor
  def depth(_colorterm), do: :ansi16

  @doc "The escape sequence that starts drawing in `style`."
  @spec sgr(atom, name, depth) :: String.t()
  def sgr(style, theme \\ :classic, depth \\ :ansi16) do
    styles = styles(theme)
    "\e[" <> codes(Map.get(styles, style, styles.normal), palette(theme), depth) <> "m"
  end

  # the colours a theme's pairs name: a scheme's roles, or the VGA colours
  defp palette(theme), do: Map.get(@palettes, theme, @colours)

  defp codes(sgr, _palette, _depth) when is_binary(sgr), do: sgr
  defp codes({fg, bg}, palette, depth), do: codes({fg, bg, []}, palette, depth)

  defp codes({fg, bg, attributes}, palette, depth) do
    # "0" resets, then e.g. ";1" for bold, before the colours
    prefix = Enum.map_join(["0" | Enum.map(attributes, &@attributes[&1])], ";", &to_string/1)
    prefix <> ";" <> colours(Map.fetch!(palette, fg), Map.fetch!(palette, bg), depth)
  end

  # An ANSI background code is the foreground's plus 10 (39, the default, too).
  defp colours({_, f}, {_, b}, :ansi16), do: "#{f};#{b + 10}"
  defp colours({f, _}, {b, _}, :truecolor), do: "38;2;#{f};48;2;#{b}"
end
