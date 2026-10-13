defmodule Agenda.Core.Facade.Dates do
  @moduledoc """
  Dates (R6, R14, R41): how date categories get dates and how the file
  reads and shows them, dates set by hand and with the When key, reading a
  typed date, and converting a category to a date category.

  Called through `Agenda.Core`.
  """

  alias Agenda.Core.{Context, Database, DateParser, DateRule}
  alias Agenda.Core.Facade.{Assignments, Changes}

  @typep db :: Agenda.Core.db()
  @typep id :: Agenda.Core.id()
  @typep clock :: Agenda.Core.clock()

  @doc """
  Turns reading When dates from text off, or back on from the item text
  (R14; Utilities Dating): When's Assign item date becomes Never or From
  the item text.
  """
  @spec toggle_auto_date(db) :: db
  def toggle_auto_date(db) do
    rule = db.categories[db.special.when].date_rule
    assign = if rule.assign == :never, do: :item_text, else: :never
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
  def set_date_rule(db, cat_id, %DateRule{} = rule) do
    if Database.date_category?(db, cat_id),
      do: {:ok, Database.update_category(db, cat_id, &%{&1 | date_rule: rule})},
      else: {:error, :not_a_date_category}
  end

  @doc "Sets how the file displays dates and times (R41)."
  @spec set_date_format(db, Agenda.Core.DateFormat.t()) :: db
  def set_date_format(db, %Agenda.Core.DateFormat{} = format), do: %{db | date_format: format}

  @doc """
  Sets how the file reads dates (R14e). Dates already read keep their
  values; relative dates in filters and conditions are read anew.
  """
  @spec set_date_settings(db, Agenda.Core.DateSettings.t()) :: db
  def set_date_settings(db, %Agenda.Core.DateSettings{} = settings),
    do: %{db | date_settings: settings}

  @doc """
  ALT-F2 (WHEN): sets the When date from typed text, and the same date in
  every date category set from the When key (R6b).
  """
  @spec when_key(db, id, String.t(), clock) :: {:ok, db} | {:error, :invalid_date}
  def when_key(db, item_id, text, clock) do
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
