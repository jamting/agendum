# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Facade.Rules do
  @moduledoc """
  The rules that assign items without the user (R13, R15, R16): actions run
  when an item joins a category, text matching settings and the questions
  of suggested assignments, assignment conditions, Utilities Execute and
  Recalc.

  Called through `Agendum.Core`.
  """

  alias Agendum.Core.{Assign, Context, Database, DateParser, NumberFormat, RangeFilter}
  alias Agendum.Core.Facade.Changes

  @typep db :: Agendum.Core.db()
  @typep id :: Agendum.Core.id()
  @typep clock :: Agendum.Core.clock()

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
    # `opts[:root] || default`: the usual way to default a keyword option
    root = opts[:root] || db.main_id
    only = if root == db.main_id, do: nil, else: MapSet.new(Database.subtree(db, root))
    clock = opts[:clock]
    rounds = map_size(db.categories) + 2

    Enum.reduce(item_ids, db, fn id, db ->
      if Map.has_key?(db.items, id) do
        # as if the item had just arrived, every membership counts as new.
        # Domain: actions normally run only for categories an item *joins*
        # (see `Changes.settle/4`). Execute with "old & new" (R15e) must
        # also run them for memberships the item already had, e.g. after
        # adding an action to a category full of items. Rather than a
        # second code path, it hands `run_actions` a `before` in which the
        # item doesn't exist, so every membership looks newly joined.
        before = if opts[:old_assignments], do: %{db | items: Map.delete(db.items, id)}, else: db

        db
        |> Assign.auto_assign(id, [], only)
        |> Assign.apply_conditions(id, clock, only)
        |> Changes.run_actions(before, id, clock, rounds, only)
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
  # A bodiless head declares the default argument once for all clauses
  # below (defaults may not be repeated on each clause).
  def set_action(db, cat_id, target, action, clock \\ nil)

  # `cat_id` twice in one head matches only when both arguments are equal:
  # a category can't act on itself.
  def set_action(_db, cat_id, cat_id, _action, _clock), do: {:error, :self}

  def set_action(db, cat_id, target, action, clock) do
    kind =
      cond do
        Database.date_category?(db, target) -> :date
        db.categories[target].kind == :numeric -> :numeric
        true -> :standard
      end

    with {:ok, action} <- check_action(kind, action, db.date_settings, clock) do
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

  # One clause per valid (kind, action) pair, then a catch-all for the
  # rest: a validation table written as function heads.
  defp check_action(:standard, action, _settings, _clock) when action in [:assign, :remove],
    do: {:ok, action}

  defp check_action(kind, :clear, _settings, _clock) when kind in [:date, :numeric],
    do: {:ok, :clear}

  defp check_action(:date, {:set, text}, settings, clock) do
    # with no clock, any fixed day will do: only whether it parses matters
    # here (`~D[...]` is a `Date` literal)
    today = if clock, do: Changes.date_of(clock), else: ~D[2000-01-01]

    # kept and read when the action runs, so read as a kept phrase
    case DateParser.parse(text, today, Context.stored_parser_opts(clock, settings)) do
      {:ok, _} -> {:ok, {:set, String.trim(text)}}
      :error -> {:error, :invalid_date}
    end
  end

  defp check_action(:numeric, {:set, text}, _settings, clock) do
    case NumberFormat.parse(to_string(text), Context.number_opts(clock)) do
      {:ok, number} -> {:ok, {:set, number}}
      :error -> {:error, :not_a_number}
    end
  end

  defp check_action(_kind, _action, _settings, _clock), do: {:error, :not_allowed}

  @doc "Removes a category's action on `target` (including a category link)."
  @spec remove_action(db, id, id) :: db
  def remove_action(db, cat_id, target) do
    Database.update_category(db, cat_id, fn cat ->
      %{
        cat
        | # `actions` is a list of `{target, action}` tuples; the `List.key*`
          # functions treat such a list as a small ordered map, keyed by the
          # tuple element at the index given (0 here).
          actions: List.keydelete(cat.actions, target, 0),
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

  # --- suggested assignments (R16) --------------------------------------------

  @doc """
  Whether text matches are made at once (`:never` asked, the default) or
  suggested and confirmed with Utilities Questions (`:always`; File
  Properties ▸ Confirm assignments, User's Guide 19-9).
  """
  @spec set_confirm_assignments(db, :never | :always | :sometimes) :: db
  def set_confirm_assignments(db, mode) when mode in [:never, :always, :sometimes],
    do: %{db | confirm_assignments: mode}

  @doc """
  Sets how the file matches item text to categories (R16a; Auto-assign
  settings). Like Agenda, existing assignments stay until items change or
  are re-checked (Utilities Execute).
  """
  @spec set_match_settings(db, Agendum.Core.TextMatch.t()) :: db
  def set_match_settings(db, %Agendum.Core.TextMatch{} = settings),
    do: %{db | match_settings: settings}

  # A module attribute used as a constant: its value is fixed at compile
  # time and pasted in wherever `@match_overrides` appears.
  @match_overrides [:enabled, :match_on, :strength, :confirm, :ignore_suffixes, :ignore_accents]

  @doc """
  Sets one text matching setting for a category instead of the file's, or
  with `:global` takes the file's again (R16b; the category's Advanced
  settings). Ignore text enclosed by is the file's only.
  """
  @spec set_match_override(db, id, atom, term) ::
          {:ok, db} | {:error, :not_standard | :not_allowed}
  def set_match_override(db, cat_id, field, value) do
    cond do
      db.categories[cat_id].kind != :standard ->
        {:error, :not_standard}

      field not in @match_overrides ->
        {:error, :not_allowed}

      value == :global ->
        {:ok,
         Database.update_category(
           db,
           cat_id,
           &%{&1 | match_overrides: Map.delete(&1.match_overrides, field)}
         )}

      true ->
        {:ok,
         Database.update_category(
           db,
           cat_id,
           &%{&1 | match_overrides: Map.put(&1.match_overrides, field, value)}
         )}
    end
  end

  @doc "A category's text matching settings: the file's with its own (R16b)."
  @spec match_settings(db, id) :: Agendum.Core.TextMatch.t()
  defdelegate match_settings(db, cat_id), to: Assign

  @doc "A category's Confirm assignments: its own or the file's (R16b)."
  @spec confirm_mode(db, id) :: :never | :always | :sometimes
  defdelegate confirm_mode(db, cat_id), to: Assign

  @doc "The items with suggested assignments, in item order, each with its categories."
  @spec questions(db) :: [{id, [id]}]
  def questions(db),
    do: for(id <- db.item_order, cats = db.suggestions[id], cats not in [nil, []], do: {id, cats})

  @doc """
  Answers an item's question (Utilities Questions, User's Guide 19-12): the
  chosen categories are assigned explicitly, the rest dropped.
  """
  @spec answer_question(db, id, [id], clock | nil) :: db
  def answer_question(db, item_id, cat_ids, clock \\ nil) do
    answered = %{db | suggestions: Map.delete(db.suggestions, item_id)}

    cat_ids
    |> Enum.filter(&Map.has_key?(db.categories, &1))
    |> Enum.reduce(answered, &Changes.user_assign(&2, item_id, &1))
    |> Changes.settle(answered, item_id, clock)
  end

  @doc """
  Re-runs automatic assignment for every item, e.g. after adding a category
  (Agenda's F9 RECALC behaviour), and gives a When date to items whose text
  has a date but that have none yet.
  """
  @spec reassign_all(db, clock) :: db
  def reassign_all(db, today) do
    # The accumulator is named `before`: the database as it was before this
    # item's turn, which `settle/4` compares with to find new memberships.
    Enum.reduce(db.item_order, db, fn id, before ->
      db = Assign.auto_assign(before, id, [])
      db = if db.items[id].when, do: db, else: Changes.item_dates(db, id, nil, [], today)
      Changes.settle(db, before, id, today)
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

  @doc """
  What a category has that Copy and Clear Conditions/Actions act on (R15f):
  `:both`, `:conditions`, `:actions`, or nil. Its assignment conditions
  count, and its assignment actions (links to other categories, and the
  date or number actions); its Also match words and special action do not
  (Agenda 2.0 copied nothing from a category with Also match alone,
  checked 2026-10-26).
  """
  @spec conditions_and_actions(db, id) :: :both | :conditions | :actions | nil
  def conditions_and_actions(db, cat_id) do
    cat = db.categories[cat_id]
    actions? = cat.actions != [] or cat.also_assign != []

    case {cat.conditions != [], actions?} do
      {true, true} -> :both
      {true, false} -> :conditions
      {false, true} -> :actions
      {false, false} -> nil
    end
  end

  @doc """
  Copy Conditions/Actions (R15f; Agenda's ALT-F9 CPY C/A, Help "Copy
  Conditions/Actions"): the source's conditions, actions or both take the
  place of the target's; what the target keeps of the other is left alone,
  and the source does not change. A condition or action naming the target
  itself is not copied to it. Like a new condition, the copy reaches the
  items already in the file when executed (R15e).
  """
  @spec copy_conditions_actions(db, id, id, :both | :conditions | :actions) ::
          {:ok, db} | {:error, :self}
  def copy_conditions_actions(_db, cat_id, cat_id, _what), do: {:error, :self}

  def copy_conditions_actions(db, from, to, what) when what in [:both, :conditions, :actions] do
    source = db.categories[from]

    copy = fn target ->
      target
      |> then(fn t ->
        if what in [:both, :conditions],
          do: %{t | conditions: Enum.reject(source.conditions, &(elem(&1, 0) == to))},
          else: t
      end)
      |> then(fn t ->
        if what in [:both, :actions],
          do: %{
            t
            | actions: Enum.reject(source.actions, &(elem(&1, 0) == to)),
              also_assign: List.delete(source.also_assign, to)
          },
          else: t
      end)
    end

    {:ok, Database.update_category(db, to, copy)}
  end

  @doc """
  Clear Conditions/Actions (R15f; Agenda's ALT-F8 CLR C/A): the category's
  conditions, actions or both go. CTRL-Z brings them back (Agenda could
  not).
  """
  @spec clear_conditions_actions(db, id, :both | :conditions | :actions) :: {:ok, db}
  def clear_conditions_actions(db, cat_id, what) when what in [:both, :conditions, :actions] do
    clear = fn cat ->
      cat
      |> then(&if what in [:both, :conditions], do: %{&1 | conditions: []}, else: &1)
      |> then(&if what in [:both, :actions], do: %{&1 | actions: [], also_assign: []}, else: &1)
    end

    {:ok, Database.update_category(db, cat_id, clear)}
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
  `Agendum.Core.TextCondition`). New conditions reach existing items when
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
    do: Enum.reduce(db.item_order, db, fn id, db -> Changes.settle(db, db, id, clock) end)

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
end
