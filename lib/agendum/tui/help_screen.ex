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
  `:viewmgr`, `:note`, `:menu` (its entries first, each by its letter),
  the moves (`:move_item`, `:browse`, `:column_width` …), `:searching`,
  `:box` (any other box: its own commands from its
  keymap, then the keys every box shares), or
  `:elsewhere` for a screen whose keys are not in a keymap yet. Pure.
  """

  alias Agendum.TUI.{Command, Commands, Keymap, Macros, Menu, State}
  alias Agendum.TUI.Boxes.{Box, ViewManager}
  alias Agendum.TUI.CategoryScreens.Manager
  alias Agendum.TUI.Render.Help
  alias Agendum.TUI.Update.{Notes, ViewKeys}

  # The places with a keymap of their own (`Agendum.TUI.Keymap`), by the
  # type of the mode on top, and what runs their commands; a box is found
  # through `Agendum.TUI.Boxes.Box`.
  @places %{
    view: {ViewKeys, :run},
    catmgr: {Manager, :run},
    viewmgr: {ViewManager, :run},
    note: {Notes, :run},
    menu: {Menu, :run},
    move_item: {Agendum.TUI.Update.Marked, :run_move},
    searching: {Agendum.TUI.Boxes.SearchBox, :run_searching},
    browse: {Agendum.TUI.Moves.Browse, :run},
    column_width: {Agendum.TUI.Moves.ColumnWidth, :run},
    column_move: {Agendum.TUI.Moves.ColumnMove, :run},
    section_move: {Agendum.TUI.Moves.SectionMove, :run}
  }

  @doc "Opens the help screen on its keys page."
  @spec open(State.t()) :: State.t()
  def open(state) do
    from =
      case {state.edit, state.modes} do
        {nil, []} -> :view
        {nil, [%{type: type} | _]} when is_map_key(@places, type) -> type
        {nil, [top | _]} -> if Box.module(top), do: :box, else: :elsewhere
        _ -> :elsewhere
      end

    State.push(state, %{
      type: :help,
      top: 0,
      page: :keys,
      from: from,
      cursor: 0,
      described: nil,
      filter: ""
    })
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

  # the list as narrowed by what was typed: names and summaries that hold
  # it, in any case
  defp shown(state, mode) do
    wanted = String.downcase(mode.filter)

    for {command, _, _} = entry <- list(state, mode.from),
        String.contains?(String.downcase(command.name <> " " <> command.summary), wanted),
        do: entry
  end

  # in a note the keys of every screen are not commands: they edit the
  # text; in the menu they do nothing
  defp typing?(from), do: from in [:note, :menu]

  # What the list shows: in a box, first the box's own commands from its
  # keymap, then the keys every box shares that it does not bind itself,
  # then the global ones.
  defp list(state, :box) do
    own = own_keys(state)
    bound = for {_, :own, keys} <- own, key <- keys, do: key

    shared =
      for {_c, :box, keys} = entry <- commands(:box),
          not Enum.any?(keys, &(&1 in bound)),
          do: entry

    global = for {_, :global, _} = entry <- commands(:box), do: entry
    own ++ shared ++ global
  end

  # in the menu, first the entries of its level, each chosen by its letter
  defp list(state, :menu) do
    mode = State.mode(state)

    entries =
      for {{label, description, _}, i} <- Enum.with_index(Menu.entries(mode)) do
        command = %Command{id: i, name: label, summary: description}
        {command, :menu_entry, [{:char, String.first(label)}]}
      end

    entries ++ commands(:menu)
  end

  defp list(_state, from), do: commands(from)

  # a box's own commands, from its keymap (R65), each with its keys
  defp own_keys(state) do
    mode = State.mode(state)

    case Box.module(mode) do
      nil ->
        []

      box ->
        keymap = box.keymap(mode)

        for {id, name, summary} <- box.commands(mode) do
          keys = for {key, ^id} <- keymap, do: key
          {%Command{id: id, name: name, summary: summary}, :own, Keymap.sort(keys)}
        end
    end
  end

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

  # typing narrows the list (by name or summary); ESC first forgets
  # what was typed, as in the category picker
  def handle(state, %{page: :commands} = mode, {:char, c}),
    do: State.put_mode(state, %{mode | filter: mode.filter <> c, cursor: 0})

  def handle(state, %{page: :commands, filter: filter} = mode, :backspace) when filter != "",
    do: State.put_mode(state, %{mode | filter: String.slice(filter, 0..-2//1), cursor: 0})

  def handle(state, %{page: :commands, filter: filter} = mode, :esc) when filter != "",
    do: State.put_mode(state, %{mode | filter: "", cursor: 0})

  def handle(state, %{page: :commands} = mode, key) do
    list = shown(State.pop(state), mode)
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
  defp run(state, {%Command{id: id}, place, _keys}) when is_map_key(@places, place),
    do: apply(elem(@places[place], 0), elem(@places[place], 1), [state, id])

  defp run(state, {%Command{id: index}, :menu_entry, _keys}), do: Menu.choose(state, index)

  defp run(state, {%Command{id: id}, :own, _keys}) do
    mode = State.mode(state)
    Box.module!(mode).run(state, mode, id)
  end

  defp run(state, {%Command{id: id, name: name}, :box, _keys}) do
    case Agendum.TUI.Update.run_box(state, id, nil) do
      :pass -> State.error(state, "#{name} cannot run here")
      next -> next
    end
  end

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

      command = from == :box && own_key(state, key) ->
        [via <> "#{name} runs #{command.name} in this box.", command.summary]

      command = local_command(from, key) ->
        [via <> "#{name} runs #{command.name} #{here}.", command.summary] ++ count_line(command)

      true ->
        unbound(state, from, key, name)
    end
  end

  # a key that runs no command there: what typing does, or nothing
  defp unbound(state, from, key, name) do
    char? = match?({:char, _}, key)

    cond do
      from == :box and char? ->
        ["#{name} picks the setting's choice starting with it, or types into it."]

      from == :view and count_digit?(key) ->
        ["#{name} adds a digit to a count for the next command (ALT-1 ALT-0 ↓: ten rows)."]

      from == :view and char? ->
        ["#{name} starts typing an item, or an entry in the highlighted column."]

      from == :catmgr and char? ->
        ["#{name} starts typing a new category below the highlighted one."]

      from == :viewmgr and char? ->
        ["#{name} highlights the next view whose name starts with what is typed."]

      from == :menu and match?({:char, _}, key) ->
        menu_letter(state, key, name)

      command = from == :note && Commands.get(:text, Keymap.lookup(:text, key)) ->
        ["#{name} runs #{command.name} in the text.", command.summary]

      from == :note and match?({:char, _}, key) ->
        ["#{name} is typed into the text."]

      key == :esc ->
        ["ESC cancels or goes back."]

      from != :elsewhere ->
        ["#{name} does nothing #{place_name(from)}."]

      true ->
        [
          "#{name} is not in a keymap here yet: only the keys of views, notes,",
          "boxes and the managers are so far. The keys page (F1) lists what it does."
        ]
    end
  end

  defp hidden(from, key) do
    case global_command(key) || local_command(from, key) do
      %Command{name: name} -> ["Without the macro it would run #{name}."]
      _ -> []
    end
  end

  # the box's own command for a key
  defp own_key(state, key) do
    Enum.find_value(own_keys(state), fn {command, :own, keys} -> if key in keys, do: command end)
  end

  defp menu_letter(state, {:char, c}, name) do
    mode = State.mode(state)

    case Menu.entry_for(mode, c) do
      nil ->
        ["#{name} chooses nothing here: no entry of this level begins with it."]

      i ->
        {label, description, _} = Enum.at(Menu.entries(mode), i)
        ["#{name} chooses #{label}.", description]
    end
  end

  defp global_command(key), do: Commands.get(:global, Keymap.lookup(:global, key))
  defp local_command(from, key), do: Commands.get(from, Keymap.lookup(from, key))

  defp place_name(:view), do: "in a view"
  defp place_name(:catmgr), do: "in the category manager"
  defp place_name(:viewmgr), do: "in the view manager"
  defp place_name(:note), do: "in a note"
  defp place_name(:menu), do: "in the menu"
  defp place_name(:move_item), do: "while moving items"
  defp place_name(:searching), do: "while searching"
  defp place_name(:browse), do: "while browsing"
  defp place_name(:column_width), do: "while changing a width"
  defp place_name(:column_move), do: "while moving a column"
  defp place_name(:section_move), do: "while moving a section"
  defp place_name(:box), do: "in every box"
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
      state
      |> below(mode)
      |> shown(mode)
      |> Enum.with_index()
      |> Enum.map(fn {{command, _place, keys}, i} ->
        style = if i == mode.cursor, do: :row, else: :normal
        for text <- entry_lines(command, keys), do: [{style, fit(text, state.width)}]
      end)

    before = entries |> Enum.take(mode.cursor + 1) |> Enum.map(&length/1) |> Enum.sum()
    top = max(before - page, 0)

    typed =
      if mode.filter == "",
        do: "   Type to narrow the list.",
        else: "   Showing those with \"#{mode.filter}\" (BACKSPACE, ESC to see all)"

    [
      [{:normal, " COMMANDS #{where(mode.from)}  (↑↓ move · ENTER runs · ESC returns)"}],
      [{:normal, typed}] | entries |> Enum.concat() |> Enum.drop(top)
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

  # the state under this help screen: a box can be drawn over the help
  # (ALT-F3 opens the macro manager anywhere), so it is not always on top
  defp below(state, mode) do
    case Enum.drop_while(state.modes, &(&1 != mode)) do
      [_help | rest] -> %{state | modes: rest}
      [] -> State.pop(state)
    end
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
  defp where(:menu), do: "IN THE MENU"
  defp where(:move_item), do: "WHILE MOVING ITEMS"
  defp where(:searching), do: "WHILE SEARCHING"
  defp where(:browse), do: "WHILE BROWSING"
  defp where(:column_width), do: "WHILE CHANGING A WIDTH"
  defp where(:column_move), do: "WHILE MOVING A COLUMN"
  defp where(:section_move), do: "WHILE MOVING A SECTION"
  defp where(:box), do: "IN THIS BOX"
  defp where(_elsewhere), do: "ON EVERY SCREEN"

  defp pad(text, width), do: String.pad_trailing(text, width - 1) <> " "
  defp fit(text, width), do: String.slice(text, 0, max(width, 0))
end
