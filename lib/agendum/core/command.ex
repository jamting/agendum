defmodule Agendum.Core.Command do
  @moduledoc """
  The command layer (R66, ADR 0036): one named command per user action,
  run by the core.

  A command is data, a tagged tuple such as `{:mark_done, [42, 43]}`. It
  names what it acts on by id, never "the highlighted row", so a front end
  without a cursor (a web page, an agent, a command line) can send it as
  well as the TUI. `run/3` checks the ids, applies the command and returns
  the new database with what changed (`Agendum.Core.Command.Changes`).

  Each command describes itself (`describe/1`): a name and a summary, for
  the help and for a list of commands an agent can call. Commands that
  move the cursor or open a box are the front end's own (ADR 0033); a
  command here is one that changes the database.
  """

  alias Agendum.Core.{Context, Database}
  alias Agendum.Core.Facade.{Assignments, Items, Views}
  alias Agendum.Core.Command.Changes

  @type id :: Database.id()

  @typedoc """
  Where a new item goes (`{:add_item, text, opts}`), all optional:
  `section:` the category it is filed under (as if typed under that
  section), `after:` the item it follows in the file's order (or `:first`),
  `adjacent:` neighbouring items, nearest first, for an ambiguous automatic
  assignment (R12), `date:` a date category's date and time (a datebook
  slot, R47), and `view_section:` a view and the index of its section, whose
  filters the item is given what they need, so it stays in sight (R28).
  """
  @type add_opts :: [
          section: id | nil,
          after: id | :first | nil,
          adjacent: [id],
          date: {id, Date.t(), Time.t() | nil},
          view_section: {id, non_neg_integer}
        ]

  @typedoc """
  A command: a tuple of its id (an atom) and its arguments, or the bare id
  when it takes none. `ids/0` lists them and `describe/1` says what each
  takes, such as `{:add_item, text, add_opts}`, `{:toggle_mark, item}` or
  `:unmark_all`.
  """
  @type t :: atom | tuple

  @typedoc """
  Why a command was refused, for the front end to word: an id not in the
  file (`:no_such_item`, `:no_such_category`, `:no_such_view`,
  `:no_such_macro`, `:no_such_calendar`), `:empty_text`, `:bad_arguments`,
  `:unknown_command`, or the reason the facade function gave (such as
  `:protected`, `:cycle`, or `{:shared, items}` with what is in the way).
  """
  @type error :: atom | {atom, term}

  # Domain: the list of commands, in the order a help screen shows them:
  # {id, name, summary, the kinds of the arguments after the id, how it
  # runs}. Written once, here, so every front end (and an agent's tool
  # list) describes a command in the same words.
  #
  # The kinds are checked before a command runs: `:item`, `:category`,
  # `:view`, `:macro` and `:calendar` must be ids of that kind in the file,
  # `:items` and `:categories` lists of them, `:text` a string that is not
  # blank, and `:value` anything (the facade function checks it).
  #
  # How it runs: `:core` calls the `Agendum.Core` function of the same name
  # with the database and the arguments; `:clock` does the same with the
  # moment it runs added last; `:own` is a clause of `apply_own/3` below,
  # for a command that is more than one call.
  @commands [
    # items (R21, R35, R14a)
    {:add_item, "Add item",
     "Adds an item, filed under a category and by what its text says, as if typed under that section (R21)",
     [:text, :add_opts], :own},
    {:edit_item, "Edit item",
     "Changes an item's text; it is filed again by what the text now says (R10, R14)",
     [:item, :text], :own},
    {:set_note, "Set note", "Replaces an item's note (R14f reads dates from it)", [:item, :value],
     :clock},
    {:move_item, "Move item",
     "Moves an item from one category to another, optionally after an item (ALT-F10, R26)",
     [:item, :category, :category, :value], :own},
    {:toggle_mark, "Mark item", "Marks an item, or unmarks a marked one (R35)", [:item], :core},
    {:set_marked, "Mark items", "Marks (true) or unmarks (false) a group of items",
     [:items, :value], :core},
    {:unmark_all, "Unmark all", "Unmarks every item in the file", [], :core},
    {:toggle_done, "Done",
     "Marks an item done today, or clears its done date; a recurring item is followed by its next occurrence (R14a)",
     [:item], :clock},
    {:mark_done, "Done (several)",
     "Marks items done today, leaving those already done as they are", [:items], :own},
    {:discard_items, "Discard items", "Deletes items from the whole file", [:items], :own},
    {:attach_zettels, "Attach Zettel ids",
     "Gives each item without a Zettel id the next one (bonalaku); an item that has one keeps it (R73)",
     [:items], :core},

    # assignments (R23, R24, R34)
    {:assign, "Assign", "Assigns an item to a category (R7: leaving an exclusive sibling)",
     [:item, :category], :clock},
    {:remove_from_category, "Remove from category", "Takes an item out of a category (DEL, R24)",
     [:item, :category], :clock},
    {:toggle_assignment, "Toggle assignment",
     "Assigns an item to a category, or takes it out when it is in it", [:item, :category],
     :clock},
    {:assign_by_name, "Assign by name",
     "Typing in a column: assigns the item to the head's child of that name, a date or a number (R23)",
     [:item, :category, :value], :clock},
    {:assign_new_by_name, "Assign to a new category",
     "Makes a category of that name under the head and assigns the item to it (R23)",
     [:item, :category, :value], :core},
    {:clear_column, "Clear column",
     "Takes an item out of a column: its entries under the head (DEL in a column, R24)",
     [:item, :category], :own},
    {:type_in_column, "Type in column",
     "Typing in a column cell (R23): the entry is a category picked ({:category, id}), a name read as a child, date or number ({:name, text}) or a new child ({:new, text}); with replace? true what was there goes first, when something was typed",
     [:item, :category, :value, :value], :own},
    {:set_in_column, "Set in column",
     "Assigns an item to a yes/no column's head, or takes it out", [:item, :category, :value],
     :clock},
    {:set_column_note, "Set column note", "Sets the note of an item's nth entry in a column",
     [:item, :category, :value, :value], :core},
    {:answer_question, "Answer question",
     "Assigns an item to the suggested categories picked (Category Questions, R16)",
     [:item, :categories], :clock},

    # dates, alarms, numbers and dependencies (R6, R14, R38, R29, R43)
    {:when_key, "Set When", "Sets an item's When date from typed text (ALT-F2)", [:item, :value],
     :clock},
    {:set_date, "Set date", "Sets an item's date in a date category", [:item, :category, :value],
     :clock},
    {:set_date_time, "Set date and time", "Sets an item's date and time in a date category",
     [:item, :category, :value, :value], :clock},
    {:set_alarm, "Set alarm", "Sets an alarm that many minutes before an item's When time (R38)",
     [:item, :value], :core},
    {:cancel_alarm, "Cancel alarm", "Removes an item's alarm", [:item], :core},
    {:remove_past_alarm, "Remove past alarm", "Takes a rung alarm off the list", [:item], :core},
    {:set_number, "Set number", "Sets an item's number in a numeric category (R29)",
     [:item, :category, :value], :clock},
    {:clear_number, "Clear number", "Clears an item's number in a numeric category",
     [:item, :category], :clock},
    {:make_dependent, "Make dependent", "Makes an item depend on others (ALT-O, R43)",
     [:item, :items], :core},
    {:clear_dependencies, "Clear dependencies", "An item depends on nothing any more", [:item],
     :core},
    {:remove_dependency, "Remove dependency", "An item no longer depends on another",
     [:item, :item], :core},

    # categories (R2, R7, R8, R25)
    {:add_category, "Add category", "Adds a category under a parent", [:category, :value, :value],
     :core},
    {:find_or_create_category, "Find or create category",
     "The category of that name anywhere, made under MAIN when there is none", [:text], :core},
    {:find_or_add_category, "Find or add category",
     "The category of that name, made under MAIN when there is none", [:value], :core},
    {:rename_category, "Rename category", "Renames a category", [:category, :value], :core},
    {:discard_category, "Discard category",
     "Deletes a category and its children; items stay in the file", [:category], :core},
    {:relocate, "Relocate category",
     "Promotes, demotes or moves a category, resolving exclusive conflicts as asked (R7b, R7d)",
     [:category, :value, :value], :core},
    {:promote, "Promote category", "Moves a category up a level, after its parent (R7d)",
     [:category, :value], :core},
    {:demote, "Demote category", "Makes a category a child of the one above it (R7d)",
     [:category, :value], :core},
    {:move_category, "Move category", "Moves a category under a parent, after a sibling (R7b)",
     [:category, :category, :value, :value], :core},
    {:make_exclusive, "Make exclusive",
     "Makes a category's children exclusive, resolving conflicts as asked (R7a)",
     [:category, :value], :core},
    {:make_unexclusive, "Make not exclusive", "A category's children are no longer exclusive",
     [:category], :core},
    {:make_date, "Make date category", "Turns a category into a date category (R6a)", [:category],
     :clock},
    {:make_numeric, "Make numeric category", "Turns a category into a numeric category (R29)",
     [:category], :clock},
    {:toggle_match_name, "Match on name",
     "Turns text matching on a category's name on or off (R10)", [:category], :core},
    {:set_short_name, "Set short name", "Sets a category's short name", [:category, :value],
     :core},
    {:set_category_note, "Set category note", "Replaces a category's note", [:category, :value],
     :core},
    {:toggle_exclude, "Toggle exclusion", "Makes two categories exclude each other, or not (R9)",
     [:category, :category], :core},
    {:toggle_also_assign, "Also assign",
     "Assigning to a category also assigns to another, or no longer (R15b)",
     [:category, :category], :core},
    {:sort_children, "Sort children", "Sorts a category's children by name", [:category], :core},

    # automatic assignment (R10, R15, R16)
    {:set_action, "Set action", "Sets what assigning to a category does to another (R15b)",
     [:category, :category, :value], :clock},
    {:remove_action, "Remove action", "Removes an action", [:category, :category], :core},
    {:set_special_action, "Set special action",
     "Marks done or discards items assigned to a category (R15b)", [:category, :value], :core},
    {:add_condition, "Add condition", "Adds an assignment condition (R15)",
     [:category, :category, :value], :core},
    {:set_condition, "Set condition",
     "Sets an assignment condition, replacing the one on that category if there is one (R15)",
     [:category, :category, :value], :own},
    {:remove_condition, "Remove condition", "Removes an assignment condition",
     [:category, :category], :core},
    {:cycle_condition, "Cycle condition",
     "Cycles a condition through none, assigned and not assigned (R15)", [:category, :category],
     :core},
    {:set_range_condition, "Set range condition",
     "A date or numeric condition on another category (R15a)", [:category, :category, :value],
     :clock},
    {:set_also_match, "Set also match", "Other words a category matches on (R10)",
     [:category, :value], :core},
    {:set_confirm_assignments, "Confirm assignments",
     "Whether text matches are suggested or made (R16)", [:value], :core},
    {:set_match_settings, "Text matching settings", "The file's text matching settings (R16a)",
     [:value], :core},
    {:set_match_override, "Category matching setting",
     "One text matching setting for one category (R16b)", [:category, :value, :value], :core},
    {:execute, "Execute",
     "Applies the rules of a family's categories to items again (Utilities Execute, R15e)",
     [:items, :value], :own},
    {:reassign_all, "Reassign all", "Applies text matching to every item again", [], :clock},
    {:recheck_conditions, "Recheck conditions",
     "Checks every conditional assignment again, as the date moves on (R15a)", [], :clock},

    # dates of the file (R6b, R14e, R41)
    {:toggle_auto_date, "Auto-dating", "Whether When dates are read from item text (R14)", [],
     :core},
    {:set_date_rule, "Date rule", "A date category's settings (R6b)", [:category, :value], :core},
    {:set_date_format, "Date format", "How the file shows dates (R41)", [:value], :core},
    {:set_date_settings, "Date settings", "How the file reads typed dates (R14e)", [:value],
     :core},

    # views and sections (R20, R27, R28, R33, R47, R61, R62)
    {:add_view, "Add view", "Adds a view with sections headed by these categories",
     [:value, :categories], :core},
    {:add_datebook_view, "Add datebook view", "Adds a datebook view (R47)", [:value, :value],
     :core},
    {:set_datebook, "Datebook settings", "A datebook view's settings (R47)", [:view, :value],
     :core},
    {:rename_view, "Rename view", "Renames a view", [:view, :value], :core},
    {:discard_view, "Discard view", "Deletes a view; its items stay in the file", [:view], :core},
    {:move_view, "Move view", "Moves a view in the view manager's order", [:view, :value], :core},
    {:sort_views, "Sort views", "Sorts the views by name", [], :core},
    {:add_section, "Add section", "Adds a section headed by a category",
     [:view, :category, :value, :value], :core},
    {:set_section_category, "Section category", "Changes a section's head",
     [:view, :value, :category], :core},
    {:move_section, "Move section", "Moves a section within its view (R62)",
     [:view, :value, :value], :core},
    {:remove_section, "Remove section", "Takes a section out of its view", [:view, :value],
     :core},
    {:set_section_collapsed, "Collapse section", "Collapses or expands a section (R33)",
     [:view, :value, :value], :core},
    {:toggle_section_collapsed, "Toggle collapsed",
     "Collapses an open section, opens a closed one", [:view, :value], :core},
    {:set_all_sections_collapsed, "Collapse all", "Collapses or expands every section",
     [:view, :value], :core},
    {:set_section_sort, "Section order", "How a view orders its sections",
     [:view, :value, :value], :core},
    {:toggle_view_option, "View option", "Turns a view option on or off (R27)", [:view, :value],
     :core},
    {:cycle_filter, "Cycle filter",
     "Cycles a category in a filter through assigned, not assigned and none (R28)",
     [:view, :value, :category], :core},
    {:set_range_filter, "Range filter", "A date or numeric filter (R28a)",
     [:view, :value, :category, :value], :clock},
    {:remove_filter, "Remove filter", "Takes a category out of a filter",
     [:view, :value, :category], :core},
    {:set_filters, "Set filters", "Replaces a filter's terms (browsing, R48)",
     [:view, :value, :value], :core},
    {:set_sort, "Sort", "How a view or section sorts its items (R36)", [:view, :value, :value],
     :core},
    {:show_items, "Show items", "Shows these items in the Show View", [:items], :core},
    {:show_match, "Show matches", "Shows the items a search matches in the Show View (R37)",
     [:value], :core},
    {:show_schedule, "Show schedule", "Shows one day's items in the Show View (R49)",
     [:category, :category, :value, :value], :core},

    # columns (R22, R55, R56, R57)
    {:add_column, "Add column", "Adds a column headed by a category",
     [:view, :category, :value, :value, :value], :core},
    {:add_column_as, "Add column as", "Adds a column of a kind (date, numeric…) under a head",
     [:view, :category, :value, :value, :value], :own},
    {:set_insert_columns, "Insert columns in",
     "Whether a new column goes into one section or all (R55)", [:value], :core},
    {:set_column_head, "Column head", "Changes a column's head", [:view, :value, :category],
     :core},
    {:set_column_linked, "Link column", "Links a column with the other sections' (R55)",
     [:view, :value, :value], :core},
    {:remove_column, "Remove column", "Takes a column out", [:view, :value, :value], :core},
    {:move_column, "Move column", "Moves a column within its section",
     [:view, :value, :value, :value], :core},
    {:set_column_width, "Column width", "Sets a column's width", [:view, :value, :value], :core},
    {:resize_column, "Resize column", "Widens or narrows a column", [:view, :value, :value],
     :core},
    {:fit_column, "Fit column", "Fits a column to its contents (R22a)", [:view, :value], :clock},
    {:set_column_format, "Column format", "A numeric column's format (R29, R56)",
     [:view, :value, :value], :core},
    {:set_column_date_format, "Column date format", "A date column's own format (R56)",
     [:view, :value, :value], :core},
    {:set_column_display, "Column display", "How a column shows its entries (R56)",
     [:view, :value, :value], :core},
    {:set_item_column, "Item column", "The item column's settings in a section (R55)",
     [:view, :value, :value], :core},
    {:set_item_column_linked, "Link item column",
     "Links the item column with the other sections'", [:view, :value, :value], :core},
    {:set_section_calcs, "Section calculations", "What a numeric section totals (R29)",
     [:view, :value, :value], :core},

    # macros (R50)
    {:add_macro, "Add macro", "Adds a macro", [:value], :core},
    {:rename_macro, "Rename macro", "Renames a macro", [:macro, :value], :core},
    {:set_macro_keys, "Macro keys", "Replaces a macro's keystrokes", [:macro, :value], :core},
    {:attach_macro, "Attach macro", "Attaches a macro to a key, or detaches it", [:macro, :value],
     :core},
    {:set_macro_run_from, "Run macro from", "Where a macro can be run from",
     [:macro, :value, :value], :core},
    {:delete_macro, "Delete macro", "Deletes a macro", [:macro], :core},
    {:move_macro, "Move macro", "Moves a macro in the list", [:macro, :value], :core},
    {:sort_macros, "Sort macros", "Sorts the macros by name", [], :core},

    # calendars (R45)
    {:subscribe_calendar, "Subscribe to calendar",
     "Adds a calendar on the web, its events filed under a category of that name",
     [:value, :value], :core},
    {:unsubscribe_calendar, "Unsubscribe calendar",
     "Stops reading a calendar, its items removed or kept", [:calendar, :value], :core},
    {:sync_calendar, "Read calendar", "Files a calendar's events as items", [:calendar, :value],
     :clock},
    {:calendar_failed, "Calendar failed", "Notes that reading a calendar failed",
     [:calendar, :value], :clock},
    {:cycle_calendar_setting, "Calendar setting", "Steps a calendar's setting up or down",
     [:calendar, :value, :value], :core},

    # alarms ringing, as the clock moves on (R38)
    {:ring_alarms, "Ring alarms", "Rings the alarms that are due; returns their items", [], :own},
    {:clear_old_alarms, "Clear old alarms", "Forgets alarms rung before today", [], :own},

    # several commands as one change (one undo step)
    {:batch, "Batch",
     "Runs several commands in turn as one change; if one is refused, none is made", [:commands],
     :own}
  ]

  @doc "The ids of every command, in the order a help screen shows them."
  @spec ids() :: [atom]
  # `for {id, …} <- list` takes each tuple apart and keeps the id
  def ids, do: for({id, _, _, _, _} <- @commands, do: id)

  @doc false
  # for the tests: how each command runs, `{id, kinds, how}`
  def runs, do: for({id, _, _, kinds, how} <- @commands, do: {id, kinds, how})

  @doc "A command's name, summary and kinds of argument, or nil for an unknown id."
  @spec describe(atom) :: %{id: atom, name: String.t(), summary: String.t(), args: [atom]} | nil
  def describe(id) do
    # `List.keyfind/3` finds the first tuple whose element 0 is `id`.
    case List.keyfind(@commands, id, 0) do
      {id, name, summary, args, _how} -> %{id: id, name: name, summary: summary, args: args}
      nil -> nil
    end
  end

  @doc """
  Runs a command. The clock is the moment it runs (a date, a date and
  time, or a `Context`), for done dates and the like. Returns the new
  database and what changed, or why the command was refused; a refused
  command changes nothing.
  """
  @spec run(Database.t(), t, Agendum.Core.clock()) ::
          {:ok, Database.t(), Changes.t()} | {:error, error}
  def run(db, command, clock) do
    # `with` as a happy path: each step must match, or its value (an
    # `{:error, reason}`) is returned at once.
    with {:ok, after_, extra} <- step(db, command, clock) do
      # `extra` adds what only the command knows, such as `new:`, the id
      # of what it made
      {:ok, after_, Map.merge(Changes.between(db, after_), extra)}
    end
  end

  # Checks and applies a command, without working out what changed (a
  # batch does that once, for all its steps).
  defp step(db, command, clock) do
    with {:ok, name, args, kinds, how} <- known(command),
         :ok <- check(db, Enum.zip(kinds, args)) do
      apply_command(db, how, name, args, clock)
    end
  end

  # A command is a bare atom (`:unmark_all`) or a tuple tagged with one,
  # with as many arguments as its kinds say.
  defp known(command) when is_atom(command), do: known({command})

  defp known(command) when is_tuple(command) and tuple_size(command) > 0 do
    [name | args] = Tuple.to_list(command)

    case List.keyfind(@commands, name, 0) do
      {^name, _, _, kinds, how} when length(kinds) == length(args) ->
        {:ok, name, args, kinds, how}

      {^name, _, _, _, _} ->
        {:error, :bad_arguments}

      nil ->
        {:error, :unknown_command}
    end
  end

  defp known(_command), do: {:error, :unknown_command}

  # Each argument must be of its kind: a front end that sends a stale or
  # made-up id gets a reason, not a crash. `Enum.find_value/3` stops at the
  # first argument that fails and returns its error; :ok when none does.
  defp check(db, pairs) do
    Enum.find_value(pairs, :ok, fn {kind, arg} ->
      case valid(db, kind, arg) do
        :ok -> nil
        error -> error
      end
    end)
  end

  defp valid(db, :item, id), do: present(db.items, id, :no_such_item)
  defp valid(db, :category, id), do: present(db.categories, id, :no_such_category)
  defp valid(db, :view, id), do: present(db.views, id, :no_such_view)
  defp valid(db, :macro, id), do: present(db.macros, id, :no_such_macro)
  defp valid(db, :calendar, id), do: present(db.calendars, id, :no_such_calendar)
  defp valid(db, :items, ids), do: all(db, :item, ids)
  defp valid(db, :categories, ids), do: all(db, :category, ids)
  defp valid(_db, :value, _arg), do: :ok

  defp valid(_db, :text, text),
    do: if(is_binary(text) and String.trim(text) != "", do: :ok, else: {:error, :empty_text})

  defp valid(_db, :commands, commands) when is_list(commands), do: :ok
  defp valid(db, :view_section, view_section), do: view_section(db, view_section)

  defp valid(db, :add_opts, opts) when is_list(opts) do
    opts
    |> Enum.reject(fn {_key, value} -> value in [nil, :first] end)
    |> Enum.map(&add_opt_kind/1)
    |> then(&check(db, &1))
  end

  defp valid(_db, _kind, _arg), do: {:error, :bad_arguments}

  # the kind of each option of `{:add_item, text, opts}`
  defp add_opt_kind({:section, id}), do: {:category, id}
  defp add_opt_kind({:after, id}), do: {:item, id}
  defp add_opt_kind({:adjacent, ids}), do: {:items, ids}
  defp add_opt_kind({:date, {cat, _date, _time}}), do: {:category, cat}
  defp add_opt_kind({:view_section, view_section}), do: {:view_section, view_section}
  defp add_opt_kind(_option), do: {:bad, nil}

  defp present(map, id, error), do: if(is_map_key(map, id), do: :ok, else: {:error, error})

  defp all(db, kind, ids) when is_list(ids), do: check(db, Enum.map(ids, &{kind, &1}))
  defp all(_db, _kind, _ids), do: {:error, :bad_arguments}

  # a view, and the index of one of its sections
  defp view_section(db, {view, index}) do
    case db.views[view] do
      %{sections: sections} when is_integer(index) and index >= 0 and index < length(sections) ->
        :ok

      _ ->
        {:error, :no_such_view}
    end
  end

  defp apply_command(db, :core, name, args, _clock),
    do: result(apply(Agendum.Core, name, [db | args]))

  defp apply_command(db, :clock, name, args, clock),
    do: result(apply(Agendum.Core, name, [db | args] ++ [clock]))

  defp apply_command(db, :own, name, args, clock),
    do: apply_own(db, List.to_tuple([name | args]), clock)

  # The facade's functions return a database, `{:ok, db}`, `{:ok, db,
  # extra}`, `{db, extra}` or `{:error, reason}`: all become `{:ok, db,
  # extra}` or the error. An id as extra is what the command made (`new:`).
  defp result(%Database{} = db), do: {:ok, db, %{}}
  defp result({:ok, %Database{} = db}), do: {:ok, db, %{}}
  defp result({:ok, %Database{} = db, extra}), do: {:ok, db, extra(extra)}
  defp result({%Database{} = db, extra}), do: {:ok, db, extra(extra)}
  defp result({:error, _reason} = error), do: error

  defp extra(id) when is_integer(id), do: %{new: id}
  defp extra(other), do: %{result: other}

  # The commands that are more than one facade call. A command made of
  # several steps (done on several items) loops here, in the core, not in a
  # front end.
  defp apply_own(db, {:add_item, text, opts}, clock) do
    {db, id} = Items.add_item(db, text, clock, Keyword.delete(opts, :view_section))
    {:ok, in_view_section(db, id, opts[:view_section], clock), %{new: id}}
  end

  defp apply_own(db, {:edit_item, id, text}, clock),
    do: result(Items.edit_item(db, id, text, clock))

  defp apply_own(db, {:mark_done, ids}, clock),
    do: result(Enum.reduce(ids, db, &Items.mark_done(&2, &1, clock)))

  defp apply_own(db, {:discard_items, ids}, _clock),
    do: result(Enum.reduce(ids, db, &Items.discard_item(&2, &1)))

  # The item's entries in a column: the head itself when it has no
  # children (or is a date category), else each child the item is in
  defp apply_own(db, {:clear_column, item_id, head}, clock) do
    entries =
      if Database.date_category?(db, head) or db.categories[head].children == [],
        do: [head],
        else: Agendum.Core.ViewModel.column_entries(db, item_id, head)

    result(Enum.reduce(entries, db, &Assignments.remove_from_category(&2, item_id, &1, clock)))
  end

  # Typing in a column cell: the entry replaces what was there, in the
  # same change, when `replace?` and something was typed (R23)
  defp apply_own(db, {:type_in_column, item_id, head, entry, replace?}, clock) do
    assign =
      case entry do
        {:category, id} -> {:assign, item_id, id}
        {:name, text} -> {:assign_by_name, item_id, head, text}
        {:new, text} -> {:assign_new_by_name, item_id, head, text}
      end

    typed? = match?({:category, _}, entry) or String.trim(elem(entry, 1)) != ""
    clear = if replace? and typed?, do: [{:clear_column, item_id, head}], else: []

    with {:ok, db, %{steps: steps}} <- apply_own(db, {:batch, clear ++ [assign]}, clock),
         do: {:ok, db, List.last(steps)}
  end

  defp apply_own(db, {:set_condition, cat_id, target, kind}, _clock) do
    db
    |> Agendum.Core.remove_condition(cat_id, target)
    |> Agendum.Core.add_condition(cat_id, target, kind)
    |> result()
  end

  # the clock goes into the options, where these functions read it
  defp apply_own(db, {:move_item, id, from, to, opts}, clock),
    do: result(Items.move_item(db, id, from, to, Keyword.put(opts, :clock, clock)))

  defp apply_own(db, {:add_column_as, view, head, kind, at, opts}, clock),
    do:
      result(
        Agendum.Core.add_column_as(db, view, head, kind, at, Keyword.put(opts, :clock, clock))
      )

  defp apply_own(db, {:execute, ids, opts}, clock),
    do: result(Agendum.Core.execute(db, ids, Keyword.put(opts, :clock, clock)))

  defp apply_own(db, {:ring_alarms}, clock),
    do: result(Agendum.Core.ring_alarms(db, Context.now(clock)))

  defp apply_own(db, {:clear_old_alarms}, clock),
    do: result(Agendum.Core.clear_old_alarms(db, Context.today(clock)))

  # Each command runs on what the one before made; the first refusal
  # stops the batch, and nothing of it is kept. What each step made is
  # kept in order (`steps:`), with `new:` from the last that made one.
  defp apply_own(db, {:batch, commands}, clock) do
    Enum.reduce_while(commands, {:ok, db, %{steps: []}}, fn command, {:ok, db, extra} ->
      case step(db, command, clock) do
        {:ok, db, made} ->
          extra = Map.merge(%{extra | steps: extra.steps ++ [made]}, Map.take(made, [:new]))
          {:cont, {:ok, db, extra}}

        {:error, _reason} = error ->
          {:halt, error}
      end
    end)
  end

  # A filtered view or section gives a new item what the filters need
  # (R28): the categories they require, and dates and numbers inside their
  # ranges. A special action (R15b) may have discarded the item already.
  defp in_view_section(db, _id, nil, _clock), do: db
  defp in_view_section(db, id, _view_section, _clock) when not is_map_key(db.items, id), do: db

  defp in_view_section(db, id, {view, index}, clock) do
    db =
      db
      |> Views.entry_categories(view, index)
      |> Enum.reduce(db, &Assignments.assign(&2, id, &1, clock))

    Views.apply_entry_values(db, id, Views.entry_values(db, view, index, clock), clock)
  end
end
