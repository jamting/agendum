defmodule Agenda.Core.SwedishDatesTest do
  @moduledoc "Reading Swedish dates and times (R14c)."
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Agenda.Core.DateLanguage.{English, Swedish}
  alias Agenda.Core.DateParser

  # A Thursday
  @today ~D[2026-10-08]
  @now ~N[2026-10-08 10:00:00]
  @sv [languages: [Swedish]]

  defp day(text), do: DateParser.parse(text, @today, @sv)
  defp date_time(text), do: DateParser.parse_when(text, @now, @sv)
  defp found(text, opts \\ @sv), do: DateParser.extract_when(text, @now, opts)

  describe "days" do
    test "today, tomorrow and yesterday, written together or apart" do
      for {text, expected} <- [
            {"idag", ~D[2026-10-08]},
            {"i dag", ~D[2026-10-08]},
            {"imorgon", ~D[2026-10-09]},
            {"i morgon", ~D[2026-10-09]},
            {"i övermorgon", ~D[2026-10-10]},
            {"övermorgon", ~D[2026-10-10]},
            {"igår", ~D[2026-10-07]},
            {"i går", ~D[2026-10-07]},
            {"i förrgår", ~D[2026-10-06]}
          ],
          do: assert(day(text) == {:ok, expected}, text)
    end

    test "weekdays: the next one, next week's, last week's, and the latest past one" do
      for {text, expected} <- [
            {"fredag", ~D[2026-10-09]},
            {"Måndag", ~D[2026-10-12]},
            {"torsdag", ~D[2026-10-08]},
            {"fredagen", ~D[2026-10-09]},
            {"nästa fredag", ~D[2026-10-16]},
            {"denna fredag", ~D[2026-10-09]},
            {"förra måndagen", ~D[2026-09-28]},
            {"i fredags", ~D[2026-10-02]},
            {"i måndags", ~D[2026-10-05]},
            {"i torsdags", ~D[2026-10-01]},
            {"fre", ~D[2026-10-09]},
            {"lör", ~D[2026-10-10]}
          ],
          do: assert(day(text) == {:ok, expected}, text)
    end
  end

  describe "dates with a month" do
    test "day and month, with or without den, :e and a year" do
      for {text, expected} <- [
            {"5 november", ~D[2026-11-05]},
            {"den 5 november", ~D[2026-11-05]},
            {"5:e nov", ~D[2026-11-05]},
            {"den 1:a december 2027", ~D[2027-12-01]},
            {"den femte november", ~D[2026-11-05]},
            {"1 maj", ~D[2027-05-01]},
            {"24 dec.", ~D[2026-12-24]}
          ],
          do: assert(day(text) == {:ok, expected}, text)
    end

    test "numbers are day/month; ISO works too" do
      assert day("5/11") == {:ok, ~D[2026-11-05]}
      assert day("5/11-27") == {:ok, ~D[2027-11-05]}
      assert day("5/11/2027") == {:ok, ~D[2027-11-05]}
      assert day("2026-11-05") == {:ok, ~D[2026-11-05]}
      assert day("31/2") == :error
    end
  end

  describe "periods and amounts" do
    test "in and ago" do
      for {text, expected} <- [
            {"om 2 dagar", ~D[2026-10-10]},
            {"om en vecka", ~D[2026-10-15]},
            {"om tre veckor", ~D[2026-10-29]},
            {"om två månader", ~D[2026-12-08]},
            {"för 2 dagar sedan", ~D[2026-10-06]},
            {"3 veckor sedan", ~D[2026-09-17]}
          ],
          do: assert(day(text) == {:ok, expected}, text)
    end

    test "this, next and last week, month and year, and their beginning and end" do
      for {text, expected} <- [
            {"nästa vecka", ~D[2026-10-12]},
            {"förra veckan", ~D[2026-09-28]},
            {"den här veckan", ~D[2026-10-05]},
            {"nästa månad", ~D[2026-11-01]},
            {"denna månad", ~D[2026-10-01]},
            {"nästa år", ~D[2027-01-01]},
            {"i slutet av nästa vecka", ~D[2026-10-16]},
            {"i början av månaden", ~D[2026-10-01]},
            {"slutet av månaden", ~D[2026-10-31]}
          ],
          do: assert(day(text) == {:ok, expected}, text)
    end
  end

  describe "times" do
    test "a 24-hour clock, with kl and a dot or a colon" do
      assert date_time("fredag kl 15") == {:ok, ~D[2026-10-09], ~T[15:00:00]}
      assert date_time("kl. 9.30") == {:ok, ~D[2026-10-08], ~T[09:30:00]}
      assert date_time("kl 3") == {:ok, ~D[2026-10-08], ~T[03:00:00]}
      assert date_time("15:30") == {:ok, ~D[2026-10-08], ~T[15:30:00]}
      assert date_time("i morgon kl 8") == {:ok, ~D[2026-10-09], ~T[08:00:00]}
    end

    test "parts of the day and amounts of time" do
      assert date_time("i kväll") == {:ok, ~D[2026-10-08], ~T[17:00:00]}
      assert date_time("ikväll") == {:ok, ~D[2026-10-08], ~T[17:00:00]}
      assert date_time("fredag eftermiddag") == {:ok, ~D[2026-10-09], ~T[14:00:00]}
      assert date_time("förmiddag") == {:ok, ~D[2026-10-08], ~T[08:00:00]}
      assert date_time("om 2 timmar") == {:ok, ~D[2026-10-08], ~T[12:00:00]}
      assert date_time("om 45 minuter") == {:ok, ~D[2026-10-08], ~T[10:45:00]}
    end
  end

  describe "in item text" do
    test "the first date and time are found" do
      assert {:ok, ~D[2026-10-09], ~T[14:00:00], _} = found("Ring Anna på fredag kl 14")
      assert {:ok, ~D[2026-11-05], nil, "den 5 november"} = found("Möte den 5 november")
      assert {:ok, ~D[2026-10-02], nil, _} = found("Fakturan kom i fredags")
    end

    test "ordinary words are not dates" do
      for text <- [
            "Köp mjölk",
            "Ring Tor om rapporten",
            "Det blir bra nu",
            "Mars är en planet",
            "Skicka till Tor"
          ],
          do: assert(found(text) == :none, text)
    end

    test "bare abbreviations count after på, till or senast" do
      assert {:ok, ~D[2026-10-09], nil, _} = found("Klart senast fre")
      assert {:ok, ~D[2026-10-11], nil, _} = found("Middag på sön")
    end
  end

  describe "the fallback language" do
    test "without it, English is not read" do
      assert found("Call Bob friday") == :none
      assert DateParser.parse("tomorrow", @today, @sv) == :error
    end

    test "with it, both languages are read; the main one wins a tie" do
      both = [languages: [Swedish, English]]
      assert {:ok, ~D[2026-10-09], nil, _} = found("Call Bob friday", both)
      assert {:ok, ~D[2026-10-09], ~T[15:00:00], _} = found("Ring Bob friday kl 15", both)
      # "5/11" is the main language's: 5 November
      assert DateParser.parse("5/11", @today, both) == {:ok, ~D[2026-11-05]}
    end
  end

  property "any mix of Swedish date words reads without crashing, as a date or not" do
    words =
      ~w(i på om för den nästa förra denna kl. kl idag morgon i går fredag fredags fre sön 5:e
         den femte november maj 31/2 5/11 2026-13-40 dagar veckor sedan början slutet av
         månaden kväll 15.30 25:99 sex två) ++ ["", "  "]

    check all(parts <- list_of(member_of(words), max_length: 8)) do
      text = Enum.join(parts, " ")

      for opts <- [@sv, [languages: [Swedish, English]]] do
        assert DateParser.parse_when(text, @now, opts) == :error or
                 match?({:ok, %Date{}, _}, DateParser.parse_when(text, @now, opts))

        assert DateParser.extract_when(text, @now, opts) == :none or
                 match?({:ok, %Date{}, _, _}, DateParser.extract_when(text, @now, opts))
      end
    end
  end

  test "English remains the default" do
    assert DateParser.parse("5/11", @today) == {:ok, ~D[2027-05-11]}
    assert DateParser.parse("fredag", @today) == :error
  end
end
