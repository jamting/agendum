defmodule Agendum.TUI.Commands do
  @moduledoc """
  The commands keys can run, by place (ADR 0033): `Agendum.TUI.Keymap`
  binds keys to their ids, `Agendum.TUI.Update.ViewKeys.run` runs the
  view's. The order is the one the command list will show.

  So far the view's (`:view`), the category manager's (`:catmgr`), the view
  manager's (`:viewmgr`), a note's (`:note`), the menu's (`:menu`), every
  box's (`:box`)
  and the global ones (`:global`); other places move over a few at a time.
  Pure.
  """

  alias Agendum.TUI.Command

  # {id, name, summary, count}: what a count does is chosen with care
  # (ADR 0033): moves take one; commands that change the file do not
  @view [
    {:up, "Up", "Highlight the row above", :own},
    {:down, "Down", "Highlight the row below", :own},
    {:page_up, "Page up", "Highlight the row a screen up", :own},
    {:page_down, "Page down", "Highlight the row a screen down", :own},
    {:top, "Top", "Highlight the first row of the view", :none},
    {:bottom, "Bottom", "Highlight the last row of the view", :none},
    {:previous_section, "Previous section", "Highlight the section head above", :own},
    {:next_section, "Next section", "Highlight the section head below", :own},
    {:next_column, "Next column", "Highlight the column to the right", :own},
    {:previous_column, "Previous column", "Highlight the column to the left", :own},
    {:insert, "Insert", "Add an item below, or a column entry", :none},
    {:edit, "Edit", "Edit the item, head or column entry", :none},
    {:choices, "Choices", "Column choices, calendar or profile", :none},
    {:done, "Done", "Mark the item(s) done", :none},
    {:note, "Note", "The note of the item or category", :none},
    {:properties, "Properties", "Item, section or column properties", :none},
    {:mark, "Mark", "Mark the item, or all in the section", :none},
    {:unmark_all, "Unmark all", "Unmark every marked item", :none},
    {:next_marked, "Next marked", "Highlight the next marked item", :repeat},
    {:remove, "Remove", "Remove from the section or column", :none},
    {:discard, "Discard", "Discard the item(s) from the file", :none},
    {:make_assign, "MakeAssign", "Assign the item(s) to a category", :none},
    {:when, "When", "Set the item's When date", :none},
    {:move, "Move", "Move the item(s), section or column", :none},
    {:copy, "Copy", "Copy the item to another section", :none},
    {:yank, "Yank", "Put back the item DEL removed last", :none},
    {:hop, "Hop", "Highlight the item's next occurrence", :repeat},
    {:dependency, "Depend", "Make it depend on the marked items", :none},
    {:section_below, "Add section below", "Add a section below this one", :none},
    {:section_above, "Add section above", "Add a section above this one", :none},
    {:column_right, "Add column right", "Add a column to the right", :none},
    {:column_left, "Add column left", "Add a column to the left", :none},
    {:collapse, "Collapse", "Collapse the section (twice: all)", :none},
    {:expand, "Expand", "Expand the section (twice: all)", :none},
    {:toggle_empty, "Empty sections", "Show or hide empty sections", :none},
    {:go_to, "Go to", "Highlight a section chosen from a list", :none},
    {:search, "Search", "Search the view", :none},
    {:browse, "Browse", "Browse the view's dates", :none},
    {:calendar, "Calendar", "Show the calendar", :none},
    {:alarm, "Alarm", "Set an alarm on the item", :none},
    {:execute_all, "Execute all", "Run all conditions and actions", :none},
    {:execute_category, "Execute", "Run the section's conditions, actions", :none},
    {:attach_zettel, "Attach Zettel id", "Give the item(s) the next Zettel id", :none},
    {:follow_link, "Follow link", "Show the items its links point at", :none},
    {:linked_from, "Linked from", "Show the items that link to it", :none},
    {:open_link, "Open link", "Open the item's link in the browser", :none},
    {:next_view, "Next view", "Show the next view", :repeat},
    {:previous_view, "Previous view", "Show the previous view", :repeat},
    {:last_view, "Last view", "Show the view shown before this one", :none},
    {:view_manager, "View manager", "List the file's views", :none},
    {:category_manager, "Category manager", "Show the category hierarchy", :none},
    {:menu, "Menu", "Open the menu", :none},
    {:help, "Help", "Help about where you are", :none},
    {:save, "Save", "Save the file", :none},
    {:retrieve, "Retrieve", "Open another file", :none}
  ]

  # the category manager (F9); no counts here yet (ADR 0033: views first)
  @catmgr [
    {:up, "Up", "Highlight the category above", :none},
    {:down, "Down", "Highlight the category below", :none},
    {:page_up, "Page up", "A screen up", :none},
    {:page_down, "Page down", "A screen down", :none},
    {:first, "First", "Highlight MAIN, the first category", :none},
    {:last, "Last", "Highlight the last category", :none},
    {:parent, "Parent", "Highlight the parent", :none},
    {:last_sibling, "Last sibling", "Highlight the last of the siblings", :none},
    {:previous_sibling, "Previous sibling", "Highlight the sibling above", :none},
    {:next_sibling, "Next sibling", "Highlight the sibling below", :none},
    {:add_below, "Add below", "Add a category below this one", :none},
    {:add_above, "Add above", "Add a category above this one", :none},
    {:add_child, "Add child", "Add a child of this category", :none},
    {:add_family, "Add family", "Add a category after the parent", :none},
    {:rename, "Rename", "Rename the category", :none},
    {:note, "Note", "The category's note", :none},
    {:properties, "Properties", "The category's properties", :none},
    {:promote, "Promote", "Move the category up a level", :none},
    {:demote, "Demote", "Make it a child of the one above", :none},
    {:move_up, "Move up", "Move it above its previous sibling", :none},
    {:move_down, "Move down", "Move it below its next sibling", :none},
    {:move, "Move", "Move it under another parent", :none},
    {:sort, "Sort", "Sort its children by name", :none},
    {:discard, "Discard", "Discard it and its children", :none},
    {:execute, "Execute", "Run its conditions and actions", :none},
    {:collapse, "Collapse", "Collapse the family (twice: all)", :none},
    {:expand, "Expand", "Expand the family (twice: all)", :none},
    {:help, "Help", "Help about where you are", :none},
    {:close, "Return", "Back to the view", :none}
  ]

  # the view manager (F8)
  @viewmgr [
    {:up, "Up", "Highlight the view above", :none},
    {:down, "Down", "Highlight the view below", :none},
    {:first, "First", "Highlight the first view", :none},
    {:last, "Last", "Highlight the last view", :none},
    {:show, "Show", "Show the highlighted view", :none},
    {:add, "Add", "Add a view", :none},
    {:rename, "Rename", "Rename the view", :none},
    {:move_up, "Move up", "Move the view up the list", :none},
    {:move_down, "Move down", "Move the view down the list", :none},
    {:sort, "Sort", "Sort the views by name", :none},
    {:order, "Recently used", "List by when last used, or your order", :none},
    {:discard, "Discard", "Discard the view (items are kept)", :none},
    {:help, "Help", "Help about where you are", :none},
    {:close, "Return", "Back to the view shown", :none}
  ]

  # a note (F5, R39, R42, R63); keys not here edit the text
  @note [
    {:mark, "Mark", "Mark text (again: unmark)", :none},
    {:copy, "Copy", "Copy the marked text (or a word …)", :none},
    {:cut, "Cut", "Cut the marked text (or a word …)", :none},
    {:delete, "Delete", "Delete the marked text, not kept", :none},
    {:paste, "Paste", "Paste what was copied or cut last", :none},
    {:search, "Search", "Search or replace in the note", :none},
    {:search_next, "Search again", "Find the next one (or replace it)", :none},
    {:insert_date, "Date", "Type today's date", :none},
    {:insert_time, "Time", "Type the time", :none},
    {:insert_link, "Insert link", "Type a link to the marked item(s)", :none},
    {:next_note, "Next note", "Save; the next item's note", :none},
    {:previous_note, "Previous note", "Save; the previous item's note", :none},
    {:make_item, "Make item", "Make the marked text an item", :none},
    {:make_category, "Make category", "Make the marked text a category", :none},
    {:key_map, "Key map", "Show or hide the function key map", :none},
    {:run_by_name, "Run by name", "Run a command chosen by its name", :none},
    {:menu, "Menu", "The note's menu: Import, Export …", :none},
    {:overwrite, "Insert/Overwrite", "Insert, or type over (OVR)", :none},
    {:tab, "Tab", "Spaces to the next tab stop", :none},
    {:page_up, "Page up", "A screen of rows up", :none},
    {:page_down, "Page down", "A screen of rows down", :none},
    {:clear, "Clear", "Delete all text in the note", :none},
    {:help, "Help", "Help about where you are", :none},
    {:close, "Return", "Save the note and go back", :none},
    {:cancel, "Cancel", "Go back; asks to discard any changes", :none},
    {:quit, "Quit", "Save the note and quit Agendum", :none}
  ]

  # the menu (F10 or /); its entries are chosen by their first letter
  @menu [
    {:choose, "Choose", "Choose the highlighted entry", :none},
    {:next, "Next", "Highlight the entry to the right", :none},
    {:previous, "Previous", "Highlight the entry to the left", :none},
    {:first, "First", "Highlight the first entry", :none},
    {:last, "Last", "Highlight the last entry", :none},
    {:back, "Back", "Back up a level", :none},
    {:help, "Help", "Help about where you are", :none},
    {:close, "Leave", "Leave the menu", :none}
  ]

  # the view's moves, as they are in the view
  @view_moves [
    {:up, "Up", "Highlight the row above", :none},
    {:down, "Down", "Highlight the row below", :none},
    {:page_up, "Page up", "Highlight the row a screen up", :none},
    {:page_down, "Page down", "Highlight the row a screen down", :none},
    {:top, "Top", "Highlight the first row of the view", :none},
    {:bottom, "Bottom", "Highlight the last row of the view", :none},
    {:previous_section, "Previous section", "Highlight the section head above", :none},
    {:next_section, "Next section", "Highlight the section head below", :none}
  ]

  @move_item [{:drop, "Drop", "Move the item(s) here", :none}] ++
               @view_moves ++
               [
                 {:help, "Help", "Help about where you are", :none},
                 {:close, "Cancel", "Leave the item(s) where they were", :none}
               ]

  @searching [
               {:next_match, "Next match", "Highlight the next match", :none},
               {:previous_match, "Previous match", "Highlight the previous match", :none},
               {:mark, "Mark", "Mark the highlighted item", :none}
             ] ++
               @view_moves ++
               [
                 {:help, "Help", "Help about where you are", :none},
                 {:close, "End search", "Stop searching", :none}
               ]

  @browse [
    {:earlier, "Earlier", "A period (filter: a day) earlier", :none},
    {:later, "Later", "A period (filter: a day) later", :none},
    {:week_earlier, "Week earlier", "In a filter: a week earlier", :none},
    {:week_later, "Week later", "In a filter: a week later", :none},
    {:month_earlier, "Month earlier", "In a filter: a month earlier", :none},
    {:month_later, "Month later", "In a filter: a month later", :none},
    {:year_earlier, "Year earlier", "In a filter: a year earlier", :none},
    {:year_later, "Year later", "In a filter: a year later", :none},
    {:go_to, "Go to", "Go to a date typed", :none},
    {:keep, "Keep", "Keep the dates shown", :none},
    {:help, "Help", "Help about where you are", :none},
    {:close, "Cancel", "Back to the dates before", :none}
  ]

  @column_width [
    {:narrower, "Narrower", "One column narrower", :none},
    {:wider, "Wider", "One column wider", :none},
    {:fit, "Fit", "As wide as what it shows", :none},
    {:keep, "Keep", "Keep this width", :none},
    {:help, "Help", "Help about where you are", :none},
    {:close, "Cancel", "Keep the width it had", :none}
  ]

  @column_move [
    {:left, "Left", "Move the column left", :none},
    {:right, "Right", "Move the column right", :none},
    {:keep, "Keep", "Keep it here", :none},
    {:help, "Help", "Help about where you are", :none},
    {:close, "Cancel", "Put it back", :none}
  ]

  @section_move [
    {:up, "Up", "Move the section up", :none},
    {:down, "Down", "Move the section down", :none},
    {:keep, "Keep", "Keep it here", :none},
    {:help, "Help", "Help about where you are", :none},
    {:close, "Cancel", "Put it back", :none}
  ]

  # what every box shares; each box's own commands are in its module
  # (`Agendum.TUI.Boxes.Box`'s `keymap/1`, `commands/1`)
  @box [
    {:choices, "Choices", "List the setting's choices", :none},
    {:cancel, "Cancel", "Close; put back the box's changes", :none},
    {:help, "Help", "Help about where you are", :none}
  ]

  # the keys that work on every screen but while typing (`Update`'s
  # global keys); Save and Retrieve are also the view's ALT-W and ALT-G
  @global [
    {:undo, "Undo", "Undo the last change", :none},
    {:redo, "Redo", "Redo what was undone", :none},
    {:save, "Save", "Save the file", :none},
    {:retrieve, "Retrieve", "Open another file", :none},
    {:export, "Print", "Print the view to a file (in a view)", :none},
    {:key_map, "Key map", "Show or hide the function key map", :none},
    {:run_by_name, "Run by name", "Run a command chosen by its name", :none},
    {:quit, "Quit", "Quit Agendum", :none}
  ]

  # Enum.map, not `for`: an entry of the wrong shape fails at compile
  # time instead of being left out
  @commands %{
    view:
      Enum.map(@view, fn {id, name, summary, count} ->
        %Command{id: id, name: name, summary: summary, count: count}
      end),
    catmgr:
      Enum.map(@catmgr, fn {id, name, summary, count} ->
        %Command{id: id, name: name, summary: summary, count: count}
      end),
    viewmgr:
      Enum.map(@viewmgr, fn {id, name, summary, count} ->
        %Command{id: id, name: name, summary: summary, count: count}
      end),
    note:
      Enum.map(@note, fn {id, name, summary, count} ->
        %Command{id: id, name: name, summary: summary, count: count}
      end),
    menu:
      Enum.map(@menu, fn {id, name, summary, count} ->
        %Command{id: id, name: name, summary: summary, count: count}
      end),
    box:
      Enum.map(@box, fn {id, name, summary, count} ->
        %Command{id: id, name: name, summary: summary, count: count}
      end),
    global:
      Enum.map(@global, fn {id, name, summary, count} ->
        %Command{id: id, name: name, summary: summary, count: count}
      end)
  }

  @line [
    {:left, "Left", "A character left", :none},
    {:right, "Right", "A character right", :none},
    {:word_left, "Word left", "A word left", :none},
    {:word_right, "Word right", "A word right", :none},
    {:line_start, "Start", "The start of the line", :none},
    {:line_end, "End", "The end of the line", :none},
    {:delete_back, "Delete back", "Delete the character before", :none},
    {:delete, "Delete", "Delete the character under the cursor", :none},
    {:delete_word, "Delete word", "Delete the word before", :none},
    {:delete_to_end, "Delete to end", "Delete to the end of the line", :none},
    {:clear, "Clear", "Clear the line", :none}
  ]

  @text [
    {:left, "Left", "A character left", :none},
    {:right, "Right", "A character right", :none},
    {:up, "Up", "The row above (as shown)", :none},
    {:down, "Down", "The row below (as shown)", :none},
    {:line_start, "Start", "Start of the row; again: of the line", :none},
    {:line_end, "End", "End of the row; again: of the line", :none},
    {:new_line, "New line", "Break the line here", :none},
    {:delete_back, "Delete back", "Delete the character before", :none},
    {:delete, "Delete", "Delete the character under the cursor", :none},
    {:word_left, "Word left", "A word left, on to the line above", :none},
    {:word_right, "Word right", "A word right, on to the line below", :none},
    {:delete_word, "Delete word", "Delete the word before", :none},
    {:delete_word_right, "Delete next word", "Delete the word after", :none},
    {:delete_to_end, "Delete to end", "Delete to the end of the line", :none},
    {:text_start, "Start of note", "The start of the note", :none},
    {:text_end, "End of note", "The end of the note", :none}
  ]

  @more %{
    line: @line,
    text: @text,
    move_item: @move_item,
    searching: @searching,
    browse: @browse,
    column_width: @column_width,
    column_move: @column_move,
    section_move: @section_move
  }

  @commands Map.merge(
              @commands,
              Map.new(@more, fn {place, list} ->
                {place,
                 Enum.map(list, fn {id, name, summary, count} ->
                   %Command{id: id, name: name, summary: summary, count: count}
                 end)}
              end)
            )

  # each command's longer text (R65b), from `Agendum.TUI.CommandDocs`
  @docs Agendum.TUI.CommandDocs.all()

  @commands Map.new(@commands, fn {place, list} ->
              {place, Enum.map(list, &%{&1 | doc: get_in(@docs, [place, &1.id])})}
            end)

  @doc "The commands of a place, in the command list's order."
  @spec all(atom) :: [Command.t()]
  def all(place), do: Map.get(@commands, place, [])

  @doc "A place's command by id, or nil."
  @spec get(atom, atom) :: Command.t() | nil
  def get(place, id), do: Enum.find(all(place), &(&1.id == id))

  # --- finding a command by its name (R65d, ADR 0040) ----------------------------

  @doc """
  The entries whose name matches `query`, best first: CTRL-X's box and
  F1 `c`'s narrowing both use it, and so is the web's palette to. Each
  entry can be anything; the options say how to read it:

    * `name:` its name (required)
    * `summary:` its summary, matched only by what it holds, after every
      name (default: none)
    * `recent:` keys of the recently used, most recent first, and `key:`
      an entry's key in it (default: its name)

  How well a name matches (case and spaces aside), best first: it starts
  with `query`; a word of it does, or the letters are the initials of its
  words in order ("azi" is Attach Zettel id); the letters are in it in
  order, the closer together the better; then the summaries. Among
  equals the recently used come first, then the list's order. With
  nothing typed every entry is kept, the recently used first. Pure.
  """
  @spec match([e], String.t(), keyword) :: [e] when e: term
  def match(entries, query, opts) do
    name = Keyword.fetch!(opts, :name)
    summary = Keyword.get(opts, :summary, fn _ -> nil end)
    key = Keyword.get(opts, :key, name)
    recent = opts |> Keyword.get(:recent, []) |> Enum.with_index() |> Map.new()
    query = String.downcase(query)

    # `Enum.with_index/1` numbers the entries, so that a sort on equal
    # ranks keeps the list's order; a generator (`<-`) whose pattern does
    # not match skips the entry, so nil from `rank/3` drops it
    for {entry, i} <- Enum.with_index(entries),
        {kind, closeness} <- [rank(String.downcase(name.(entry)), summary.(entry), query)] do
      {kind, Map.get(recent, key.(entry), map_size(recent)), closeness, i, entry}
    end
    # tuples compare element by element: the kind of match, how recent,
    # how close the letters are, then the list's place
    |> Enum.sort()
    |> Enum.map(&elem(&1, 4))
  end

  # how well `name` (lowercased) matches: `{kind, closeness}`, smaller is
  # better (kind 0 a prefix … 3 the summary only), or nil for no match
  defp rank(_name, _summary, ""), do: {0, 0}

  defp rank(name, summary, query) do
    letters = String.replace(query, " ", "")
    words = String.split(name, " ", trim: true)

    cond do
      String.starts_with?(name, query) -> {0, 0}
      String.contains?(" " <> name, " " <> query) -> {1, 0}
      initials?(words, String.graphemes(letters)) -> {1, 1}
      span = spread(String.graphemes(String.replace(name, " ", "")), letters) -> {2, span}
      summary && String.contains?(String.downcase(summary), query) -> {3, 0}
      true -> nil
    end
  end

  # whether each letter begins a word, in order (words may be skipped)
  defp initials?(_words, []), do: true
  defp initials?([], _letters), do: false

  defp initials?([word | words], [letter | rest] = letters) do
    if String.starts_with?(word, letter),
      do: initials?(words, rest),
      else: initials?(words, letters)
  end

  # How far apart the letters of `query` are in `name` (both without
  # spaces), each found as early as it can be after the one before; nil
  # when they are not all there in order. The span is how many characters
  # the match covers beyond the query's own.
  defp spread(name, query) do
    query
    |> String.graphemes()
    |> Enum.reduce_while({name, 0, nil}, fn letter, {rest, at, first} ->
      case Enum.find_index(rest, &(&1 == letter)) do
        nil -> {:halt, nil}
        i -> {:cont, {Enum.drop(rest, i + 1), at + i + 1, first || at + i}}
      end
    end)
    |> case do
      nil -> nil
      {_rest, last, first} -> last - first - String.length(query)
    end
  end
end
