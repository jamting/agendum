# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Facade.Changes do
  @moduledoc """
  What every change to an item goes through, shared by the area
  modules of `Agendum.Core`: assignments the user asked for, the dates
  date categories get (R14, R14f, R6b), dates set by hand, and settling
  after a change: conditions checked again and actions run (R15, R15b).
  Internal to the facade.
  """

  alias Agendum.Core.{Assign, Context, Database, DateParser, DateRule}
  alias Agendum.Core.Facade.Items

  # These functions are `def` (public) only so the other facade modules can
  # call them; `@doc false` hides them from the API docs. Elixir has no
  # "package-private": a module's functions are either public or `defp`.

  # An assignment the user asked for: never treated as conditional (R15).
  @doc false
  def user_assign(db, item_id, cat_id) do
    db |> Assign.assign(item_id, cat_id) |> Database.unmark_conditional(item_id, cat_id)
  end

  # --- how date categories get dates (R14, R14f, R6b) -----------------------------

  # After an item is entered or changed: every date category whose rule
  # stamps on one of `events` gets the current date (and time), and every
  # one whose rule reads text gets the date found there. `old_item` is the
  # item before the change, nil for a new one.
  @doc false
  def item_dates(db, id, old_item, events, clock) do
    db
    |> date_categories()
    |> Enum.reduce(db, fn cat_id, db ->
      rule = db.categories[cat_id].date_rule

      cond do
        DateRule.stamps?(rule, events) -> stamp_date(db, id, cat_id, clock)
        DateRule.sources(rule) != [] -> date_from_text(db, id, old_item, cat_id, clock)
        true -> db
      end
    end)
  end

  defp date_categories(db),
    # a map iterates in no order you should rely on, hence the sort (ids are
    # given out in order, so this is creation order)
    do: for({id, %{kind: :date}} <- db.categories, do: id) |> Enum.sort()

  # The current date (and time, where the category keeps one).
  defp stamp_date(db, _id, _cat_id, nil), do: db

  defp stamp_date(db, id, cat_id, clock) do
    now = now_of(clock)
    # the clock is a `Date` (day only) or carries a time; `match?/2` tests
    # which struct it is
    time = if match?(%Date{}, clock), do: nil, else: NaiveDateTime.to_time(now)
    auto_date(db, id, cat_id, NaiveDateTime.to_date(now), time, nil)
  end

  # A date read from text (R14, R6b), unless the user set one by hand.
  # Relative dates are read once: after an edit the date is only re-read
  # when the date words themselves changed (so "tomorrow" keeps meaning
  # the day it was typed). Removing the date words clears a date they gave.
  #
  # Domain: "Call Bob tomorrow" typed on Monday means Tuesday. If fixing a
  # typo on Wednesday re-read the text, the item would silently move to
  # Thursday. So the old and new texts are both read and only their date
  # *phrases* compared: same phrase, keep the stored date; new phrase, read
  # it; phrase gone, clear the date. A date the user set by hand (When
  # column, ALT-F2) always wins over the text.
  defp date_from_text(db, id, old_item, cat_id, clock) do
    if Database.date_explicit?(db, id, cat_id) do
      db
    else
      rule = db.categories[cat_id].date_rule
      opts = Context.parser_opts(clock, db.date_settings)
      read = &read_date(rule, &1, now_of(clock), opts)
      old = if old_item, do: read.(old_item), else: :none

      # Matching on a tuple of both readings compares them in one `case`.
      # `phrase` appears twice in the first pattern, so it only matches when
      # both are equal: a repeated variable in a pattern must bind the same value.
      case {old, read.(db.items[id])} do
        {{:ok, _, _, _, phrase}, {:ok, _, _, _, phrase}} -> db
        {_, {:ok, date, time, recurrence, _}} -> auto_date(db, id, cat_id, date, time, recurrence)
        {{:ok, _, _, _, _}, :none} -> auto_date(db, id, cat_id, nil, nil, nil)
        {:none, :none} -> db
      end
    end
  end

  # The date in the texts the rule reads, the first that has one; the
  # first date, or with Which one the nth (no recurrence then).
  defp read_date(rule, item, now, opts) do
    # `find_value` returns the first non-nil result of the function, or the
    # default (`:none`) when every element gives nil.
    Enum.find_value(DateRule.sources(rule), :none, fn source ->
      text = if source == :item, do: item.text, else: item.note

      case nth_date(text, rule.which, now, opts) do
        :none -> nil
        found -> found
      end
    end)
  end

  defp nth_date(text, 1, now, opts), do: DateParser.extract_recurring(text, now, opts)

  defp nth_date(text, n, now, opts) do
    case Enum.at(DateParser.extract_all(text, now, opts), n - 1) do
      {date, time, phrase} -> {:ok, date, time, nil, phrase}
      nil -> :none
    end
  end

  # A date the program gives (not the user): When keeps a time and a
  # recurrence, Entry and Done the day, other date categories day and time.
  defp auto_date(db, id, cat_id, date, time, recurrence) do
    case Database.date_field(db, cat_id) do
      :when ->
        Database.update_item(
          db,
          id,
          # `date && time`: nil when there is no date, else the time
          # (`&&` returns its left side if that is nil or false)
          &%{&1 | when: date, when_time: date && time, recurrence: date && recurrence}
        )

      nil ->
        Database.put_item_date(db, id, cat_id, date, time, false)

      # `field` is an atom naming the item's field (:entry or :done);
      # `Map.put/3` sets a key chosen at runtime, which `%{s | k: v}` can't
      field ->
        Database.update_item(db, id, &Map.put(&1, field, date))
    end
  end

  # Items that joined a category: dates set "when item is assigned".
  defp assigned_dates(db, before, id, clock) do
    # `MapSet` is the set type (in the standard library, like Map)
    joined? =
      Map.has_key?(before.items, id) == false or
        not MapSet.subset?(
          Database.explicit_categories(db, id),
          Database.explicit_categories(before, id)
        )

    if joined? do
      db
      |> date_categories()
      |> Enum.filter(&DateRule.stamps?(db.categories[&1].date_rule, [:assigned]))
      |> Enum.reduce(db, &stamp_date(&2, id, &1, clock))
    else
      db
    end
  end

  # F4 (DONE) and ALT-F2 (WHEN) also set the date of every other date
  # category whose rule says so (R6b): the current date and time for the
  # Done key, the When date for the When key. Set by the user, by hand.
  @doc false
  def key_dates(db, id, key, clock) do
    own = if key == :done_key, do: db.special.done, else: db.special.when

    {date, time} =
      if key == :done_key,
        do:
          {date_of(clock),
           if(match?(%Date{}, clock), do: nil, else: NaiveDateTime.to_time(now_of(clock)))},
        else: {db.items[id].when, db.items[id].when_time}

    db
    |> date_categories()
    |> Enum.filter(&(&1 != own and Map.fetch!(db.categories[&1].date_rule, key)))
    |> Enum.reduce(db, &put_date(&2, id, &1, date, time))
  end

  @doc false
  def date_of(clock), do: Context.today(clock)
  @doc false
  def now_of(clock), do: Context.now(clock)

  @doc false
  def direct_items(db, cat_id),
    do: for(item <- Database.items(db), Database.explicit?(db, item.id, cat_id), do: item.id)

  # A date and time set by hand (typed, or from a datebook slot); When also
  # takes the recurrence typed with it.
  @doc false
  def put_date_time(db, item_id, cat_id, date, time, rule) do
    db = put_date(db, item_id, cat_id, date, time)

    if Database.date_field(db, cat_id) == :when,
      do: Database.update_item(db, item_id, &%{&1 | when_time: time, recurrence: rule}),
      else: db
  end

  # Sets or clears an item's date in a date category; a time is kept only
  # by date categories the user made (When's is set by the caller).
  # A When date set or cleared by the user: set is explicit and overrides
  # the text; cleared hands the When date back to the text (R14).
  @doc false
  def put_date(db, item_id, cat_id, date, time \\ nil) do
    case Database.date_field(db, cat_id) do
      :when ->
        Database.update_item(
          db,
          item_id,
          &%{&1 | when: date, when_time: nil, when_explicit: date != nil, recurrence: nil}
        )

      nil ->
        Database.put_item_date(db, item_id, cat_id, date, time, true)

      field ->
        Database.update_item(db, item_id, &Map.put(&1, field, date))
    end
  end

  # --- conditions and actions after a change (R15, R15b) ------------------------

  # After a change to an item: its conditions are checked again, then the
  # actions of every category it has newly joined (compared with `before`)
  # run, once (User's Guide 18-7, 21-15).
  #
  # Domain: every user action that touches an item ends here, so this is
  # where Agenda's "rules" happen. The order matters: (1) date categories
  # that stamp "when item is assigned" get today's date, (2) assignment
  # conditions (R15) may add or drop memberships, (3) the categories the
  # item has *newly* joined run their actions (R15b). Comparing with
  # `before`, instead of keeping a flag per item, is what makes actions run
  # once: staying in a category is not joining it again.
  @doc false
  def settle(db, before, item_id, clock) do
    db
    |> assigned_dates(before, item_id, clock)
    |> Assign.apply_conditions(item_id, clock)
    |> run_actions(before, item_id, clock, map_size(db.categories) + 2, nil)
  end

  # Actions can trigger further actions, so this recurses; `rounds` counts
  # down from more than the number of categories, so a cycle of actions
  # (A assigns B, B assigns A) still ends. The `0` clause stops it.
  @doc false
  def run_actions(db, _before, _item_id, _clock, 0, _only), do: db

  def run_actions(db, before, item_id, clock, rounds, only) do
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

      # Domain: an action can assign the item to a category that has actions
      # of its own (Sales assigns Receivables, which sets a date …), so the
      # next round runs for what *this* round joined: `db` (before these
      # actions) becomes the next round's `before`.
      after_actions = run_actions(after_actions, db, item_id, clock, rounds - 1, only)

      # Special actions (mark done, discard) come last, after all the
      # ordinary ones, so a discarded item still got its other actions'
      # effects first and nothing runs on an item that is gone (R15b).

      joined
      |> Enum.map(&db.categories[&1].special)
      |> Enum.reject(&is_nil/1)
      |> Enum.reduce(after_actions, &apply_special(&2, item_id, &1, clock))
    end
  end

  # Categories with actions the item belongs to now but not before,
  # children before their parents. Membership includes ancestors, so
  # joining Sales/Europe also joins Sales: the parent's actions run too,
  # after the child's (R15b, "children's first").
  defp joined_with_actions(db, before, item_id) do
    was_there = Map.has_key?(before.items, item_id)

    db.categories
    |> Map.values()
    |> Enum.filter(fn cat ->
      (cat.actions != [] or cat.special != nil) and Database.member?(db, item_id, cat.id) and
        not (was_there and Map.has_key?(before.categories, cat.id) and
               Database.member?(before, item_id, cat.id))
    end)
    # Sorting by a tuple sorts by its first element, then the second: deepest
    # first (children before parents), ties by id. Tuples compare element-wise.
    |> Enum.sort_by(&{-Database.depth(db, &1.id), &1.id})
    |> Enum.map(& &1.id)
  end

  # `is_map_key/2` is one of the few map checks allowed in a guard: an
  # earlier action may have discarded the item, and then nothing applies.
  defp apply_action(db, item_id, _action, _clock) when not is_map_key(db.items, item_id),
    do: db

  defp apply_action(db, item_id, {target, action}, clock) do
    cond do
      not Map.has_key?(db.categories, target) ->
        db

      action == :remove or action == :clear ->
        if Database.date_category?(db, target),
          do: put_date(db, item_id, target, nil),
          else: Assign.unassign(db, item_id, target)

      # Domain: a set action's value must fit its target, a date phrase for
      # a date category and a number for a numeric one; a hand-made JSON
      # file can hold one that does not, which is left alone (code review
      # 2026-10-26: it crashed the first time an item joined)
      Database.date_category?(db, target) ->
        case action do
          {:set, text} when is_binary(text) ->
            case action_date(db, text, clock) do
              {:ok, date} -> put_date(db, item_id, target, date)
              :error -> db
            end

          _ ->
            db
        end

      db.categories[target].kind == :numeric ->
        case action do
          {:set, number} when is_number(number) ->
            db |> user_assign(item_id, target) |> Database.put_number(item_id, target, number)

          _ ->
            db
        end

      true ->
        db
    end
  end

  # The date of a date action, read when it runs; without a clock (the core
  # never reads one) only an ISO date can be read.
  defp action_date(_db, text, nil) do
    case Date.from_iso8601(text) do
      {:ok, date} -> {:ok, date}
      _ -> :error
    end
  end

  defp action_date(db, text, clock),
    do:
      DateParser.parse(text, date_of(clock), Context.stored_parser_opts(clock, db.date_settings))

  defp apply_special(db, item_id, _special, _clock) when not is_map_key(db.items, item_id),
    do: db

  defp apply_special(db, item_id, :done, clock), do: Items.mark_done(db, item_id, clock)
  # into the trash, as Agenda's (User's Guide J-14: "You can recover the
  # item from the trash")
  defp apply_special(db, item_id, :discard, clock),
    do: Agendum.Core.Facade.Trash.discard_items(db, [item_id], clock)

  # Only standard categories have negative links (R9).
  @doc false
  def drop_excludes(db, cat_id) do
    Enum.reduce(db.categories[cat_id].excludes, db, fn other, db ->
      db
      |> Database.update_category(other, &%{&1 | excludes: List.delete(&1.excludes, cat_id)})
      |> Database.update_category(cat_id, &%{&1 | excludes: List.delete(&1.excludes, other)})
    end)
  end
end
