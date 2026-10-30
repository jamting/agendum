# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.DateDisplayOptionsTest do
  @moduledoc """
  More date display options (R41a; User's Guide 6-19 to 6-22, 7-14 to
  7-15): Display date and/or time, Day #, Week #, Relative and Relative #
  formats, Show am/pm, Time separator, and date columns with their own
  format (Column Properties) instead of the global defaults.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.{DateFormat, ViewModel}

  @date ~D[1990-11-13]
  # a Thursday, as in the Lotus Q&A "Relative Date Format is Displayed for only Seven Days"
  @today ~D[1990-12-13]

  defp fmt(fields), do: struct(DateFormat, fields)
  defp rel(date, order \\ :relative), do: DateFormat.date(date, fmt(order: order), today: @today)

  test "the new settings default to Agenda's" do
    f = %DateFormat{}
    assert {f.show, f.am_pm, f.time_separator} == {:date_time, true, ":"}
  end

  describe "Day # and Week #" do
    test "with and without the word" do
      assert DateFormat.date(@date, fmt(order: :day)) == "Day 317"
      assert DateFormat.date(@date, fmt(order: :day_number)) == "317"
      assert DateFormat.date(@date, fmt(order: :week)) == "Week 46"
      assert DateFormat.date(@date, fmt(order: :week_number)) == "46"
    end

    test "weeks are ISO 8601 weeks" do
      assert DateFormat.date(~D[2027-01-01], fmt(order: :week_number)) == "53"
      assert DateFormat.date(~D[2026-12-28], fmt(order: :week_number)) == "53"
      assert DateFormat.date(~D[2027-01-04], fmt(order: :week_number)) == "1"
    end
  end

  describe "Relative" do
    test "today, tomorrow and yesterday" do
      assert rel(@today) == "Today"
      assert rel(Date.add(@today, 1)) == "Tomorrow"
      assert rel(Date.add(@today, -1)) == "Yesterday"
    end

    test "the coming and the past week by the day's name" do
      assert rel(~D[1990-12-16]) == "nxt Sun"
      assert rel(~D[1990-12-18]) == "nxt Tues"
      assert rel(~D[1990-12-19]) == "nxt Wed"
      assert rel(~D[1990-12-07]) == "lst Fri"
      assert rel(~D[1990-12-08]) == "lst Sat"
    end

    test "other dates in the global format" do
      global = fmt(order: :mmddyy, separator: "/")

      assert DateFormat.date(~D[1990-12-20], fmt(order: :relative), today: @today, global: global) ==
               "12/20/90"

      assert rel(~D[1990-12-06]) == "1990-12-06"
    end

    test "without today's date, the global format" do
      assert DateFormat.date(@today, fmt(order: :relative)) == "1990-12-13"
    end

    test "Relative # counts days" do
      assert rel(Date.add(@today, 1), :relative_number) == "1 day"
      assert rel(Date.add(@today, 30), :relative_number) == "30 days"
      assert rel(@today, :relative_number) == "0 days"
      assert rel(Date.add(@today, -2), :relative_number) == "-2 days"
    end
  end

  describe "Display date and/or time" do
    test "date time, date only, time date, time only" do
      t = ~T[15:25:00]
      assert DateFormat.date_time(@date, t, fmt(show: :date_time)) == "1990-11-13 15:25"
      assert DateFormat.date_time(@date, t, fmt(show: :date)) == "1990-11-13"
      assert DateFormat.date_time(@date, t, fmt(show: :time_date)) == "15:25 1990-11-13"
      assert DateFormat.date_time(@date, t, fmt(show: :time)) == "15:25"
      assert DateFormat.date_time(@date, nil, fmt(show: :time)) == ""
      assert DateFormat.date_time(@date, nil, fmt(show: :time_date)) == "1990-11-13"
    end

    test "the title bar clock shows date and time whatever the setting" do
      assert DateFormat.datetime(~N[1990-11-13 15:25:00], fmt(show: :time)) == "1990-11-13 15:25"
    end
  end

  describe "time options" do
    test "Show am/pm No" do
      assert DateFormat.time(~T[15:25:00], fmt(clock: 12, am_pm: false)) == "3:25"
      assert DateFormat.time(~T[15:25:00], fmt(clock: 24, am_pm: false)) == "15:25"
    end

    test "the hm time separator" do
      assert DateFormat.time(~T[15:30:00], fmt(time_separator: "hm")) == "15h30m"
      assert DateFormat.time(~T[15:30:00], fmt(clock: 12, time_separator: "hm")) == "3h30m pm"

      assert DateFormat.time(~T[15:30:00], fmt(clock: 12, am_pm: false, time_separator: "hm")) ==
               "3h30m"
    end
  end

  test "cycling reaches every new choice" do
    orders = Stream.iterate(%DateFormat{}, &DateFormat.cycle(&1, :order, 1)) |> Enum.take(20)

    assert Enum.all?(
             ~w(day day_number week week_number relative relative_number)a,
             &(&1 in Enum.map(orders, fn f -> f.order end))
           )

    assert DateFormat.cycle(%DateFormat{}, :show, 1).show == :date
    assert DateFormat.cycle(%DateFormat{}, :show, -1).show == :time
    assert DateFormat.cycle(%DateFormat{}, :am_pm, 1).am_pm == false
    assert DateFormat.cycle(%DateFormat{}, :time_separator, 1).time_separator == "hm"
  end

  describe "a date column with its own format" do
    setup do
      db = Core.new_file()
      {db, id} = Core.add_item(db, "Lunch tomorrow at 1pm", @today)
      view = db.views |> Map.values() |> hd()
      db = Core.assign(db, id, hd(view.sections).category_id)
      db = Core.add_column(db, view.id, db.special.when, {0, 0})
      %{db: db, view: view.id, item: id}
    end

    defp cells(db, view, today) do
      rows = db |> ViewModel.build(db.views[view], today) |> Enum.flat_map(& &1.rows)
      row = Enum.find(rows, &(&1.item.text =~ "Lunch"))
      hd(row.cells)
    end

    test "uses the global defaults until given its own", %{db: db, view: view} do
      assert cells(db, view, @today) == "12/14/90 1:00pm"
      db = Core.set_date_format(db, fmt(order: :ddmmyy, separator: "."))
      assert cells(db, view, @today) == "14.12.90 13:00"
    end

    test "its own format overrides the global one", %{db: db, view: view} do
      db = Core.set_column_date_format(db, view, {0, 0}, fmt(order: :relative, show: :date))
      assert cells(db, view, @today) == "Tomorrow"
      assert cells(db, view, ~D[1990-12-14]) == "Today"
      assert cells(db, view, ~D[1991-01-14]) == "12/14/90"

      db = Core.set_column_date_format(db, view, {0, 0}, nil)
      assert cells(db, view, @today) == "12/14/90 1:00pm"
    end

    test "falls back on the global format outside the relative week", %{db: db, view: view} do
      db = Core.set_date_format(db, fmt(order: :ddmmyyyy, separator: "/"))
      db = Core.set_column_date_format(db, view, {0, 0}, fmt(order: :relative, show: :date))
      assert cells(db, view, ~D[1991-01-14]) == "14/12/1990"
    end
  end
end
