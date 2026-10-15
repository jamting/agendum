defmodule Agendum.TUI.Render.Help do
  @moduledoc """
  F1 then `a` in the help (R65): every key, made from the keymaps
  (`Agendum.TUI.Keymap`, `Agendum.TUI.Commands`), so it says what the keys
  do and cannot drift from them. First the keys that work almost
  everywhere, then the view's, the note editor's and typing's, then the
  rest; a few words for Mac keyboards at the end. Also the rows the
  command list (F1 then `c`) draws. Pure.
  """

  alias Agendum.TUI.{Command, Commands, Keymap}
  alias Agendum.TUI.Boxes.Box

  # each part: its heading and the places whose keys it lists
  @parts [
    {"Almost everywhere (not while typing)", [:global]},
    {"In a view", [:view]},
    {"In a note", [:note, :text]},
    {"Typing on a line (an item, a name, a box's field, a prompt)", [:line]},
    {"In the category manager (F9)", [:catmgr]},
    {"In the view manager (F8)", [:viewmgr]},
    {"In the menu (F10 or /)", [:menu]},
    {"In every box", [:box]},
    {"In a box of settings", [:settings]},
    {"Moving items (ALT-F10)", [:move_item]},
    {"Moving a section or a column (ALT-F10 on its head)", [:section_move, :column_move]},
    {"A column's width (View ▸ Column ▸ Width)", [:column_width]},
    {"Browsing dates (ALT-B)", [:browse]},
    {"Searching the view (ALT-F6)", [:searching]}
  ]

  # what a part adds below its keys
  @notes %{
    "Almost everywhere (not while typing)" => [
      "F1 is help wherever you are (then c: the commands there, d: what a key does).",
      "ESC cancels or goes back."
    ],
    "In a view" => [
      "Typing adds an item to the section (or types in the highlighted column).",
      "ALT-1 … ALT-9 before a move give a count: ALT-1 ALT-0 ↓ goes ten rows down."
    ],
    "In the menu (F10 or /)" => ["A letter chooses the entry it begins."],
    "In every box" => ["Each box has keys of its own: F1 then c in the box lists them."]
  }

  @mac [
    "On a Mac, hold fn for F1…F10 (or make them standard function keys in",
    "System Settings ▸ Keyboard). ALT is ⌥ with \"Use Option as Meta key\";",
    "ALT-F1…F10 are ⌥ with the function key. ⌘ shortcuts (⌘N, ⌘Z, ⌘S …) work",
    "once the terminal maps them to the CTRL keys above (docs/KEYBOARD.md)."
  ]

  @doc "The lines of the all-keys page, `width` wide, as `{style, text}` segments."
  @spec lines(pos_integer) :: [[{atom, String.t()}]]
  def lines(width) do
    parts =
      Enum.flat_map(@parts, fn {heading, places} ->
        rows =
          for place <- places,
              {command, keys} <- commands(place),
              text <- row(command, keys),
              do: [{:normal, fit(text, width)}]

        notes =
          for note <- Map.get(@notes, heading, []), do: [{:normal, fit("   " <> note, width)}]

        [[{:normal, " " <> heading}] | rows] ++ notes ++ [[{:normal, ""}]]
      end)

    [[{:normal, " ALL KEYS"}], [{:normal, ""}]] ++
      parts ++ Enum.map(@mac, &[{:normal, fit(" " <> &1, width)}])
  end

  # a place's commands with their keys; a box of settings has the keys
  # `Box.settings_keymap/1` gives every settings box
  defp commands(:settings) do
    keymap = Box.settings_keymap()

    for {id, name, summary} <- Box.settings_commands(),
        do: {%Command{id: id, name: name, summary: summary}, keys(keymap, id)}
  end

  defp commands(place) do
    for command <- Commands.all(place), do: {command, Keymap.keys_for(place, command.id)}
  end

  defp keys(keymap, id), do: Keymap.sort(for {key, ^id} <- keymap, do: key)

  # --- the rows of a command ---------------------------------------------------

  @name_width 18
  @keys_width 23

  @doc """
  A command's rows: its name, keys and summary; keys that do not fit go on
  to further rows under the first (DEL F4 ALT-F4 CTRL-D CTRL-K).
  """
  @spec row(Command.t(), [term]) :: [String.t()]
  def row(command, keys) do
    [first | more] = key_lines(Enum.map(keys, &Keymap.name/1))
    blank = String.duplicate(" ", @name_width)

    [" " <> pad(command.name, @name_width) <> pad(first, @keys_width) <> command.summary] ++
      for(keys <- more, do: " " <> blank <> keys)
  end

  defp key_lines(names) do
    names
    |> Enum.reduce([], fn
      name, [] -> [name]
      name, [line | rest] -> add_key(line, name, rest)
    end)
    |> Enum.reverse()
    |> then(&if(&1 == [], do: [""], else: &1))
  end

  defp add_key(line, name, rest) do
    if String.length(line) + 1 + String.length(name) < @keys_width,
      do: [line <> " " <> name | rest],
      else: [name, line | rest]
  end

  defp pad(text, width), do: String.pad_trailing(text, width - 1) <> " "

  @doc "A line cut to `width`."
  @spec fit(String.t(), integer) :: String.t()
  def fit(text, width), do: String.slice(text, 0, max(width, 0))
end
