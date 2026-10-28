# Writes the hostile files in this folder (ROADMAP, Sharpen the saw: a
# collection of hostile files). Every file is made here, so the collection
# can be read, changed and made again:
#
#     mix run test/fixtures/hostile/make.exs
#
# One folder per parser; `test/agendum/hostile_files_test.exs` reads every
# file in them through its parser. A bug of this kind found later adds its
# file here, under a name that says what it does.

defmodule Hostile do
  @moduledoc false
  @here Path.dirname(__ENV__.file)

  def write(path, bytes) do
    file = Path.join(@here, path)
    File.mkdir_p!(Path.dirname(file))
    File.write!(file, bytes)
  end

  def calendar(body), do: "BEGIN:VCALENDAR\r\nVERSION:2.0\r\n" <> body <> "END:VCALENDAR\r\n"

  def event(lines),
    do: "BEGIN:VEVENT\r\n" <> Enum.map_join(lines, &(&1 <> "\r\n")) <> "END:VEVENT\r\n"

  def rss(items),
    do:
      ~s(<?xml version="1.0"?><rss version="2.0"><channel><title>Hostile</title>) <>
        items <> "</channel></rss>"

  # An .AG file is a header of 1024 bytes and 64-byte blocks; block n
  # starts at 0x400 + 64·n, word w of it two bytes from 2·w
  # (docs/AGENDA_FILE_FORMAT.md).
  def set_word(bytes, offset, value) do
    <<before::binary-size(^offset), _::little-16, rest::binary>> = bytes
    <<before::binary, value::little-16, rest::binary>>
  end

  def set_block_word(bytes, block, word, value),
    do: set_word(bytes, 0x400 + 64 * block + 2 * word, value)
end

# Lotus's starter, damaged below; not in the public copy (meeting
# 2026-10-28-5, § 7), where the files made from it are left out too
ag =
  if File.exists?("test/fixtures/ag/INFOSIFT.AG"), do: File.read!("test/fixtures/ag/INFOSIFT.AG")

golden = Agendum.Starters.Golden.build() |> Agendum.Core.JSONFile.encode()

# --- Markdown -----------------------------------------------------------------

# the slice C review: a line starting with # that is no heading looped for ever
Hostile.write("markdown/hashtag-loop.md", "#elixir is fun\n#\n####### x\n> #tag\n")
# Zettel links inside addresses and code are not links (slice C review)
Hostile.write(
  "markdown/zettel-in-code.md",
  "`[[bonalaku]]` and https://x.example/[[a]] and [t](https://x.example/202610261200)\n"
)

Hostile.write(
  "markdown/stars.md",
  String.duplicate("*", 20_000) <> "\n" <> String.duplicate("_a", 10_000)
)

Hostile.write(
  "markdown/brackets.md",
  String.duplicate("[", 10_000) <> String.duplicate("](", 5_000)
)

Hostile.write("markdown/backticks.md", String.duplicate("`", 20_000) <> "\n```\nnever closed\n")
Hostile.write("markdown/deep-quote.md", String.duplicate(">", 5_000) <> " deep\n")

Hostile.write(
  "markdown/deep-list.md",
  Enum.map_join(0..399, "\n", &(String.duplicate(" ", &1) <> "- [ ] item"))
)

Hostile.write(
  "markdown/escapes.md",
  String.duplicate("\\", 20_001) <> "\n" <> String.duplicate("![", 5_000)
)

Hostile.write(
  "markdown/html.md",
  "<script>alert(1)</script> &amp; <img src=x onerror=alert(1)> " <>
    "[x](javascript:alert(1)) ![y](javascript:alert(1))\n"
)

# --- iCal ---------------------------------------------------------------------

Hostile.write(
  "ical/interval-zero.ics",
  Hostile.calendar(
    Hostile.event([
      "UID:z",
      "DTSTART:20261026T090000",
      "SUMMARY:Stand-up",
      "RRULE:FREQ=WEEKLY;INTERVAL=0;BYDAY=MO,WE"
    ])
  )
)

Hostile.write(
  "ical/latin1.ics",
  Hostile.calendar(
    Hostile.event([
      "UID:l1",
      "DTSTART;VALUE=DATE:20261027",
      "SUMMARY:Lunch at Caf" <> <<0xE9>>,
      "ORGANIZER;CN=M" <> <<0xFC>> <> "ller:mailto:m@example.com"
    ])
  )
)

Hostile.write(
  "ical/secondly-forever.ics",
  Hostile.calendar(
    Hostile.event(["UID:s", "DTSTART:20200101T000000", "RRULE:FREQ=SECONDLY"]) <>
      Hostile.event([
        "UID:m",
        "DTSTART:20200101T000000",
        "RRULE:FREQ=MINUTELY;UNTIL=99991231T000000"
      ]) <>
      Hostile.event(["UID:c", "DTSTART:20200101T000000", "RRULE:FREQ=HOURLY;COUNT=2147483647"])
  )
)

# rules no day ever meets: the 30th of February, the fifth Monday every year
Hostile.write(
  "ical/never.ics",
  Hostile.calendar(
    Hostile.event([
      "UID:f",
      "DTSTART;VALUE=DATE:20260101",
      "RRULE:FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=30"
    ]) <>
      Hostile.event(["UID:g", "DTSTART;VALUE=DATE:20260101", "RRULE:FREQ=MONTHLY;BYMONTHDAY=32"]) <>
      Hostile.event(["UID:h", "DTSTART;VALUE=DATE:20260101", "RRULE:FREQ=YEARLY;BYDAY=60MO"]) <>
      Hostile.event(["UID:i", "DTSTART;VALUE=DATE:20260101", "RRULE:FREQ=WEEKLY;BYDAY=XX"])
  )
)

Hostile.write(
  "ical/folded-forever.ics",
  Hostile.calendar(
    Hostile.event([
      "UID:fold",
      "DTSTART:20261026T090000",
      "SUMMARY:start" <> String.duplicate("\r\n x", 20_000)
    ])
  )
)

Hostile.write(
  "ical/no-end.ics",
  "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:n\r\nDTSTART:20261026T090000\r\nBEGIN:VEVENT\r\nBEGIN:VTIMEZONE\r\n"
)

Hostile.write(
  "ical/bad-zone.ics",
  Hostile.calendar(
    "BEGIN:VTIMEZONE\r\nTZID:Bad\r\nBEGIN:STANDARD\r\nTZOFFSETFROM:+9999\r\nTZOFFSETTO:-9999\r\n" <>
      "DTSTART:00000000T000000\r\nRRULE:FREQ=YEARLY;BYMONTH=13;BYDAY=-9SU\r\nEND:STANDARD\r\nEND:VTIMEZONE\r\n" <>
      Hostile.event([
        "UID:b",
        "DTSTART;TZID=Bad:20261026T090000",
        "DTEND;TZID=Bad:20261026T080000"
      ])
  )
)

Hostile.write(
  "ical/bad-numbers.ics",
  Hostile.calendar(
    Hostile.event(["UID:d1", "DTSTART:99999999T999999", "DURATION:P99999999999W"]) <>
      Hostile.event([
        "UID:d2",
        "DTSTART:20261026T090000",
        "DURATION:-P1D",
        "RRULE:FREQ=DAILY;COUNT=-5"
      ]) <>
      Hostile.event([
        "UID:d3",
        "DTSTART:20261026",
        "RRULE:FREQ=DAILY;INTERVAL=99999999999999999999"
      ]) <>
      Hostile.event(["UID:d4", "DTSTART:", "DTEND:x", "EXDATE:y"])
  )
)

Hostile.write(
  "ical/utf16.ics",
  :unicode.characters_to_binary(Hostile.calendar(""), :utf8, {:utf16, :little})
)

Hostile.write(
  "ical/nul-bytes.ics",
  Hostile.calendar(Hostile.event(["UID:\0", "DTSTART:2026\0", "SUMMARY:\0\0"]))
)

# --- feeds --------------------------------------------------------------------

laughs =
  Enum.map_join(1..9, "\n", fn n ->
    ~s(<!ENTITY lol#{n} ") <> String.duplicate("&lol#{n - 1};", 10) <> ~s(">)
  end)

Hostile.write(
  "feed/billion-laughs.xml",
  ~s(<?xml version="1.0"?><!DOCTYPE rss [<!ENTITY lol0 "lol">\n#{laughs}]>) <>
    Hostile.rss("<item><title>&lol9;</title></item>")
)

Hostile.write("feed/deep-nesting.xml", Hostile.rss(String.duplicate("<item>", 20_000)))
Hostile.write("feed/unclosed-cdata.xml", Hostile.rss("<item><title><![CDATA[never closed"))
Hostile.write("feed/unclosed-comment.xml", Hostile.rss("<item><title>a</title><!-- never closed"))

Hostile.write(
  "feed/many-entries.xml",
  Hostile.rss(
    Enum.map_join(1..1_000, &"<item><guid>#{&1}</guid><title>Entry #{&1}</title></item>")
  )
)

Hostile.write(
  "feed/entities.xml",
  Hostile.rss(
    "<item><title>&#0;&#xD800;&#1114112;&#99999999999999999999;&#x;&#;&amp&bogus;&</title>" <>
      "<description>&lt;script&gt;alert(1)&lt;/script&gt;&lt;p&gt;text</description></item>"
  )
)

Hostile.write(
  "feed/not-utf8.xml",
  Hostile.rss("<item><title>Caf" <> <<0xE9, 0xFF, 0xFE>> <> "</title></item>")
)

Hostile.write(
  "feed/attributes.xml",
  ~s(<feed xmlns="http://www.w3.org/2005/Atom" ) <>
    String.duplicate(~s(a="1" ), 10_000) <> ~s(b="unclosed><entry><id>1</id></entry></feed>)
)

Hostile.write(
  "feed/bad-dates.xml",
  Hostile.rss(
    "<item><guid>1</guid><pubDate>Mon, 32 Foo 2026 25:61:61 +9999</pubDate></item>" <>
      "<item><guid>2</guid><pubDate>99999999999999999999</pubDate></item>" <>
      ~s(<item><guid>3</guid><pubDate>2026-13-40T99:99:99+25:00</pubDate></item>)
  )
)

Hostile.write(
  "feed/script.xml",
  ~s(<feed xmlns="http://www.w3.org/2005/Atom"><title>T</title><entry><id>1</id>) <>
    ~s{<summary type="html">&lt;script&gt;alert(1)&lt;/script&gt;</summary>} <>
    ~s{<content type="xhtml"><div><script>alert(1)</script></div></content></entry></feed>}
)

Hostile.write("feed/empty.xml", "")
Hostile.write("feed/bom-only.xml", <<0xEF, 0xBB, 0xBF>>)

# --- .AG files ----------------------------------------------------------------

Hostile.write("ag/header-only.AG", "T" <> :binary.copy(<<0>>, 1023))

# `if` with no `else` gives nil, and does nothing, when the starter is missing
if ag do
  Hostile.write("ag/cut-after-header.AG", binary_part(ag, 0, 1024))
  Hostile.write("ag/last-block-huge.AG", Hostile.set_word(ag, 0x3A, 0xFFFF))

  # The slice A review: a category reachable from many parents was read once
  # for each path to it. MAIN (block 9) gets a chain of blocks, each the first
  # child and the next sibling of the one before: 2^25 paths, 26 blocks.
  many =
    Enum.reduce(250..274, Hostile.set_block_word(ag, 9, 17, 250), fn n, bytes ->
      bytes
      |> Hostile.set_block_word(n, 0, n)
      |> Hostile.set_block_word(n, 17, n + 1)
      |> Hostile.set_block_word(n, 15, n + 1)
    end)

  Hostile.write("ag/many-parents.AG", many)

  # MAIN its own first child and next sibling
  Hostile.write(
    "ag/cycle.AG",
    ag |> Hostile.set_block_word(9, 17, 9) |> Hostile.set_block_word(9, 15, 9)
  )

  # every text chain pointing at itself, the root at a block past the end
  Hostile.write(
    "ag/self-chains.AG",
    Enum.reduce(
      1..294,
      Hostile.set_word(ag, 0x40, 0xFFF0),
      &Hostile.set_block_word(&2, &1, 2, &1)
    )
  )
end

# --- JSON ---------------------------------------------------------------------

Hostile.write(
  "json/deep-array.json",
  String.duplicate("[", 20_000) <> String.duplicate("]", 20_000)
)

Hostile.write(
  "json/huge-number.json",
  String.replace(golden, ~s("version": ), ~s("version": 1e400, "x": ), global: false)
)

Hostile.write("json/bom.json", <<0xEF, 0xBB, 0xBF>> <> golden)
Hostile.write("json/not-json.json", <<0xFF, 0x00, 0x7B, 0x22>>)
Hostile.write("json/other-format.json", ~s({"format": "agendum-json", "version": 999999}))

Hostile.write(
  "json/wrong-shape.json",
  ~s({"format": "agendum-json", "version": 1, "items": "none"})
)

doc = JSON.decode!(golden)

# every item given the same id
same =
  Map.update!(doc, "items", fn items -> Enum.map(items, &Map.put(&1, "id", 7)) end)

Hostile.write("json/same-ids.json", JSON.encode!(same))

# every reference pointing at a category that is not there
dangling =
  Map.update!(doc, "items", fn items ->
    Enum.map(items, fn item -> Map.put(item, "categories", [999_999, -1, 0]) end)
  end)

Hostile.write("json/dangling-references.json", JSON.encode!(dangling))

# --- dates --------------------------------------------------------------------

Hostile.write(
  "dates/typed.txt",
  Enum.join(
    [
      "every 0 days",
      "every -1 weeks",
      "in 99999999999999999999 years",
      "99999999",
      "31/12/9999 at 25:61",
      "0/0/0",
      "feb 30",
      "the 0th of never",
      String.duplicate("next ", 2_000) <> "monday",
      String.duplicate("1 ", 2_000),
      "every other other other friday",
      "3 days after 3 days after 3 days after tomorrow",
      "varje 0 dagar",
      "om 99999999999 veckor"
    ],
    "\n"
  )
)
