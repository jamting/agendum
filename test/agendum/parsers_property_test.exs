defmodule Agendum.ParsersPropertyTest do
  @moduledoc """
  The parsers of outside input get random and broken input (ROADMAP,
  Sharpen the saw; the slice reviews, 2026-10-26): Markdown, iCal, the
  feed parser (XML), the `.AG` reader, the JSON import and the date
  parser. Each must answer as its `@spec` says, within a time budget:
  never raise, never loop. Of the three cloud reviews' 30 findings, the
  Markdown loop, `INTERVAL=0`, the Latin-1 calendar and the `.AG`
  reader's blow-up were of this kind.

  The input is made from pieces of the format (tags, keywords, numbers)
  and random text between them, so most cases get past the first check
  and reach the parser's corners. A few dozen cases each in `mix test`;
  PARSER_RUNS sets more for a longer search:
  PARSER_RUNS=2000 mix test test/agendum/parsers_property_test.exs
  """
  use ExUnit.Case, async: true
  # ExUnitProperties brings `check all` and the generators (StreamData)
  use ExUnitProperties

  alias Agendum.Bounded
  alias Agendum.Core
  alias Agendum.Core.{DateLanguage, DateParser, JSONFile}
  alias Agendum.Core.Extras.{FeedParser, ICal, Markdown}

  @runs String.to_integer(System.get_env("PARSER_RUNS", "40"))
  @now ~N[2026-10-26 23:30:00]

  # Joins pieces of a format with random text and separators between them.
  # `one_of` picks a generator for each piece, `list_of` makes a list of
  # them, and `map` turns the list into the text (all lazy: StreamData
  # draws a value only when the property asks for one).
  # With `bytes: true`, raw bytes too, which need not be UTF-8: what comes
  # over the network (a calendar, a feed) can hold anything, while text
  # typed or kept in the file (a note, a date) is always valid UTF-8.
  defp pieces(tokens, separators, max, opts \\ []) do
    raw = if opts[:bytes], do: [binary(max_length: 3)], else: []

    piece =
      one_of(
        [
          member_of(tokens),
          member_of(tokens),
          member_of(separators),
          string(:printable, max_length: 6),
          string(:utf8, max_length: 3),
          map(binary(max_length: 3), &Base.encode16/1)
        ] ++ raw
      )

    map(list_of(piece, max_length: max), &Enum.join/1)
  end

  # --- Markdown --------------------------------------------------------------

  # (a plain list: a ~w sigil cannot hold the brackets and parentheses)
  @markdown ~w(# ## ###### * ** _ __ ` ``` > - + 1. 99. --- ! < & \\ |) ++
              [
                "[",
                "]",
                "(",
                ")",
                "[[",
                "]]",
                "- [ ] ",
                "- [x] ",
                "- [-] ",
                "#tag",
                "#",
                "[a](https://x.example/)",
                "![i](https://x.example/i.png)",
                "https://x.example/a_b*c",
                "202610261200",
                "bonalaku",
                "    ",
                "\t"
              ]

  property "Markdown always gives HTML, at once" do
    check all(text <- pieces(@markdown, ["\n", "\n\n", " ", "\r\n"], 40), max_runs: @runs) do
      used = %{"202610261200" => 1}
      html = Bounded.value!(fn -> Markdown.to_html(text, used) end, text)
      assert is_binary(html)
      # what a note says is text: no tag of its own reaches the page
      refute html =~ "<script"
    end
  end

  # --- iCal --------------------------------------------------------------------

  @ical [
    "BEGIN:VCALENDAR",
    "END:VCALENDAR",
    "BEGIN:VEVENT",
    "END:VEVENT",
    "UID:a",
    "UID:b",
    "SUMMARY:Lunch",
    "DESCRIPTION:a\\nb\\,c",
    " continued",
    "DTSTART:20261026T090000",
    "DTSTART:20261026T090000Z",
    "DTSTART;VALUE=DATE:20261027",
    "DTSTART;TZID=Europe/Stockholm:20261026T090000",
    "DTSTART;TZID=Nowhere:20261026T090000",
    "DTSTART:99999999T999999",
    "DTSTART:20260230",
    "DTSTART:",
    "DTEND:20261026T100000",
    "DTEND;VALUE=DATE:20261020",
    "DURATION:PT1H",
    "DURATION:-P1D",
    "DURATION:P99999999W",
    "RRULE:FREQ=DAILY;COUNT=3",
    "RRULE:FREQ=WEEKLY;INTERVAL=-2;BYDAY=MO,XX",
    "RRULE:FREQ=MONTHLY;BYMONTHDAY=31",
    "RRULE:FREQ=MONTHLY;BYDAY=5FR",
    "RRULE:FREQ=YEARLY;UNTIL=20270101",
    "RRULE:FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=30",
    "RRULE:FREQ=SECONDLY",
    "RRULE:FREQ=MINUTELY;INTERVAL=1",
    "RRULE:FREQ=HOURLY;COUNT=999999",
    "RRULE:INTERVAL=2",
    "RRULE:FREQ=WEEKLY;COUNT=0",
    "EXDATE:20261027T090000",
    "RECURRENCE-ID:20261026T090000",
    "STATUS:CANCELLED",
    "STATUS:TENTATIVE",
    "BEGIN:VTIMEZONE",
    "TZID:Europe/Stockholm",
    "BEGIN:STANDARD",
    "BEGIN:DAYLIGHT",
    "TZOFFSETFROM:+0200",
    "TZOFFSETTO:+0100",
    "TZOFFSETTO:+9999",
    "RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU",
    "END:STANDARD",
    "END:DAYLIGHT",
    "END:VTIMEZONE",
    "BEGIN:VALARM",
    "END:VALARM"
  ]

  # A time zone as calendars send it, so that TZID starts are turned to UTC
  # by its rules.
  @zone [
    "BEGIN:VTIMEZONE",
    "TZID:Europe/Stockholm",
    "BEGIN:DAYLIGHT",
    "TZOFFSETFROM:+0100",
    "TZOFFSETTO:+0200",
    "DTSTART:19700329T020000",
    "RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU",
    "END:DAYLIGHT",
    "BEGIN:STANDARD",
    "TZOFFSETFROM:+0200",
    "TZOFFSETTO:+0100",
    "DTSTART:19701025T030000",
    "RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU",
    "END:STANDARD",
    "END:VTIMEZONE"
  ]

  # A calendar made of blocks: events of random lines, the time zone (perhaps
  # with a line changed), and stray lines; a line is mostly one of the
  # format's, sometimes made of its pieces. `frequency` weighs the choices.
  defp ical_text do
    line =
      frequency([{6, member_of(@ical)}, {1, pieces(@ical, [":", ";", "=", ","], 4, bytes: true)}])

    # most events have the UID and start an event needs, so they get past
    # the first checks
    start = member_of(Enum.filter(@ical, &String.starts_with?(&1, "DTSTART")))

    event =
      map(tuple({member_of(["UID:a", "UID:b", nil]), start, list_of(line, max_length: 8)}), fn
        {uid, start, lines} -> ["BEGIN:VEVENT", uid, start | lines] ++ ["END:VEVENT"]
      end)

    zone =
      map(tuple({integer(0..(length(@zone) - 1)), line}), fn {at, line} ->
        List.replace_at(@zone, at, line)
      end)

    block = frequency([{5, event}, {1, constant(@zone)}, {1, zone}, {1, map(line, &[&1])}])

    map(tuple({list_of(block, max_length: 5), boolean(), member_of(["\r\n", "\n"])}), fn
      {blocks, wrapped, newline} ->
        lines = blocks |> List.flatten() |> Enum.reject(&is_nil/1)

        lines =
          if wrapped,
            do: ["BEGIN:VCALENDAR", "VERSION:2.0"] ++ lines ++ ["END:VCALENDAR"],
            else: lines

        Enum.join(lines, newline) <> newline
    end)
  end

  property "iCal gives events or :not_ical, and the events sync" do
    check all(text <- ical_text(), max_runs: @runs) do
      case Bounded.value!(fn -> ICal.parse(text) end, text) do
        {:ok, events} ->
          db = Core.new_file()
          {:ok, db, cal} = Core.subscribe_calendar(db, "Work", "https://w.example/w.ics")

          assert {:ok, _db, _counts} =
                   Bounded.value!(fn -> Core.sync_calendar(db, cal, events, @now) end, text)

        {:error, :not_ical} ->
          :ok
      end
    end
  end

  # --- feeds (XML) -------------------------------------------------------------

  @feed [
    ~s(<?xml version="1.0" encoding="utf-8"?>),
    ~s(<!DOCTYPE x [<!ENTITY a "b">]>),
    "<rss>",
    ~s(<rss version="2.0">),
    "</rss>",
    "<channel>",
    "</channel>",
    "<item>",
    "</item>",
    "<title>",
    "</title>",
    "<link>",
    "</link>",
    ~s(<link href="https://x.example/a"/>),
    "<guid>",
    "</guid>",
    "<description>",
    "</description>",
    "<pubDate>",
    "</pubDate>",
    "Mon, 26 Oct 2026 10:00:00 GMT",
    "Mon, 32 Foo 2026 25:61:61 +9999",
    ~s(<feed xmlns="http://www.w3.org/2005/Atom">),
    "</feed>",
    "<entry>",
    "</entry>",
    "<id>",
    "</id>",
    "<updated>",
    "</updated>",
    "2026-10-26T10:00:00Z",
    "2026-13-40T99:99:99+25:00",
    ~s(<summary type="html">),
    "</summary>",
    ~s(<content type="xhtml">),
    "</content>",
    "<rdf:RDF>",
    "</rdf:RDF>",
    "<![CDATA[",
    "]]>",
    "<!--",
    "-->",
    "&amp;",
    "&lt;p&gt;",
    "&#x41;",
    "&#99999999;",
    "&#xD800;",
    "&bogus;",
    "&",
    "<",
    ">",
    "</",
    "/>",
    "<p>",
    "<br>",
    "<script>",
    ~s(<a href="),
    ~s(">)
  ]

  @entry_fields ~w(title link guid description pubDate id updated published summary content author)

  # A feed as a tree: RSS, Atom or RDF, their entries' fields holding text or
  # the format's pieces, then perhaps damaged (a piece put in anywhere, or
  # the text cut short), as a broken server or a hostile one would send it.
  defp feed_text do
    leaf = one_of([member_of(@feed), string(:printable, max_length: 10), binary(max_length: 4)])

    field =
      map(tuple({member_of(@entry_fields), list_of(leaf, max_length: 3)}), fn {name, inside} ->
        "<#{name}>" <> Enum.join(inside) <> "</#{name}>"
      end)

    entries =
      list_of(tuple({member_of(~w(item entry)), list_of(field, max_length: 6)}), max_length: 4)

    tree =
      map(tuple({member_of([:rss, :atom, :rdf]), field, entries}), fn {kind, title, entries} ->
        inside =
          Enum.map_join(entries, fn {name, fields} ->
            "<#{name}>" <> Enum.join(fields) <> "</#{name}>"
          end)

        case kind do
          :rss -> ~s(<rss version="2.0"><channel>) <> title <> inside <> "</channel></rss>"
          :atom -> ~s(<feed xmlns="http://www.w3.org/2005/Atom">) <> title <> inside <> "</feed>"
          :rdf -> "<rdf:RDF><channel>" <> title <> "</channel>" <> inside <> "</rdf:RDF>"
        end
      end)

    damage = list_of(tuple({float(min: 0.0, max: 1.0), member_of(@feed)}), max_length: 3)

    map(tuple({tree, damage, float(min: 0.0, max: 1.2)}), fn {text, damage, cut} ->
      text =
        Enum.reduce(damage, text, fn {at, piece}, text ->
          {before, rest} = String.split_at(text, round(at * String.length(text)))
          before <> piece <> rest
        end)

      if cut < 1.0, do: String.slice(text, 0, round(cut * String.length(text))), else: text
    end)
  end

  property "a feed gives entries or :not_a_feed, and the entries sync" do
    check all(text <- feed_text(), max_runs: @runs) do
      case Bounded.value!(fn -> FeedParser.parse(text) end, text) do
        {:ok, %{title: title, entries: entries}} ->
          assert is_binary(title)
          db = Core.new_file()
          {:ok, db, feed} = Core.subscribe_feed(db, "News", "https://n.example/feed")

          assert {:ok, _db, _counts} =
                   Bounded.value!(fn -> Core.sync_feed(db, feed, entries, @now) end, text)

        {:error, :not_a_feed} ->
          :ok
      end
    end
  end

  # --- .AG files -----------------------------------------------------------------

  # The smallest real Agenda file; damage done to it reaches deeper into the
  # reader than random bytes would. Lotus's starter is not in the public
  # copy (meeting 2026-10-28-5, § 7), where RICH.AG, made in Agenda for
  # the tests, takes its place.
  @ag if File.exists?("test/fixtures/ag/INFOSIFT.AG"),
        do: File.read!("test/fixtures/ag/INFOSIFT.AG"),
        else: File.read!("test/fixtures/ag/RICH.AG")

  # A damage: some bytes set to random values, or the file cut short.
  defp damaged_ag do
    size = byte_size(@ag)

    one_of([
      map(
        list_of(tuple({integer(0..(size - 1)), integer(0..255)}), min_length: 1, max_length: 30),
        fn changes ->
          Enum.reduce(changes, @ag, fn {at, byte}, bytes ->
            <<before::binary-size(^at), _, rest::binary>> = bytes
            <<before::binary, byte, rest::binary>>
          end)
        end
      ),
      map(integer(1..size), &binary_part(@ag, 0, &1)),
      map(binary(min_length: 1024, max_length: 4096), &("T" <> &1))
    ])
  end

  property "a damaged .AG file imports or is refused" do
    check all(bytes <- damaged_ag(), max_runs: div(@runs, 2)) do
      case Bounded.value!(fn -> Core.import_ag(bytes, clock: @now) end, "this .AG", 5_000) do
        {:ok, _db, _report} -> :ok
        {:error, _reason} -> :ok
      end
    end
  end

  # --- JSON ------------------------------------------------------------------------

  # The golden file's JSON, decoded: every stored field is in it.
  @golden Agendum.Starters.Golden.build() |> JSONFile.encode() |> JSON.decode!()

  defp junk do
    one_of([
      constant(nil),
      boolean(),
      integer(),
      float(),
      string(:printable, max_length: 8),
      constant(-1),
      constant(0),
      constant(""),
      constant([]),
      constant(%{}),
      list_of(integer(), max_length: 3),
      map_of(string(:alphanumeric, max_length: 4), integer(), max_length: 2)
    ])
  end

  # Replaces the value at a random place in the document (`path` picks a
  # child at each level) with junk, or deletes it.
  defp mutate(_doc, [], value), do: value

  defp mutate(doc, [pick | path], value) when is_map(doc) and map_size(doc) > 0 do
    key = doc |> Map.keys() |> Enum.sort() |> Enum.at(rem(pick, map_size(doc)))

    case {path, value} do
      {[], :delete} -> Map.delete(doc, key)
      _ -> Map.put(doc, key, mutate(doc[key], path, value))
    end
  end

  defp mutate(doc, [pick | path], value) when is_list(doc) and doc != [] do
    at = rem(pick, length(doc))

    case {path, value} do
      {[], :delete} -> List.delete_at(doc, at)
      _ -> List.update_at(doc, at, &mutate(&1, path, value))
    end
  end

  defp mutate(_doc, _path, :delete), do: nil
  defp mutate(_doc, _path, value), do: value

  property "a damaged JSON file decodes or says what is wrong" do
    check all(
            changes <-
              list_of(
                tuple(
                  {list_of(integer(0..1000), min_length: 1, max_length: 6),
                   one_of([constant(:delete), junk()])}
                ),
                min_length: 1,
                max_length: 4
              ),
            max_runs: @runs
          ) do
      doc = Enum.reduce(changes, @golden, fn {path, value}, doc -> mutate(doc, path, value) end)

      case Bounded.value!(fn -> JSONFile.decode_document(doc) end, changes) do
        {:ok, %Core.Database{}} -> :ok
        {:error, message} -> assert is_binary(message)
      end
    end
  end

  # --- dates -----------------------------------------------------------------------

  @dates ~w(today tomorrow yesterday next last every this end of the week month quarter year
            monday fri jan january feb 29 30 31 1 2 12 13 24 25 99 0 00 2026 1900 9999 99999999
            am pm noon midnight at in on before after days weeks months years hours minutes
            ago from now beginning other second third last weekday weekdays working day
            idag imorgon igår nästa förra varje måndag fredag januari dagar veckor om kl efter)
  @date_separators [" ", " ", "-", "/", ".", ":", ",", "+", "'"]
  @phrases [
    "today",
    "tomorrow at 3 pm",
    "next monday",
    "every other friday",
    "every weekday at 9am",
    "jan 31",
    "feb 29",
    "end of next month",
    "in 3 weeks",
    "3 days after tomorrow",
    "2026-02-29",
    "31/12/9999",
    "12/31/0001",
    "the last day of the month",
    "every 0 days",
    "every 99999999 weeks",
    "in 99999999 years",
    "om 2 dagar",
    "nästa fredag kl 15",
    "varje måndag"
  ]

  # Mostly a few date words with spaces, as people type them; sometimes the
  # words run together with other separators and random text.
  # Random words seldom make a date, so phrases that do are given too,
  # whole or with words added, to reach the parser's deeper rules.
  defp date_text do
    words = map(list_of(member_of(@dates), min_length: 1, max_length: 5), &Enum.join(&1, " "))
    phrase = member_of(@phrases)

    frequency([
      {2, phrase},
      {2, map(tuple({phrase, words}), fn {p, w} -> p <> " " <> w end)},
      {1, map(tuple({words, phrase}), fn {w, p} -> w <> " " <> p end)},
      {2, words},
      {1, pieces(@dates, @date_separators, 12)}
    ])
  end

  property "a typed date gives a date or :error" do
    check all(text <- date_text(), max_runs: @runs) do
      opts = [languages: [DateLanguage.English, DateLanguage.Swedish]]

      case Bounded.value!(fn -> DateParser.parse_recurring(text, @now, opts) end, text) do
        {:ok, %Date{}, _time, _rule} -> :ok
        :error -> :ok
      end

      case Bounded.value!(fn -> DateParser.extract_recurring(text, @now, opts) end, text) do
        :none -> :ok
        found -> assert elem(found, 0) == :ok
      end
    end
  end
end
