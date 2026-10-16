defmodule Agendum.Core.FeedParserTest do
  @moduledoc "Reading feeds: RSS 2.0, RSS 1.0, Atom, dates and HTML (R75)."
  use ExUnit.Case, async: true

  alias Agendum.Core.{FeedParser, Xml}

  @rss """
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE rss>
  <rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/">
  <channel>
    <title>Owl &amp; Co</title>
    <item>
      <title>Honey prices &lt;up&gt;</title>
      <link>https://wood.example/honey</link>
      <guid isPermaLink="false">honey-1</guid>
      <pubDate>Sat, 17 Oct 2026 08:30:00 +0200</pubDate>
      <description><![CDATA[<p>Pooh is <b>worried</b>.</p><p>Very.</p><script>alert(1)</script>]]></description>
    </item>
    <item>
      <title>No guid</title>
      <link>https://wood.example/no-guid</link>
      <description>Plain &amp; simple</description>
    </item>
  </channel>
  </rss>
  """

  @atom """
  <?xml version="1.0" encoding="utf-8"?>
  <feed xmlns="http://www.w3.org/2005/Atom">
    <title type="text">Piglet's Journal</title>
    <entry>
      <title>A very small animal</title>
      <link rel="alternate" href="https://piglet.example/small"/>
      <link rel="self" href="https://piglet.example/small.atom"/>
      <id>tag:piglet.example,2026:1</id>
      <updated>2026-10-16T22:15:00Z</updated>
      <summary type="html">&lt;p&gt;Brave &amp;amp; small&lt;/p&gt;</summary>
    </entry>
  </feed>
  """

  @rdf """
  <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://purl.org/rss/1.0/" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel><title>Rabbit's List</title></channel>
    <item rdf:about="https://rabbit.example/1">
      <title>Things to do</title>
      <link>https://rabbit.example/1</link>
      <dc:date>2026-10-15</dc:date>
    </item>
  </rdf:RDF>
  """

  test "RSS 2.0: title, entries, guid, date in UTC, HTML as text" do
    assert {:ok, feed} = FeedParser.parse(@rss)
    assert feed.title == "Owl & Co"
    assert [honey, plain] = feed.entries

    assert honey == %{
             id: "honey-1",
             title: "Honey prices <up>",
             link: "https://wood.example/honey",
             summary: "Pooh is worried.\n\nVery.",
             published: ~N[2026-10-17 06:30:00]
           }

    # without a guid the link is the id; without a date, nil
    assert plain.id == "https://wood.example/no-guid"
    assert plain.summary == "Plain & simple"
    assert plain.published == nil
  end

  test "Atom: the alternate link, the id, an escaped HTML summary" do
    assert {:ok, %{title: "Piglet's Journal", entries: [entry]}} = FeedParser.parse(@atom)
    assert entry.link == "https://piglet.example/small"
    assert entry.id == "tag:piglet.example,2026:1"
    assert entry.summary == "Brave & small"
    assert entry.published == ~N[2026-10-16 22:15:00]
  end

  test "RSS 1.0 (RDF), with a Dublin Core date" do
    assert {:ok, %{title: "Rabbit's List", entries: [entry]}} = FeedParser.parse(@rdf)
    assert entry.published == ~N[2026-10-15 00:00:00]
  end

  test "not a feed" do
    assert FeedParser.parse("<html><body>hello</body></html>") == {:error, :not_a_feed}
    assert FeedParser.parse("just text") == {:error, :not_a_feed}
  end

  test "a broken feed is read as far as it goes" do
    broken = "<rss><channel><title>Half</title><item><title>One</title></item><item><title>Two"
    assert {:ok, %{entries: [%{title: "One"}, %{title: "Two"}]}} = FeedParser.parse(broken)
  end

  test "dates: RFC 822 with zones, two-digit years, RFC 3339 with offsets" do
    assert FeedParser.date("Fri, 16 Oct 2026 20:00:00 GMT") == ~N[2026-10-16 20:00:00]
    assert FeedParser.date("16 Oct 26 20:00 EST") == ~N[2026-10-17 01:00:00]
    assert FeedParser.date("2026-10-16T20:00:00+02:00") == ~N[2026-10-16 18:00:00]
    assert FeedParser.date("whenever") == nil
  end

  test "HTML as text: lists, breaks, entities, scripts gone" do
    html = "<ul><li>Honey</li><li>Haycorns &amp; more</li></ul>Line<br>break &#233; &#x2603;"
    assert FeedParser.text(html) == "• Honey\n• Haycorns & more\nLine\nbreak é ☃"
    assert FeedParser.text("<style>p{}</style><p>a</p>") == "a"
  end

  test "the XML reader makes no atoms from a feed's names" do
    names = for i <- 1..50, do: "never_an_atom_#{i}_#{System.unique_integer([:positive])}"
    Xml.parse("<rss>" <> Enum.map_join(names, &"<#{&1} #{&1}='x'/>") <> "</rss>")

    for name <- names,
        do: assert_raise(ArgumentError, fn -> String.to_existing_atom(name) end)
  end
end
