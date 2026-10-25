defmodule Agendum.Core.DateFormat do
  @moduledoc """
  How a file displays dates and times (SPEC R41; Agenda's global Display
  format, User's Guide 6-20 to 6-22 and 7-13 to 7-15).

    * `order`: the order and length of day, month and year (Agenda's
      MMDDYY … DDMMMYYYY); the struct's default `:yyyymmdd` with "-" is
      ISO 8601
    * `separator`: between the numbers of a date; dates with a month name
      ("Nov 13 90") always use spaces
    * `clock`: 24 or 12 (12 shows am/pm: "3:25pm")
    * `day_of_week`: show "Tue" before the date
    * `show` (Display date and/or time): `:date_time`, `:date` (only),
      `:time_date` or `:time` (only)
    * `am_pm` (Show am/pm): with a 12-hour clock, "3:25pm" or "3:25"
    * `time_separator`: ":" ("3:25") or "hm" ("3h25m")

  Besides dates, `order` can be a count (R41a): `:day` ("Day 317"),
  `:day_number` ("317"), `:week` ("Week 46", ISO 8601 weeks),
  `:week_number` ("46"), `:relative` ("Today", "Tomorrow", "nxt Sun",
  "lst Fri" within a week of today, else the global format) or
  `:relative_number` ("1 day", "-2 days"). The relative ones need today's
  date (`today:`); without it they show the global format (`global:`,
  ISO 8601 when that is relative too).

  The file's format is the global default; a date column may have its
  own (`View.Column.date`). A new file starts with Agenda's default,
  `agenda/0` (MMDDYY, "/", 12 hours); the struct's own defaults, ISO 8601
  on a 24-hour clock, are what files from before format 7 show, and the
  fallback where a format is needed but none is given.

  Only display: what the user types is read by `Agendum.Core.DateParser`,
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
          | :day_number
          | :day
          | :week_number
          | :week
          | :relative
          | :relative_number

  @type show :: :date_time | :date | :time_date | :time

  @type t :: %__MODULE__{
          order: order,
          separator: String.t(),
          clock: 12 | 24,
          day_of_week: boolean,
          show: show,
          am_pm: boolean,
          time_separator: String.t()
        }
  defstruct order: :yyyymmdd,
            separator: "-",
            clock: 24,
            day_of_week: false,
            show: :date_time,
            am_pm: true,
            time_separator: ":"

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
    :ddmmmyyyy,
    :day_number,
    :day,
    :week_number,
    :week,
    :relative,
    :relative_number
  ]
  @relative [:relative, :relative_number]
  @shows [:date_time, :date, :time_date, :time]
  @separators ["-", ".", ",", " ", ":", "/"]
  @months ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
  @days ~w(Mon Tue Wed Thu Fri Sat Sun)
  # as Agenda wrote them in relative dates (Lotus Q&A, 1990)
  @relative_days ~w(Mon Tues Wed Thurs Fri Sat Sun)

  @doc """
  Agenda's default, which a new file starts with: "11/13/90 9:10pm"
  (Agenda 2.0's Display Format box on a new file, checked 2026-10-25).
  """
  @spec agenda() :: t
  # A struct literal with some fields named: the fields left out keep the
  # defaults from `defstruct` above.
  def agenda, do: %__MODULE__{order: :mmddyy, separator: "/", clock: 12}

  @doc "Every date order, in the order the settings offer them."
  @spec orders() :: [order]
  def orders, do: @orders

  @doc "Every date separator."
  @spec separators() :: [String.t()]
  def separators, do: @separators

  @doc "Every choice for Display date and/or time."
  @spec shows() :: [show]
  def shows, do: @shows

  @doc ~S|An order's name as Agenda wrote it ("MMDDYY", "Week #").|
  @spec label(order) :: String.t()
  def label(:day_number), do: "<Day> #"
  def label(:day), do: "Day #"
  def label(:week_number), do: "<Week> #"
  def label(:week), do: "Week #"
  def label(:relative), do: "Relative"
  def label(:relative_number), do: "Relative #"
  def label(order), do: order |> Atom.to_string() |> String.upcase()

  @doc "A Display date and/or time choice as the settings show it."
  @spec show_label(show) :: String.t()
  def show_label(:date_time), do: "Date time"
  def show_label(:date), do: "Date only"
  def show_label(:time_date), do: "Time date"
  def show_label(:time), do: "Time only"

  @typedoc "`today:` for relative dates; `global:` the format they fall back on."
  @type opts :: [today: Date.t() | nil, global: t | nil]

  @doc "A date as displayed."
  @spec date(Date.t() | nil, t, opts) :: String.t()
  def date(date, format, opts \\ [])
  def date(nil, _format, _opts), do: ""

  def date(%Date{} = date, %__MODULE__{order: order}, opts) when order in @relative do
    case relative(date, order, opts[:today]) do
      nil -> date(date, fallback(opts[:global]), [])
      text -> text
    end
  end

  def date(%Date{} = date, %__MODULE__{} = f, _opts) do
    text = date_text(date, f)
    if f.day_of_week, do: Enum.at(@days, Date.day_of_week(date) - 1) <> " " <> text, else: text
  end

  defp fallback(%__MODULE__{order: order} = global) when order not in @relative, do: global
  defp fallback(_global), do: %__MODULE__{}

  # Agenda 2.0 names the days of the week around today; the rest are dates.
  defp relative(_date, _order, nil), do: nil

  defp relative(date, :relative_number, today) do
    days = Date.diff(date, today)
    "#{days} day" <> if(abs(days) == 1, do: "", else: "s")
  end

  defp relative(date, :relative, today) do
    day = Enum.at(@relative_days, Date.day_of_week(date) - 1)

    case Date.diff(date, today) do
      0 -> "Today"
      1 -> "Tomorrow"
      -1 -> "Yesterday"
      n when n in 2..6 -> "nxt " <> day
      n when n in -6..-2 -> "lst " <> day
      _ -> nil
    end
  end

  @doc "A time of day as displayed."
  @spec time(Time.t(), t) :: String.t()
  def time(%Time{hour: h, minute: m}, %__MODULE__{} = f) do
    hour =
      cond do
        f.clock == 24 -> pad(h)
        rem(h, 12) == 0 -> "12"
        true -> Integer.to_string(rem(h, 12))
      end

    text =
      if f.time_separator == "hm", do: "#{hour}h#{pad(m)}m", else: "#{hour}:#{pad(m)}"

    cond do
      f.clock == 24 or not f.am_pm -> text
      f.time_separator == "hm" -> text <> " " <> am_pm(h)
      true -> text <> am_pm(h)
    end
  end

  defp am_pm(h), do: if(h < 12, do: "am", else: "pm")

  @doc """
  A date with an optional time, as date columns show them, by Display
  date and/or time; with only a date, the date.
  """
  @spec date_time(Date.t() | nil, Time.t() | nil, t, opts) :: String.t()
  def date_time(date, time, format, opts \\ [])
  def date_time(nil, _time, _format, _opts), do: ""
  def date_time(_date, nil, %__MODULE__{show: :time}, _opts), do: ""
  def date_time(date, nil, format, opts), do: date(date, format, opts)

  def date_time(date, time, %__MODULE__{} = f, opts) do
    case f.show do
      :date_time -> date(date, f, opts) <> " " <> time(time, f)
      :date -> date(date, f, opts)
      :time_date -> time(time, f) <> " " <> date(date, f, opts)
      :time -> time(time, f)
    end
  end

  @doc "A moment (date and time of day), as the title bar clock and alarms show it."
  @spec datetime(NaiveDateTime.t(), t) :: String.t()
  def datetime(%NaiveDateTime{} = at, format) do
    format = fallback(format)
    date(NaiveDateTime.to_date(at), format) <> " " <> time(NaiveDateTime.to_time(at), format)
  end

  @doc """
  Agenda's formatted sample: how 13 November 1990 at 3:25 pm looks (on
  the day before, for relative formats).
  """
  @spec sample(t) :: String.t()
  def sample(format), do: date_time(~D[1990-11-13], ~T[15:25:00], format, today: ~D[1990-11-12])

  @doc "The next (`step` 1) or previous (-1) choice for one setting."
  @spec cycle(t, atom, integer) :: t
  def cycle(f, :order, step), do: %{f | order: next(@orders, f.order, step)}
  def cycle(f, :show, step), do: %{f | show: next(@shows, f.show, step)}
  def cycle(f, :am_pm, _step), do: %{f | am_pm: not f.am_pm}

  def cycle(f, :time_separator, _step),
    do: %{f | time_separator: if(f.time_separator == ":", do: "hm", else: ":")}

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
        :day_number -> {[Integer.to_string(Date.day_of_year(date))], ""}
        :day -> {["Day", Integer.to_string(Date.day_of_year(date))], " "}
        :week_number -> {[Integer.to_string(week(date))], ""}
        :week -> {["Week", Integer.to_string(week(date))], " "}
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

  # ISO 8601: a week belongs to the year its Thursday is in.
  defp week(date) do
    thursday = Date.add(date, 4 - Date.day_of_week(date))
    div(Date.day_of_year(thursday) - 1, 7) + 1
  end

  defp pad(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")
end
