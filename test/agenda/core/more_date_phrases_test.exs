defmodule Agenda.Core.MoreDatePhrasesTest do
  @moduledoc """
  More date phrases (R14d; User's Guide 6-10 to 6-11, 7-15 to 7-16):
  working days, quarters, "first Wednesday in November", months alone.
  """
  use ExUnit.Case, async: true

  alias Agenda.Core.DateLanguage.Swedish
  alias Agenda.Core.DateParser

  # A Thursday
  @today ~D[2026-10-08]
  @sv [languages: [Swedish]]

  defp day(text, opts \\ []), do: DateParser.parse(text, @today, opts)

  defp found(text, opts \\ []) do
    case DateParser.extract(text, @today, opts) do
      {:ok, date, _phrase} -> date
      :none -> :none
    end
  end

  defp check(cases, opts \\ []) do
    for {text, expected} <- cases do
      expected = if expected == :error, do: :error, else: {:ok, expected}
      assert day(text, opts) == expected, text
    end
  end

  describe "working days skip Saturday and Sunday" do
    test "forwards and backwards" do
      check([
        {"in five working days", ~D[2026-10-15]},
        {"in 1 working day", ~D[2026-10-09]},
        {"2 working days from today", ~D[2026-10-12]},
        {"3 working days ago", ~D[2026-10-05]}
      ])
    end

    test "from a weekend, the first working day is Monday" do
      assert DateParser.parse("in 1 working day", ~D[2026-10-10]) == {:ok, ~D[2026-10-12]}
      assert DateParser.parse("1 working day ago", ~D[2026-10-11]) == {:ok, ~D[2026-10-09]}
    end

    test "every working day is not a recurring date (yet)" do
      assert day("every working day") == :error
    end
  end

  describe "quarters and years" do
    test "this, next and last quarter start the quarter" do
      check([
        {"this quarter", ~D[2026-10-01]},
        {"next quarter", ~D[2027-01-01]},
        {"last quarter", ~D[2026-07-01]},
        {"end of the quarter", ~D[2026-12-31]},
        {"beginning of next quarter", ~D[2027-01-01]},
        {"end of last quarter", ~D[2026-09-30]}
      ])
    end

    test "the first to fourth quarter: this year's, unless it has ended" do
      check([
        {"fourth quarter", ~D[2026-10-01]},
        {"the first quarter", ~D[2027-01-01]},
        {"second quarter", ~D[2027-04-01]},
        {"fifth quarter", :error}
      ])
    end

    test "beginning and end of a year" do
      check([
        {"end of the year", ~D[2026-12-31]},
        {"beginning of next year", ~D[2027-01-01]},
        {"end of next year", ~D[2027-12-31]}
      ])
    end
  end

  describe "the nth weekday of a month" do
    test "of a named month, put in the future" do
      check([
        {"first Wednesday in November", ~D[2026-11-04]},
        {"the third Thursday in November 2027", ~D[2027-11-18]},
        {"first Wednesday in October", ~D[2027-10-06]},
        {"last Monday of November", ~D[2026-11-30]},
        {"fifth Monday in February", :error}
      ])
    end

    test "of this, next or last month" do
      check([
        {"the last Friday of the month", ~D[2026-10-30]},
        {"first Monday of the month", ~D[2026-10-05]},
        {"second Monday of next month", ~D[2026-11-09]},
        {"last Tuesday of last month", ~D[2026-09-29]}
      ])
    end
  end

  describe "a month alone means its first day" do
    test "on its own: this year's, unless the month is over" do
      check([
        {"December", ~D[2026-12-01]},
        {"October", ~D[2026-10-01]},
        {"April", ~D[2027-04-01]},
        {"in September", ~D[2027-09-01]}
      ])
    end

    test "this, next and last" do
      check([
        {"this April", ~D[2026-04-01]},
        {"next April", ~D[2027-04-01]},
        {"next November", ~D[2026-11-01]},
        {"next October", ~D[2027-10-01]},
        {"last April", ~D[2026-04-01]},
        {"last October", ~D[2025-10-01]}
      ])
    end

    test "beginning and end of a month" do
      check([
        {"end of next March", ~D[2027-03-31]},
        {"beginning of April", ~D[2027-04-01]},
        {"end of April", ~D[2027-04-30]},
        {"end of October", ~D[2026-10-31]}
      ])
    end
  end

  describe "a day of this or next month, and calendar notation with a month name" do
    test "the nth of the month" do
      check([
        {"the second of the month", ~D[2026-10-02]},
        {"the 15th of next month", ~D[2026-11-15]},
        {"the 31st of next month", :error}
      ])
    end

    test "Nov/12/90" do
      check([
        {"Nov/12/2026", ~D[2026-11-12]},
        {"Nov/12/90", ~D[1990-11-12]},
        {"nov/12", ~D[2026-11-12]}
      ])
    end
  end

  describe "in item text" do
    test "the manual's examples and friends" do
      assert found("Status report due first Wednesday in November") == ~D[2026-11-04]
      assert found("Attend conference next September") == ~D[2027-09-01]
      assert found("Attend conference in September") == ~D[2027-09-01]
      assert found("Budget review this quarter") == ~D[2026-10-01]
      assert found("Send the proofs in five working days") == ~D[2026-10-15]
    end

    test "a month name on its own is not a date in text" do
      assert found("You may come along") == :none
      assert found("March forward") == :none
      assert found("Plan the trip in mar") == :none
    end
  end

  describe "Swedish" do
    test "working days, quarters and years" do
      check(
        [
          {"om fem arbetsdagar", ~D[2026-10-15]},
          {"om 2 vardagar", ~D[2026-10-12]},
          {"för 3 arbetsdagar sedan", ~D[2026-10-05]},
          {"detta kvartal", ~D[2026-10-01]},
          {"nästa kvartal", ~D[2027-01-01]},
          {"i slutet av kvartalet", ~D[2026-12-31]},
          {"första kvartalet", ~D[2027-01-01]},
          {"i slutet av året", ~D[2026-12-31]}
        ],
        @sv
      )
    end

    test "the nth weekday of a month" do
      check(
        [
          {"första onsdagen i november", ~D[2026-11-04]},
          {"sista fredagen i månaden", ~D[2026-10-30]},
          {"andra måndagen i nästa månad", ~D[2026-11-09]}
        ],
        @sv
      )
    end

    test "months alone and days of a month" do
      check(
        [
          {"april", ~D[2027-04-01]},
          {"i april", ~D[2027-04-01]},
          {"nästa april", ~D[2027-04-01]},
          {"i början av april", ~D[2027-04-01]},
          {"i slutet av nästa mars", ~D[2027-03-31]},
          {"den 15:e nästa månad", ~D[2026-11-15]},
          {"den andra i månaden", ~D[2026-10-02]}
        ],
        @sv
      )
    end

    test "in text, \"i jul\" is Christmas, not July" do
      assert found("Fira i jul", @sv) == :none
      assert found("Konferens i september", @sv) == ~D[2027-09-01]
    end
  end
end
