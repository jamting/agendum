defmodule Agenda.Core.RangeFilter do
  @moduledoc """
  Date and numeric filters (SPEC R28a; User's Guide 11-5 to 11-12): a
  filter on a date or numeric category can ask for a range, written as the
  filter criterion `{category, {:range, from, to, :inside | :outside}}`.

  For a date category `from` and `to` are date expressions as typed
  ("2026-11-05", "monday", "today"), read again against today's date each
  time, so "monday" to "friday" always means this week, in the date
  languages of the given clock (`Agenda.Core.Context`); a "$" before one
  ("$monday") reads it once, when the range is set, and keeps that date
  (R14f). For a numeric
  category they are numbers. Either end may be nil (open). An item without
  a date or number is never in a range. Pure.
  """

  alias Agenda.Core.{Context, Database, DateParser, NumberFormat}

  @type bound :: String.t() | float | nil
  @type term_ :: {:range, bound, bound, :inside | :outside}

  @doc "Whether a category takes ranges (date and numeric categories)."
  @spec range_category?(Database.t(), Database.id()) :: boolean
  def range_category?(db, cat_id),
    do: db.categories[cat_id].kind in [:date, :numeric]

  @doc """
  Checks and normalizes the settings typed in the filter box: dates must be
  readable (relative ones are kept as typed), numbers become floats.
  """
  @spec build(
          Database.t(),
          Database.id(),
          String.t() | nil,
          String.t() | nil,
          atom,
          Context.clock()
        ) ::
          {:ok, term_} | {:error, :invalid_date | :not_a_number}
  def build(db, cat_id, from, to, where, today) do
    with {:ok, from} <- bound(db, cat_id, from, today),
         {:ok, to} <- bound(db, cat_id, to, today) do
      {:ok, {:range, from, to, where}}
    end
  end

  defp bound(_db, _cat_id, nil, _today), do: {:ok, nil}

  defp bound(db, cat_id, text, today) do
    text = String.trim(text)

    cond do
      text == "" ->
        {:ok, nil}

      db.categories[cat_id].kind == :numeric ->
        with :error <- NumberFormat.parse(text), do: {:error, :not_a_number}

      true ->
        date_bound(db, text, today)
    end
  end

  # "$monday" is read now and kept as that date (R14f); other words are
  # kept to be read again each day.
  defp date_bound(db, text, today) do
    {fixed?, words} =
      case text do
        "$" <> rest -> {true, String.trim(rest)}
        _ -> {false, text}
      end

    case DateParser.parse(
           words,
           Context.today(today),
           Context.parser_opts(today, db.date_settings)
         ) do
      {:ok, date} -> {:ok, if(fixed?, do: Date.to_iso8601(date), else: text)}
      :error -> {:error, :invalid_date}
    end
  end

  @doc "Whether an item's date or number falls in (or outside) the range."
  @spec met?(Database.t(), Database.id(), Database.id(), term_, Context.clock() | nil) :: boolean
  def met?(db, item_id, cat_id, {:range, from, to, where}, today) do
    case value(db, item_id, cat_id) do
      nil ->
        false

      value ->
        inside =
          after_start?(value, resolve(db, from, today)) and
            before_end?(value, resolve(db, to, today))

        if where == :inside, do: inside, else: not inside
    end
  end

  defp after_start?(_value, nil), do: true
  defp after_start?(value, start), do: compare(value, start) != :lt

  defp before_end?(_value, nil), do: true
  defp before_end?(value, stop), do: compare(value, stop) != :gt

  defp compare(%Date{} = a, %Date{} = b), do: Date.compare(a, b)
  defp compare(a, b) when a < b, do: :lt
  defp compare(a, b) when a > b, do: :gt
  defp compare(_a, _b), do: :eq

  # An item's date (the day only, for When) or number in the category.
  defp value(db, item_id, cat_id) do
    if Database.date_category?(db, cat_id),
      do: Database.item_date(db, item_id, cat_id),
      else: Database.number(db, item_id, cat_id)
  end

  # Date expressions are read against today; without a today only ISO
  # dates can be read.
  defp resolve(_db, nil, _today), do: nil
  defp resolve(_db, number, _today) when is_number(number), do: number

  defp resolve(_db, text, nil) do
    case Date.from_iso8601(text) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp resolve(db, text, clock) do
    case DateParser.parse(
           text,
           Context.today(clock),
           Context.parser_opts(clock, db.date_settings)
         ) do
      {:ok, date} -> date
      :error -> nil
    end
  end

  @doc """
  The value a new item entered under the filter gets (User's Guide 11-7,
  11-12): the start (or, with only an end, the end) of an inside range;
  for an outside range the day or number just before the start (or just
  after the end). Nil when the range is open at both ends.
  """
  @spec entry_value(Database.t(), Database.id(), term_, Context.clock() | nil) ::
          {:date, Date.t()} | {:number, float} | nil
  def entry_value(db, cat_id, {:range, from, to, where}, today) do
    from = resolve(db, from, today)
    to = resolve(db, to, today)

    value =
      case {where, from, to} do
        {_, nil, nil} -> nil
        {:inside, nil, to} -> to
        {:inside, from, _} -> from
        {:outside, nil, to} -> step(to, 1)
        {:outside, from, _} -> step(from, -1)
      end

    cond do
      value == nil -> nil
      db.categories[cat_id].kind == :numeric -> {:number, value}
      true -> {:date, value}
    end
  end

  defp step(%Date{} = date, days), do: Date.add(date, days)
  defp step(number, n), do: number + n

  @doc """
  A date range moved by `days` and `months` (browsing, R48): each end is
  read against the clock, moved, and kept as a fixed date; an open end
  stays open. With no shift it is unchanged.
  """
  @spec shift(Database.t(), term_, %{days: integer, months: integer}, Context.clock()) :: term_
  def shift(_db, range, %{days: 0, months: 0}, _clock), do: range

  def shift(db, {:range, from, to, where}, shift, clock),
    do: {:range, shift_bound(db, from, shift, clock), shift_bound(db, to, shift, clock), where}

  defp shift_bound(_db, nil, _shift, _clock), do: nil

  defp shift_bound(db, text, %{days: days, months: months}, clock) do
    case resolve(db, text, clock) do
      nil ->
        text

      date ->
        date
        |> Agenda.Core.MonthCalendar.move(:month, months)
        |> Agenda.Core.MonthCalendar.move(:day, days)
        |> Date.to_iso8601()
    end
  end

  @doc "The range as the title bar shows it, in the file's formats."
  @spec describe(Database.t(), term_, Context.clock() | nil) :: String.t()
  def describe(db, {:range, from, to, where}, today) do
    show = fn
      nil ->
        ""

      number when is_number(number) ->
        decimals = if number == Float.round(number), do: 0, else: 2
        NumberFormat.format(number, %NumberFormat{decimals: decimals, thousands: true})

      text ->
        Agenda.Core.DateFormat.date(resolve(db, text, today), db.date_format)
    end

    range = show.(from) <> ".." <> show.(to)
    if where == :inside, do: range, else: "not " <> range
  end
end
