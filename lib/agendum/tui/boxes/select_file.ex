defmodule Agendum.TUI.Boxes.SelectFile do
  @moduledoc """
  The Select File box (F3 in a prompt for a file name; SPEC R51; User's
  Guide 22-4 to 22-5, Help "Select a File"): a folder's subfolders and the
  files a prompt can use, to pick one instead of typing its name.

    * `../` goes up; a folder ends in `/`; files are those with the
      prompt's extensions (`.agendum` and `.agenda` for opening and saving
      files, `.json` for import and export, `.txt` for printing, `.txt`
      and `.md` for a note, `.opml` and `.xml` for feed lists)
    * ↑ ↓ PGUP PGDN HOME END move; typing narrows the list to names
      containing what is typed (BACKSPACE takes a letter back)
    * ENTER opens a folder, or puts the file in the prompt
    * F7 shows when each was last changed
    * ESC goes back to the prompt as it was

  The shell reads folders (`{:list_dir, dir}`, answered by
  `listed/3`); until then the box says it is reading. Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :accept, indicator: "CHOICES"

  alias Agendum.Core.DateFormat
  alias Agendum.TUI.{Boxes.Box, Typing.LineEdit, State}

  @extensions %{
    retrieve: [".agendum", ".agenda"],
    startup_open: [".agendum", ".agenda"],
    new_file: [".agendum", ".agenda"],
    save_as: [".agendum", ".agenda"],
    save_as_then_quit: [".agendum", ".agenda"],
    import_json: [".json"],
    export_json: [".json"],
    export: [".txt"],
    note_import: [".txt", ".md"],
    note_export: [".txt", ".md"],
    # feed lists (R75): OPML files, which some readers save as .xml
    import_opml: [".opml", ".xml"],
    export_opml: [".opml", ".xml"]
  }

  @doc "Whether a prompt asks for a file name (and so offers F3)."
  def file_prompt?(action), do: extensions(action) != nil

  defp extensions({:save_as_then, _}), do: @extensions.save_as
  defp extensions(action), do: Map.get(@extensions, action)

  @doc "Opens the box over a file-name prompt, in the folder of what is typed."
  def open(state, prompt) do
    typed = String.trim(state.edit.line.text)
    base = if state.path, do: Path.dirname(state.path), else: "."

    dir =
      cond do
        typed == "" -> base
        String.ends_with?(typed, "/") -> typed
        true -> Path.dirname(Path.expand(typed, base))
      end
      |> Path.expand()

    mode = %{
      type: :select_file,
      dir: dir,
      entries: :reading,
      extensions: extensions(prompt.action),
      cursor: 0,
      filter: "",
      dates: false,
      line: state.edit.line
    }

    state |> State.push(mode) |> State.effect({:list_dir, dir})
  end

  @doc "The shell's listing of a folder, for the box showing it."
  def listed(state, dir, result) do
    case Enum.find_index(state.modes, &match?(%{type: :select_file, dir: ^dir}, &1)) do
      nil ->
        state

      i ->
        entries =
          case result do
            {:ok, entries} -> entries
            {:error, reason} -> {:error, reason}
          end

        %{state | modes: List.update_at(state.modes, i, &%{&1 | entries: entries, cursor: 0})}
    end
  end

  @impl Box
  def about(_state, _mode) do
    """
    Choose a file: the folders and the files that fit, .. going up a
    folder. Type to narrow the list; BACKSPACE takes a letter back.

    ENTER opens the highlighted folder, or takes the file; F7 shows or hides
    the dates. ESC goes back to the prompt as it was.
    """
  end

  @impl Box
  # typing narrows the list; BACKSPACE takes a letter back
  def handle(state, mode, {:char, c}), do: narrow(state, mode, mode.filter <> c)

  def handle(state, mode, :backspace),
    do: narrow(state, mode, String.slice(mode.filter, 0..-2//1))

  def handle(state, _mode, _key), do: state

  # R65
  @impl Box
  def keymap(_mode) do
    %{
      :up => :up,
      :down => :down,
      :pgup => :page_up,
      :pgdn => :page_down,
      :home => :first,
      :end => :last,
      {:f, 7} => :dates,
      :enter => :open,
      :esc => :close
    }
  end

  @impl Box
  def commands(_mode) do
    [{:open, "Open", "Open the file or folder"}, {:dates, "Dates", "Show or hide the dates"}] ++
      Box.list_moves() ++
      [
        {:page_up, "Page up", "Ten up"},
        {:page_down, "Page down", "Ten down"},
        {:close, "Back", "Back to the prompt"}
      ]
  end

  @impl Box
  def run(state, mode, :close), do: back(state, mode.line)
  def run(state, mode, :dates), do: State.put_mode(state, %{mode | dates: not mode.dates})
  def run(state, mode, :open), do: choose(state, mode, Enum.at(rows(mode), mode.cursor))

  def run(state, mode, id) do
    count = length(rows(mode))

    case id do
      :page_up -> Box.list_move(state, %{mode | cursor: mode.cursor - 9}, count, :up)
      :page_down -> Box.list_move(state, %{mode | cursor: mode.cursor + 9}, count, :down)
      _ -> Box.list_move(state, mode, count, id)
    end
  end

  defp narrow(state, mode, filter), do: State.put_mode(state, %{mode | filter: filter, cursor: 0})

  defp choose(state, _mode, nil), do: state

  defp choose(state, mode, %{name: "..", dir?: true}), do: go(state, mode, Path.dirname(mode.dir))

  defp choose(state, mode, %{name: name, dir?: true}),
    do: go(state, mode, Path.join(mode.dir, name))

  defp choose(state, mode, %{name: name}) do
    path = Path.join(mode.dir, name)
    back(state, LineEdit.new(path))
  end

  defp go(state, mode, dir) do
    state
    |> State.put_mode(%{mode | dir: dir, entries: :reading, cursor: 0, filter: ""})
    |> State.effect({:list_dir, dir})
  end

  # back to the prompt, its line as given
  defp back(state, line), do: %{State.pop(state) | edit: %{line: line}}

  @doc "The rows shown: `..`, then the folders and the files that fit, narrowed by what is typed."
  def rows(%{entries: entries} = mode) when is_list(entries) do
    filter = String.downcase(mode.filter)
    up = if mode.dir == "/", do: [], else: [%{name: "..", dir?: true, modified: nil}]

    shown =
      Enum.filter(entries, fn e ->
        (e.dir? or String.downcase(Path.extname(e.name)) in mode.extensions) and
          String.contains?(String.downcase(e.name), filter)
      end)

    if filter == "", do: up ++ shown, else: shown
  end

  def rows(_mode), do: []

  # the folder, its start left out when long
  @impl Box
  def title(state, mode) do
    dir = mode.dir
    room = max(width(state, mode) - 16, 10)

    dir =
      if String.length(dir) > room, do: "…" <> String.slice(dir, -(room - 1)..-1//1), else: dir

    "Select file: " <> dir
  end

  @impl Box
  def content(state, mode, _inner, max_rows) do
    rows =
      state
      |> lines(mode, max_rows)
      |> Enum.map(fn {style, text} -> [{style, " " <> text}] end)

    rows ++ [[{:box, " ENTER opens · type to narrow · F7 dates · ESC back"}]]
  end

  @impl Box
  def keys(_state, _mode),
    do: [
      {"ENTER", "Open", "Open the folder or pick the file"},
      {"type", "Narrow", "Narrow the list"},
      {"F7", "Dates", "Show the dates"},
      {"ESC", "Back", "Back to the prompt"}
    ]

  @impl Box
  def help, do: nil

  # `{style, text}`, the highlighted row selected
  defp lines(state, mode, max_rows) do
    body =
      case mode.entries do
        :reading ->
          [{:box, "Reading the folder…"}]

        {:error, reason} ->
          [{:box, "This folder cannot be read: #{reason}"}]

        _ ->
          rows = rows(mode)
          top = max(mode.cursor - (max_rows - 4), 0)

          case rows do
            [] ->
              [{:box, "No files here that fit (#{Enum.join(mode.extensions, " ")})"}]

            _ ->
              rows
              |> Enum.with_index()
              |> Enum.drop(top)
              |> Enum.take(max(max_rows - 3, 1))
              |> Enum.map(fn {row, i} ->
                {if(i == mode.cursor, do: :box_selected, else: :box), row_text(state, mode, row)}
              end)
          end
      end

    narrowed = if mode.filter == "", do: [], else: [{:box, "Narrowed to: " <> mode.filter}]
    body ++ [{:box, ""}] ++ narrowed
  end

  defp row_text(state, mode, row) do
    name = if row.dir?, do: row.name <> "/", else: row.name

    if mode.dates and row.modified,
      do:
        Agendum.TUI.Terminal.Draw.pad(name, 36) <>
          DateFormat.datetime(row.modified, state.db.date_format),
      else: name
  end
end
