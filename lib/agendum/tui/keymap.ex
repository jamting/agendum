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
    # Zettel ids (R73, R73b): ours, on CTRL keys Agenda left free (the
    # owner's choice, 2026-10-17)
    {:ctrl, "t"} => :attach_zettel,
    {:ctrl, "g"} => :follow_link,
    {:ctrl, "r"} => :linked_from,
    # a feed entry's link in the browser (R75)
    {:ctrl, "v"} => :open_link,
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
    # the category manager's own menu, as Agenda's (2026-10-24)
    {:f, 10} => :menu,
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
    {:f, 6} => :properties,
    {:alt_f, 5} => :sort,
    {:f, 5} => :order,
    {:alt, :up} => :move_up,
    {:alt, :down} => :move_down,
    {:f, 4} => :discard,
    :delete => :discard,
    {:alt_f, 4} => :discard,
    {:ctrl, "d"} => :discard
  }

  # a note (F5): any key not here edits the text (`Typing.TextEdit`)
  @note %{
    {:ctrl, "l"} => :insert_link,
    # Agenda's (R64f)
    {:alt_f, 9} => :append,
    {:alt_f, 8} => :get_items,
    {:alt, "c"} => :calendar,
    # INS / OVR and TAB (R64e); CTRL-N stands for INS
    :insert => :overwrite,
    :tab => :tab,
    :pgup => :page_up,
    :pgdn => :page_down,
    {:f, 10} => :menu,
    {:ctrl, "x"} => :run_by_name,
    :esc => :cancel,
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

  # the menu (F10 or /): a letter chooses the entry it begins (`Menu`)
  @menu %{
    :right => :next,
    :tab => :next,
    :left => :previous,
    :shift_tab => :previous,
    :home => :first,
    :end => :last,
    :enter => :choose,
    :esc => :back,
    :backspace => :back,
    {:f, 10} => :close,
    {:f, 1} => :help
  }

  # the highlight's moves in the view, while items move or a search runs
  @view_moves %{
    :up => :up,
    :down => :down,
    :pgup => :page_up,
    :pgdn => :page_down,
    :home => :top,
    :end => :bottom,
    :ctrl_pgup => :previous_section,
    :ctrl_pgdn => :next_section
  }

  # moving items (ALT-F10): the highlight shows where they go
  @move_item Map.merge(@view_moves, %{:enter => :drop, :esc => :close, {:f, 1} => :help})

  # searching the view (ALT-F6, then the matches)
  @searching Map.merge(@view_moves, %{
               {:alt, "n"} => :next_match,
               {:f, 8} => :next_match,
               {:alt, "p"} => :previous_match,
               {:f, 7} => :mark,
               :enter => :close,
               :esc => :close,
               {:f, 1} => :help
             })

  # Browse (ALT-B): a datebook's periods, or a date filter's days
  @browse %{
    :left => :earlier,
    {:char, "<"} => :earlier,
    :right => :later,
    {:char, ">"} => :later,
    :up => :week_earlier,
    :ctrl_left => :week_earlier,
    :down => :week_later,
    :ctrl_right => :week_later,
    :pgup => :month_earlier,
    :pgdn => :month_later,
    :ctrl_pgup => :year_earlier,
    :ctrl_pgdn => :year_later,
    {:alt_f, 5} => :go_to,
    :enter => :keep,
    :esc => :close,
    {:f, 1} => :help
  }

  # a column's width (View ▸ Column ▸ Width); digits type it (`ColumnWidth`)
  @column_width %{
    :left => :narrower,
    :right => :wider,
    {:char, "?"} => :fit,
    :enter => :keep,
    :esc => :close,
    {:f, 1} => :help
  }

  # moving a column (ALT-F10 on a column head)
  @column_move %{
    :left => :left,
    {:char, "<"} => :left,
    :right => :right,
    {:char, ">"} => :right,
    :enter => :keep,
    :esc => :close,
    {:f, 1} => :help
  }

  # moving a section (ALT-F10 on a section head)
  @section_move %{
    :up => :up,
    {:char, "<"} => :up,
    :down => :down,
    {:char, ">"} => :down,
    :enter => :keep,
    :esc => :close,
    {:f, 1} => :help
  }

  # typing on one line: an item, a name, a box's field, a prompt
  # (`Typing.LineEdit`); Mac and emacs keys beside the PC ones
  @line %{
    :left => :left,
    {:ctrl, "b"} => :left,
    :right => :right,
    {:ctrl, "f"} => :right,
    :home => :line_start,
    {:ctrl, "a"} => :line_start,
    :end => :line_end,
    {:ctrl, "e"} => :line_end,
    :ctrl_left => :word_left,
    {:alt, "b"} => :word_left,
    {:alt, :left} => :word_left,
    :ctrl_right => :word_right,
    {:alt, "f"} => :word_right,
    {:alt, :right} => :word_right,
    :backspace => :delete_back,
    :delete => :delete,
    {:ctrl, "d"} => :delete,
    {:ctrl, "k"} => :delete_to_end,
    {:ctrl, "w"} => :delete_word,
    {:alt, :backspace} => :delete_word,
    {:ctrl, "u"} => :clear,
    # Agenda's editing keys (User's Guide 3-4; `Typing.LineClip`): F7
    # marks, F3 copies, F4 cuts, ALT-F4 deletes, F2 pastes; F5 opens an
    # item's note, F1 the help
    {:f, 1} => :help,
    {:f, 2} => :paste,
    {:f, 3} => :copy,
    {:f, 4} => :cut,
    {:alt_f, 4} => :delete_marked,
    {:f, 5} => :note,
    {:f, 7} => :mark
  }

  # typing in a note (`Typing.TextEdit`); the note's own commands are `@note`
  @text %{
    :left => :left,
    :right => :right,
    :up => :up,
    :down => :down,
    :home => :line_start,
    {:ctrl, "a"} => :line_start,
    :end => :line_end,
    {:ctrl, "e"} => :line_end,
    :enter => :new_line,
    :backspace => :delete_back,
    :delete => :delete,
    {:ctrl, "d"} => :delete,
    # Agenda's (R64e), with the Mac's ⌥ keys and Emacs's beside them
    {:alt, "m"} => :new_line,
    :ctrl_left => :word_left,
    {:alt, :left} => :word_left,
    :ctrl_right => :word_right,
    {:alt, :right} => :word_right,
    {:alt, :backspace} => :delete_word,
    {:ctrl, "w"} => :delete_word,
    {:alt, "w"} => :delete_word_right,
    {:ctrl, "k"} => :delete_to_end,
    :ctrl_home => :text_start,
    {:alt, "<"} => :text_start,
    :ctrl_end => :text_end,
    {:alt, ">"} => :text_end
  }

  # every box (`Update`'s box stage); its own keys are the box's
  @box %{
    {:f, 1} => :help,
    # Agenda's EDIT: the highlighted setting's text (`Boxes.BoxEdit`)
    {:f, 2} => :edit,
    {:f, 3} => :choices,
    # Agenda's DEFAULT and DFLTALL (User's Guide 2-17)
    {:f, 8} => :default,
    {:alt_f, 8} => :default_all,
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
    # `Agendum.TUI.Macros` takes ALT-F3 before any keymap (in Learn mode
    # too); bound here so the key bar and the help can name it
    {:alt_f, 3} => :macros,
    # ours (R65d, ADR 0040): Agenda left CTRL-X free
    {:ctrl, "x"} => :run_by_name,
    {:alt, "q"} => :quit,
    {:ctrl, "q"} => :quit,
    {:ctrl, "c"} => :quit
  }

  @keymaps %{
    view: @view,
    catmgr: @catmgr,
    viewmgr: @viewmgr,
    note: @note,
    menu: @menu,
    line: @line,
    text: @text,
    move_item: @move_item,
    searching: @searching,
    browse: @browse,
    column_width: @column_width,
    column_move: @column_move,
    section_move: @section_move,
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

  @doc "The places with a keymap."
  @spec places() :: [atom]
  def places, do: Map.keys(@keymaps)

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
              for(n <- 1..10, k <- [{:f, n}, {:alt_f, n}, {:shift_f, n}, {:ctrl_f, n}], do: k) ++
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
  def name({:ctrl_f, n}), do: "CTRL-F#{n}"
  def name({:ctrl, c}), do: "CTRL-" <> String.upcase(c)
  def name({:alt, key}) when is_atom(key), do: "ALT-" <> name(key)
  def name({:alt, "-"}), do: "ALT-−"
  def name({:alt, c}), do: "ALT-" <> String.upcase(c)
  def name({:char, " "}), do: "SPACE"
  def name({:char, c}), do: c
  def name(key), do: inspect(key)
end
