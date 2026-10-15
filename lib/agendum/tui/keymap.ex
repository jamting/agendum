defmodule Agendum.TUI.Keymap do
  @moduledoc """
  Which command a key runs, by place (ADR 0033): a key event (as
  `Agendum.TUI.Terminal.Keys` decodes it) to a command id of
  `Agendum.TUI.Commands`. Agenda's keys (SPEC R42), with ours beside them
  (R31). ALT-letters are here too; ESC + letter is the same key once
  decoded.

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

  @keymaps %{view: @view}

  @doc "The command id `key` runs in `place`, or nil when it is not bound there."
  @spec lookup(atom, term) :: atom | nil
  def lookup(place, key), do: @keymaps |> Map.get(place, %{}) |> Map.get(key)

  @doc "A place's bindings, key to command id."
  @spec bindings(atom) :: %{term => atom}
  def bindings(place), do: Map.get(@keymaps, place, %{})

  @doc "The keys bound to a command in a place."
  @spec keys_for(atom, atom) :: [term]
  def keys_for(place, id), do: for({key, ^id} <- bindings(place), do: key)
end
