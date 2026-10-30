# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Facade.Dates do
  @moduledoc """
  Dates (R6, R14, R41): how date categories get dates and how the file
  reads and shows them, dates set by hand and with the When key, reading a
  typed date, and converting a category to a date category.

  Called through `Agendum.Core`.
  """

  alias Agendum.Core.{Context, Database, DateParser, DateRule}
  alias Agendum.Core.Facade.{Assignments, Changes}

  @typep db :: Agendum.Core.db()
  @typep id :: Agendum.Core.id()
  @typep clock :: Agendum.Core.clock()

  @doc """
  Turns reading When dates from text off, or back on from the item text
  (R14; Utilities Dating): When's Assign item date becomes Never or From
  the item text.
  """
  @spec toggle_auto_date(db) :: db
  def toggle_auto_date(db) do
    rule = db.categories[db.special.when].date_rule
    assign = if rule.assign == :never, do: :item_text, else: :never
    # `=` is a match, not just assignment: this asserts the result is
    # `{:ok, db}` and raises a MatchError otherwise. Fine here, since When
    # is always a date category, so an error would be a bug ("let it crash").
    {:ok, db} = set_date_rule(db, db.special.when, %{rule | assign: assign})
    db
  end

  @doc "Whether When dates are read from text at all (Utilities Dating)."
  @spec auto_dating?(db) :: boolean
  def auto_dating?(db), do: db.categories[db.special.when].date_rule.assign != :never

  @doc """
  Sets how a date category gets dates (R6b; Advanced settings). Items keep
  the dates they have.
  """
  @spec set_date_rule(db, id, DateRule.t()) :: {:ok, db} | {:error, :not_a_date_category}
  # `%DateRule{} = rule` accepts only a `DateRule` struct. A struct is a map
  # with a fixed set of keys and a `__struct__` field naming its module.
  def set_date_rule(db, cat_id, %DateRule{} = rule) do
    if Database.date_category?(db, cat_id),
      do: {:ok, Database.update_category(db, cat_id, &%{&1 | date_rule: rule})},
      else: {:error, :not_a_date_category}
  end

  @doc "Sets how the file displays dates and times (R41)."
  @spec set_date_format(db, Agendum.Core.DateFormat.t()) :: db
  def set_date_format(db, %Agendum.Core.DateFormat{} = format), do: %{db | date_format: format}

  @doc """
  Sets how the file reads dates (R14e). Dates already read keep their
  values; relative dates in filters and conditions are read anew.
  """
  @spec set_date_settings(db, Agendum.Core.DateSettings.t()) :: db
  def set_date_settings(db, %Agendum.Core.DateSettings{} = settings),
    do: %{db | date_settings: settings}

  @doc """
  The text ALT-F2 and the When column offer for editing an item's When
  date (R14a): a recurring one's rule, base date and time in the reader's
  main language, `every Monday (starting 2026-10-19) at 9:00am`, as Agenda
  offers `every Mon (strtng 10/19/2026)`, so accepting it keeps the rule;
  else (or when that language has no words for the rule) the date, ISO
  8601, "" without one.
  """
  @spec when_text(db, id, clock) :: String.t()
  def when_text(db, item_id, clock) do
    item = db.items[item_id]

    # `&&` gives its right side only when the left is truthy (not nil or
    # false), so `phrase` is nil for an item without a rule or a date
    phrase =
      item.recurrence && item.when &&
        DateParser.format_recurring(
          item.recurrence,
          item.when,
          item.when_time,
          hd(Context.languages(clock))
        )

    phrase || DateParser.format(item.when)
  end

  @doc """
  ALT-F2 (WHEN): sets the When date from typed text, and the same date in
  every date category set from the When key (R6b).
  """
  @spec when_key(db, id, String.t(), clock) :: {:ok, db} | {:error, :invalid_date}
  def when_key(db, item_id, text, clock) do
    # A `with` without `else` returns the first non-matching value as it is,
    # so an `{:error, :invalid_date}` passes straight through to the caller.
    with {:ok, db, :date} <- Assignments.assign_by_name(db, item_id, db.special.when, text, clock) do
      {:ok, Changes.key_dates(db, item_id, :when_key, clock)}
    end
  end

  @doc """
  Sets or clears the date for a date category, then re-checks conditions
  (date conditions, R15a, read against `clock`).
  """
  @spec set_date(db, id, id, Date.t() | nil, clock | nil) :: db
  def set_date(db, item_id, cat_id, date, clock \\ nil) do
    # Raising is for programmer errors (the UI only offers date categories
    # here); expected failures return `{:error, reason}` instead.
    unless Database.date_category?(db, cat_id), do: raise(ArgumentError, "not a date category")
    db |> Changes.put_date(item_id, cat_id, date) |> Changes.settle(db, item_id, clock)
  end

  @doc """
  Sets the date and time of a date category, as typed in its column (set
  by hand), then re-checks conditions; a nil date clears it.
  """
  @spec set_date_time(db, id, id, Date.t() | nil, Time.t() | nil, clock | nil) :: db
  def set_date_time(db, item_id, cat_id, date, time, clock \\ nil) do
    unless Database.date_category?(db, cat_id), do: raise(ArgumentError, "not a date category")

    db
    |> Changes.put_date_time(item_id, cat_id, date, time, nil)
    |> Changes.settle(db, item_id, clock)
  end

  @doc """
  A date and/or time typed on its own ("friday 3pm", "2026-12-24", "15:30"),
  read as in a date column with the file's date settings and the reader's
  languages and input format: `{:ok, date, time or nil}`. A time alone is
  today's (R14b). Used by the pop-up calendar (R46).
  """
  @spec read_when(db, String.t(), clock) :: {:ok, Date.t(), Time.t() | nil} | :error
  def read_when(db, text, clock),
    do:
      DateParser.parse_when(
        text,
        Changes.now_of(clock),
        Context.parser_opts(clock, db.date_settings)
      )

  @doc """
  What converting a standard category to a date category would do to its
  children (User's Guide 7-3 to 7-4): they are removed, and their items get
  the child's name as their date, read against `clock`; the children in
  `non_dates` are not dates, so their items get none, nor do the
  `assigned` items assigned to the category itself.
  """
  @spec date_conversion(db, id, clock) :: %{
          children: non_neg_integer,
          non_dates: [String.t()],
          assigned: non_neg_integer
        }
  def date_conversion(db, cat_id, clock) do
    children = Enum.map(db.categories[cat_id].children, &db.categories[&1])

    %{
      children: length(children),
      non_dates: for(c <- children, child_date(db, c.name, clock) == :error, do: c.name),
      assigned: db |> Changes.direct_items(cat_id) |> length()
    }
  end

  @doc """
  Converts a standard category to a date category (R6a; User's Guide 7-3
  to 7-4). Its children become dates (see `date_conversion/3`); a category
  with grandchildren cannot be converted. Like Agenda, a date category
  cannot be changed back.
  """
  @spec make_date(db, id, clock) :: {:ok, db} | {:error, :not_standard | :protected | :too_deep}
  def make_date(db, cat_id, clock) do
    cat = db.categories[cat_id]

    cond do
      cat.kind != :standard ->
        {:error, :not_standard}

      Database.protected?(db, cat_id) ->
        {:error, :protected}

      Enum.any?(cat.children, &(db.categories[&1].children != [])) ->
        {:error, :too_deep}

      true ->
        # Two generators nest like two loops. A generator with a pattern
        # skips what doesn't match: wrapping the parse in a one-element
        # list makes `{:ok, date, time} <- [...]` a filter that also binds.
        dates =
          for child <- cat.children,
              {:ok, date, time} <- [child_date(db, db.categories[child].name, clock)],
              item <- Database.items_in(db, child),
              do: {item.id, date, time}

        db =
          Enum.reduce(cat.children, db, fn child, db ->
            {:ok, db} = Database.delete_category(db, child)
            db
          end)

        db =
          db
          |> unlink_all(cat_id)
          |> Changes.drop_excludes(cat_id)
          |> Database.update_category(
            cat_id,
            &%{&1 | kind: :date, match_name: false, exclusive: false, date_rule: %DateRule{}}
          )

        {:ok,
         Enum.reduce(dates, db, fn {item, date, time}, db ->
           Database.put_item_date(db, item, cat_id, date, time, true)
         end)}
    end
  end

  defp child_date(db, name, clock) do
    DateParser.parse_when(
      name,
      Changes.now_of(clock),
      Context.parser_opts(clock, db.date_settings)
    )
  end

  defp unlink_all(db, cat_id),
    do: Enum.reduce(Changes.direct_items(db, cat_id), db, &Database.unlink(&2, &1, cat_id))
end
