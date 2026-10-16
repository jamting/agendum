defmodule Agendum.TUI.Terminal.Theme.Palettes do
  @moduledoc """
  Themes made from terminal colour schemes (`docs/THEMES.md`, copied from
  terminalthemes.com): Modus Operandi, Modus Vivendi, Alabaster, Zenburn,
  Ayu and Borland (SPEC R40).

  A scheme gives a palette of colour roles (background, foreground,
  selection, cursor and a few ANSI colours); `styles/0` lays every screen
  style out on those roles, the same way for each scheme, so the five look
  alike in their parts and differ only in colour. `Agendum.TUI.Terminal.Theme` uses
  both at compile time.

  Each role is `{"#rrggbb", ansi}`: the exact colour for terminals taking
  24-bit colour, and an ANSI foreground code (30-37, 90-97, or 39 for the
  terminal's own default) for the others. Where the scheme's colour is one
  of its 16 ANSI colours, the code is that colour's, so a terminal set to
  the same scheme shows it exactly even without 24-bit colour.
  """

  @typedoc "A colour role: the 24-bit colour and the ANSI code to fall back on."
  @type role :: {String.t(), pos_integer}

  # The roles:
  #   bg, fg            the screen
  #   sel_bg, sel_fg    the scheme's selection: the control panel and menus
  #   cursor, cursor_fg the highlight (the scheme's cursor colours)
  #   tint              the highlighted line, boxes and the key bar
  #   shade             a box's shadow
  #   muted             done items, hints, the screen behind a box
  #   accent            section heads, column entries, box frames
  #   accent2           column heads and item symbols
  #   alert             errors
  @palettes %{
    modus_operandi: %{
      bg: {"#ffffff", 39},
      fg: {"#000000", 39},
      sel_bg: {"#bdbdbd", 37},
      sel_fg: {"#000000", 30},
      # the scheme's cursor (black) is too harsh for the highlight:
      # Modus's own intense blue background
      cursor: {"#9fcfff", 36},
      cursor_fg: {"#000000", 97},
      # Modus's own colour for the current line
      tint: {"#dae5ec", 37},
      shade: {"#9f9f9f", 90},
      muted: {"#595959", 90},
      accent: {"#0031a9", 34},
      accent2: {"#721045", 35},
      alert: {"#a60000", 31}
    },
    modus_vivendi: %{
      bg: {"#000000", 39},
      fg: {"#ffffff", 39},
      sel_bg: {"#5a5a5a", 90},
      sel_fg: {"#ffffff", 97},
      # the scheme's cursor (white) is too harsh for the highlight:
      # Modus's own intense blue background
      cursor: {"#2a40b8", 34},
      cursor_fg: {"#ffffff", 30},
      tint: {"#2f3849", 90},
      shade: {"#000000", 30},
      # ANSI 8 (#595959) is too dark to read on black
      muted: {"#989898", 37},
      accent: {"#2fafff", 34},
      accent2: {"#00d3d0", 36},
      alert: {"#ff5f59", 31}
    },
    alabaster: %{
      bg: {"#f7f7f7", 39},
      fg: {"#000000", 39},
      sel_bg: {"#bfdbfe", 34},
      sel_fg: {"#000000", 97},
      cursor: {"#007acc", 94},
      # the scheme's cursor text (#bfdbfe) is faint on its cursor: white
      cursor_fg: {"#ffffff", 97},
      tint: {"#e4e4e4", 90},
      shade: {"#bdbdbd", 90},
      muted: {"#777777", 90},
      accent: {"#325cc0", 34},
      accent2: {"#7a3e9d", 35},
      alert: {"#aa3731", 31}
    },
    zenburn: %{
      bg: {"#3f3f3f", 39},
      fg: {"#dcdccc", 39},
      sel_bg: {"#21322f", 30},
      sel_fg: {"#c2d87a", 93},
      # Zenburn's cursor (#73635a) is too dull for the highlight: its yellow
      cursor: {"#f0dfaf", 33},
      cursor_fg: {"#3f3f3f", 30},
      tint: {"#4f4f4f", 30},
      shade: {"#2b2b2b", 30},
      muted: {"#709080", 90},
      # Zenburn's ANSI blue (#506070) is unreadable on its background
      accent: {"#94bff3", 94},
      accent2: {"#f0dfaf", 33},
      alert: {"#dca3a3", 91}
    },
    ayu: %{
      bg: {"#0b0e14", 39},
      fg: {"#bfbdb6", 39},
      sel_bg: {"#409fff", 94},
      sel_fg: {"#0b0e14", 30},
      cursor: {"#e6b450", 33},
      cursor_fg: {"#0b0e14", 30},
      tint: {"#1c212b", 90},
      shade: {"#000000", 30},
      muted: {"#686868", 90},
      accent: {"#53bdfa", 34},
      accent2: {"#f9af4f", 33},
      alert: {"#ea6c73", 31}
    },
    # yellow on blue, as Borland's DOS tools
    borland: %{
      bg: {"#0000a4", 39},
      fg: {"#ffff4e", 39},
      sel_bg: {"#a4a4a4", 37},
      sel_fg: {"#0000a4", 34},
      # the scheme's cursor text (white) is faint on its orange: the screen's blue
      cursor: {"#ffa560", 33},
      cursor_fg: {"#0000a4", 34},
      tint: {"#1c1cc4", 90},
      shade: {"#000050", 30},
      # ANSI 8 (#7c7c7c) is hard to read on the blue: the selection's grey
      muted: {"#a4a4a4", 37},
      accent: {"#ffffff", 97},
      accent2: {"#a8ff60", 92},
      alert: {"#ff6c60", 31}
    }
  }

  # The styles, as {foreground role, background role} or with attributes:
  # bold, dim, or reverse (which swaps the two, so `{fg, bg, [:reverse]}`
  # draws bg-coloured text on fg, also on 16-colour terminals, where bg and
  # fg are the terminal's own defaults).
  @styles %{
    normal: {:fg, :bg},
    title: {:sel_fg, :sel_bg},
    indicator: {:sel_fg, :sel_bg, [:bold]},
    section: {:accent, :bg, [:bold]},
    column_head: {:accent2, :bg, [:bold]},
    item: {:fg, :bg},
    item_done: {:muted, :bg},
    cell: {:accent, :bg},
    row: {:fg, :tint},
    row_done: {:muted, :tint},
    row_cell: {:accent, :tint},
    cursor: {:cursor_fg, :cursor},
    cursor_cell: {:cursor_fg, :cursor},
    edit: {:sel_fg, :sel_bg},
    edit_cursor: {:cursor_fg, :cursor},
    note_match: {:cursor_fg, :cursor},
    edit_hint: {:sel_fg, :sel_bg, [:dim]},
    symbol: {:accent2, :bg},
    menu: {:sel_fg, :sel_bg},
    menu_selected: {:cursor_fg, :cursor},
    menu_help: {:sel_fg, :sel_bg},
    panel: {:sel_fg, :sel_bg},
    panel_hint: {:sel_fg, :sel_bg, [:dim]},
    prompt: {:sel_fg, :sel_bg},
    message: {:sel_fg, :sel_bg, [:bold]},
    error: {:alert, :bg, [:bold, :reverse]},
    keybar: {:fg, :tint},
    keybar_key: {:accent, :tint, [:bold]},
    box: {:fg, :tint},
    box_selected: {:cursor_fg, :cursor},
    box_frame: {:accent, :tint},
    box_title: {:accent, :tint, [:bold]},
    box_title_dim: {:muted, :tint},
    shadow: {:muted, :shade},
    backdrop: {:muted, :bg},
    dim: {:muted, :bg},
    calc: {:accent, :bg},
    catmgr: {:fg, :bg},
    catmgr_head: {:accent, :bg, [:bold]},
    catmgr_note: {:muted, :bg},
    help: {:fg, :bg},
    help_dim: {:muted, :bg},
    help_title: {:accent, :bg, [:bold]},
    help_rule: {:muted, :bg},
    help_pane: {:fg, :tint},
    help_pane_title: {:accent, :tint, [:bold]},
    splash_logo: {:fg, :bg, [:reverse]},
    splash_title: {:fg, :tint, [:bold]},
    splash_value: {:accent, :tint}
  }

  @doc "The schemes' names, in the order they are offered."
  @spec names() :: [atom]
  def names, do: [:modus_operandi, :modus_vivendi, :alabaster, :zenburn, :ayu, :borland]

  @doc """
  The colour roles of a scheme, each as `{"r;g;b", ansi}`: the hex colour
  already turned into the decimal triple an SGR sequence takes.
  """
  @spec palette(atom) :: %{atom => {String.t(), pos_integer}}
  def palette(name) do
    # Map.new/2 builds a map from {key, value} pairs the function returns
    Map.new(Map.fetch!(@palettes, name), fn {role, {hex, ansi}} -> {role, {rgb(hex), ansi}} end)
  end

  @doc "The style → spec map every scheme shares, in roles of `palette/1`."
  @spec styles() :: %{atom => tuple}
  def styles, do: @styles

  # "#0031a9" → "0;49;169"
  defp rgb("#" <> hex) do
    # `for <<pair::binary-size(2) <- hex>>` walks the string two bytes at a time
    numbers = for <<pair::binary-size(2) <- hex>>, do: String.to_integer(pair, 16)
    Enum.join(numbers, ";")
  end
end
