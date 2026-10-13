defmodule Agenda.Core do
  @moduledoc """
  The functional core: user-level operations on an Agendum database.

  This is the API the TUI (and any other shell) uses. Every function is
  pure; anything that depends on the outside world, such as today's date,
  is passed in as an argument.

  Following the patent, all modification happens "through a view": adding
  an item under a section assigns it to the section's category, typing a
  name into a column assigns (or creates) a subcategory of the column head,
  and so on.

  `Agenda.Core` stays the one entry point, a table of contents: each
  function delegates to an area module under `Agenda.Core.Facade`, where
  it is written and documented: `Files`, `Items`, `Assignments`, `Dates`,
  `Alarms`, `Numbers`, `Dependencies`, `Rules`, `Categories`, `Views`,
  `Macros` and `Calendars`. What every change to an item goes through
  (dates, conditions and actions after a change) is in
  `Agenda.Core.Facade.Changes`.
  """

  # `alias` only shortens names inside this module (`Database` for
  # `Agenda.Core.Database`); it imports nothing. The `{...}` form aliases
  # several modules that share a prefix at once.
  alias Agenda.Core.Database

  alias Agenda.Core.Facade.{
    Alarms,
    Assignments,
    Calendars,
    Categories,
    Dates,
    Dependencies,
    Files,
    Items,
    Macros,
    Numbers,
    Rules,
    Views
  }

  # `@type` declares a public type (for `@spec`s and Dialyzer, the static
  # checker run by `mix check`); other modules refer to it as `Agenda.Core.db()`.
  # Types have no effect at runtime: Elixir is dynamically typed.
  @type db :: Database.t()
  @type id :: Database.id()

  @typedoc """
  The current moment, passed in by the shell: a date, or a date and time
  (needed for times like "in 2 hours" and for alarms). The core never reads
  the clock itself.
  """
  @type clock :: Agenda.Core.Context.clock()

  @typedoc "A change to a category's place in the hierarchy."
  @type relocation :: :promote | :demote | {:move, id, id | :first | nil}

  @typedoc "How items that a move puts in conflict are resolved."
  @type move_resolution :: :remove_moved | :remove_other | {:new_category, String.t()}

  # `defdelegate f(a, b), to: M` defines a public `f/2` here that just calls
  # `M.f(a, b)`; this module holds no code of its own. A default argument
  # (`opts \\ []`) defines two functions, `f/1` and `f/2`: in Elixir a
  # function is known by name *and* arity, so `new_file/0` and `new_file/1`
  # are separate functions. Delegates have no `@doc`, so the API docs show
  # "See Agenda.Core.Facade.Files.new_file/1" and the docs live there.

  # files: new, and as JSON (R44)
  defdelegate new_file(opts \\ []), to: Files
  defdelegate export_json(db), to: Files
  defdelegate import_json(text), to: Files

  # items: adding and editing (R21), moving (R26), done, marking (R35), discarding
  defdelegate add_item(db, text, today, opts \\ []), to: Items
  defdelegate edit_item(db, id, text, today, adjacent \\ []), to: Items
  defdelegate set_note(db, id, note, clock), to: Items
  defdelegate move_item(db, item_id, from, to, opts \\ []), to: Items
  defdelegate toggle_done(db, id, today), to: Items
  defdelegate toggle_mark(db, id), to: Items
  defdelegate mark_done(db, id, today), to: Items
  defdelegate marked_items(db), to: Items
  defdelegate set_marked(db, ids, marked), to: Items
  defdelegate unmark_all(db), to: Items
  defdelegate discard_item(db, id), to: Items

  # assigning items by hand (R23, R24), completion (R32), Item Properties (R34)
  defdelegate remove_from_category(db, item_id, cat_id, clock \\ nil), to: Assignments
  defdelegate assign(db, item_id, cat_id, clock \\ nil), to: Assignments
  defdelegate toggle_assignment(db, item_id, cat_id, clock \\ nil), to: Assignments
  defdelegate assign_by_name(db, item_id, head_id, text, today), to: Assignments
  defdelegate item_assignments(db, item_id), to: Assignments
  defdelegate completions(db, head_id, text), to: Assignments
  defdelegate assign_new_by_name(db, item_id, head_id, text), to: Assignments

  # dates (R6, R14, R41)
  defdelegate toggle_auto_date(db), to: Dates
  defdelegate auto_dating?(db), to: Dates
  defdelegate set_date_rule(db, cat_id, rule), to: Dates
  defdelegate set_date_format(db, format), to: Dates
  defdelegate set_date_settings(db, settings), to: Dates
  defdelegate when_key(db, item_id, text, clock), to: Dates
  defdelegate set_date(db, item_id, cat_id, date, clock \\ nil), to: Dates
  defdelegate set_date_time(db, item_id, cat_id, date, time, clock \\ nil), to: Dates
  defdelegate read_when(db, text, clock), to: Dates
  defdelegate date_conversion(db, cat_id, clock), to: Dates
  defdelegate make_date(db, cat_id, clock), to: Dates

  # times and alarms (R14b, R38)
  defdelegate when_at(item), to: Alarms
  defdelegate set_alarm(db, id, minutes), to: Alarms
  defdelegate cancel_alarm(db, id), to: Alarms
  defdelegate ring_alarms(db, now), to: Alarms
  defdelegate alarm_list(db, today), to: Alarms
  defdelegate remove_past_alarm(db, id), to: Alarms
  defdelegate clear_old_alarms(db, today), to: Alarms

  # numbers (R29)
  defdelegate set_number(db, item_id, cat_id, value, clock \\ nil), to: Numbers
  defdelegate clear_number(db, item_id, cat_id, clock \\ nil), to: Numbers
  defdelegate numeric_conversion(db, cat_id, clock \\ nil), to: Numbers
  defdelegate make_numeric(db, cat_id, clock \\ nil), to: Numbers

  # dependencies (R43)
  defdelegate make_dependent(db, item_id, prerequisite_ids), to: Dependencies
  defdelegate clear_dependencies(db, item_id), to: Dependencies
  defdelegate remove_dependency(db, item_id, prerequisite_id), to: Dependencies
  defdelegate prerequisites(db, item_id), to: Dependencies
  defdelegate dependents(db, item_id), to: Dependencies
  defdelegate waiting?(db, item_id), to: Dependencies
  defdelegate related_items(db, item_id, direction, level), to: Dependencies

  # rules: actions, text matching, conditions, Execute, Recalc (R13, R15, R16)
  defdelegate execute(db, item_ids, opts \\ []), to: Rules
  defdelegate set_action(db, cat_id, target, action, clock \\ nil), to: Rules
  defdelegate remove_action(db, cat_id, target), to: Rules
  defdelegate set_special_action(db, cat_id, special), to: Rules
  defdelegate set_confirm_assignments(db, mode), to: Rules
  defdelegate set_match_settings(db, settings), to: Rules
  defdelegate set_match_override(db, cat_id, field, value), to: Rules
  defdelegate match_settings(db, cat_id), to: Rules
  defdelegate confirm_mode(db, cat_id), to: Rules
  defdelegate questions(db), to: Rules
  defdelegate answer_question(db, item_id, cat_ids, clock \\ nil), to: Rules
  defdelegate reassign_all(db, today), to: Rules
  defdelegate add_condition(db, cat_id, target, kind), to: Rules
  defdelegate remove_condition(db, cat_id, target), to: Rules
  defdelegate set_also_match(db, cat_id, text), to: Rules
  defdelegate set_range_condition(db, cat_id, target, range, clock), to: Rules
  defdelegate recheck_conditions(db, clock), to: Rules
  defdelegate cycle_condition(db, cat_id, target), to: Rules

  # categories: hierarchy (R2), moving and exclusive children (R7), links (R8, R9)
  defdelegate add_category(db, parent_id, name, opts \\ []), to: Categories
  defdelegate find_or_add_category(db, name), to: Categories
  defdelegate find_or_create_category(db, name), to: Categories
  defdelegate rename_category(db, id, name), to: Categories
  defdelegate discard_category(db, id), to: Categories
  defdelegate relocation_conflicts(db, id, relocation), to: Categories
  defdelegate relocate(db, id, relocation, resolution \\ :remove_moved), to: Categories
  defdelegate move_category(db, id, parent, after_id, resolution \\ :remove_moved), to: Categories
  defdelegate promote(db, id, resolution \\ :remove_moved), to: Categories
  defdelegate demote(db, id, resolution \\ :remove_moved), to: Categories
  defdelegate move_conflicts(db, id, parent, after_id), to: Categories
  defdelegate promote_conflicts(db, id), to: Categories
  defdelegate demote_conflicts(db, id), to: Categories
  defdelegate exclusive_conflicts(db, id), to: Categories
  defdelegate make_exclusive(db, id, resolution \\ :parent), to: Categories
  defdelegate make_unexclusive(db, id), to: Categories
  defdelegate toggle_match_name(db, id), to: Categories
  defdelegate set_short_name(db, id, text), to: Categories
  defdelegate set_category_note(db, id, note), to: Categories
  defdelegate toggle_exclude(db, a, b), to: Categories
  defdelegate toggle_also_assign(db, cat_id, target), to: Categories
  defdelegate sort_children(db, parent_id), to: Categories

  # views: sections, columns, filters (R28), sorting (R36), the Show View (R37, R49)
  defdelegate add_datebook_view(db, name, datebook), to: Views
  defdelegate set_datebook(db, view_id, datebook), to: Views
  defdelegate add_view(db, name, section_ids), to: Views
  defdelegate rename_view(db, view_id, name), to: Views
  defdelegate discard_view(db, view_id), to: Views
  defdelegate move_view(db, view_id, index), to: Views
  defdelegate set_section_category(db, view_id, index, cat_id), to: Views
  defdelegate add_section(db, view_id, cat_id, index, from \\ nil), to: Views
  defdelegate remove_section(db, view_id, index), to: Views
  defdelegate set_section_collapsed(db, view_id, index, collapsed), to: Views
  defdelegate set_all_sections_collapsed(db, view_id, collapsed), to: Views
  defdelegate toggle_section_collapsed(db, view_id, index), to: Views
  defdelegate add_column(db, view_id, cat_id, at, width \\ nil, insert_in \\ nil), to: Views
  defdelegate default_column_width(db, cat_id, kind \\ nil), to: Views
  defdelegate add_column_as(db, view_id, cat_id, kind, at, opts \\ []), to: Views
  defdelegate set_insert_columns(db, where), to: Views
  defdelegate set_column_linked(db, view_id, at, linked), to: Views
  defdelegate set_column_head(db, view_id, at, cat_id), to: Views
  defdelegate remove_column(db, view_id, at, from \\ :all), to: Views
  defdelegate move_column(db, view_id, sidx, from, to), to: Views
  defdelegate set_item_column(db, view_id, sidx, changes), to: Views
  defdelegate set_item_column_linked(db, view_id, sidx, linked), to: Views
  defdelegate item_column_fit(db, view_id, sidx, clock, screen), to: Views
  defdelegate set_column_format(db, view_id, at, format), to: Views
  defdelegate set_column_display(db, view_id, at, changes), to: Views
  defdelegate set_column_date_format(db, view_id, at, format), to: Views
  defdelegate resize_column(db, view_id, at, delta), to: Views
  defdelegate set_column_width(db, view_id, at, width), to: Views
  defdelegate fit_column(db, view_id, at, clock), to: Views
  defdelegate cycle_filter(db, view_id, scope, cat_id), to: Views
  defdelegate set_range_filter(db, view_id, scope, cat_id, filter, today), to: Views
  defdelegate remove_filter(db, view_id, scope, cat_id), to: Views
  defdelegate entry_values(db, view_id, index, today), to: Views
  defdelegate apply_entry_values(db, item_id, values, clock \\ nil), to: Views
  defdelegate set_sort(db, view_id, scope, keys), to: Views
  defdelegate entry_categories(db, view_id, index), to: Views
  defdelegate show_match(db, search), to: Views
  defdelegate show_schedule(db, date_category, section, date, filter), to: Views
  defdelegate show_items(db, ids), to: Views
  defdelegate set_section_sort(db, view_id, sort, order), to: Views
  defdelegate sort_views(db), to: Views
  defdelegate date_filters?(db, filters), to: Views
  defdelegate shift_filters(db, filters, shift, clock), to: Views
  defdelegate set_filters(db, view_id, scope, filters), to: Views
  defdelegate toggle_view_option(db, view_id, option), to: Views

  # macros (R50)
  defdelegate add_macro(db, name), to: Macros
  defdelegate rename_macro(db, id, name), to: Macros
  defdelegate set_macro_keys(db, id, keys), to: Macros
  defdelegate attach_macro(db, id, key), to: Macros
  defdelegate set_macro_run_from(db, id, place, allowed), to: Macros
  defdelegate delete_macro(db, id), to: Macros
  defdelegate move_macro(db, id, index), to: Macros
  defdelegate sort_macros(db), to: Macros

  # calendar subscriptions (R45)
  defdelegate subscribe_calendar(db, name, url), to: Calendars
  defdelegate unsubscribe_calendar(db, cal_id, remove_items), to: Calendars
  defdelegate sync_calendar(db, cal_id, events, clock), to: Calendars
  defdelegate calendar_failed(db, cal_id, message, clock), to: Calendars
  defdelegate cycle_calendar_setting(db, cal_id, setting, step), to: Calendars
  defdelegate calendars_due(db, now), to: Calendars
end
