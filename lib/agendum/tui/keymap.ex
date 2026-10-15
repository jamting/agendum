defmodule Agendum.TUI.Keymap do
  @moduledoc """
  Which command a key runs, by place (ADR 0033): a key event (as
  `Agendum.TUI.Terminal.Keys` decodes it) to a command id of
  `Agendum.TUI.Commands`. Agenda's keys (SPEC R42), with ours beside them
  (R31). ALT-letters are here too (⌥-letters on a Mac with Option as
  Meta, which sends ESC and the letter together).

  A printable character is not bound in a view: it starts typing an item
  or a column entry (what Emacs calls self-insert). Later the person's own
  bindings will be looked up first (MULTIUSER.md §6).

  Pure.
  """

  # one line per key, like Agenda's key charts
  @view %{
    :up => :up,
    :down => :down,
    :enter => :down,
    :pgup => :page_up,
    :pgdn => :page_down,
    :home => :top,
    :ctrl_home => :top,
    :end => :bottom,
    :ctrl_end => :bottom,
    :ctrl_pgup => :previous_section,
    :ctrl_pgdn => :next_section,
    # the highlight goes left and right as the columns are shown (R55)
    :right => :next_column,
    :tab => :next_column,
    :left => :previous_column,
    :shift_tab => :previous_column,
    {:char, "/"} => :menu,
    :insert => :insert,
    {:alt, "i"} => :insert,
    :delete => :remove,
    {:f, 1} => :help,
    {:f, 2} => :edit,
    {:f, 3} => :choices,
    {:f, 4} => :done,
    {:f, 5} => :note,
    {:f, 6} => :properties,
    {:f, 7} => :mark,
    {:alt_f, 7} => :unmark_all,
    {:alt, "j"} => :next_marked,
    {:alt, "m"} => :make_assign,
    {:f, 8} => :view_manager,
    {:f, 9} => :category_manager,
    {:f, 10} => :menu,
    {:alt_f, 4} => :discard,
    {:ctrl, "d"} => :discard,
    {:alt_f, 2} => :when,
    {:alt_f, 10} => :move,
    {:alt_f, 9} => :copy,
    {:alt, "y"} => :yank,
    {:alt, "h"} => :hop,
    {:alt, "d"} => :section_below,
    {:alt, "u"} => :section_above,
    {:alt_f, 5} => :go_to,
    {:alt, "n"} => :next_view,
    {:alt, "p"} => :previous_view,
    {:alt_f, 8} => :last_view,
    {:alt, "w"} => :save,
    {:alt, "g"} => :retrieve,
    {:alt, "v"} => :toggle_empty,
    {:alt, "o"} => :dependency,
    {:alt, "x"} => :execute_all,
    {:alt, "e"} => :execute_category,
    {:alt_f, 6} => :search,
    {:alt, "a"} => :alarm,
    {:alt, "c"} => :calendar,
    {:alt, "b"} => :browse,
    {:alt, "-"} => :collapse,
    {:alt, "="} => :expand,
    {:alt, "r"} => :column_right,
    {:alt, "l"} => :column_left
  }

  # the category manager (F9; User's Guide 16-1 to 16-12, R42)
  @catmgr %{
    :up => :up,
    :backspace => :up,
    :down => :down,
    :enter => :down,
    :pgup => :page_up,
    :pgdn => :page_down,
    :ctrl_home => :first,
    :ctrl_end => :last,
    :home => :parent,
    :end => :last_sibling,
    :ctrl_pgup => :previous_sibling,
    :ctrl_pgdn => :next_sibling,
    :esc => :close,
    {:f, 9} => :close,
    {:f, 10} => :close,
    {:f, 1} => :help,
    :insert => :add_below,
    {:alt, "d"} => :add_below,
    {:alt, "i"} => :add_below,
    {:alt, "u"} => :add_above,
    {:alt, "l"} => :add_family,
    {:alt, "r"} => :add_child,
    {:alt, "e"} => :execute,
    {:f, 2} => :rename,
    {:f, 5} => :note,
    {:f, 6} => :properties,
    {:f, 7} => :promote,
    {:f, 8} => :demote,
    {:alt, :up} => :move_up,
    {:alt, :down} => :move_down,
    {:alt_f, 5} => :sort,
    {:alt_f, 10} => :move,
    :delete => :discard,
    {:alt_f, 4} => :discard,
    {:ctrl, "d"} => :discard,
    {:alt, "-"} => :collapse,
    {:alt, "="} => :expand
  }

  # the view manager (F8, a box over the view); typing a letter finds a
  # view (R53). F4 (DELETE) is Agenda's discard here
  @viewmgr %{
    :up => :up,
    :down => :down,
    :home => :first,
    :end => :last,
    :enter => :show,
    :esc => :close,
    {:f, 8} => :close,
    {:f, 1} => :help,
    :insert => :add,
    {:f, 2} => :rename,
    {:alt_f, 5} => :sort,
    {:alt, :up} => :move_up,
    {:alt, :down} => :move_down,
    {:f, 4} => :discard,
    :delete => :discard,
    {:alt_f, 4} => :discard,
    {:ctrl, "d"} => :discard
  }

  # a note (F5): any key not here edits the text (`Typing.TextEdit`)
  @note %{
    :esc => :close,
    {:f, 5} => :close,
    {:f, 1} => :help,
    {:f, 7} => :mark,
    {:f, 3} => :copy,
    {:f, 4} => :cut,
    {:alt_f, 4} => :delete,
    {:f, 2} => :paste,
    {:alt_f, 6} => :search,
    {:alt, "s"} => :search_next,
    {:alt, "d"} => :insert_date,
    {:alt, "t"} => :insert_time,
    {:alt, "n"} => :next_note,
    {:alt, "p"} => :previous_note,
    {:alt_f, 7} => :make_item,
    {:alt_f, 2} => :make_category,
    {:alt, "k"} => :key_map,
    {:alt, "q"} => :quit
  }

  # every box (`Update`'s box stage); its own keys are the box's
  @box %{
    {:f, 1} => :help,
    {:f, 3} => :choices,
    :esc => :cancel
  }

  # on every screen, but not while typing or answering (`Update`)
  @global %{
    {:ctrl, "z"} => :undo,
    {:ctrl, "y"} => :redo,
    {:ctrl, "s"} => :save,
    {:ctrl, "o"} => :retrieve,
    {:ctrl, "p"} => :export,
    {:alt, "k"} => :key_map,
    {:alt, "q"} => :quit,
    {:ctrl, "q"} => :quit,
    {:ctrl, "c"} => :quit
  }

  @keymaps %{
    view: @view,
    catmgr: @catmgr,
    viewmgr: @viewmgr,
    note: @note,
    box: @box,
    global: @global
  }

  # Keys that stand for other keys (R31): for Mac keyboards without INS,
  # CTRL-N is INS everywhere, CTRL-E is F2 and CTRL-K F4 unless typing
  # (where they edit text); ⌥↑ ⌥↓ are CTRL-PGUP / CTRL-PGDN in a view.
  # `Update` turns them into the key they stand for before anything else.
  @aliases %{
    {:ctrl, "n"} => {:insert, :always},
    {:ctrl, "e"} => {{:f, 2}, :not_typing},
    {:ctrl, "k"} => {{:f, 4}, :not_typing},
    {:alt, :up} => {:ctrl_pgup, :view},
    {:alt, :down} => {:ctrl_pgdn, :view}
  }

  @doc "The command id `key` runs in `place`, or nil when it is not bound there."
  @spec lookup(atom, term) :: atom | nil
  def lookup(place, key), do: @keymaps |> Map.get(place, %{}) |> Map.get(key)

  @doc "A place's bindings, key to command id."
  @spec bindings(atom) :: %{term => atom}
  def bindings(place), do: Map.get(@keymaps, place, %{})

  @doc """
  The key `key` stands for, and when: `{key, :always | :not_typing |
  :view}`; nil when it stands for itself.
  """
  @spec alias_of(term) :: {term, :always | :not_typing | :view} | nil
  def alias_of(key), do: Map.get(@aliases, key)

  # places where the person types text: CTRL-E and CTRL-K edit there
  @typing [:note]

  @doc """
  The key `key` stands for in `place` (not while typing), or nil when it
  stands for itself there: ⌥↑ is CTRL-PGUP in a view, but its own key in
  the category manager; CTRL-E is F2, but in a note it goes to the end of
  the line.
  """
  @spec alias_in(atom, term) :: term | nil
  def alias_in(place, key) do
    case alias_of(key) do
      {target, :view} -> if place == :view, do: target
      {target, :not_typing} -> if place not in @typing, do: target
      {target, :always} -> target
      nil -> nil
    end
  end

  @doc "The keys bound to a command in a place, aliases included, in the order shown."
  @spec keys_for(atom, atom) :: [term]
  def keys_for(place, id) do
    keys = for {key, ^id} <- bindings(place), do: key
    aliases = for {key, _} <- @aliases, alias_in(place, key) in keys, do: key
    sort(keys ++ aliases)
  end

  @doc "Keys in the order the help shows them: plain keys (arrows first), F-keys, ALT, CTRL."
  @spec sort([term]) :: [term]
  def sort(keys), do: Enum.sort_by(keys, &{rank(&1), name(&1)})

  # the shown order: plain keys (arrows first), F-keys, ALT-F, ALT, then CTRL
  @plain [:up, :down, :left, :right, :pgup, :pgdn, :home, :end, :insert, :delete] ++
           [:esc, :enter, :backspace, :tab, :shift_tab] ++
           [:ctrl_pgup, :ctrl_pgdn, :ctrl_home, :ctrl_end]

  defp rank({:f, n}), do: {1, n}
  defp rank({:alt_f, n}), do: {2, n}
  defp rank({:alt, _}), do: {3, 0}
  defp rank({:ctrl, _}), do: {4, 0}
  defp rank(key), do: {0, Enum.find_index(@plain, &(&1 == key)) || length(@plain)}

  @names %{
    up: "↑",
    down: "↓",
    left: "←",
    right: "→",
    enter: "ENTER",
    tab: "TAB",
    shift_tab: "SHIFT-TAB",
    backspace: "BACKSPACE",
    delete: "DEL",
    insert: "INS",
    esc: "ESC",
    home: "HOME",
    end: "END",
    pgup: "PGUP",
    pgdn: "PGDN",
    ctrl_left: "CTRL-←",
    ctrl_right: "CTRL-→",
    ctrl_up: "CTRL-↑",
    ctrl_down: "CTRL-↓",
    ctrl_pgup: "CTRL-PGUP",
    ctrl_pgdn: "CTRL-PGDN",
    ctrl_home: "CTRL-HOME",
    ctrl_end: "CTRL-END"
  }

  # every key `parse/1` can read back from its name
  @parsable Map.keys(@names) ++
              for(n <- 1..10, k <- [{:f, n}, {:alt_f, n}, {:shift_f, n}], do: k) ++
              for(c <- ?a..?z, k <- [{:ctrl, <<c>>}, {:alt, <<c>>}], do: k) ++
              for(k <- [:up, :down, :left, :right, :enter, :backspace], do: {:alt, k})

  @doc """
  The key a name stands for (`ALT-F4`, `CTRL-D`, `SPACE`, `x`), or nil; a
  dash, as a key bar writes "no key", is none.
  """
  @spec parse(String.t()) :: term | nil
  def parse("SPACE"), do: {:char, " "}
  def parse(<<c::utf8>> = char) when c not in [?—, ?-, ?·], do: {:char, char}

  def parse(name) do
    upper = String.upcase(name)
    Enum.find(@parsable, &(name(&1) == upper))
  end

  @doc "A key's name as the help and KEYBOARD.md write it: `ALT-F4`, `CTRL-D`, `↓`."
  @spec name(term) :: String.t()
  def name(key) when is_map_key(@names, key), do: @names[key]
  def name({:f, n}), do: "F#{n}"
  def name({:alt_f, n}), do: "ALT-F#{n}"
  def name({:shift_f, n}), do: "SHIFT-F#{n}"
  def name({:ctrl, c}), do: "CTRL-" <> String.upcase(c)
  def name({:alt, key}) when is_atom(key), do: "ALT-" <> name(key)
  def name({:alt, "-"}), do: "ALT-−"
  def name({:alt, c}), do: "ALT-" <> String.upcase(c)
  def name({:char, " "}), do: "SPACE"
  def name({:char, c}), do: c
  def name(key), do: inspect(key)
end
