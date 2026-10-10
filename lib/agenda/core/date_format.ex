defmodule Agenda.Core.DateFormat do
  @moduledoc """
  How a file displays dates and times (SPEC R41; Agenda's global Display
  format, User's Guide 6-20 to 6-22 and 7-13 to 7-15).

    * `order`: the order and length of day, month and year (Agenda's
      MMDDYY … DDMMMYYYY); the default `:yyyymmdd` with "-" is ISO 8601
    * `separator`: between the numbers of a date; dates with a month name
      ("Nov 13 90") always use spaces
    * `clock`: 24 or 12 (12 shows am/pm: "3:25pm")
    * `day_of_week`: show "Tue" before the date

  Only display: what the user types is read by `Agenda.Core.DateParser`,
  and dates offered for editing stay ISO 8601 (`DateParser.format/1`).
  Pure.
  """

  @type order ::
          :mmddyy
          | :mmddyyyy
          | :ddmmyy
          | :ddmmyyyy
          | :yymmdd
          | :yyyymmdd
          | :yyddmm
          | :yyyyddmm
          | :mmmdd
          | :mmmddyy
          | :mmmddyyyy
          | :ddmmm
          | :ddmmmyy
          | :ddmmmyyyy

  @type t :: %__MODULE__{
          order: order,
          separator: String.t(),
          clock: 12 | 24,
          day_of_week: boolean
        }
  defstruct order: :yyyymmdd, separator: "-", clock: 24, day_of_week: false

  @orders [
    :yyyymmdd,
    :yymmdd,
    :yyyyddmm,
    :yyddmm,
    :mmddyy,
    :mmddyyyy,
    :ddmmyy,
    :ddmmyyyy,
    :mmmdd,
    :mmmddyy,
    :mmmddyyyy,
    :ddmmm,
    :ddmmmyy,
    :ddmmmyyyy
  ]
  @separators ["-", ".", ",", " ", ":", "/"]
  @months ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
  @days ~w(Mon Tue Wed Thu Fri Sat Sun)

  @doc "Every date order, in the order the settings offer them."
  @spec orders() :: [order]
  def orders, do: @orders

  @doc "Every date separator."
  @spec separators() :: [String.t()]
  def separators, do: @separators

  @doc ~S|An order's name as Agenda wrote it ("MMDDYY").|
  @spec label(order) :: String.t()
  def label(order), do: order |> Atom.to_string() |> String.upcase()

  @doc "A date as displayed."
  @spec date(Date.t() | nil, t) :: String.t()
  def date(nil, _format), do: ""

  def date(%Date{} = date, %__MODULE__{} = f) do
    text = date_text(date, f)
    if f.day_of_week, do: Enum.at(@days, Date.day_of_week(date) - 1) <> " " <> text, else: text
  end

  @doc "A time of day as displayed."
  @spec time(Time.t(), t) :: String.t()
  def time(%Time{} = t, %__MODULE__{clock: 24}), do: t |> Time.to_string() |> String.slice(0, 5)

  def time(%Time{hour: h, minute: m}, %__MODULE__{clock: 12}) do
    hour = if rem(h, 12) == 0, do: 12, else: rem(h, 12)
    "#{hour}:#{pad(m)}" <> if(h < 12, do: "am", else: "pm")
  end

  @doc "A date with an optional time, as date columns show When."
  @spec date_time(Date.t() | nil, Time.t() | nil, t) :: String.t()
  def date_time(nil, _time, _format), do: ""
  def date_time(date, nil, format), do: date(date, format)
  def date_time(date, time, format), do: date(date, format) <> " " <> time(time, format)

  @doc "Agenda's formatted sample: how 13 November 1990 at 3:25 pm looks."
  @spec sample(t) :: String.t()
  def sample(format), do: date_time(~D[1990-11-13], ~T[15:25:00], format)

  @doc "The next (`step` 1) or previous (-1) choice for one setting."
  @spec cycle(t, :order | :separator | :clock | :day_of_week, integer) :: t
  def cycle(f, :order, step), do: %{f | order: next(@orders, f.order, step)}
  def cycle(f, :separator, step), do: %{f | separator: next(@separators, f.separator, step)}
  def cycle(f, :clock, _step), do: %{f | clock: if(f.clock == 24, do: 12, else: 24)}
  def cycle(f, :day_of_week, _step), do: %{f | day_of_week: not f.day_of_week}

  defp next(list, value, step) do
    index = Enum.find_index(list, &(&1 == value)) || 0
    Enum.at(list, Integer.mod(index + step, length(list)))
  end

  # --- dates ---------------------------------------------------------------------

  defp date_text(date, f) do
    yy = pad(rem(date.year, 100))
    yyyy = Integer.to_string(date.year)
    mm = pad(date.month)
    dd = pad(date.day)
    mmm = Enum.at(@months, date.month - 1)

    {parts, separator} =
      case f.order do
        :mmddyy -> {[mm, dd, yy], f.separator}
        :mmddyyyy -> {[mm, dd, yyyy], f.separator}
        :ddmmyy -> {[dd, mm, yy], f.separator}
        :ddmmyyyy -> {[dd, mm, yyyy], f.separator}
        :yymmdd -> {[yy, mm, dd], f.separator}
        :yyyymmdd -> {[yyyy, mm, dd], f.separator}
        :yyddmm -> {[yy, dd, mm], f.separator}
        :yyyyddmm -> {[yyyy, dd, mm], f.separator}
        :mmmdd -> {[mmm, dd], " "}
        :mmmddyy -> {[mmm, dd, yy], " "}
        :mmmddyyyy -> {[mmm, dd, yyyy], " "}
        :ddmmm -> {[dd, mmm], " "}
        :ddmmmyy -> {[dd, mmm, yy], " "}
        :ddmmmyyyy -> {[dd, mmm, yyyy], " "}
      end

    Enum.join(parts, separator)
  end

  defp pad(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")
end
