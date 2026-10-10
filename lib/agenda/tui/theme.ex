defmodule Agenda.TUI.Theme do
  @moduledoc """
  Maps symbolic styles to ANSI SGR codes (SPEC R40). `Render` only names
  styles; the theme decides how they look.

    * `:classic` imitates the blue-and-white look of a DOS text-mode
      application (the default)
    * `:mono` uses only bold, dim, underline and reverse video, for
      monochrome terminals, screen readers and NO_COLOR

  Like Agenda, which chose colour or monochrome when it was installed, the
  theme is picked when the program starts (`Agenda.CLI`), not in the file.
  """

  @type name :: :classic | :mono

  # SGR: 0 reset, 1 bold, 2 dim, 4 underline, 7 reverse; 30-37 fg, 40-47 bg, 90-97 bright fg
  @themes %{
    classic: %{
      normal: "0;97;44",
      title: "0;30;46",
      indicator: "0;1;93;46",
      section: "0;1;93;44",
      column_head: "0;1;96;44",
      item: "0;97;44",
      item_done: "0;37;44",
      cell: "0;96;44",
      cursor: "0;30;47",
      cursor_cell: "0;30;106",
      edit: "0;30;107",
      edit_cursor: "0;97;40",
      edit_hint: "0;90;107",
      symbol: "0;1;92;44",
      menu: "0;30;46",
      menu_selected: "0;97;40",
      menu_help: "0;97;44",
      prompt: "0;1;97;44",
      message: "0;1;92;44",
      error: "0;1;97;41",
      keybar: "0;30;46",
      keybar_key: "0;1;97;46",
      box: "0;30;47",
      box_selected: "0;97;40",
      dim: "0;37;44",
      calc: "0;1;96;44"
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
      cursor: "0;7",
      cursor_cell: "0;1;7",
      edit: "0;4",
      edit_cursor: "0;7",
      edit_hint: "0;2;4",
      symbol: "0;1",
      menu: "0;7",
      menu_selected: "0;1",
      menu_help: "0",
      prompt: "0;1",
      message: "0;1",
      error: "0;1;7",
      keybar: "0;7",
      keybar_key: "0;1;7",
      box: "0;7",
      box_selected: "0;1",
      dim: "0;2",
      calc: "0;1"
    }
  }

  @doc "The theme names, default first."
  @spec names() :: [name]
  def names, do: [:classic, :mono]

  @doc "The style → SGR map of a theme."
  @spec styles(name) :: %{atom => String.t()}
  def styles(theme), do: Map.fetch!(@themes, theme)

  @doc "A theme name typed by the user."
  @spec parse(String.t()) :: {:ok, name} | :error
  def parse(text) do
    case Enum.find(names(), &(Atom.to_string(&1) == String.downcase(text))) do
      nil -> :error
      name -> {:ok, name}
    end
  end

  @spec sgr(atom, name) :: String.t()
  def sgr(style, theme \\ :classic) do
    styles = styles(theme)
    "\e[" <> Map.get(styles, style, styles.normal) <> "m"
  end
end
