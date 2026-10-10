defmodule Agenda.Core.RangeFilter do
  @moduledoc """
  Date and numeric filters (SPEC R28a; User's Guide 11-5 to 11-12): a
  filter on a date or numeric category can ask for a range, written as the
  filter criterion `{category, {:range, from, to, :inside | :outside}}`.

  For a date category `from` and `to` are date expressions as typed
  ("2026-11-05", "monday", "today"), read again against today's date each
  time, so "monday" to "friday" always means this week. For a numeric
  category they are numbers. Either end may be nil (open). An item without
  a date or number is never in a range. Pure.
  """

  alias Agenda.Core.{Database, DateParser, NumberFormat}

  @type bound :: String.t() | float | nil
  @type term_ :: {:range, bound, bound, :inside | :outside}

  @doc "Whether a category takes ranges (date and numeric categories)."
  @spec range_category?(Database.t(), Database.id()) :: boolean
  def range_category?(db, cat_id),
    do: Database.date_field(db, cat_id) != nil or db.categories[cat_id].kind == :numeric

  @doc """
  Checks and normalizes the settings typed in the filter box: dates must be
  readable (relative ones are kept as typed), numbers become floats.
  """
  @spec build(Database.t(), Database.id(), String.t() | nil, String.t() | nil, atom, Date.t()) ::
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
        case DateParser.parse(text, today) do
          {:ok, _} -> {:ok, text}
          :error -> {:error, :invalid_date}
        end
    end
  end

  @doc "Whether an item's date or number falls in (or outside) the range."
  @spec met?(Database.t(), Database.id(), Database.id(), term_, Date.t() | nil) :: boolean
  def met?(db, item_id, cat_id, {:range, from, to, where}, today) do
    case value(db, item_id, cat_id) do
      nil ->
        false

      value ->
        inside =
          after_start?(value, resolve(from, today)) and before_end?(value, resolve(to, today))

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
    case Database.date_field(db, cat_id) do
      nil -> Database.number(db, item_id, cat_id)
      field -> Map.get(db.items[item_id], field)
    end
  end

  # Date expressions are read against today; without a today only ISO
  # dates can be read.
  defp resolve(nil, _today), do: nil
  defp resolve(number, _today) when is_number(number), do: number

  defp resolve(text, nil) do
    case Date.from_iso8601(text) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp resolve(text, today) do
    case DateParser.parse(text, today) do
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
  @spec entry_value(Database.t(), Database.id(), term_, Date.t() | nil) ::
          {:date, Date.t()} | {:number, float} | nil
  def entry_value(db, cat_id, {:range, from, to, where}, today) do
    from = resolve(from, today)
    to = resolve(to, today)

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

  @doc "The range as the title bar shows it, in the file's formats."
  @spec describe(Database.t(), term_, Date.t() | nil) :: String.t()
  def describe(db, {:range, from, to, where}, today) do
    show = fn
      nil ->
        ""

      number when is_number(number) ->
        decimals = if number == Float.round(number), do: 0, else: 2
        NumberFormat.format(number, %NumberFormat{decimals: decimals, thousands: true})

      text ->
        Agenda.Core.DateFormat.date(resolve(text, today), db.date_format)
    end

    range = show.(from) <> ".." <> show.(to)
    if where == :inside, do: range, else: "not " <> range
  end
end
