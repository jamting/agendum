defmodule Agendum.Core.FeedParser do
  @moduledoc """
  Reads a feed (R75): RSS 2.0, RSS 1.0 (RDF) and Atom, through
  `Agendum.Core.Xml`. Pure; everything in a feed is data, never
  instructions, and HTML in it becomes plain text (`text/1`).

  An entry is `%{id, title, link, summary, published}`: its id the guid
  (Atom's id), else the link, else the title and date; its summary plain
  text; its published moment a `NaiveDateTime` in UTC, or nil.
  """

  alias Agendum.Core.Xml

  @type entry :: %{
          id: String.t(),
          title: String.t(),
          link: String.t(),
          summary: String.t(),
          published: NaiveDateTime.t() | nil
        }

  @doc "The feed's title and entries, or `{:error, :not_a_feed}`."
  @spec parse(String.t()) :: {:ok, %{title: String.t(), entries: [entry]}} | {:error, :not_a_feed}
  def parse(text) do
    root = text |> Xml.parse() |> Xml.elements() |> List.first()

    case root && Xml.local(elem(root, 0)) do
      "rss" -> {:ok, rss(Xml.child(root, ["channel"]) || root)}
      "rdf" -> {:ok, rdf(root)}
      "feed" -> {:ok, atom(root)}
      _ -> {:error, :not_a_feed}
    end
  end

  # RSS 2.0: <channel><item>…; RSS 1.0 has its items beside the channel
  defp rss(channel),
    do: %{
      title: Xml.child_text(channel, ["title"]),
      entries: Enum.map(Xml.children(channel, "item"), &rss_item/1)
    }

  defp rdf(root) do
    %{
      title:
        root
        |> Xml.child(["channel"])
        |> then(&if(&1, do: Xml.child_text(&1, ["title"]), else: "")),
      entries: Enum.map(Xml.children(root, "item"), &rss_item/1)
    }
  end

  defp rss_item(item) do
    title = item |> Xml.child_text(["title"]) |> one_line()
    link = Xml.child_text(item, ["link"])
    summary = Xml.child_text(item, ["encoded", "description", "summary"])
    published = item |> Xml.child_text(["pubdate", "date", "published", "updated"]) |> date()
    guid = Xml.child_text(item, ["guid"])

    entry(guid, title, link, summary, published)
  end

  defp atom(feed) do
    %{
      title: feed |> Xml.child_text(["title"]) |> one_line(),
      entries: Enum.map(Xml.children(feed, "entry"), &atom_entry/1)
    }
  end

  defp atom_entry(entry) do
    links = Xml.children(entry, "link")

    link =
      Enum.find_value(links, fn {_, attrs, _} ->
        if Map.get(attrs, "rel", "alternate") == "alternate", do: attrs["href"]
      end) || Enum.find_value(links, fn {_, attrs, _} -> attrs["href"] end) || ""

    summary = Xml.child_text(entry, ["summary", "content"])
    published = entry |> Xml.child_text(["published", "updated"]) |> date()

    entry(
      Xml.child_text(entry, ["id"]),
      one_line(Xml.child_text(entry, ["title"])),
      link,
      summary,
      published
    )
  end

  defp entry(id, title, link, summary, published) do
    title = if title == "", do: "(no title)", else: title

    id =
      cond do
        id != "" -> id
        link != "" -> link
        true -> title <> " " <> to_string(published)
      end

    %{id: id, title: title, link: String.trim(link), summary: text(summary), published: published}
  end

  # a title is plain text (its entities already read): one line of it
  defp one_line(text), do: text |> String.replace(~r/\s+/u, " ") |> String.trim()

  # --- dates ----------------------------------------------------------------------

  @months ~w(jan feb mar apr may jun jul aug sep oct nov dec)

  # the zones RFC 822 names, as hours from UTC
  @zones %{"ut" => 0, "gmt" => 0, "z" => 0, "est" => -5, "edt" => -4, "cst" => -6, "cdt" => -5}
         |> Map.merge(%{"mst" => -7, "mdt" => -6, "pst" => -8, "pdt" => -7})

  @doc """
  A feed's date in UTC: RFC 822 (`Sat, 17 Oct 2026 08:00:00 +0200`, RSS)
  or RFC 3339 (`2026-10-17T08:00:00Z`, Atom); nil for anything else.
  """
  @spec date(String.t()) :: NaiveDateTime.t() | nil
  def date(""), do: nil

  def date(text) do
    text = String.trim(text)

    case DateTime.from_iso8601(text) do
      {:ok, dt, _offset} -> DateTime.to_naive(dt)
      {:error, _} -> iso_without_zone(text) || rfc822(text)
    end
  end

  defp iso_without_zone(text) do
    case NaiveDateTime.from_iso8601(text) do
      {:ok, naive} ->
        naive

      {:error, _} ->
        case Date.from_iso8601(String.slice(text, 0, 10)) do
          {:ok, d} -> NaiveDateTime.new!(d, ~T[00:00:00])
          {:error, _} -> nil
        end
    end
  end

  @rfc822 ~r/^(?:[A-Za-z]{3},?\s+)?(\d{1,2})\s+([A-Za-z]{3})[a-z]*\s+(\d{2,4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?\s*([+-]\d{4}|[A-Za-z]+)?/

  defp rfc822(text) do
    with [_ | parts] <- Regex.run(@rfc822, text),
         [day, mon, year | rest] = parts ++ List.duplicate("", 7 - length(parts)),
         month when month != nil <- Enum.find_index(@months, &(&1 == String.downcase(mon))),
         {:ok, date} <- Date.new(year(year), month + 1, String.to_integer(day)),
         {:ok, time} <- time(Enum.take(rest, 3)) do
      date
      |> NaiveDateTime.new!(time)
      |> NaiveDateTime.add(-offset(Enum.at(rest, 3, "")), :second)
    else
      _ -> nil
    end
  end

  defp year(y) when byte_size(y) == 2, do: 2000 + String.to_integer(y)
  defp year(y), do: String.to_integer(y)

  defp time(["", _, _]), do: {:ok, ~T[00:00:00]}
  defp time([h, m, ""]), do: Time.new(String.to_integer(h), String.to_integer(m), 0)

  defp time([h, m, s]),
    do: Time.new(String.to_integer(h), String.to_integer(m), String.to_integer(s))

  # seconds east of UTC
  defp offset(<<sign, h::binary-size(2), m::binary-size(2)>>) when sign in [?+, ?-] do
    seconds = String.to_integer(h) * 3600 + String.to_integer(m) * 60
    if sign == ?-, do: -seconds, else: seconds
  end

  defp offset(zone), do: Map.get(@zones, String.downcase(zone), 0) * 3600

  # --- HTML as text -------------------------------------------------------------------

  @doc """
  HTML as plain text: tags removed (scripts and styles with what is in
  them), entities decoded, paragraphs, line breaks and list items as
  lines, other runs of space as one.
  """
  @spec text(String.t()) :: String.t()
  def text(html) do
    html
    |> then(&Regex.replace(~r/<(script|style)\b.*?<\/\1\s*>/is, &1, ""))
    |> then(&Regex.replace(~r/<!--.*?-->/s, &1, ""))
    |> then(&Regex.replace(~r/<li\b[^>]*>/i, &1, "\n• "))
    |> then(
      &Regex.replace(
        ~r/<(br|\/p|\/div|\/h[1-6]|\/tr|\/blockquote|p|div|h[1-6]|\/?ul|\/?ol)\b[^>]*>/i,
        &1,
        "\n"
      )
    )
    |> then(&Regex.replace(~r/<[^>]*>/s, &1, ""))
    |> Xml.entities()
    |> String.split("\n")
    |> Enum.map(&(&1 |> String.replace(~r/[ \t\r\f\v ]+/u, " ") |> String.trim()))
    |> Enum.chunk_by(&(&1 == ""))
    |> Enum.reject(&(hd(&1) == ""))
    |> Enum.map_join("\n\n", &Enum.join(&1, "\n"))
  end
end
