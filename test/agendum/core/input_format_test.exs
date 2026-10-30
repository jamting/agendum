# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.InputFormatTest do
  @moduledoc """
  The reader's Input format (R41b; User's Guide 7-17): number order,
  input date separator and input clock, each the date language's unless
  the person sets their own (ADR 0008, 0013).
  """
  use ExUnit.Case, async: true

  alias Agendum.Core.{Context, DateParser, InputFormat}
  alias Agendum.Core.DateLanguage.{English, Swedish}

  @today ~D[2026-10-08]
  @now ~N[2026-10-08 09:00:00]

  defp input(fields), do: struct(InputFormat, fields)

  defp day(text, fields, langs \\ [English]),
    do: DateParser.parse(text, @today, languages: langs, input: input(fields))

  defp time(text, fields, langs \\ [English]) do
    case DateParser.parse_when(text, @now, languages: langs, input: input(fields)) do
      {:ok, _date, time} -> time
      :error -> :error
    end
  end

  test "by default everything is the language's" do
    assert %InputFormat{} == input(number_order: nil, separator: nil, clock: nil)
    assert day("11/12/90", []) == {:ok, ~D[1990-11-12]}
    assert day("11/12/90", [], [Swedish]) == {:ok, ~D[1990-12-11]}
  end

  describe "number order" do
    test "Agenda's six orders all read 12 November 1990" do
      for {order, text} <- [
            mdy: "11/12/90",
            myd: "11/90/12",
            dmy: "12/11/90",
            dym: "12/90/11",
            ydm: "90/12/11",
            ymd: "90/11/12"
          ],
          do: assert(day(text, number_order: order) == {:ok, ~D[1990-11-12]}, "#{order}")
    end

    test "four-digit years, and month and day alone in the order's sequence" do
      assert day("1990/11/12", number_order: :ymd) == {:ok, ~D[1990-11-12]}
      assert day("12/11/1990", number_order: :dmy) == {:ok, ~D[1990-11-12]}
      assert day("12/11", number_order: :dmy) == {:ok, ~D[2026-11-12]}
      assert day("11/12", number_order: :ydm) == {:ok, ~D[2026-12-11]}
    end

    test "overrides the language's order, in text too" do
      assert day("5/11", [number_order: :mdy], [Swedish]) == {:ok, ~D[2027-05-11]}

      assert {:ok, ~D[2026-11-05], _} =
               DateParser.extract("Ring Bo 5/11", @today,
                 languages: [English],
                 input: input(number_order: :dmy)
               )
    end

    test "impossible dates are not dates" do
      assert day("13/13/90", number_order: :dmy) == :error
      assert day("123/1/90", number_order: :dmy) == :error
    end
  end

  describe "input date separator" do
    test "dates are typed with it" do
      assert day("12.11.90", separator: ".", number_order: :dmy) == {:ok, ~D[1990-11-12]}
      assert day("11-12-90", separator: "-") == {:ok, ~D[1990-11-12]}
      assert day("11,12,90", separator: ",") == {:ok, ~D[1990-11-12]}
      assert day("nov.12", separator: ".") == {:ok, ~D[2026-11-12]}
    end

    test "with the language's order when only the separator is set" do
      assert day("5.11.26", [separator: "."], [Swedish]) == {:ok, ~D[2026-11-05]}
    end

    test "the slash is no longer a date separator" do
      assert day("11/12/90", separator: ".") == :error
    end

    test "ISO dates are still read" do
      assert day("2026-10-20", separator: "-", number_order: :dmy) == {:ok, ~D[2026-10-20]}
      assert day("2026-10-20", separator: ".") == {:ok, ~D[2026-10-20]}
    end

    test "a period does not turn times into dates" do
      assert time("15.30", [separator: ".", number_order: :dmy], [Swedish]) in [
               ~T[15:30:00],
               :error
             ]
    end
  end

  describe "input clock" do
    test "12 hr reads 3:00 as 3 pm, as Agenda's default" do
      assert time("3:00", clock: 12) == ~T[15:00:00]
      assert time("3:00", [clock: 12], [Swedish]) == ~T[15:00:00]
    end

    test "impossible times are not times, with either clock" do
      assert time("3:99", clock: 12) == :error
      assert time("3:99", clock: 24) == :error

      # in item text it no longer crashes
      assert {:ok, _, _, _} = DateParser.extract_when("Call at 3:99", @now)
    end

    test "24 hr reads every hour as written" do
      assert time("3:00", clock: 24) == ~T[03:00:00]
      assert time("at 3", clock: 24) == ~T[03:00:00]
      assert time("3pm", clock: 24) == ~T[15:00:00]
    end
  end

  test "settings cycle through Language and Agenda's choices" do
    f = %InputFormat{}
    orders = Stream.iterate(f, &InputFormat.cycle(&1, :number_order, 1)) |> Enum.take(7)
    assert Enum.map(orders, & &1.number_order) == [nil, :mdy, :myd, :dmy, :dym, :ydm, :ymd]
    assert InputFormat.cycle(f, :number_order, -1).number_order == :ymd
    assert InputFormat.cycle(f, :separator, 1).separator == "/"
    assert InputFormat.cycle(f, :clock, 1).clock == 12
    assert InputFormat.cycle(input(clock: 24), :clock, 1).clock == nil
  end

  test "labels say what the language gives" do
    assert InputFormat.label(%InputFormat{}, :number_order, [Swedish]) == "Language (DMY)"
    assert InputFormat.label(%InputFormat{}, :separator, [English]) == "Language (/)"
    assert InputFormat.label(%InputFormat{}, :clock, [Swedish]) == "Language (24 hr)"
    assert InputFormat.label(input(number_order: :ymd), :number_order, [English]) == "YMD"
    assert InputFormat.label(input(clock: 12), :clock, [English]) == "12 hr"
  end

  test "the context carries it to the parser" do
    ctx = %Context{now: @now, input: input(number_order: :dmy)}
    opts = Context.parser_opts(ctx, nil)
    assert opts[:input].number_order == :dmy
    assert Context.parser_opts(@today, nil)[:input] == %InputFormat{}
  end
end
