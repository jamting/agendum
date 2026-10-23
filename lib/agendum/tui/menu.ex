defmodule Agendum.TUI.Menu do
  @moduledoc """
  The Lotus-style two-line menu (F10 or `/`).

  The first line lists the commands at the current level; the second line
  shows the highlighted command's subcommands or a description. Select a
  command with the arrow keys and ENTER, or by typing its first letter.
  ESC backs up one level.

  A command that opens a box, a prompt or a question keeps the menu
  beneath it, as Agenda did: ESC there comes back to the menu level the
  command was chosen from, and ESC again backs up a level until the view
  (screenshot notes 8 to 15). A box finished any other way (ENTER) closes
  the menu too (`resumed/2`).
  """

  alias Agendum.TUI.{Keymap, State}
  alias Agendum.TUI.Update.Actions

  @doc """
  A menu tree: `{label, description, children_or_action}`. The view's
  (`:main`, the default) or the note editor's (`:note`, R64b), whose
  actions are a note's commands, `{:note, id}`. The whole tree, extras
  included (R77): `entries/1` leaves them out while they are off, and a
  description that names them is `{without, with}` the extras.
  """
  @spec tree(:main | :note) :: [tuple]
  def tree(which \\ :main)

  # Agenda's note menu (R64b): File, Print, Import, Export, Clear, Return,
  # Quit; printing is out of scope, File comes with external note files
  # (NOTE_EDITOR.md step 7)
  def tree(:note) do
    [
      {"Import", "Import a text file into the current note", {:note, :import}},
      {"Export", "Export the current note to a text file", {:note, :export}},
      {"Clear", "Delete all text in the current note", {:note, :clear}},
      {"Return", "Return to the previous activity (F5)", {:note, :close}},
      {"Quit", "End this Agendum session (ALT-Q); the note is saved", {:note, :quit}}
    ]
  end

  def tree(:main) do
    [
      {"File", "Retrieve, save or create files",
       [
         {"Retrieve", "Open an existing Agendum file (CTRL-O)", :retrieve},
         {"Save", "Save the current file (CTRL-S)", :save},
         {"Write", "Write the file under a new name (Save As)", :save_as},
         {"New", "Create a new, empty file", :new_file},
         {"Dating", "Turn When dates read from text on or off", :toggle_auto_date},
         {"Properties", "How the file displays dates and times", :file_props},
         {"Customize", "Your theme, date languages and input format, for every file", :customize},
         {"Transfer",
          {"Export or import the file",
           "Export or import the file, calendars, feeds, publish the blog"},
          [
            {"Export", "Write the whole file as a JSON file", :export_json},
            {"Import", "Open a JSON file as a new, untitled file", :import_json},
            {"Calendars", "Subscribe to calendars on the web (iCal); read them now", :calendars},
            {"Publish", "Write the blog from the posts category as a website, and upload it",
             :publish},
            {"Feeds", "Subscribe to RSS and Atom feeds; read them now; OPML", :feeds}
          ]}
       ]},
      {"Item", "Work with the highlighted item",
       [
         {"Properties", "Text, note and every assignment of the item (F6)", :item_props},
         {"Note", "Edit the item's note (F5)", :note},
         {"When", "Set the item's When date; overrides dates in the text (ALT-F2)", :when},
         {"Show", "Show the item's assignment profile (F3)", :assign},
         {"Alarm", "Set or cancel an alarm before the When time (ALT-A)", :alarm},
         {"Finished", "Mark the item done / not done (F4)", :done},
         {"Mark", "Mark or unmark the item; on a section head, all its items (F7)", :mark},
         {"Unmark", "Unmark all marked items in the file (ALT-F7)", :unmark_all},
         {"Categorize", "Assign the item, or all marked items, to a category (ALT-M)",
          :make_assign},
         {"Reposition", "Move the item to another section or position (ALT-F10)", :move_item},
         {"Open link", "Open the item's web link in the browser (CTRL-V)", :open_link},
         {"Zettel", "Zettel ids: give the item one, follow its links",
          [
            {"Attach", "Give the item, or the marked items, the next Zettel id", :attach_zettel},
            {"Follow", "Show the items the item's links point at", :follow_link},
            {"Linked", "Show the items that link to the item (Linked from)", :linked_from}
          ]},
         {"Discard", "Delete the item from the file (ALT-F4)", :discard}
       ]},
      {"Category", "Work with categories",
       [
         {"Manager", "Open the category manager (F9)", :category_manager},
         {"Add", "Add a category under MAIN", :add_category},
         {"Recalc", "Re-run automatic assignment for every item", :recalc},
         {"Execute", "Apply conditions and actions to existing items (ALT-X all, ALT-E one)",
          :execute},
         {"Questions", "Confirm suggested assignments (Utilities Questions)", :questions}
       ]},
      {"View", "Change the current view or create new ones",
       [
         {"Manager", "Switch, add, rename or discard views (F8)", :view_manager},
         {"Add", "Create a new view", :add_view},
         {"Rename", "Rename the current view", :rename_view},
         {"Discard", "Delete the current view (items are kept)", :discard_view},
         {"Properties", "A datebook view's settings: period, base date, categories", :view_props},
         {"Browse", "Move a datebook view or a date filter to other dates (ALT-B)", :browse},
         {"Section", "Add, remove or collapse sections",
          [
            {"Below", "Add a section below the current one (ALT-D)", :section_below},
            {"Above", "Add a section above the current one (ALT-U)", :section_above},
            {"Remove", "Remove the current section from the view (DEL on head)", :remove_section},
            {"Collapse", "Collapse or expand the current section", :collapse_section},
            {"Filter", "Show only items in (or not in) chosen categories, in this section",
             :filter_section},
            {"Sort", "How this section's items are ordered", :sort_section},
            {"Properties", "The section's head, sorting, filter and columns (F6 on its head)",
             :section_props},
            {"Move", "Move the section up or down in this view (ALT-F10 on its head)",
             :section_move},
            {"Lines", "Lines between the sections (section separators)",
             {:toggle_view, :section_separators}}
          ]},
         {"Column", "Add, remove or resize columns",
          [
            {"Properties",
             "The column's width, link with other sections, and how it shows values",
             :column_props},
            {"Add", "Add a column, right or left of the current one (ALT-R, ALT-L)", :column_add},
            {"Remove", "Remove the highlighted column", :remove_column},
            {"Move", "Move the highlighted column in its section (ALT-F10 on its head)",
             :column_move},
            {"Width", "The highlighted column's width: ← →, a number, or ? to fit it",
             :column_width}
          ]},
         {"Filter", "Show only items in (or not in) chosen categories", :filter_view},
         {"Order", "Sort the items in every section (the view's sort settings)", :sort_view},
         {"Last", "Return to the view shown before this one (ALT-F8)", :last_view},
         {"Hide", "Choose which items the view hides",
          [
            {"Done", "Hide or show done items", {:toggle_view, :hide_done}},
            {"Empty", "Hide or show empty sections", {:toggle_view, :hide_empty}},
            {"Inherited", "Hide or show items only in subcategories",
             {:toggle_view, :hide_inherited}},
            {"Pending", "Hide or show items waiting for others to be done (ALT-O)",
             {:toggle_view, :hide_dependent}},
            {"Column heads", "Show column heads only in the first section on the screen",
             {:toggle_view, :hide_column_heads}}
          ]}
       ]},
      {"Search", "Find items by their text",
       [
         {"View", "Search this view: ALT-N next, ALT-P previous, F7 mark (ALT-F6)", :search_view},
         {"File", "Show every matching item in the file in the Show View", :search_file},
         {"Alarms", "Current alarms and today's past alarms", :alarm_list},
         {"Schedule", "One date's items in the Show View (Utilities Show Sched)", :show_schedule},
         {"Depends", "Show the items that depend on this one (Utilities Show Depends)",
          [
            {"One level", "Items directly depending on this one",
             {:show_related, :dependents, :one}},
            {"All levels", "The whole chain of items depending on this one",
             {:show_related, :dependents, :all}},
            {"Every item", "Every item in the file that others depend on",
             {:show_related, :dependents, :every}}
          ]},
         {"Prereqs", "Show the items this one depends on (Utilities Show Prereqs)",
          [
            {"One level", "Items directly this one depends on",
             {:show_related, :prerequisites, :one}},
            {"All levels", "The whole chain of items this one depends on",
             {:show_related, :prerequisites, :all}},
            {"Every item", "Every item in the file that depends on others",
             {:show_related, :prerequisites, :every}}
          ]}
       ]},
      {"Undo", "Undo the last change (CTRL-Z)", :undo},
      {"Redo", "Redo the last undone change (CTRL-Y)", :redo},
      {"Print", "Print the current view to a text file (CTRL-P)", :export},
      {"Quit", "Leave Agendum (CTRL-Q)", :quit}
    ]
  end

  @doc """
  Opens the menu: the view's, or the note editor's (`:note`); with the
  extras while the Extras preference is on (R77).
  """
  def open(state, which \\ :main) do
    State.push(state, %Agendum.TUI.Modes.Menu{
      path: [],
      selected: 0,
      tree: which,
      extras: state.prefs.extras
    })
  end

  # the tree a menu mode shows (a menu made before `tree` was a field: the
  # view's), the extras left out unless the menu was opened with them
  defp tree_of(mode), do: shown(Map.get(mode, :tree) || :main, Map.get(mode, :extras) == true)

  @doc """
  The tree as the person sees it (R77): without the extras unless
  `extras?`, each description picked for it. The comparison with Agenda's
  own menus reads it with the extras off.
  """
  @spec shown(:main | :note | [tuple], boolean) :: [tuple]
  def shown(which, extras?) when is_atom(which), do: shown(tree(which), extras?)

  # A level's entries as shown (R77): with the extras off, an entry that
  # runs an extra goes, and so does a level left empty by it (Item ▸
  # Zettel); a description `{without, with}` the extras is picked.
  def shown(level, extras?) do
    # a generator over a one-element list binds `action` anew for the
    # filter after it: a sub-level is first cut down itself
    for {label, description, action} <- level,
        action <- [if(is_list(action), do: shown(action, extras?), else: action)],
        extras? or not extra?(action),
        do: {label, description(description, extras?), action}
  end

  defp extra?([]), do: true
  defp extra?(action), do: action in Agendum.TUI.Commands.extra_actions()

  defp description({without, _with}, false), do: without
  defp description({_without, with}, true), do: with
  defp description(text, _extras?), do: text

  @doc "The entries at the menu's current level."
  def entries(%{path: path} = mode) do
    Enum.reduce(path, tree_of(mode), fn index, level ->
      {_, _, children} = Enum.at(level, index)
      children
    end)
  end

  @doc "The labels of the entries chosen to reach the menu's current level (`[\"View\", \"Hide\"]`)."
  @spec labels(map) :: [String.t()]
  def labels(%{path: path} = mode) do
    {labels, _level} =
      Enum.reduce(path, {[], tree_of(mode)}, fn index, {labels, level} ->
        {label, _, children} = Enum.at(level, index)
        {labels ++ [label], children}
      end)

    labels
  end

  @doc "F1's text in the menu (R65)."
  @spec about() :: String.t()
  def about do
    """
    The menu. Its first line lists the commands at this level; the second
    says what the highlighted one does, or lists what it holds.

    Type a command's first letter, or move with ← → and press ENTER. ESC
    backs up a level; F10 leaves the menu. A box opened from the menu comes
    back to it on ESC.
    """
  end

  @doc """
  A key in the menu: it runs the command the menu's keymap binds it to
  (`Agendum.TUI.Keymap`, R65); a letter chooses the entry it begins.
  """
  def handle(state, mode, key) do
    case {Keymap.lookup(:menu, key), key} do
      {nil, {:char, c}} -> letter(state, mode, c)
      {nil, _} -> state
      {id, _} -> command(state, mode, id)
    end
  end

  @doc "Runs a menu command (`Agendum.TUI.Commands`) in the menu on top."
  @spec run(State.t(), atom) :: State.t()
  def run(state, id), do: command(state, State.mode(state), id)

  @doc "Chooses the entry at `index` of the menu on top's level, as its letter would."
  @spec choose(State.t(), non_neg_integer) :: State.t()
  def choose(state, index), do: choose(state, State.mode(state), index)

  @doc "The index of the entry a letter chooses at the menu's level, or nil."
  @spec entry_for(map, String.t()) :: non_neg_integer | nil
  def entry_for(mode, c) do
    Enum.find_index(entries(mode), fn {label, _, _} ->
      String.upcase(String.first(label)) == String.upcase(c)
    end)
  end

  defp letter(state, mode, c) do
    case entry_for(mode, c) do
      nil -> state
      index -> choose(state, mode, index)
    end
  end

  defp command(state, mode, :next) do
    count = length(entries(mode))
    State.put_mode(state, %{mode | selected: rem(mode.selected + 1, count)})
  end

  defp command(state, mode, :previous) do
    count = length(entries(mode))
    State.put_mode(state, %{mode | selected: rem(mode.selected - 1 + count, count)})
  end

  defp command(state, mode, :first), do: State.put_mode(state, %{mode | selected: 0})

  defp command(state, mode, :last),
    do: State.put_mode(state, %{mode | selected: length(entries(mode)) - 1})

  defp command(state, mode, :choose), do: choose(state, mode, mode.selected)
  defp command(state, mode, :back), do: back(state, mode)
  defp command(state, _mode, :close), do: State.pop(state)
  defp command(state, _mode, :help), do: Agendum.TUI.HelpScreen.open(state)

  defp back(state, %{path: []}), do: State.pop(state)

  defp back(state, %{path: path} = mode) do
    State.put_mode(state, %{mode | path: Enum.drop(path, -1), selected: List.last(path)})
  end

  defp choose(state, mode, index) do
    case Enum.at(entries(mode), index) do
      {_, _, children} when is_list(children) ->
        State.put_mode(state, %{mode | path: mode.path ++ [index], selected: 0})

      # a note's command runs in the note beneath the menu (R64b)
      {_, _, {:note, id}} ->
        below = State.pop(state)

        below
        |> Agendum.TUI.Update.Notes.run(id)
        |> keep_beneath(below, %{mode | selected: index})

      {_, _, action} ->
        below = State.pop(state)
        below |> Actions.perform(action) |> keep_beneath(below, %{mode | selected: index})
    end
  end

  # The modes the command pushed onto `below`: if they are boxes, prompts
  # or questions, the menu goes beneath them, to come back to on ESC.
  defp keep_beneath(state, below, menu) do
    pushed = length(state.modes) - length(below.modes)
    {new, old} = Enum.split(state.modes, max(pushed, 0))

    if pushed > 0 and old == below.modes and Enum.all?(new, &overlay?/1),
      do: %{state | modes: new ++ [%{menu | resume: true} | old]},
      else: state
  end

  defp overlay?(mode), do: mode.type in [:prompt, :confirm] or Agendum.TUI.Render.box?(mode)

  @doc """
  After any key: when the box above a kept menu has just closed, ESC
  shows the menu again (stepping back); any other key that closed it
  finished the command, so the menu goes too.
  """
  @spec resumed(State.t(), term) :: State.t()
  def resumed(%State{modes: [%{type: :menu, resume: true} = menu | _]} = state, key) do
    if key == :esc,
      do: State.put_mode(state, %{menu | resume: nil}),
      else: State.pop(state)
  end

  def resumed(state, _key), do: state
end
