defmodule Agendum.TUI.HelpScreen do
  @moduledoc """
  The help screen (F1) and its two other pages (R65, ADR 0033), as Emacs's
  C-h then a letter:

    * the keys (`Agendum.TUI.Render.Help`'s text): ↑↓ PGUP PGDN scroll,
      `c` and `d` go to the other pages, any other key returns;
    * `c`, the command list: the commands that can run where F1 was
      pressed (its own first, then those of every screen), each with its
      keys and summary; ENTER runs the highlighted one, ESC returns;
    * `d`, describe key: the next key pressed is described (which command
      it runs there, or the macro attached to it), then any key returns.

  The mode remembers where F1 was pressed (`from`): `:view`, `:catmgr`,
  `:viewmgr`, `:note`, or `:elsewhere` for a screen whose keys are not in a keymap yet. Pure.
  """

  alias Agendum.TUI.{Command, Commands, Keymap, Macros, State}
  alias Agendum.TUI.Boxes.ViewManager
  alias Agendum.TUI.CategoryScreens.Manager
  alias Agendum.TUI.Render.Help
  alias Agendum.TUI.Typing.{TextEdit, Wrap}
  alias Agendum.TUI.Update.{Notes, ViewKeys}

  @doc "Opens the help screen on its keys page."
  @spec open(State.t()) :: State.t()
  def open(state) do
    from =
      case {state.edit, state.modes} do
        {nil, []} -> :view
        {nil, [%{type: type} | _]} when type in [:catmgr, :viewmgr, :note] -> type
        _ -> :elsewhere
      end

    State.push(state, %{type: :help, top: 0, page: :keys, from: from, cursor: 0, described: nil})
  end

  @doc """
  The commands the list shows for a place: its own, then the global ones
  it does not have, each `{command, place, keys}`.
  """
  @spec commands(atom) :: [{Command.t(), atom, [term]}]
  def commands(from) do
    local = for c <- Commands.all(from), do: {c, from, Keymap.keys_for(from, c.id)}
    ids = for {c, _, _} <- local, do: c.id

    global =
      for c <- Commands.all(:global),
          c.id not in ids,
          not typing?(from),
          do: {c, :global, Keymap.keys_for(:global, c.id)}

    local ++ global
  end

  # in a note the keys of every screen are not commands: they edit the text
  defp typing?(from), do: from == :note

  # --- keys ---------------------------------------------------------------------

  @doc "A key on the help screen."
  @spec handle(State.t(), map, term) :: State.t()
  def handle(state, %{page: :keys} = mode, key) do
    case key do
      {:char, "c"} -> State.put_mode(state, %{mode | page: :commands, cursor: 0, top: 0})
      {:char, "d"} -> State.put_mode(state, %{mode | page: :describe, described: nil})
      _ -> scroll(state, mode, key, Help.line_count())
    end
  end

  def handle(state, %{page: :commands} = mode, key) do
    list = commands(mode.from)
    page = State.body_height(state) - 2

    cursor =
      case key do
        :up -> mode.cursor - 1
        :down -> mode.cursor + 1
        :pgup -> mode.cursor - page
        :pgdn -> mode.cursor + page
        :home -> 0
        :end -> length(list) - 1
        :enter -> :run
        :esc -> :close
        _ -> mode.cursor
      end

    case cursor do
      :close -> State.pop(state)
      :run -> run(State.pop(state), Enum.at(list, mode.cursor))
      n -> State.put_mode(state, %{mode | cursor: n |> min(length(list) - 1) |> max(0)})
    end
  end

  # ESC before a key is described goes back; after, any key does
  def handle(state, %{page: :describe, described: nil}, :esc), do: State.pop(state)

  def handle(state, %{page: :describe, described: nil} = mode, key),
    do: State.put_mode(state, %{mode | described: describe(State.pop(state), mode.from, key)})

  def handle(state, %{page: :describe}, _key), do: State.pop(state)

  defp scroll(state, mode, key, count) do
    page = State.body_height(state)
    last = max(count - page, 0)

    top =
      case key do
        :up -> mode.top - 1
        :down -> mode.top + 1
        :pgup -> mode.top - page
        k when k in [:pgdn, {:char, " "}] -> mode.top + page
        _ -> :close
      end

    if top == :close,
      do: State.pop(state),
      else: State.put_mode(state, %{mode | top: top |> min(last) |> max(0)})
  end

  # a command from the list runs where F1 was pressed, as its key would
  defp run(state, {%Command{id: id}, :view, _keys}), do: ViewKeys.run(state, id)
  defp run(state, {%Command{id: id}, :catmgr, _keys}), do: Manager.run(state, id)
  defp run(state, {%Command{id: id}, :viewmgr, _keys}), do: ViewManager.run(state, id)
  defp run(state, {%Command{id: id}, :note, _keys}), do: Notes.run(state, id)

  defp run(state, {%Command{id: id, name: name}, :global, _keys}) do
    case Agendum.TUI.Update.run_global(state, id) do
      :pass -> State.error(state, "#{name} cannot run here")
      next -> next
    end
  end

  defp run(state, nil), do: state

  # --- describe key ---------------------------------------------------------------

  @doc """
  What `key` does in the place under the help screen (`state` without it),
  as lines of text: the macro attached to it comes first (R50), then the
  global keys, then the place's keymap; an alias says what it stands for.
  """
  @spec describe(State.t(), atom, term) :: [String.t()]
  def describe(state, from, key) do
    name = Keymap.name(key)

    {key, via} =
      case Keymap.alias_in(from, key) do
        nil -> {key, ""}
        target -> {target, "#{name} stands for #{Keymap.name(target)}. "}
      end

    macro = Macros.attached(state, key)
    here = place_name(from)

    cond do
      macro != nil ->
        ["#{name} runs the macro #{macro.name}, attached to it in this file."] ++
          hidden(from, key)

      command = not typing?(from) && global_command(key) ->
        [via <> "#{name} runs #{command.name}, everywhere but while typing.", command.summary]

      command = local_command(from, key) ->
        [via <> "#{name} runs #{command.name} #{here}.", command.summary] ++ count_line(command)

      from == :view and count_digit?(key) ->
        ["#{name} adds a digit to a count for the next command (ALT-1 ALT-0 ↓: ten rows)."]

      from == :view and match?({:char, _}, key) ->
        ["#{name} starts typing an item, or an entry in the highlighted column."]

      from == :catmgr and match?({:char, _}, key) ->
        ["#{name} starts typing a new category below the highlighted one."]

      from == :viewmgr and match?({:char, _}, key) ->
        ["#{name} highlights the next view whose name starts with what is typed."]

      from == :note and edits_text?(state, key) ->
        ["#{name} edits the text: types, moves the cursor or deletes."]

      key == :esc ->
        ["ESC cancels or goes back."]

      from != :elsewhere ->
        ["#{name} does nothing #{here}."]

      true ->
        [
          "#{name} is not in a keymap here yet: only the keys of views, notes and",
          "the managers are so far. The keys page (F1) lists what it does."
        ]
    end
  end

  defp hidden(from, key) do
    case global_command(key) || local_command(from, key) do
      %Command{name: name} -> ["Without the macro it would run #{name}."]
      _ -> []
    end
  end

  defp edits_text?(state, key),
    do: match?({:ok, _}, TextEdit.handle(State.mode(state).edit, key, Wrap.width(state)))

  defp global_command(key), do: Commands.get(:global, Keymap.lookup(:global, key))
  defp local_command(from, key), do: Commands.get(from, Keymap.lookup(from, key))

  defp place_name(:view), do: "in a view"
  defp place_name(:catmgr), do: "in the category manager"
  defp place_name(:viewmgr), do: "in the view manager"
  defp place_name(:note), do: "in a note"
  defp place_name(_elsewhere), do: "here"

  defp count_line(%Command{count: :none}), do: []
  defp count_line(_command), do: ["Takes a count: ALT-digits before it run it that many times."]

  defp count_digit?({:alt, d}), do: d in ~w(1 2 3 4 5 6 7 8 9 0)
  defp count_digit?(_key), do: false

  # --- drawing --------------------------------------------------------------------

  @doc "The help screen's lines, `{style, text}` segments, from its top."
  @spec lines(State.t(), map) :: [[{atom, String.t()}]]
  def lines(_state, %{page: :keys} = mode), do: Enum.drop(Help.lines(), mode.top)

  def lines(state, %{page: :commands} = mode) do
    page = State.body_height(state) - 2

    # each command's lines, then the lines of all, scrolled so that the
    # highlighted command shows whole
    entries =
      mode.from
      |> commands()
      |> Enum.with_index()
      |> Enum.map(fn {{command, _place, keys}, i} ->
        style = if i == mode.cursor, do: :row, else: :normal
        for text <- entry_lines(command, keys), do: [{style, fit(text, state.width)}]
      end)

    before = entries |> Enum.take(mode.cursor + 1) |> Enum.map(&length/1) |> Enum.sum()
    top = max(before - page, 0)

    [
      [{:normal, " COMMANDS #{where(mode.from)}  (↑↓ move · ENTER runs · ESC returns)"}],
      [{:normal, ""}] | entries |> Enum.concat() |> Enum.drop(top)
    ]
  end

  def lines(_state, %{page: :describe, described: nil, from: from}) do
    [
      [{:normal, " DESCRIBE KEY #{where(from)}"}],
      [{:normal, ""}],
      [{:normal, "   Press a key to see what it does (ESC returns)."}]
    ]
  end

  def lines(_state, %{page: :describe, described: text, from: from}) do
    [[{:normal, " DESCRIBE KEY #{where(from)}"}], [{:normal, ""}]] ++
      Enum.map(text, &[{:normal, "   " <> &1}]) ++
      [[{:normal, ""}], [{:normal, "   Any key returns."}]]
  end

  @name_width 18
  @keys_width 23

  # a command's name, keys and summary; keys that do not fit go on to
  # further lines under the first (DEL F4 ALT-F4 CTRL-D CTRL-K)
  defp entry_lines(command, keys) do
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

  defp where(:view), do: "IN A VIEW"
  defp where(:catmgr), do: "IN THE CATEGORY MANAGER"
  defp where(:viewmgr), do: "IN THE VIEW MANAGER"
  defp where(:note), do: "IN A NOTE"
  defp where(_elsewhere), do: "ON EVERY SCREEN"

  defp pad(text, width), do: String.pad_trailing(text, width - 1) <> " "
  defp fit(text, width), do: String.slice(text, 0, max(width, 0))
end
