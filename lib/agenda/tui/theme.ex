defmodule Agenda.TUI.Theme do
  @moduledoc """
  Maps symbolic styles to ANSI SGR codes. The default palette imitates the
  blue-and-white look of a DOS text-mode application.
  """

  # SGR: 0 reset, 1 bold, 7 reverse; 30-37 fg, 40-47 bg, 90-97 bright fg
  @styles %{
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
    dim: "0;37;44"
  }

  @spec sgr(atom) :: String.t()
  def sgr(style), do: "\e[" <> Map.get(@styles, style, @styles.normal) <> "m"
end
