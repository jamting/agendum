defmodule Agenda.Core.DateParserTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Agenda.Core.DateParser

  describe "parse/2 follows the manual's table (today is Wednesday 11/7/1990)" do
    @wednesday ~D[1990-11-07]

    for {input, expected} <- [
          {"Wednesday", ~D[1990-11-07]},
          {"This Wednesday", ~D[1990-11-07]},
          {"Next Wednesday", ~D[1990-11-14]},
          {"Last Wednesday", ~D[1990-10-31]},
          {"Friday", ~D[1990-11-09]},
          {"This Friday", ~D[1990-11-09]},
          {"Next Friday", ~D[1990-11-16]},
          {"Last Friday", ~D[1990-11-02]},
          {"Monday", ~D[1990-11-12]},
          {"This Monday", ~D[1990-11-05]},
          {"Next Monday", ~D[1990-11-12]},
          {"Last Monday", ~D[1990-10-29]},
          {"This week", ~D[1990-11-05]}
        ] do
      test "#{inspect(input)}" do
        assert DateParser.parse(unquote(input), @wednesday) ==
                 {:ok, unquote(Macro.escape(expected))}
      end
    end
  end

  describe "parse/2 (today is Thursday 2026-10-08)" do
    @today ~D[2026-10-08]

    for {input, expected} <- [
          {"today", ~D[2026-10-08]},
          {"Tomorrow", ~D[2026-10-09]},
          {"tmorrow", ~D[2026-10-09]},
          {"yesterday", ~D[2026-10-07]},
          {"friday", ~D[2026-10-09]},
          {"thu", ~D[2026-10-08]},
          {"next tuesday", ~D[2026-10-13]},
          {"next week", ~D[2026-10-12]},
          {"next month", ~D[2026-11-01]},
          {"this year", ~D[2026-01-01]},
          {"end of the month", ~D[2026-10-31]},
          {"beginning of next month", ~D[2026-11-01]},
          {"end of next week", ~D[2026-10-16]},
          {"in 3 days", ~D[2026-10-11]},
          {"in two weeks", ~D[2026-10-22]},
          {"in a fortnight", ~D[2026-10-22]},
          {"one week from today", ~D[2026-10-15]},
          {"2 days ago", ~D[2026-10-06]},
          {"the day after tomorrow", ~D[2026-10-10]},
          {"2026-12-24", ~D[2026-12-24]},
          {"12/24/26", ~D[2026-12-24]},
          {"11/20/90", ~D[1990-11-20]},
          {"1/2/2027", ~D[2027-01-02]},
          {"12/24", ~D[2026-12-24]},
          {"November 23rd", ~D[2026-11-23]},
          {"the first of November", ~D[2026-11-01]},
          {"7 Aug", ~D[2027-08-07]},
          {"November 20, 1990", ~D[1990-11-20]},
          {"Thursday at 3:30 pm", ~D[2026-10-08]}
        ] do
      test "#{inspect(input)}" do
        assert DateParser.parse(unquote(input), @today) == {:ok, unquote(Macro.escape(expected))}
      end
    end

    test "rejects nonsense, invalid dates and extra words" do
      assert DateParser.parse("someday", @today) == :error
      assert DateParser.parse("2026-02-30", @today) == :error
      assert DateParser.parse("friday please", @today) == :error
    end
  end

  describe "extract/2 finds the first date in item text" do
    @today ~D[2026-10-08]

    for {text, expected} <- [
          {"Call Toni on August 7", ~D[2027-08-07]},
          {"Cheryl arrives tomorrow", ~D[2026-10-09]},
          {"Call Marketing this Tuesday at 3:00", ~D[2026-10-06]},
          {"Meet with John Smith on Tuesday", ~D[2026-10-13]},
          {"Cheryl arrives tomorrow, leaves next Friday", ~D[2026-10-09]},
          {"See you on Sat.", ~D[2026-10-10]},
          {"Report due 12/24", ~D[2026-12-24]}
        ] do
      test "#{inspect(text)}" do
        assert {:ok, unquote(Macro.escape(expected)), _phrase} =
                 DateParser.extract(unquote(text), @today)
      end
    end

    test "common words are not mistaken for abbreviated dates" do
      for text <- ["sat down with Ed", "I may call", "the sun is out", "wed in June"] do
        assert DateParser.extract(text, @today) == :none, text
      end
    end

    test "returns the date words, normalised" do
      assert {:ok, _, "next friday"} = DateParser.extract("Lunch NEXT   Friday", @today)
    end
  end

  property "extract/2 and parse/2 never crash on arbitrary text" do
    words =
      ~w(next last this monday fri sat may 12/24 31/31 2/30 in two a weeks ago tomorrow of the
               november 23rd 1990 at 3:00 pm end beginning month week year åäö 0/0 99/99/99 day after)

    check all(
            tokens <-
              list_of(one_of([member_of(words), string(:printable, max_length: 6)]),
                max_length: 12
              ),
            today <- member_of([~D[2026-10-08], ~D[2024-02-29], ~D[1990-11-07], ~D[2026-12-31]])
          ) do
      text = Enum.join(tokens, " ")

      case DateParser.extract(text, today) do
        :none -> :ok
        {:ok, %Date{}, phrase} -> assert is_binary(phrase)
      end

      assert DateParser.parse(text, today) == :error or
               match?({:ok, %Date{}}, DateParser.parse(text, today))
    end
  end
end
