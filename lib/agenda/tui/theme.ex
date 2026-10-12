defmodule Agenda.TUI.Theme do
  @moduledoc """
  Maps symbolic styles to ANSI SGR codes (SPEC R40). `Render` only names
  styles; the theme decides how they look.

    * `:classic` imitates Agenda 2.0 on a colour VGA screen (the default):
      black text on a grey screen, blue section heads and column entries,
      white-on-red highlights, cyan boxes in a solid blue frame with a
      shadow, a cyan category manager and yellow-on-blue help
    * `:blue` is white on blue, the look of the clone before it was
      compared with the real Agenda, with the same parts: a control panel
      (black on cyan), the highlighted line (bright blue), box titles,
      shadows and the faded screen behind a box
    * `:mono` uses only bold, dim, underline and reverse video, for
      monochrome terminals, screen readers and NO_COLOR: the control panel
      in reverse video like the title bar, the highlighted line in bold

  A `:classic` style is a pair of the 16 VGA colours (plus `:tint`, the
  background of the highlighted line). Terminals that say they take 24-bit
  colour (`COLORTERM=truecolor`) get the VGA colours exactly; others get the
  nearest of their 16 ANSI colours, whose shades depend on the terminal.

  Like Agenda, where Utilities Customize chose colour or monochrome for all
  files, the theme is the person's: File ▸ Customize, saved in their
  preferences (`Agenda.Preferences`), or `--theme` for a session; never
  in the file.
  """

  @type name :: :classic | :blue | :mono
  @type depth :: :ansi16 | :truecolor
  @type colour :: atom
  @type spec :: String.t() | {colour, colour}

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
      catmgr: {:black, :cyan},
      catmgr_head: {:blue, :cyan},
      catmgr_note: {:blue, :cyan},
      help: {:yellow, :blue},
      splash_logo: {:white, :black},
      splash_title: {:white, :cyan},
      splash_value: {:blue, :cyan}
    },
    blue: %{
      normal: "0;97;44",
      title: "0;30;46",
      indicator: "0;1;93;46",
      section: "0;1;93;44",
      column_head: "0;1;96;44",
      item: "0;97;44",
      item_done: "0;37;44",
      cell: "0;96;44",
      row: "0;97;104",
      row_done: "0;37;104",
      row_cell: "0;96;104",
      cursor: "0;30;47",
      cursor_cell: "0;30;106",
      edit: "0;30;107",
      edit_cursor: "0;97;40",
      edit_hint: "0;90;107",
      symbol: "0;1;92;44",
      menu: "0;30;46",
      menu_selected: "0;97;40",
      menu_help: "0;30;46",
      panel: "0;30;46",
      panel_hint: "0;34;46",
      prompt: "0;30;46",
      message: "0;1;34;46",
      error: "0;1;97;41",
      keybar: "0;30;46",
      keybar_key: "0;1;97;46",
      box: "0;30;47",
      box_selected: "0;97;40",
      box_frame: "0;30;47",
      box_title: "0;1;34;47",
      box_title_dim: "0;90;47",
      shadow: "0;37;40",
      backdrop: "0;90;44",
      dim: "0;37;44",
      calc: "0;1;96;44",
      catmgr: "0;97;44",
      catmgr_head: "0;1;93;44",
      catmgr_note: "0;37;44",
      help: "0;97;44",
      splash_logo: "0;97;40",
      splash_title: "0;1;30;47",
      splash_value: "0;34;47"
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
      splash_logo: "0;1",
      splash_title: "0;1;7",
      splash_value: "0;4;7"
    }
  }

  @doc "The theme names, default first."
  @spec names() :: [name]
  def names, do: [:classic, :blue, :mono]

  @doc "The style → spec map of a theme: SGR codes, or a pair of VGA colours."
  @spec styles(name) :: %{atom => spec}
  def styles(theme), do: Map.fetch!(@themes, theme)

  @doc "A theme name typed by the user."
  @spec parse(String.t()) :: {:ok, name} | :error
  def parse(text) do
    case Enum.find(names(), &(Atom.to_string(&1) == String.downcase(text))) do
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
    "\e[" <> codes(Map.get(styles, style, styles.normal), depth) <> "m"
  end

  defp codes(sgr, _depth) when is_binary(sgr), do: sgr

  defp codes({fg, bg}, :ansi16) do
    {_, f} = Map.fetch!(@colours, fg)
    {_, b} = Map.fetch!(@colours, bg)
    "0;#{f};#{b + 10}"
  end

  defp codes({fg, bg}, :truecolor) do
    {f, _} = Map.fetch!(@colours, fg)
    {b, _} = Map.fetch!(@colours, bg)
    "0;38;2;#{f};48;2;#{b}"
  end
end
