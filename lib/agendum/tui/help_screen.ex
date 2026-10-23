defmodule Agendum.TUI.HelpScreen do
  @moduledoc """
  The help screen (F1) and its two other pages (R65, ADR 0033), as Emacs's
  C-h then a letter:

    * F1 shows a text about where the person is (the view, a note, the
      box on top …: `about/2`): ↑↓ PGUP PGDN scroll, `c`, `d` and `a` go
      to the other pages, any other key returns;
    * `a`, all the keys, made from the keymaps (`Agendum.TUI.Render.Help`);
    * `c`, the command list: the commands of the place where F1 was
      pressed (its own first, then those of every screen), each with its
      keys and summary; ENTER runs the highlighted one, ESC returns. Those
      that cannot run now are greyed, and the highlighted one says why
      (R65a);
    * `d`, describe key: the next key pressed is described (which command
      it runs there, or the macro attached to it), then any key returns.

  The mode remembers where F1 was pressed (`from`): `:view`, `:catmgr`,
  `:viewmgr`, `:note`, `:menu` (its entries first, each by its letter),
  the moves (`:move_item`, `:browse`, `:column_width` …), `:searching`,
  `:box` (any other box: its own commands from its
  keymap, then the keys every box shares), or
  `:elsewhere` for a screen whose keys are not in a keymap yet. Pure.
  """

  alias Agendum.TUI.{Command, CommandDocs, Commands, Keymap, Macros, Menu, State}
  alias Agendum.TUI.Boxes.{Box, ViewManager}
  alias Agendum.TUI.CategoryScreens.Manager
  alias Agendum.TUI.Render.Help
  alias Agendum.TUI.Update.{Notes, ViewKeys}

  # The places with a keymap of their own (`Agendum.TUI.Keymap`), by the
  # type of the mode on top: what runs their commands, F1's text, and
  # what says which commands cannot run now (R65a; nil: all can). A box
  # is found through `Agendum.TUI.Boxes.Box`.
  @places %{
    view: {ViewKeys, :run, :about, :unavailable},
    catmgr: {Manager, :run, :about, :unavailable},
    viewmgr: {ViewManager, :run, :about, :unavailable},
    note: {Notes, :run, :about, :unavailable},
    menu: {Menu, :run, :about, nil},
    move_item: {Agendum.TUI.Update.Marked, :run_move, :about_move, nil},
    searching: {Agendum.TUI.Boxes.SearchBox, :run_searching, :about_searching, nil},
    browse: {Agendum.TUI.Moves.Browse, :run, :about, nil},
    column_width: {Agendum.TUI.Moves.ColumnWidth, :run, :about, nil},
    column_move: {Agendum.TUI.Moves.ColumnMove, :run, :about, nil},
    section_move: {Agendum.TUI.Moves.SectionMove, :run, :about, nil}
  }

  @doc "The places with a keymap and an F1 text of their own, by mode type."
  @spec places() :: [atom]
  def places, do: Map.keys(@places)

  @doc "Opens the help screen on its keys page."
  @spec open(State.t()) :: State.t()
  def open(state) do
    State.push(state, %Agendum.TUI.Modes.Help{
      top: 0,
      page: :about,
      from: place(state),
      cursor: 0,
      described: nil,
      filter: "",
      pane: 0
    })
  end

  @doc """
  Where the person is, as the command list names places: `:view`, a
  place with a keymap of its own (`:catmgr`, `:note` …), `:box`, or
  `:elsewhere`. F1 and CTRL-X (`Agendum.TUI.Boxes.RunByName`) ask this
  before they open.
  """
  @spec place(State.t()) :: atom
  def place(state) do
    case {state.edit, state.modes} do
      {nil, []} -> :view
      {nil, [%{type: type} | _]} when is_map_key(@places, type) -> type
      {nil, [top | _]} -> if Box.module(top), do: :box, else: :elsewhere
      _ -> :elsewhere
    end
  end

  @doc """
  The commands the list shows for a place: its own, then the global ones
  it does not have, each `{command, place, keys}`; the extras only when
  `extras?` (the Extras preference, R77).
  """
  @spec commands(atom, boolean) :: [{Command.t(), atom, [term]}]
  def commands(from, extras?) do
    local = for c <- Commands.shown(from, extras?), do: {c, from, Keymap.keys_for(from, c.id)}
    ids = for {c, _, _} <- local, do: c.id

    global =
      for c <- Commands.shown(:global, extras?),
          c.id not in ids,
          not typing?(from),
          do: {c, :global, Keymap.keys_for(:global, c.id)}

    local ++ global
  end

  @doc """
  The commands that cannot run now where F1 was pressed (`state` is the
  state under the help), by `{place, id}` as `commands/1` lists them, each
  with why (R65a). Each place says this of its own commands
  (`unavailable/1` beside its `run`); `Agendum.TUI.Update` of the global
  ones.
  """
  @spec unavailable(State.t(), atom) :: %{{atom, term} => String.t()}
  def unavailable(state, from) do
    own =
      case @places[from] do
        {module, _run, _about, fun} when fun != nil -> apply(module, fun, [state])
        _ -> %{}
      end

    global = if typing?(from), do: %{}, else: Agendum.TUI.Update.unavailable_global(state)

    Map.merge(
      Map.new(own, fn {id, reason} -> {{from, id}, reason} end),
      Map.new(global, fn {id, reason} -> {{:global, id}, reason} end)
    )
  end

  # the reason a listed command cannot run now, or nil
  defp reason(unavailable, {%Command{id: id}, place, _keys}), do: unavailable[{place, id}]
  defp reason(_unavailable, nil), do: nil

  # after typing narrows the list: the first command that can run, so
  # that typing then ENTER runs something (the first match if none can)
  defp first_runnable(state, mode) do
    below = State.pop(state)
    unavailable = unavailable(below, mode.from)
    Enum.find_index(shown(below, mode), &(reason(unavailable, &1) == nil)) || 0
  end

  # the list as narrowed by what was typed (R65d): the names that match
  # it, best first, then the summaries that hold it; nothing typed keeps
  # the list's order, so its places can be learnt
  defp shown(state, %{filter: ""} = mode), do: entries(state, mode.from)

  defp shown(state, mode), do: state |> entries(mode.from) |> match(state, mode.from, mode.filter)

  @doc """
  The `entries/2` that match `query`, best first, the recently run by
  name first among equals (`Agendum.TUI.Commands.match/3`).
  """
  @spec match([{Command.t(), term, [term]}], State.t(), atom, String.t()) ::
          [{Command.t(), term, [term]}]
  def match(entries, state, from, query) do
    Commands.match(entries, query,
      name: fn {command, _, _} -> command.name end,
      summary: fn {command, _, _} -> command.summary end,
      key: fn {command, _, _} -> {from, command.name} end,
      recent: state.last.commands
    )
  end

  # in a note the keys of every screen are not commands: they edit the
  # text; in the menu they do nothing
  defp typing?(from), do: from in [:note, :menu]

  @doc """
  The entries `{command, place, keys}` the command list has where the
  person is (`from`, as `place/1` says; `state` the state there), in its
  order: in a box, first the box's own commands from its keymap, then the
  keys every box shares that it does not bind itself, then the global
  ones; in the menu, first the entries of its level, each chosen by its
  letter; elsewhere `commands/1`.
  """
  @spec entries(State.t(), atom) :: [{Command.t(), term, [term]}]
  def entries(state, :box) do
    own = own_keys(state)
    bound = for {_, :own, keys} <- own, key <- keys, do: key

    shared =
      for {_c, :box, keys} = entry <- commands(:box, state.prefs.extras),
          not Enum.any?(keys, &(&1 in bound)),
          do: entry

    global = for {_, :global, _} = entry <- commands(:box, state.prefs.extras), do: entry
    own ++ shared ++ global
  end

  def entries(state, :menu) do
    mode = State.mode(state)

    above = Menu.labels(mode)

    entries =
      for {{label, description, action}, i} <- Enum.with_index(Menu.entries(mode)) do
        doc = CommandDocs.menu(above ++ [label], action)
        command = %Command{id: i, name: label, summary: description, doc: doc}
        {command, :menu_entry, [{:char, String.first(label)}]}
      end

    entries ++ commands(:menu, state.prefs.extras)
  end

  def entries(state, from), do: commands(from, state.prefs.extras)

  # a box's own commands, from its keymap (R65), each with its keys
  defp own_keys(state) do
    mode = State.mode(state)

    case Box.module(mode) do
      nil ->
        []

      box ->
        keymap = box.keymap(mode)
        settings? = Map.get(keymap, {:char, " "}) == :change

        for {id, name, summary} <- box.commands(mode) do
          keys = for {key, ^id} <- keymap, do: key
          doc = CommandDocs.box(box, id, settings?)
          {%Command{id: id, name: name, summary: summary, doc: doc}, :own, Keymap.sort(keys)}
        end
    end
  end

  # --- keys ---------------------------------------------------------------------

  @doc "A key on the help screen."
  @spec handle(State.t(), map, term) :: State.t()
  def handle(state, %{page: :about} = mode, key) do
    case key do
      {:char, "c"} -> State.put_mode(state, %{mode | page: :commands, cursor: 0, top: 0, pane: 0})
      {:char, "d"} -> State.put_mode(state, %{mode | page: :describe, described: nil})
      {:char, "a"} -> State.put_mode(state, %{mode | page: :all, top: 0})
      _ -> scroll(state, mode, key)
    end
  end

  def handle(state, %{page: :all} = mode, key), do: scroll(state, mode, key)

  # typing narrows the list (by name or summary); ESC first forgets
  # what was typed, as in the category picker
  def handle(state, %{page: :commands} = mode, {:char, c}),
    do: narrow(state, %{mode | filter: mode.filter <> c})

  def handle(state, %{page: :commands, filter: filter} = mode, :backspace) when filter != "",
    do: narrow(state, %{mode | filter: String.slice(filter, 0..-2//1)})

  def handle(state, %{page: :commands, filter: filter} = mode, :esc) when filter != "",
    do: State.put_mode(state, %{mode | filter: "", cursor: 0, top: 0, pane: 0})

  # ← → page through the highlighted command's text in the pane
  def handle(state, %{page: :commands} = mode, key) when key in [:left, :right] do
    step = if key == :right, do: 1, else: -1

    pages =
      state |> State.pop() |> shown(mode) |> Enum.at(mode.cursor) |> pane_pages(width(state))

    State.put_mode(state, %{mode | pane: (mode.pane + step) |> min(length(pages) - 1) |> max(0)})
  end

  def handle(state, %{page: :commands} = mode, key) do
    list = shown(State.pop(state), mode)
    page = list_height(state)

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
      :run -> run_or_say(State.pop(state), mode.from, Enum.at(list, mode.cursor))
      n -> State.put_mode(state, move_to(state, mode, list, n))
    end
  end

  # ESC before a key is described goes back; after, any key does
  def handle(state, %{page: :describe, described: nil}, :esc), do: State.pop(state)

  def handle(state, %{page: :describe, described: nil} = mode, key),
    do: State.put_mode(state, %{mode | described: describe(State.pop(state), mode.from, key)})

  def handle(state, %{page: :describe}, _key), do: State.pop(state)

  # the highlight on command `n`; the list scrolls only when it reaches
  # an edge, and the pane starts at the text's beginning
  defp move_to(state, mode, list, n) do
    cursor = n |> min(length(list) - 1) |> max(0)
    top = window(heights(list), mode.top, cursor, list_height(state))
    %{mode | cursor: cursor, top: top, pane: if(cursor == mode.cursor, do: mode.pane, else: 0)}
  end

  defp narrow(state, mode),
    do: State.put_mode(state, %{mode | cursor: first_runnable(state, mode), top: 0, pane: 0})

  defp scroll(state, mode, key) do
    page = content_height(state)
    count = length(page_lines(State.pop(state), mode, width(state)))
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

  @doc """
  Runs an entry of `entries/2` where the person is (`state`, the state at
  `from`), as its key would, and remembers it as run by name (R65d); one
  that cannot run now says why instead (R65a).
  """
  @spec run_or_say(State.t(), atom, {Command.t(), term, [term]} | nil) :: State.t()
  def run_or_say(state, _from, nil), do: state

  def run_or_say(state, from, {command, _, _} = entry) do
    case reason(unavailable(state, from), entry) do
      nil -> state |> remember(from, command.name) |> run(entry)
      why -> State.error(state, why)
    end
  end

  # the last ten commands run by name, most recent first, each once
  defp remember(state, from, name) do
    recent = [{from, name} | List.delete(state.last.commands, {from, name})]
    %{state | last: %{state.last | commands: Enum.take(recent, 10)}}
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
          hidden(state, from, key)

      command = not typing?(from) && global_command(key) ->
        [via <> "#{name} runs #{command.name}, everywhere but while typing.", command.summary] ++
          doc_lines(state, command) ++ not_now(state, from, {:global, command.id})

      command = from == :box && own_key(state, key) ->
        [via <> "#{name} runs #{command.name} in this box.", command.summary]

      command = local_command(state, from, key) ->
        [via <> "#{name} runs #{command.name} #{here}.", command.summary] ++
          doc_lines(state, command) ++
          count_line(command) ++ not_now(state, from, {from, command.id})

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

  # the command's longer text (R65b), wrapped as describe key draws it
  defp doc_lines(_state, %Command{doc: nil}), do: []

  defp doc_lines(state, %Command{doc: doc}),
    do: ["" | Agendum.TUI.Terminal.Draw.wrap(doc, width(state) - 4)]

  defp not_now(state, from, place_id) do
    case unavailable(state, from)[place_id] do
      nil -> []
      why -> ["Not now: " <> why]
    end
  end

  defp hidden(state, from, key) do
    case global_command(key) || local_command(state, from, key) do
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
        {label, description, action} = Enum.at(Menu.entries(mode), i)
        doc = CommandDocs.menu(Menu.labels(mode) ++ [label], action)

        ["#{name} chooses #{label}.", description] ++
          doc_lines(state, %Command{id: i, name: label, summary: description, doc: doc})
    end
  end

  defp global_command(key), do: Commands.get(:global, Keymap.lookup(:global, key))
  # an extra's key is unbound while the extras are off (R77)
  defp local_command(state, from, key) do
    case Commands.get(from, Keymap.lookup(from, key)) do
      %Command{extra: true} when not state.prefs.extras -> nil
      command -> command
    end
  end

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

  # --- the text about where you are (F1) -----------------------------------------

  # the page's lines under its heading, before scrolling, from the state
  # under the help
  defp page_lines(_state, %{page: :all}, width), do: Help.lines(width)

  defp page_lines(state, %{page: :about, from: from}, width) do
    text = about(state, from)

    [[{:normal, ""}]] ++
      Enum.flat_map(String.split(text, "\n\n"), fn paragraph ->
        lines =
          paragraph |> String.replace("\n", " ") |> Agendum.TUI.Terminal.Draw.wrap(width - 4)

        Enum.map(lines, &[{:normal, "  " <> &1}]) ++ [[{:normal, ""}]]
      end)
  end

  @doc """
  F1's text about where the person is (`from`, under the help): the
  place's (`about/0` of its module), or the box's (`c:Box.about/2`, else
  one made from its title and settings' help).
  """
  @spec about(State.t(), atom) :: String.t()
  def about(state, :box) do
    mode = State.mode(state)
    box = Box.module!(mode)
    box.about(state, mode) || Box.default_about(box, state, mode)
  end

  def about(_state, from) when is_map_key(@places, from),
    do: apply(elem(@places[from], 0), elem(@places[from], 2), [])

  def about(_state, _from),
    do: "Press c for the commands that work here, d to see what a key does, a for all keys."

  # --- drawing --------------------------------------------------------------------

  # The frame every page has (R65c): a heading (and what keys do there,
  # on the right), a line under it, a rule; the command list also has a
  # pane of @pane lines at the foot, under a rule of its own.
  @head 3
  @pane 5

  @doc "The help screen's lines, `{style, text}` segments, from its top."
  @spec lines(State.t(), map) :: [[{atom, String.t()}]]
  def lines(state, %{page: :about, from: from} = mode) do
    head("HELP #{where(from)}", "", " c commands here · d describe a key · a all keys", state) ++
      (state |> below(mode) |> page_lines(mode, width(state)) |> Enum.drop(mode.top))
  end

  def lines(state, %{page: :all} = mode) do
    head("ALL KEYS", "↑↓ PGUP PGDN scroll", "   Every key, made from the keymaps.", state) ++
      (state |> below(mode) |> page_lines(mode, width(state)) |> Enum.drop(mode.top))
  end

  def lines(state, %{page: :commands} = mode) do
    # each command's rows, greyed when it cannot run now (R65a); the
    # list shows from `top` (see `window/4`) and leaves room for the pane
    under = below(state, mode)
    unavailable = unavailable(under, mode.from)
    list = shown(under, mode)
    rows = list_height(state)
    top = window(heights(list), mode.top, mode.cursor, rows)

    entries =
      list
      |> Enum.with_index()
      |> Enum.map(fn {{command, _place, keys} = entry, i} ->
        style =
          cond do
            i == mode.cursor -> :row
            reason(unavailable, entry) != nil -> :dim
            true -> :normal
          end

        for text <- Help.row(command, keys), do: [{style, Help.clip(text, width(state))}]
      end)

    shown = entries |> Enum.drop(top) |> fitting(rows)
    after_shown = length(entries) - top - length(shown)
    visible = Enum.concat(shown)
    entry = Enum.at(list, mode.cursor)

    typed =
      if mode.filter == "",
        do: "   Type to narrow the list.",
        else: "   Showing those with \"#{mode.filter}\" (BACKSPACE, ESC to see all)"

    head("COMMANDS #{where(mode.from)}", "↑↓ move · ENTER runs · ESC returns", typed, state) ++
      visible ++
      List.duplicate([], max(rows - length(visible), 0)) ++
      [pane_rule(top, after_shown, entry, mode.pane, width(state))] ++
      pane(entry, reason(unavailable, entry), mode.pane, width(state))
  end

  def lines(state, %{page: :describe, described: nil, from: from}),
    do:
      head(
        "DESCRIBE KEY #{where(from)}",
        "",
        "   Press a key to see what it does (ESC returns).",
        state
      )

  def lines(state, %{page: :describe, described: text, from: from}) do
    head("DESCRIBE KEY #{where(from)}", "", "   Any key returns.", state) ++
      [[{:normal, ""}]] ++ Enum.map(text, &[{:normal, "   " <> &1}])
  end

  # the heading (with `keys` on its right, when they fit), the line under
  # it, and a rule
  defp head(heading, keys, under, state) do
    width = width(state)
    title = " " <> heading
    gap = width - String.length(title) - String.length(keys) - 1

    right = if keys != "" and gap >= 2, do: String.duplicate(" ", gap) <> keys, else: ""

    [
      [{:help_title, Help.clip(title, width)}, {:normal, right}],
      [{:normal, Help.clip(under, width)}],
      [{:help_rule, rule(width)}]
    ]
  end

  defp rule(width), do: " " <> String.duplicate("─", max(width - 2, 0))

  # the rows the list has, and the rows a scrolled page shows
  defp list_height(state), do: max(height(state) - @head - 1 - @pane, 1)
  defp content_height(state), do: max(height(state) - @head, 1)

  @doc """
  The inside of the help's box, `{width, height}` (R65c). The box leaves
  a margin of the faded screen around it: at most a tenth of the screen
  on each side, less on a smaller screen, where the help needs the room
  more (80×25: about nine tenths; 200×60: four fifths). `Agendum.TUI.Render`
  draws the box; every page is laid out to fit inside it.
  """
  @spec size(State.t()) :: {pos_integer, pos_integer}
  def size(state) do
    w = state.width
    h = State.body_height(state)
    # the margin on each side: nothing below 60 columns (16 rows), then a
    # column for every six more (a row for every four), up to a tenth
    across = (w - 60) |> div(6) |> min(div(w, 10)) |> max(0)
    down = (h - 16) |> div(4) |> min(div(h, 10)) |> max(0)
    {max(w - 2 * across - 2, 1), max(h - 2 * down - 2, 1)}
  end

  defp width(state), do: elem(size(state), 0)
  defp height(state), do: elem(size(state), 1)

  # how many rows each command takes (its keys may need more than one)
  defp heights(list), do: for({command, _, keys} <- list, do: length(Help.row(command, keys)))

  # The first command shown, so that the highlighted one shows whole: the
  # list does not move until the highlight would leave it (a pure answer,
  # kept in the mode by the keys, and worked out again when drawing).
  defp window(heights, top, cursor, rows) do
    top = top |> min(cursor) |> max(0)

    if top < cursor and Enum.sum(Enum.slice(heights, top..cursor//1)) > rows,
      do: window(heights, top + 1, cursor, rows),
      else: top
  end

  # the entries that fit in `rows`, whole
  defp fitting(entries, rows) do
    entries
    |> Enum.reduce_while({[], 0}, fn entry, {kept, used} ->
      if used + length(entry) <= rows,
        do: {:cont, {[entry | kept], used + length(entry)}},
        else: {:halt, {kept, used}}
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  # the rule over the pane: where the list goes on, and which part of a
  # long text the pane shows
  defp pane_rule(top, after_shown, entry, page, width) do
    pages = length(pane_pages(entry, width))

    marks =
      [
        top > 0 && "↑ #{top} above",
        after_shown > 0 && "↓ #{after_shown} more",
        pages > 1 && "← → #{min(page, pages - 1) + 1}/#{pages}"
      ]
      |> Enum.filter(&is_binary/1)
      |> Enum.join(" · ")

    base = rule(width)

    if marks == "" or String.length(marks) + 6 > width do
      [{:help_rule, base}]
    else
      keep = width - String.length(marks) - 4
      [{:help_rule, String.slice(base, 0, keep) <> "─ " <> marks <> " ─"}]
    end
  end

  # The pane (R65c): the command's name and keys, and why it cannot run
  # now on the right; under them its longer text (R65b), or its summary,
  # four lines at a time (← → for the rest).
  defp pane(nil, _why, _page, width),
    do: List.duplicate([{:help_pane, String.duplicate(" ", width)}], @pane)

  defp pane({command, _place, keys} = entry, why, page, width) do
    names = Enum.map_join(keys, " ", &Keymap.name/1)
    title = " " <> command.name <> if(names == "", do: "", else: " · " <> names)
    not_now = if why, do: "Not now: " <> why <> " ", else: ""
    gap = width - String.length(title) - String.length(not_now)

    first =
      if why != nil and gap >= 1,
        do: [{:help_pane_title, title <> String.duplicate(" ", gap)}, {:error, not_now}],
        else: [{:help_pane_title, pad(title, width)}]

    pages = pane_pages(entry, width)
    text = Enum.at(pages, page |> min(length(pages) - 1) |> max(0))
    body = for line <- text, do: [{:help_pane, pad(" " <> line, width)}]

    [first | body] ++
      List.duplicate([{:help_pane, String.duplicate(" ", width)}], @pane - 1 - length(body))
  end

  # the text's lines, wrapped to the pane, @pane - 1 at a time
  defp pane_pages(nil, _width), do: [[]]

  defp pane_pages({command, _place, _keys}, width) do
    (command.doc || command.summary)
    |> Agendum.TUI.Terminal.Draw.wrap(max(width - 3, 10))
    |> Enum.chunk_every(@pane - 1)
    |> then(&if(&1 == [], do: [[]], else: &1))
  end

  defp pad(text, width) do
    text = Help.clip(text, width)
    text <> String.duplicate(" ", max(width - String.length(text), 0))
  end

  # the state under this help screen: a box can be drawn over the help
  # (ALT-F3 opens the macro manager anywhere), so it is not always on top
  defp below(state, mode) do
    case Enum.drop_while(state.modes, &(&1 != mode)) do
      [_help | rest] -> %{state | modes: rest}
      [] -> State.pop(state)
    end
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
end
