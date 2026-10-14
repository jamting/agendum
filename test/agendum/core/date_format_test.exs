defmodule Agendum.Core.DateFormatTest do
  @moduledoc "How dates and times are displayed (R41; User's Guide 6-20 to 6-22, 7-13 to 7-15)."
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.{DateFormat, ViewModel}

  @date ~D[1990-11-13]

  defp fmt(fields), do: struct(DateFormat, fields)

  test "the default is ISO 8601 with a 24-hour clock, as before" do
    assert DateFormat.date(@date, %DateFormat{}) == "1990-11-13"
    assert DateFormat.date_time(@date, ~T[15:25:00], %DateFormat{}) == "1990-11-13 15:25"
    assert DateFormat.date_time(@date, nil, %DateFormat{}) == "1990-11-13"
    assert DateFormat.date_time(nil, nil, %DateFormat{}) == ""
  end

  test "every date order in Agenda's table" do
    expected = %{
      mmddyy: "11/13/90",
      mmddyyyy: "11/13/1990",
      ddmmyy: "13/11/90",
      ddmmyyyy: "13/11/1990",
      yymmdd: "90/11/13",
      yyyymmdd: "1990/11/13",
      yyddmm: "90/13/11",
      yyyyddmm: "1990/13/11",
      mmmdd: "Nov 13",
      mmmddyy: "Nov 13 90",
      mmmddyyyy: "Nov 13 1990",
      ddmmm: "13 Nov",
      ddmmmyy: "13 Nov 90",
      ddmmmyyyy: "13 Nov 1990"
    }

    assert Map.keys(expected) |> Enum.sort() == Enum.sort(Enum.take(DateFormat.orders(), 14))

    for {order, text} <- expected,
        do: assert(DateFormat.date(@date, fmt(order: order, separator: "/")) == text)
  end

  test "the separator goes between numbers" do
    assert DateFormat.date(@date, fmt(order: :ddmmyy, separator: ".")) == "13.11.90"
    assert DateFormat.date(~D[2026-03-05], fmt(order: :mmddyy, separator: " ")) == "03 05 26"
  end

  test "a 12-hour clock shows am and pm" do
    twelve = fmt(clock: 12)
    assert DateFormat.time(~T[15:25:00], twelve) == "3:25pm"
    assert DateFormat.time(~T[00:05:00], twelve) == "12:05am"
    assert DateFormat.time(~T[12:00:00], twelve) == "12:00pm"
    assert DateFormat.time(~T[09:30:00], fmt(clock: 24)) == "09:30"
  end

  test "the day of the week comes first when shown" do
    assert DateFormat.date(@date, fmt(day_of_week: true)) == "Tue 1990-11-13"
  end

  test "a sample shows what the settings look like" do
    assert DateFormat.sample(fmt(order: :ddmmmyy, clock: 12)) == "13 Nov 90 3:25pm"
  end

  test "settings cycle through their choices" do
    f = %DateFormat{}
    assert DateFormat.cycle(f, :separator, 1).separator == "."
    assert DateFormat.cycle(f, :separator, -1).separator == "/"
    assert DateFormat.cycle(f, :clock, 1).clock == 12
    assert DateFormat.cycle(f, :day_of_week, 1).day_of_week
    assert DateFormat.cycle(f, :order, 1).order != f.order
  end

  test "the file's format is used in date columns" do
    db = Core.new_file()
    {db, id} = Core.add_item(db, "Call Bob", ~D[2026-10-08])
    db = Core.set_date(db, id, db.special.when, ~D[2026-10-09])
    db = Core.set_date_format(db, fmt(order: :ddmmyyyy, separator: "."))
    assert ViewModel.cell(db, db.items[id], db.special.when) == "09.10.2026"
  end
end
