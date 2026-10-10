defmodule Agenda.Core do
  @moduledoc """
  The functional core: user-level operations on an Agenda database.

  This is the API the TUI (and any other shell) uses. Every function is
  pure; anything that depends on the outside world, such as today's date,
  is passed in as an argument.

  Following the patent, all modification happens "through a view": adding
  an item under a section assigns it to the section's category, typing a
  name into a column assigns (or creates) a subcategory of the column head,
  and so on.
  """

  alias Agenda.Core.{
    Assign,
    Context,
    Database,
    DateParser,
    Links,
    NumberFormat,
    RangeFilter,
    Recurrence,
    View
  }

  alias Agenda.Core.View.{Column, Section}

  @type db :: Database.t()
  @type id :: Database.id()

  @typedoc """
  The current moment, passed in by the shell: a date, or a date and time
  (needed for times like "in 2 hours" and for alarms). The core never reads
  the clock itself.
  """
  @type clock :: Agenda.Core.Context.clock()

  @show_view "Show View"

  defdelegate new_file(opts \\ []), to: Database, as: :new

  # ---------------------------------------------------------------------------
  # Items
  # ---------------------------------------------------------------------------

  @doc """
  Adds an item, assigns it to `:section` (a category id) and runs automatic
  assignment.

  Options:
    * `:section` – category the item was typed under
    * `:after` – item to place the new item after
    * `:adjacent` – neighbouring item ids, nearest first, for resolving
      ambiguous automatic assignments
  """
  @spec add_item(db, String.t(), clock, keyword) :: {db, id}
  def add_item(db, text, today, opts \\ []) do
    before = db
    {db, id} = Database.insert_item(db, String.trim(text), date_of(today), after: opts[:after])

    db =
      case opts[:section] do
        nil -> db
        section -> user_assign(db, id, section)
      end

    db =
      db
      |> Assign.auto_assign(id, Keyword.get(opts, :adjacent, []))
      |> date_from_text(id, nil, today)
      |> settle(before, id, today)

    {db, id}
  end

  @doc """
  Changes an item's text, re-runs automatic assignment (it only adds
  assignments) and updates a When date read from the text (R14).
  """
  @spec edit_item(db, id, String.t(), clock, [id]) :: db
  def edit_item(db, id, text, today, adjacent \\ []) do
    old_text = db.items[id].text

    db
    |> Database.update_item(id, &%{&1 | text: String.trim(text)})
    |> Assign.auto_assign(id, adjacent)
    |> date_from_text(id, old_text, today)
    |> settle(db, id, today)
  end

  # An assignment the user asked for: never treated as conditional (R15).
  defp user_assign(db, item_id, cat_id) do
    db |> Assign.assign(item_id, cat_id) |> Database.unmark_conditional(item_id, cat_id)
  end

  # SPEC R14: the first date in an item's text is its When date, unless the
  # user set one explicitly or turned automatic dating off. Relative dates
  # are read once: after an edit the date is only re-read when the date
  # words themselves changed (so "tomorrow" keeps meaning the day it was
  # typed). Removing the date words clears a When date they gave.
  defp date_from_text(db, id, old_text, today) do
    item = db.items[id]

    if not db.auto_date or item.when_explicit do
      db
    else
      now = now_of(today)

      old =
        if old_text,
          do: DateParser.extract_recurring(old_text, now, Context.parser_opts(today)),
          else: :none

      case {old, DateParser.extract_recurring(item.text, now, Context.parser_opts(today))} do
        {{:ok, _, _, _, phrase}, {:ok, _, _, _, phrase}} ->
          db

        {_, {:ok, date, time, rule, _}} ->
          Database.update_item(db, id, &%{&1 | when: date, when_time: time, recurrence: rule})

        {{:ok, _, _, _, _}, :none} ->
          Database.update_item(db, id, &%{&1 | when: nil, when_time: nil, recurrence: nil})

        {:none, :none} ->
          db
      end
    end
  end

  @doc "Turns reading When dates from item text on or off for the file (R14)."
  @spec toggle_auto_date(db) :: db
  def toggle_auto_date(db), do: %{db | auto_date: not db.auto_date}

  @doc "Sets how the file displays dates and times (R41)."
  @spec set_date_format(db, Agenda.Core.DateFormat.t()) :: db
  def set_date_format(db, %Agenda.Core.DateFormat{} = format), do: %{db | date_format: format}

  @spec set_note(db, id, String.t()) :: db
  def set_note(db, id, note), do: Database.update_item(db, id, &%{&1 | note: note})

  @doc """
  Moves an item from one section's category to another (ALT-F10). The item
  leaves `from` and joins `to` (MAIN is never left or joined explicitly).
  With `after: item_id`, it is also placed after that item in item order.
  """
  @spec move_item(db, id, id, id, keyword) :: db
  def move_item(db, item_id, from, to, opts \\ []) do
    before = db

    db =
      if to == from do
        db
      else
        db = if from == db.main_id, do: db, else: Assign.unassign(db, item_id, from)
        if to == db.main_id, do: db, else: user_assign(db, item_id, to)
      end

    db =
      case opts[:after] do
        nil -> db
        ^item_id -> db
        after_id -> Database.reorder_item(db, item_id, after_id)
      end

    settle(db, before, item_id, opts[:clock])
  end

  @doc """
  Marks an item done today, or clears its done date (F4 DONE). A recurring
  item marked done is followed by a copy with the next When date (R14a).
  """
  @spec toggle_done(db, id, Date.t()) :: db
  def toggle_done(db, id, today) do
    if db.items[id].done,
      do: Database.update_item(db, id, &%{&1 | done: nil}),
      else: mark_done(db, id, today)
  end

  @doc "Toggles the mark used to select several items (F7 MARK)."
  @spec toggle_mark(db, id) :: db
  def toggle_mark(db, id), do: Database.update_item(db, id, &%{&1 | marked: not &1.marked})

  @doc """
  Marks an item done today unless it already has a done date (bulk F4
  DONE); a recurring one is followed by its next occurrence (R14a).
  """
  @spec mark_done(db, id, clock) :: db
  def mark_done(db, id, today) do
    case db.items[id] do
      %{done: nil} = item ->
        db
        |> Database.update_item(id, &%{&1 | done: date_of(today)})
        |> next_occurrence(item, today)

      _ ->
        db
    end
  end

  # A recurring item marked done is followed by a copy with the next When
  # date (User's Guide 7-12): same text, note, time, alarm and assignments.
  defp next_occurrence(db, %{recurrence: nil}, _today), do: db
  defp next_occurrence(db, %{when: nil}, _today), do: db

  defp next_occurrence(db, item, today) do
    {db, copy} = Database.insert_item(db, item.text, date_of(today), after: item.id)

    db =
      Database.update_item(db, copy, fn new ->
        %{
          new
          | note: item.note,
            when: Recurrence.next(item.recurrence, item.when),
            when_time: item.when_time,
            when_explicit: item.when_explicit,
            recurrence: item.recurrence,
            alarm_minutes: item.alarm_minutes
        }
      end)

    db
    |> Database.explicit_categories(item.id)
    |> Enum.reduce(db, fn cat, db ->
      db = Database.link(db, copy, cat)

      db =
        if Database.conditional?(db, item.id, cat),
          do: Database.mark_conditional(db, copy, cat),
          else: db

      case Database.number(db, item.id, cat) do
        nil -> db
        number -> Database.put_number(db, copy, cat, number)
      end
    end)
  end

  # --- times and alarms (R14b, R38) ---

  defp date_of(clock), do: Context.today(clock)
  defp now_of(clock), do: Context.now(clock)

  @doc "An item's When date and time (midnight when it has no time), or nil."
  @spec when_at(Agenda.Core.Item.t()) :: NaiveDateTime.t() | nil
  def when_at(%{when: nil}), do: nil
  def when_at(%{when: date, when_time: time}), do: NaiveDateTime.new!(date, time || ~T[00:00:00])

  @doc """
  Sets an alarm to ring `minutes` (0 to 60) before the item's When date and
  time (Item Alarm, ALT-A; User's Guide 10-17).
  """
  @spec set_alarm(db, id, integer) :: {:ok, db} | {:error, :no_when | :minutes}
  def set_alarm(db, id, minutes) do
    cond do
      minutes not in 0..60 -> {:error, :minutes}
      db.items[id].when == nil -> {:error, :no_when}
      true -> {:ok, Database.update_item(db, id, &%{&1 | alarm_minutes: minutes})}
    end
  end

  @spec cancel_alarm(db, id) :: db
  def cancel_alarm(db, id), do: Database.update_item(db, id, &%{&1 | alarm_minutes: nil})

  @doc """
  Rings the alarms whose time has come: they leave the current alarms and
  join today's past alarms. Returns the items that rang.
  """
  @spec ring_alarms(db, NaiveDateTime.t()) :: {db, [id]}
  def ring_alarms(db, %NaiveDateTime{} = now) do
    due =
      for item <- Database.items(db),
          item.alarm_minutes != nil,
          at = when_at(item),
          at != nil,
          NaiveDateTime.compare(NaiveDateTime.add(at, -item.alarm_minutes * 60), now) != :gt,
          do: item.id

    db =
      Enum.reduce(
        due,
        db,
        &Database.update_item(&2, &1, fn i -> %{i | alarm_minutes: nil, alarm_rung_at: now} end)
      )

    {db, due}
  end

  @doc "Current alarms (in When order) and today's past alarms (latest first)."
  @spec alarm_list(db, Date.t()) :: %{current: [id], past: [id]}
  def alarm_list(db, %Date{} = today) do
    items = Database.items(db)

    current =
      items
      |> Enum.filter(&(&1.alarm_minutes != nil))
      |> Enum.sort_by(&when_at/1, NaiveDateTime)
      |> Enum.map(& &1.id)

    past =
      items
      |> Enum.filter(&(&1.alarm_rung_at && NaiveDateTime.to_date(&1.alarm_rung_at) == today))
      |> Enum.sort_by(& &1.alarm_rung_at, {:desc, NaiveDateTime})
      |> Enum.map(& &1.id)

    %{current: current, past: past}
  end

  @doc "Removes an item from the past alarms (DEL in the alarm list)."
  @spec remove_past_alarm(db, id) :: db
  def remove_past_alarm(db, id), do: Database.update_item(db, id, &%{&1 | alarm_rung_at: nil})

  @doc "Forgets past alarms from earlier days (Agenda clears them at the end of the day)."
  @spec clear_old_alarms(db, Date.t()) :: db
  def clear_old_alarms(db, %Date{} = today) do
    old =
      for i <- Database.items(db),
          i.alarm_rung_at && Date.compare(NaiveDateTime.to_date(i.alarm_rung_at), today) == :lt,
          do: i.id

    Enum.reduce(old, db, &remove_past_alarm(&2, &1))
  end

  @doc "Marked items, in item order (the group bulk commands act on)."
  @spec marked_items(db) :: [id]
  def marked_items(db), do: for(item <- Database.items(db), item.marked, do: item.id)

  @doc "Marks (true) or unmarks (false) a group of items (F7 on a section head)."
  @spec set_marked(db, [id], boolean) :: db
  def set_marked(db, ids, marked),
    do: Enum.reduce(ids, db, &Database.update_item(&2, &1, fn i -> %{i | marked: marked} end))

  @doc "Unmarks every item in the file (ALT-F7 UNMKALL)."
  @spec unmark_all(db) :: db
  def unmark_all(db), do: set_marked(db, marked_items(db), false)

  @doc "Deletes an item from the whole file (ALT-F4 DISCARD)."
  @spec discard_item(db, id) :: db
  defdelegate discard_item(db, id), to: Database, as: :delete_item

  @doc """
  Removes an item from a category and its descendants (DEL on an item in a
  section, or on a column entry). For a date category, clears the date.
  """
  @spec remove_from_category(db, id, id, clock | nil) :: db
  def remove_from_category(db, item_id, cat_id, clock \\ nil) do
    case Database.date_field(db, cat_id) do
      nil -> Assign.unassign(db, item_id, cat_id)
      field -> put_date(db, item_id, field, nil)
    end
    |> settle(db, item_id, clock)
  end

  @doc """
  Assigns an item to a category (with mutual exclusion, the
  ancestor/descendant rule and category links), then re-checks the file's
  assignment conditions for the item (R15), read against `clock` for date
  conditions (R15a).
  """
  @spec assign(db, id, id, clock | nil) :: db
  def assign(db, item_id, cat_id, clock \\ nil),
    do: db |> user_assign(item_id, cat_id) |> settle(db, item_id, clock)

  @doc """
  Toggles one explicit assignment, as in the assignment profile: an
  explicit link is removed (only that link, not the subtree); otherwise the
  item is assigned with the usual rules.
  """
  @spec toggle_assignment(db, id, id, clock | nil) :: db
  def toggle_assignment(db, item_id, cat_id, clock \\ nil) do
    if Database.explicit?(db, item_id, cat_id),
      do: db |> Database.unlink(item_id, cat_id) |> settle(db, item_id, clock),
      else:
        user_assign(db, item_id, cat_id)
        |> settle(db, item_id, clock)
  end

  @doc """
  Handles text typed into a column cell for an item (claims 3 and 6 of the
  patent). For a date column the text is parsed as a date, for a numeric
  column as a number (R29). Otherwise the
  text names a descendant of the column head: an exact name match is used
  first, then a unique prefix match; if nothing matches, a new child of the
  column head is created. Returns the category assigned.
  """
  @spec assign_by_name(db, id, id, String.t(), clock) ::
          {:ok, db, id | :date | :number}
          | {:error, :invalid_date | :not_a_number | :ambiguous | :empty}
  def assign_by_name(db, item_id, head_id, text, today) do
    text = String.trim(text)
    before = db

    cond do
      text == "" ->
        {:error, :empty}

      db.categories[head_id].kind == :numeric ->
        with {:ok, value} <- NumberFormat.parse(text),
             {:ok, db} <- set_number(db, item_id, head_id, value, today) do
          {:ok, db, :number}
        else
          _ -> {:error, :not_a_number}
        end

      field = Database.date_field(db, head_id) ->
        case DateParser.parse_recurring(text, now_of(today), Context.parser_opts(today)) do
          {:ok, date, time, rule} ->
            db = put_date(db, item_id, field, date)

            db =
              if field == :when,
                do: Database.update_item(db, item_id, &%{&1 | when_time: time, recurrence: rule}),
                else: db

            {:ok, settle(db, before, item_id, today), :date}

          :error ->
            {:error, :invalid_date}
        end

      true ->
        case resolve_name(db, head_id, text) do
          {:ok, cat_id} ->
            {:ok, assign(db, item_id, cat_id), cat_id}

          :none ->
            {db, cat_id} = Database.insert_category(db, head_id, text)
            {:ok, assign(db, item_id, cat_id), cat_id}

          :ambiguous ->
            {:error, :ambiguous}
        end
    end
  end

  @doc """
  Sets or clears the date for a date category, then re-checks conditions
  (date conditions, R15a, read against `clock`).
  """
  @spec set_date(db, id, id, Date.t() | nil, clock | nil) :: db
  def set_date(db, item_id, cat_id, date, clock \\ nil) do
    field = Database.date_field(db, cat_id) || raise ArgumentError, "not a date category"
    db |> put_date(item_id, field, date) |> settle(db, item_id, clock)
  end

  # A When date set or cleared by the user: set is explicit and overrides
  # the text; cleared hands the When date back to the text (R14).
  # --- conditions and actions after a change (R15, R15b) ------------------------

  # After a change to an item: its conditions are checked again, then the
  # actions of every category it has newly joined (compared with `before`)
  # run, once (User's Guide 18-7, 21-15).
  defp settle(db, before, item_id, clock) do
    db
    |> Assign.apply_conditions(item_id, clock)
    |> run_actions(before, item_id, clock, map_size(db.categories) + 2, nil)
  end

  defp run_actions(db, _before, _item_id, _clock, 0, _only), do: db

  defp run_actions(db, before, item_id, clock, rounds, only) do
    joined =
      db
      |> joined_with_actions(before, item_id)
      |> Enum.filter(&(only == nil or MapSet.member?(only, &1)))

    if joined == [] or not Map.has_key?(db.items, item_id) do
      db
    else
      after_actions =
        joined
        |> Enum.flat_map(&db.categories[&1].actions)
        |> Enum.reduce(db, &apply_action(&2, item_id, &1, clock))
        |> Assign.apply_conditions(item_id, clock)

      after_actions = run_actions(after_actions, db, item_id, clock, rounds - 1, only)

      joined
      |> Enum.map(&db.categories[&1].special)
      |> Enum.reject(&is_nil/1)
      |> Enum.reduce(after_actions, &apply_special(&2, item_id, &1, clock))
    end
  end

  # Categories with actions the item belongs to now but not before,
  # children before their parents.
  defp joined_with_actions(db, before, item_id) do
    was_there = Map.has_key?(before.items, item_id)

    db.categories
    |> Map.values()
    |> Enum.filter(&(&1.actions != [] or &1.special != nil))
    |> Enum.filter(fn cat ->
      Database.member?(db, item_id, cat.id) and
        not (was_there and Map.has_key?(before.categories, cat.id) and
               Database.member?(before, item_id, cat.id))
    end)
    |> Enum.sort_by(&{-Database.depth(db, &1.id), &1.id})
    |> Enum.map(& &1.id)
  end

  defp apply_action(db, item_id, _action, _clock) when not is_map_key(db.items, item_id),
    do: db

  defp apply_action(db, item_id, {target, action}, clock) do
    cond do
      not Map.has_key?(db.categories, target) ->
        db

      action == :remove or action == :clear ->
        case Database.date_field(db, target) do
          nil -> Assign.unassign(db, item_id, target)
          field -> put_date(db, item_id, field, nil)
        end

      field = Database.date_field(db, target) ->
        {:set, text} = action

        case action_date(text, clock) do
          {:ok, date} -> put_date(db, item_id, field, date)
          :error -> db
        end

      true ->
        {:set, number} = action
        db |> user_assign(item_id, target) |> Database.put_number(item_id, target, number)
    end
  end

  # The date of a date action, read when it runs; without a clock (the core
  # never reads one) only an ISO date can be read.
  defp action_date(text, nil) do
    case Date.from_iso8601(text) do
      {:ok, date} -> {:ok, date}
      _ -> :error
    end
  end

  defp action_date(text, clock),
    do: DateParser.parse(text, date_of(clock), Context.parser_opts(clock))

  defp apply_special(db, item_id, _special, _clock) when not is_map_key(db.items, item_id),
    do: db

  defp apply_special(db, item_id, :done, clock), do: mark_done(db, item_id, clock)
  defp apply_special(db, item_id, :discard, _clock), do: Database.delete_item(db, item_id)

  @doc """
  Utilities Execute (R15e; User's Guide 20-19, 21-17): applies the text
  matching, conditions and actions of the categories in `:root`'s family
  (default MAIN: all) to the given items, which may have been in the file
  before those were set. Actions run for the assignments this makes; with
  `old_assignments: true`, also for the ones the items already had.
  `:clock` reads date conditions and actions.
  """
  @spec execute(db, [id], keyword) :: db
  def execute(db, item_ids, opts \\ []) do
    root = opts[:root] || db.main_id
    only = if root == db.main_id, do: nil, else: MapSet.new(Database.subtree(db, root))
    clock = opts[:clock]
    rounds = map_size(db.categories) + 2

    Enum.reduce(item_ids, db, fn id, db ->
      if Map.has_key?(db.items, id) do
        # as if the item had just arrived, every membership counts as new
        before = if opts[:old_assignments], do: %{db | items: Map.delete(db.items, id)}, else: db

        db
        |> Assign.auto_assign(id, [], only)
        |> Assign.apply_conditions(id, clock, only)
        |> run_actions(before, id, clock, rounds, only)
      else
        db
      end
    end)
  end

  @doc """
  Sets one of a category's actions on `target` (R15b; User's Guide 21-3 to
  21-7), run when an item joins the category: on a standard category
  `:assign` (a category link, R8) or `:remove`; on a date category
  `{:set, "date"}` (read when the action runs) or `:clear`; on a numeric
  category `{:set, "number"}` or `:clear`.
  """
  @spec set_action(db, id, id, :assign | :remove | :clear | {:set, String.t()}, clock | nil) ::
          {:ok, db} | {:error, :self | :invalid_date | :not_a_number | :not_allowed}
  def set_action(db, cat_id, target, action, clock \\ nil)

  def set_action(_db, cat_id, cat_id, _action, _clock), do: {:error, :self}

  def set_action(db, cat_id, target, action, clock) do
    kind =
      cond do
        Database.date_field(db, target) -> :date
        db.categories[target].kind == :numeric -> :numeric
        true -> :standard
      end

    with {:ok, action} <- check_action(kind, action, clock) do
      db = remove_action(db, cat_id, target)

      db =
        if action == :assign,
          do:
            Database.update_category(db, cat_id, &%{&1 | also_assign: &1.also_assign ++ [target]}),
          else:
            Database.update_category(
              db,
              cat_id,
              &%{&1 | actions: &1.actions ++ [{target, action}]}
            )

      {:ok, db}
    end
  end

  defp check_action(:standard, action, _clock) when action in [:assign, :remove],
    do: {:ok, action}

  defp check_action(kind, :clear, _clock) when kind in [:date, :numeric], do: {:ok, :clear}

  defp check_action(:date, {:set, text}, clock) do
    today = if clock, do: date_of(clock), else: ~D[2000-01-01]

    case DateParser.parse(text, today, Context.parser_opts(clock)) do
      {:ok, _} -> {:ok, {:set, String.trim(text)}}
      :error -> {:error, :invalid_date}
    end
  end

  defp check_action(:numeric, {:set, text}, _clock) do
    case NumberFormat.parse(to_string(text)) do
      {:ok, number} -> {:ok, {:set, number}}
      :error -> {:error, :not_a_number}
    end
  end

  defp check_action(_kind, _action, _clock), do: {:error, :not_allowed}

  @doc "Removes a category's action on `target` (including a category link)."
  @spec remove_action(db, id, id) :: db
  def remove_action(db, cat_id, target) do
    Database.update_category(db, cat_id, fn cat ->
      %{
        cat
        | actions: List.keydelete(cat.actions, target, 0),
          also_assign: List.delete(cat.also_assign, target)
      }
    end)
  end

  @doc """
  Sets a category's special action (R15b; User's Guide 21-8): `:done` marks
  items done when they join it, `:discard` discards them; `nil` for none.
  """
  @spec set_special_action(db, id, :done | :discard | nil) :: {:ok, db}
  def set_special_action(db, cat_id, special) when special in [nil, :done, :discard],
    do: {:ok, Database.update_category(db, cat_id, &%{&1 | special: special})}

  # --- dependencies (R43) ------------------------------------------------------

  @doc """
  Makes an item depend on prerequisite items (ALT-O with marked items;
  User's Guide 13-12), adding to any it already has. An item cannot depend
  on itself, or on an item that depends on it.
  """
  @spec make_dependent(db, id, [id]) :: {:ok, db} | {:error, :cycle}
  def make_dependent(db, item_id, prerequisite_ids) do
    below = related_items(db, item_id, :dependents, :all)

    if Enum.any?(prerequisite_ids, &(&1 == item_id or &1 in below)) do
      {:error, :cycle}
    else
      links = Enum.reduce(prerequisite_ids, db.dependencies, &Links.link(&2, item_id, &1))
      {:ok, %{db | dependencies: links}}
    end
  end

  @doc "Clears all of an item's prerequisites (ALT-O on a dependent item)."
  @spec clear_dependencies(db, id) :: db
  def clear_dependencies(db, item_id),
    do: %{db | dependencies: Links.drop_left(db.dependencies, item_id)}

  @doc "The items an item depends on, in item order."
  @spec prerequisites(db, id) :: [id]
  defdelegate prerequisites(db, item_id), to: Database

  @doc "The items that depend on an item, in item order."
  @spec dependents(db, id) :: [id]
  defdelegate dependents(db, item_id), to: Database

  @doc "Whether an item still waits for a prerequisite that is not done (shown with &)."
  @spec waiting?(db, id) :: boolean
  defdelegate waiting?(db, item_id), to: Database

  @doc """
  Items related to an item by dependencies, in item order (Utilities Show
  Depends / Show Prereqs): `:one` level, `:all` levels, or `:every` item in
  the file that has dependents (or prerequisites); `item_id` is ignored
  for `:every`.
  """
  @spec related_items(db, id | nil, :dependents | :prerequisites, :one | :all | :every) :: [id]
  def related_items(db, _item_id, direction, :every) do
    step = step_fun(direction)
    for id <- db.item_order, step.(db, id) != [], do: id
  end

  def related_items(db, item_id, direction, level) do
    found = reach(db, step_fun(direction), [item_id], MapSet.new(), level)
    Enum.filter(db.item_order, &(&1 in found and &1 != item_id))
  end

  defp step_fun(:dependents), do: &Database.dependents/2
  defp step_fun(:prerequisites), do: &Database.prerequisites/2

  defp reach(_db, _step, [], seen, _level), do: seen

  defp reach(db, step, frontier, seen, level) do
    next = frontier |> Enum.flat_map(&step.(db, &1)) |> Enum.reject(&(&1 in seen))
    seen = MapSet.union(seen, MapSet.new(next))
    if level == :one, do: seen, else: reach(db, step, next, seen, level)
  end

  # --- numbers (R29) ----------------------------------------------------------

  @doc """
  Gives an item a number in a numeric category, assigning it there (with
  the usual assignment rules).
  """
  @spec set_number(db, id, id, number, clock | nil) :: {:ok, db} | {:error, :not_numeric}
  def set_number(db, item_id, cat_id, value, clock \\ nil) do
    if db.categories[cat_id].kind == :numeric do
      db =
        db
        |> user_assign(item_id, cat_id)
        |> Database.put_number(item_id, cat_id, value)
        |> settle(db, item_id, clock)

      {:ok, db}
    else
      {:error, :not_numeric}
    end
  end

  @doc "Removes an item's number, and so its assignment to the numeric category."
  @spec clear_number(db, id, id, clock | nil) :: db
  def clear_number(db, item_id, cat_id, clock \\ nil),
    do: remove_from_category(db, item_id, cat_id, clock)

  @doc """
  What converting a standard category to numeric would do to its children
  (User's Guide 8-11): they are removed, and their items get the child's
  name as their number, or 0 for the names listed in `non_numeric`; the
  `assigned` items assigned to the category itself get 0.
  """
  @spec numeric_conversion(db, id) :: %{
          children: non_neg_integer,
          non_numeric: [String.t()],
          assigned: non_neg_integer
        }
  def numeric_conversion(db, cat_id) do
    children = Enum.map(db.categories[cat_id].children, &db.categories[&1])

    %{
      children: length(children),
      non_numeric: for(c <- children, NumberFormat.parse(c.name) == :error, do: c.name),
      assigned: db |> direct_items(cat_id) |> length()
    }
  end

  defp direct_items(db, cat_id),
    do: for(item <- Database.items(db), Database.explicit?(db, item.id, cat_id), do: item.id)

  @doc """
  Converts a standard category to a numeric one (User's Guide 8-11 to
  8-12). Its children, if any, become numbers (see `numeric_conversion/2`);
  a category with grandchildren cannot be converted. Numeric categories do
  not match item text.
  """
  @spec make_numeric(db, id) :: {:ok, db} | {:error, :not_standard | :protected | :too_deep}
  def make_numeric(db, cat_id) do
    cat = db.categories[cat_id]

    cond do
      cat.kind != :standard ->
        {:error, :not_standard}

      Database.protected?(db, cat_id) ->
        {:error, :protected}

      Enum.any?(cat.children, &(db.categories[&1].children != [])) ->
        {:error, :too_deep}

      true ->
        values =
          for(item <- direct_items(db, cat_id), do: {item, 0.0}) ++
            for child <- cat.children,
                value = child_value(db.categories[child].name),
                item <- Database.items_in(db, child),
                do: {item.id, value}

        db =
          Enum.reduce(cat.children, db, fn child, db ->
            {:ok, db} = Database.delete_category(db, child)
            db
          end)

        db =
          Database.update_category(
            db,
            cat_id,
            &%{&1 | kind: :numeric, match_name: false, exclusive: false}
          )

        {:ok,
         Enum.reduce(values, db, fn {item, v}, db -> Database.put_number(db, item, cat_id, v) end)}
    end
  end

  defp child_value(name) do
    case NumberFormat.parse(name) do
      {:ok, value} -> value
      :error -> 0.0
    end
  end

  defp put_date(db, item_id, :when, date) do
    Database.update_item(
      db,
      item_id,
      &%{&1 | when: date, when_time: nil, when_explicit: date != nil, recurrence: nil}
    )
  end

  defp put_date(db, item_id, field, date),
    do: Database.update_item(db, item_id, &Map.put(&1, field, date))

  @doc """
  Everything an item is assigned to, in hierarchy order, as the Item
  Properties box lists it: date categories with the item's date (`:date`),
  numeric categories with its number (`:numeric`, R29), and links the
  user made (`:explicit`) or a condition made
  (`:conditional`). Membership through subcategories is not listed.
  """
  @spec item_assignments(db, id) :: [
          %{
            required(:category) => id,
            required(:kind) => :date | :numeric | :explicit | :conditional,
            required(:date) => Date.t() | nil,
            optional(:number) => float
          }
        ]
  def item_assignments(db, item_id) do
    item = db.items[item_id]

    db
    |> Database.hierarchy()
    |> Enum.flat_map(fn {id, _depth} ->
      cond do
        field = Database.date_field(db, id) ->
          case Map.get(item, field) do
            nil -> []
            date -> [%{category: id, kind: :date, date: date}]
          end

        number = Database.number(db, item_id, id) ->
          [%{category: id, kind: :numeric, date: nil, number: number}]

        Database.explicit?(db, item_id, id) ->
          kind = if Database.conditional?(db, item_id, id), do: :conditional, else: :explicit
          [%{category: id, kind: kind, date: nil}]

        true ->
          []
      end
    end)
  end

  @doc """
  Automatic completion (R32): the subcategories of `head_id` whose names
  begin with `text`, ignoring case and accents, in hierarchy order with an
  exact name first. The first one is what Agenda shows as you type; the
  others are reached with NEXTSEL / PREVSEL.
  """
  @spec completions(db, id, String.t()) :: [id]
  def completions(db, head_id, text) do
    case fold(text) do
      "" ->
        []

      wanted ->
        matches =
          db
          |> Database.descendants(head_id)
          |> Enum.filter(&String.starts_with?(fold(db.categories[&1].name), wanted))

        {exact, prefix} = Enum.split_with(matches, &(fold(db.categories[&1].name) == wanted))
        exact ++ prefix
    end
  end

  @doc """
  Assigns an item to a new child of `head_id` named exactly `text`,
  overriding automatic completion (Agenda's NEWCAT / INS): typing "Low"
  creates Low even when Lowest exists. If a child with that name already
  exists, that one is used.
  """
  @spec assign_new_by_name(db, id, id, String.t()) :: {:ok, db, id} | {:error, :empty}
  def assign_new_by_name(db, item_id, head_id, text) do
    case add_category(db, head_id, text) do
      {:ok, db, cat_id} ->
        {:ok, assign(db, item_id, cat_id), cat_id}

      {:error, :duplicate} ->
        wanted = Database.normalize(text)

        cat_id =
          Enum.find(
            db.categories[head_id].children,
            &(Database.normalize(db.categories[&1].name) == wanted)
          )

        {:ok, assign(db, item_id, cat_id), cat_id}

      {:error, :empty} ->
        {:error, :empty}
    end
  end

  # Case- and accent-insensitive form used for completion ("éc" ~ "ec").
  defp fold(text) do
    text
    |> String.trim()
    |> :unicode.characters_to_nfd_binary()
    |> String.replace(~r/\p{Mn}/u, "")
    |> String.downcase()
  end

  # Exact (case-insensitive) match among descendants of `root`, else a
  # unique prefix match.
  defp resolve_name(db, root, text) do
    wanted = Database.normalize(text)
    candidates = Database.descendants(db, root)

    case Database.find_categories(db, text, root) -- [root] do
      [id | _] ->
        {:ok, id}

      [] ->
        prefixed =
          Enum.filter(
            candidates,
            &String.starts_with?(Database.normalize(db.categories[&1].name), wanted)
          )

        case prefixed do
          [] -> :none
          [id] -> {:ok, id}
          _ -> :ambiguous
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Categories
  # ---------------------------------------------------------------------------

  @doc """
  Adds a category under `parent_id`. Names must be unique among siblings.
  Accepts the same options as `Database.insert_category/4`.
  """
  @spec add_category(db, id, String.t(), keyword) :: {:ok, db, id} | {:error, :duplicate | :empty}
  def add_category(db, parent_id, name, opts \\ []) do
    name = String.trim(name)
    siblings = db.categories[parent_id].children
    wanted = Database.normalize(name)

    cond do
      name == "" ->
        {:error, :empty}

      Enum.any?(siblings, &(Database.normalize(db.categories[&1].name) == wanted)) ->
        {:error, :duplicate}

      true ->
        {db, id} = Database.insert_category(db, parent_id, name, opts)
        {:ok, db, id}
    end
  end

  @doc "Finds a category anywhere by name, or creates it under MAIN."
  @spec find_or_create_category(db, String.t()) :: {db, id}
  def find_or_create_category(db, name) do
    case Database.find_categories(db, name) do
      [id | _] -> {db, id}
      [] -> Database.insert_category(db, db.main_id, String.trim(name))
    end
  end

  @spec rename_category(db, id, String.t()) :: {:ok, db} | {:error, :empty | :protected}
  def rename_category(db, id, name) do
    name = String.trim(name)

    cond do
      name == "" -> {:error, :empty}
      Database.protected?(db, id) -> {:error, :protected}
      true -> {:ok, Database.rename_category(db, id, name)}
    end
  end

  defdelegate discard_category(db, id), to: Database, as: :delete_category
  # --- moving categories (SPEC R7b, R7c, R7d) ---

  @typedoc "A change to a category's place in the hierarchy."
  @type relocation :: :promote | :demote | {:move, id, id | :first | nil}

  @typedoc "How items that a move puts in conflict are resolved."
  @type move_resolution :: :remove_moved | :remove_other | {:new_category, String.t()}

  @doc """
  Items that a relocation would put in conflict with the assignment rules
  (an exclusive family twice, R7b; a category and its ancestor, R7c).
  Returns the relocation's error if it is invalid.
  """
  @spec relocation_conflicts(db, id, relocation) :: {:ok, [id]} | {:error, atom}
  def relocation_conflicts(db, id, relocation) do
    with {:ok, moved} <- do_relocate(db, id, relocation) do
      {:ok, Assign.placement_conflicts(moved, id)}
    end
  end

  @doc """
  Promotes, demotes or moves a category, resolving the items this puts in
  conflict, as Agenda 2.0 does:

    * `:remove_moved` (default) – the items keep their other assignments and
      lose the conflicting ones in the moved category
    * `:remove_other` – they keep the moved category's assignments and lose
      the other, conflicting ones
    * `{:new_category, name}` – create `name` under the category the
      conflict hinges on and move the items there (only when there are
      conflicts)
  """
  @spec relocate(db, id, relocation, move_resolution) :: {:ok, db} | {:error, atom}
  def relocate(db, id, relocation, resolution \\ :remove_moved) do
    with {:ok, moved_db} <- do_relocate(db, id, relocation) do
      original = MapSet.new(Database.subtree(db, id))
      resolve_move(moved_db, id, original, Assign.placement_conflicts(moved_db, id), resolution)
    end
  end

  defp do_relocate(db, id, :promote), do: Database.promote(db, id)
  defp do_relocate(db, id, :demote), do: Database.demote(db, id)

  defp do_relocate(db, id, {:move, parent, after_id}),
    do: Database.move_category(db, id, parent, after_id)

  defp resolve_move(db, _id, _original, [], _resolution), do: {:ok, db}

  defp resolve_move(db, id, original, items, {:new_category, name}) do
    family = Assign.conflicting_family(db, id, items)

    with {:ok, db, target} <- add_category(db, family, name) do
      {:ok,
       Enum.reduce(items, db, &Assign.resolve_placement(&2, original, &1, {:category, target}))}
    end
  end

  defp resolve_move(db, _id, original, items, rule) when rule in [:remove_moved, :remove_other] do
    {:ok, Enum.reduce(items, db, &Assign.resolve_placement(&2, original, &1, rule))}
  end

  @doc "Moves a category under `parent` (ALT-F10); see `relocate/4`."
  @spec move_category(db, id, id, id | :first | nil, move_resolution) ::
          {:ok, db} | {:error, atom}
  def move_category(db, id, parent, after_id, resolution \\ :remove_moved),
    do: relocate(db, id, {:move, parent, after_id}, resolution)

  @doc "Moves a category up one level, adopting its following siblings (F7, R7d); see `relocate/4`."
  @spec promote(db, id, move_resolution) :: {:ok, db} | {:error, atom}
  def promote(db, id, resolution \\ :remove_moved), do: relocate(db, id, :promote, resolution)

  @doc "Moves a category down one level, under its previous sibling (F8); see `relocate/4`."
  @spec demote(db, id, move_resolution) :: {:ok, db} | {:error, atom}
  def demote(db, id, resolution \\ :remove_moved), do: relocate(db, id, :demote, resolution)

  @spec move_conflicts(db, id, id, id | :first | nil) :: {:ok, [id]} | {:error, atom}
  def move_conflicts(db, id, parent, after_id),
    do: relocation_conflicts(db, id, {:move, parent, after_id})

  @spec promote_conflicts(db, id) :: {:ok, [id]} | {:error, atom}
  def promote_conflicts(db, id), do: relocation_conflicts(db, id, :promote)

  @spec demote_conflicts(db, id) :: {:ok, [id]} | {:error, atom}
  def demote_conflicts(db, id), do: relocation_conflicts(db, id, :demote)

  @doc "Items assigned to more than one child of `id` (see `make_exclusive/3`)."
  @spec exclusive_conflicts(db, id) :: [id]
  defdelegate exclusive_conflicts(db, id), to: Assign

  @doc """
  Makes the children of a category mutually exclusive (SPEC R7a). Items
  already assigned to several children are resolved first, as in Agenda
  2.0's "Assign conflicting item(s) to" box:

    * `:parent` (default) – assign them to the category itself instead
    * `:first_child` – keep the child closest to the top of the family
    * `{:new_child, name}` – create a new child and assign them to it
      (only created when there are conflicts)
  """
  @spec make_exclusive(db, id, :parent | :first_child | {:new_child, String.t()}) ::
          {:ok, db} | {:error, :protected | :empty | :duplicate}
  def make_exclusive(db, id, resolution \\ :parent) do
    conflicts = Assign.exclusive_conflicts(db, id)

    with :ok <- if(Database.protected?(db, id), do: {:error, :protected}, else: :ok),
         {:ok, db, rule} <- exclusive_rule(db, id, resolution, conflicts) do
      db = Enum.reduce(conflicts, db, &Assign.resolve_exclusive(&2, id, &1, rule))
      {:ok, Database.update_category(db, id, &%{&1 | exclusive: true})}
    end
  end

  defp exclusive_rule(db, _id, _resolution, []), do: {:ok, db, :parent}

  defp exclusive_rule(db, id, {:new_child, name}, _conflicts) do
    with {:ok, db, child} <- add_category(db, id, name), do: {:ok, db, {:category, child}}
  end

  defp exclusive_rule(db, _id, rule, _conflicts) when rule in [:parent, :first_child],
    do: {:ok, db, rule}

  @doc "Lets the children of a category be combined again. Assignments are kept."
  @spec make_unexclusive(db, id) :: db
  def make_unexclusive(db, id), do: Database.update_category(db, id, &%{&1 | exclusive: false})

  @doc "Toggles whether a category takes part in automatic assignment."
  @spec toggle_match_name(db, id) :: db
  def toggle_match_name(db, id),
    do: Database.update_category(db, id, &%{&1 | match_name: not &1.match_name})

  @doc "Sets a category's short name (an alias for matching); blank clears it."
  @spec set_short_name(db, id, String.t()) :: db
  def set_short_name(db, id, text) do
    short = if String.trim(text) == "", do: nil, else: String.trim(text)
    Database.update_category(db, id, &%{&1 | short_name: short})
  end

  @spec set_category_note(db, id, String.t()) :: db
  def set_category_note(db, id, note), do: Database.update_category(db, id, &%{&1 | note: note})

  @doc "Adds `target` to a category's `also_assign` links, or removes it if present."
  @spec toggle_also_assign(db, id, id) :: db
  def toggle_also_assign(db, cat_id, target) do
    Database.update_category(db, cat_id, fn c ->
      if target in c.also_assign,
        do: %{c | also_assign: List.delete(c.also_assign, target)},
        else: %{c | also_assign: c.also_assign ++ [target]}
    end)
  end

  @doc """
  Re-runs automatic assignment for every item, e.g. after adding a category
  (Agenda's F9 RECALC behaviour), and gives a When date to items whose text
  has a date but that have none yet.
  """
  @spec reassign_all(db, clock) :: db
  def reassign_all(db, today) do
    Enum.reduce(db.item_order, db, fn id, before ->
      db = Assign.auto_assign(before, id, [])
      db = if db.items[id].when, do: db, else: date_from_text(db, id, nil, today)
      settle(db, before, id, today)
    end)
  end

  # --- assignment conditions (R15) ---

  @doc """
  Adds an assignment condition to a category: items `:assigned` (or
  `:not_assigned`) to `target` are assigned to it. Like Agenda, a new
  condition applies to items as they are added or changed; Recalc
  (`reassign_all/2`) applies it to all existing items.
  """
  @spec add_condition(db, id, id, :assigned | :not_assigned) ::
          {:ok, db} | {:error, :self | :duplicate}
  def add_condition(db, cat_id, target, kind) when kind in [:assigned, :not_assigned] do
    cond do
      cat_id == target ->
        {:error, :self}

      List.keymember?(db.categories[cat_id].conditions, target, 0) ->
        {:error, :duplicate}

      true ->
        {:ok,
         Database.update_category(
           db,
           cat_id,
           &%{&1 | conditions: &1.conditions ++ [{target, kind}]}
         )}
    end
  end

  @spec remove_condition(db, id, id) :: db
  def remove_condition(db, cat_id, target) do
    Database.update_category(
      db,
      cat_id,
      &%{&1 | conditions: List.keydelete(&1.conditions, target, 0)}
    )
  end

  @doc """
  Sets a category's text conditions, its "Also match" setting (R15d,
  `Agenda.Core.TextCondition`). New conditions reach existing items when
  they are checked again (Recalc).
  """
  @spec set_also_match(db, id, String.t()) :: {:ok, db}
  def set_also_match(db, cat_id, text),
    do: {:ok, Database.update_category(db, cat_id, &%{&1 | also_match: String.trim(text)})}

  @doc """
  Sets a date or numeric condition on a category (R15a; User's Guide 20-5 to
  20-7): items whose date (or number) in `target` is in, or outside, the
  range are assigned to it; blank ends are open, both blank means any date
  (or number). Dates are checked against `clock` and may be relative ("this
  week"); they are read again whenever conditions are checked.
  """
  @spec set_range_condition(
          db,
          id,
          id,
          {String.t() | nil, String.t() | nil, :inside | :outside},
          clock
        ) :: {:ok, db} | {:error, :self | :not_a_range_category | :invalid_date | :not_a_number}
  def set_range_condition(_db, cat_id, cat_id, _range, _clock), do: {:error, :self}

  def set_range_condition(db, cat_id, target, {from, to, where}, clock) do
    if RangeFilter.range_category?(db, target) do
      with {:ok, range} <- RangeFilter.build(db, target, from, to, where, clock) do
        term = if match?({:range, nil, nil, _}, range), do: :assigned, else: range
        conditions = db.categories[cat_id].conditions

        conditions =
          if List.keymember?(conditions, target, 0),
            do: List.keyreplace(conditions, target, 0, {target, term}),
            else: conditions ++ [{target, term}]

        {:ok, Database.update_category(db, cat_id, &%{&1 | conditions: conditions})}
      end
    else
      {:error, :not_a_range_category}
    end
  end

  @doc """
  Checks every item against the file's conditions again, as Agenda does
  when the date changes (date conditions with relative dates, R15a).
  """
  @spec recheck_conditions(db, clock) :: db
  def recheck_conditions(db, clock),
    do: Enum.reduce(db.item_order, db, fn id, db -> settle(db, db, id, clock) end)

  @doc """
  Cycles the condition on `target` the way the category properties box
  does: none → assigned → not assigned → none.
  """
  @spec cycle_condition(db, id, id) :: {:ok, db} | {:error, :self}
  def cycle_condition(db, cat_id, target) do
    case List.keyfind(db.categories[cat_id].conditions, target, 0) do
      nil ->
        add_condition(db, cat_id, target, :assigned)

      {_, :assigned} ->
        {:ok,
         Database.update_category(
           db,
           cat_id,
           &%{&1 | conditions: List.keyreplace(&1.conditions, target, 0, {target, :not_assigned})}
         )}

      {_, :not_assigned} ->
        {:ok, remove_condition(db, cat_id, target)}
    end
  end

  # ---------------------------------------------------------------------------
  # Views
  # ---------------------------------------------------------------------------

  @spec add_view(db, String.t(), [id]) :: {db, id}
  def add_view(db, name, section_ids),
    do: Database.insert_view(db, String.trim(name), sections: section_ids)

  @spec rename_view(db, id, String.t()) :: db
  def rename_view(db, view_id, name),
    do: Database.update_view(db, view_id, &%{&1 | name: String.trim(name)})

  defdelegate discard_view(db, view_id), to: Database, as: :delete_view

  @doc "Moves a view to position `index` in the view manager (clamped)."
  @spec move_view(db, id, integer) :: db
  def move_view(db, view_id, index) do
    rest = List.delete(db.view_order, view_id)
    index = index |> max(0) |> min(length(rest))
    %{db | view_order: List.insert_at(rest, index, view_id)}
  end

  @doc "Changes the category heading the section at `index`."
  @spec set_section_category(db, id, non_neg_integer, id) :: db
  def set_section_category(db, view_id, index, cat_id) do
    Database.update_view(db, view_id, fn v ->
      %{v | sections: List.update_at(v.sections, index, &%{&1 | category_id: cat_id})}
    end)
  end

  @doc "Inserts a section headed by `cat_id` at `index` in the view."
  @spec add_section(db, id, id, non_neg_integer) :: db
  def add_section(db, view_id, cat_id, index) do
    Database.update_view(db, view_id, fn %View{} = v ->
      %{v | sections: List.insert_at(v.sections, index, %Section{category_id: cat_id})}
    end)
  end

  @spec remove_section(db, id, non_neg_integer) :: db
  def remove_section(db, view_id, index) do
    Database.update_view(db, view_id, &%{&1 | sections: List.delete_at(&1.sections, index)})
  end

  @doc "Collapses (true) or expands (false) the section at `index`."
  @spec set_section_collapsed(db, id, non_neg_integer, boolean) :: db
  def set_section_collapsed(db, view_id, index, collapsed) do
    Database.update_view(db, view_id, fn v ->
      %{v | sections: List.update_at(v.sections, index, &%{&1 | collapsed: collapsed})}
    end)
  end

  @doc "Collapses or expands every section of a view."
  @spec set_all_sections_collapsed(db, id, boolean) :: db
  def set_all_sections_collapsed(db, view_id, collapsed) do
    Database.update_view(db, view_id, fn v ->
      %{v | sections: Enum.map(v.sections, &%{&1 | collapsed: collapsed})}
    end)
  end

  @spec toggle_section_collapsed(db, id, non_neg_integer) :: db
  def toggle_section_collapsed(db, view_id, index) do
    Database.update_view(db, view_id, fn v ->
      %{v | sections: List.update_at(v.sections, index, &%{&1 | collapsed: not &1.collapsed})}
    end)
  end

  @doc "Inserts a column headed by `cat_id` at `index` in the view."
  @spec add_column(db, id, id, non_neg_integer, pos_integer) :: db
  def add_column(db, view_id, cat_id, index, width \\ 12) do
    Database.update_view(db, view_id, fn v ->
      %{v | columns: List.insert_at(v.columns, index, %Column{category_id: cat_id, width: width})}
    end)
  end

  @spec remove_column(db, id, non_neg_integer) :: db
  def remove_column(db, view_id, index) do
    Database.update_view(db, view_id, &%{&1 | columns: List.delete_at(&1.columns, index)})
  end

  @doc "Sets how a numeric column shows its numbers and calculations (R29)."
  @spec set_column_format(db, id, non_neg_integer, NumberFormat.t()) :: db
  def set_column_format(db, view_id, index, %NumberFormat{} = format) do
    Database.update_view(db, view_id, fn v ->
      %{v | columns: List.update_at(v.columns, index, &%{&1 | number: format})}
    end)
  end

  @spec resize_column(db, id, non_neg_integer, integer) :: db
  def resize_column(db, view_id, index, delta) do
    Database.update_view(db, view_id, fn v ->
      %{v | columns: List.update_at(v.columns, index, &%{&1 | width: max(3, &1.width + delta)})}
    end)
  end

  # --- filters (R28) and sorting (R36) ---

  @doc """
  Cycles the filter on `cat_id` for a view (`:view`) or one of its sections
  (`{:section, index}`): none → assigned → not assigned → none. A filtered
  view shows only items meeting all its criteria (mutually exclusive
  categories count as alternatives).
  """
  @spec cycle_filter(db, id, :view | {:section, non_neg_integer}, id) :: {:ok, db}
  def cycle_filter(db, view_id, scope, cat_id) do
    filter = get_scoped(db, view_id, scope, :filter)

    filter =
      case List.keyfind(filter, cat_id, 0) do
        nil -> filter ++ [{cat_id, :assigned}]
        {_, :assigned} -> List.keyreplace(filter, cat_id, 0, {cat_id, :not_assigned})
        {_, :not_assigned} -> List.keydelete(filter, cat_id, 0)
      end

    {:ok, put_scoped(db, view_id, scope, :filter, filter)}
  end

  @doc """
  Sets the filter on a date or numeric category (R28a): `{:assigned, from,
  to, :inside | :outside}` shows items with a date or number in (or outside)
  the range, or any date or number when `from` and `to` are blank;
  `{:not_assigned, _, _, _}` shows items without one. Dates may be relative
  ("monday"); they are checked against `today` here and read again whenever
  the view is shown.
  """
  @spec set_range_filter(
          db,
          id,
          :view | {:section, non_neg_integer},
          id,
          {:assigned | :not_assigned, String.t() | nil, String.t() | nil, :inside | :outside},
          clock
        ) :: {:ok, db} | {:error, :not_a_range_category | :invalid_date | :not_a_number}
  def set_range_filter(db, view_id, scope, cat_id, {show, from, to, where}, today) do
    cond do
      not RangeFilter.range_category?(db, cat_id) ->
        {:error, :not_a_range_category}

      show == :not_assigned ->
        {:ok, put_filter(db, view_id, scope, cat_id, :not_assigned)}

      true ->
        with {:ok, range} <- RangeFilter.build(db, cat_id, from, to, where, today) do
          term = if match?({:range, nil, nil, _}, range), do: :assigned, else: range
          {:ok, put_filter(db, view_id, scope, cat_id, term)}
        end
    end
  end

  @doc "Removes a category from a view's or section's filter."
  @spec remove_filter(db, id, :view | {:section, non_neg_integer}, id) :: db
  def remove_filter(db, view_id, scope, cat_id) do
    filter = db |> get_scoped(view_id, scope, :filter) |> List.keydelete(cat_id, 0)
    put_scoped(db, view_id, scope, :filter, filter)
  end

  defp put_filter(db, view_id, scope, cat_id, term) do
    filter = get_scoped(db, view_id, scope, :filter)

    filter =
      if List.keymember?(filter, cat_id, 0),
        do: List.keyreplace(filter, cat_id, 0, {cat_id, term}),
        else: filter ++ [{cat_id, term}]

    put_scoped(db, view_id, scope, :filter, filter)
  end

  @doc """
  The dates and numbers a new item typed into section `index` gets from
  the date and numeric filters (R28a; see `RangeFilter.entry_value/4`).
  """
  @spec entry_values(db, id, non_neg_integer, clock) ::
          [{id, {:date, Date.t()} | {:number, float}}]
  def entry_values(db, view_id, index, today) do
    view = Database.view(db, view_id)
    section = Enum.at(view.sections, index)

    for {cat, {:range, _, _, _} = range} <- view.filter ++ section.filter,
        value = RangeFilter.entry_value(db, cat, range, today),
        do: {cat, value}
  end

  @doc "Gives an item the dates and numbers from `entry_values/4`."
  @spec apply_entry_values(db, id, [{id, {:date, Date.t()} | {:number, float}}], clock | nil) ::
          db
  def apply_entry_values(db, item_id, values, clock \\ nil) do
    Enum.reduce(values, db, fn
      {cat, {:date, date}}, db ->
        set_date(db, item_id, cat, date, clock)

      {cat, {:number, number}}, db ->
        {:ok, db} = set_number(db, item_id, cat, number, clock)
        db
    end)
  end

  @doc """
  Sets the sort keys (`[View.SortKey.t()]`, at most two are used) for a view
  or a section; a section's `nil` means "as the view".
  """
  @spec set_sort(db, id, :view | {:section, non_neg_integer}, [View.SortKey.t()] | nil) :: db
  def set_sort(db, view_id, scope, keys),
    do: put_scoped(db, view_id, scope, :sort, keys && Enum.take(keys, 2))

  @doc """
  The categories a new item typed into section `index` must have to pass
  the view's and the section's filters (User's Guide 11-4). Of mutually
  exclusive alternatives, the first is used.
  """
  @spec entry_categories(db, id, non_neg_integer) :: [id]
  def entry_categories(db, view_id, index) do
    view = Database.view(db, view_id)
    section = Enum.at(view.sections, index)

    (view.filter ++ section.filter)
    |> Enum.filter(&(elem(&1, 1) == :assigned))
    |> Enum.map(&elem(&1, 0))
    |> Enum.reject(&RangeFilter.range_category?(db, &1))
    |> Enum.reduce([], fn cat, chosen ->
      if Enum.any?(chosen, &Assign.conflict?(db, cat, &1)), do: chosen, else: chosen ++ [cat]
    end)
  end

  @doc """
  Searches the whole file (Agenda's Utilities Show Match, R37): the "Show
  View" lists every matching item under MAIN. It is created the first
  time and updated afterwards. Returns the view.
  """
  @spec show_match(db, Agenda.Core.Search.t()) :: {db, id}
  def show_match(db, %Agenda.Core.Search{} = search), do: show(db, search)

  defp show(db, match) do
    case Enum.find(Database.views(db), &(&1.name == @show_view)) do
      nil ->
        {db, view_id} = Database.insert_view(db, @show_view, sections: [db.main_id])
        {Database.update_view(db, view_id, &%{&1 | match: match}), view_id}

      view ->
        {Database.update_view(db, view.id, &%{&1 | match: match}), view.id}
    end
  end

  @doc """
  Lists items in the Show View (User's Guide 13-15, R43), as `show_match/2`
  does for a search. Returns the view.
  """
  @spec show_items(db, [id]) :: {db, id}
  def show_items(db, ids), do: show(db, {:items, ids})

  @doc "Sorts a category's children alphabetically (ALT-F5 in the category manager)."
  @spec sort_children(db, id) :: db
  def sort_children(db, parent_id) do
    Database.update_category(db, parent_id, fn c ->
      %{c | children: Enum.sort_by(c.children, &String.downcase(db.categories[&1].name))}
    end)
  end

  @doc """
  How a view orders its section heads (User's Guide 15-20): `:none` (as
  added), `:category` (hierarchy order), `:alpha` or `:numeric` (by name).
  """
  @spec set_section_sort(db, id, :none | :category | :alpha | :numeric, :asc | :desc) :: db
  def set_section_sort(db, view_id, sort, order),
    do: Database.update_view(db, view_id, &%{&1 | section_sort: sort, section_order: order})

  @doc "Sorts the views alphabetically (ALT-F5 in the view manager)."
  @spec sort_views(db) :: db
  def sort_views(db),
    do: %{db | view_order: Enum.sort_by(db.view_order, &String.downcase(db.views[&1].name))}

  defp get_scoped(db, view_id, :view, field), do: Map.fetch!(Database.view(db, view_id), field)

  defp get_scoped(db, view_id, {:section, index}, field),
    do:
      db |> Database.view(view_id) |> Map.fetch!(:sections) |> Enum.at(index) |> Map.fetch!(field)

  defp put_scoped(db, view_id, :view, field, value),
    do: Database.update_view(db, view_id, &Map.put(&1, field, value))

  defp put_scoped(db, view_id, {:section, index}, field, value) do
    Database.update_view(db, view_id, fn v ->
      %{v | sections: List.update_at(v.sections, index, &Map.put(&1, field, value))}
    end)
  end

  @doc "Toggles a boolean view option such as `:hide_done`."
  @spec toggle_view_option(db, id, :hide_done | :hide_empty | :hide_inherited | :hide_dependent) ::
          db
  def toggle_view_option(db, view_id, option) do
    Database.update_view(db, view_id, &Map.update!(&1, option, fn value -> not value end))
  end
end
