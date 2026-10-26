defmodule Agendum.Core.Extras.Markdown do
  @moduledoc """
  A small Markdown of our own, for the micro-blog's posts (R74): a note
  becomes HTML. Pure, and with no package (ADR 0021).

  Blocks, separated by blank lines:

    * paragraphs; a line break inside one stays a space
    * headings, `#` to `######`
    * code blocks between ` ``` ` lines, kept as they are
    * quotes, lines starting with `>`
    * lists: `- ` or `* ` items, or `1. ` numbered ones
    * task boxes, the owner's three: `- [ ]` to do, `- [x]` done and
      `- [-]` cancelled (struck through)
    * a rule, `---`

  In a line: `*emphasis*` or `_emphasis_`, `**strong**`, `` `code` ``,
  `[text](https://…)` links, `![alt](https://…)` images, bare `https://`
  addresses, and Zettel links (R73b) through the `link` function given:
  `[[bonalaku]]`, or an id an item has. A backslash keeps the next
  character as it is. Everything else is text: `<` and `&` are escaped,
  so a note can never put HTML or a script in a page.
  """

  alias Agendum.Core.Extras.ZettelLinks

  @typedoc """
  How a Zettel link becomes HTML: given the item it points at (nil for a
  broken link) and the id as written, the HTML to put in its place.
  """
  @type link_fun :: (Agendum.Core.Database.id() | nil, String.t() -> String.t())

  @doc """
  The HTML of `text`. `used` is the Zettel ids in use (number to item) and
  `link` turns a link into HTML (see `t:link_fun/0`).
  """
  @spec to_html(String.t(), map, link_fun) :: String.t()
  def to_html(text, used \\ %{}, link \\ &default_link/2) do
    text
    |> String.replace("\r\n", "\n")
    |> String.split("\n")
    |> blocks([])
    |> Enum.map_join("\n", &block_html(&1, used, link))
  end

  @doc "A link without a target page: the id as written, in a span."
  @spec default_link(term, String.t()) :: String.t()
  def default_link(_target, word), do: ~s(<span class="zettel">#{escape(word)}</span>)

  # --- blocks ------------------------------------------------------------------

  # The lines are cut into blocks, each `{kind, lines}`, in order. Each
  # clause looks at the next line and takes what belongs to its block.
  defp blocks([], acc), do: Enum.reverse(acc)

  defp blocks([line | rest], acc) do
    trimmed = String.trim(line)

    cond do
      trimmed == "" ->
        blocks(rest, acc)

      String.starts_with?(trimmed, "```") ->
        {code, rest} = Enum.split_while(rest, &(not String.starts_with?(String.trim(&1), "```")))
        blocks(Enum.drop(rest, 1), [{:code, code} | acc])

      Regex.match?(~r/^(-{3,}|\*{3,})$/, trimmed) ->
        blocks(rest, [{:rule, []} | acc])

      heading = Regex.run(~r/^(\#{1,6})\s+(.*)$/, trimmed) ->
        [_, hashes, title] = heading
        blocks(rest, [{{:heading, String.length(hashes)}, [title]} | acc])

      String.starts_with?(trimmed, ">") ->
        {quote, rest} =
          Enum.split_while([line | rest], &String.starts_with?(String.trim(&1), ">"))

        blocks(rest, [{:quote, Enum.map(quote, &unquote_line/1)} | acc])

      list_kind(trimmed) ->
        kind = list_kind(trimmed)
        {items, rest} = list_items([line | rest], kind, [])
        blocks(rest, [{{:list, kind}, items} | acc])

      # Domain: the paragraph always takes this line, then the lines that
      # go on with it: a line like "#elixir" is no heading and no other
      # block, and took nothing before, so the same line came back for
      # ever (code review 2026-10-26)
      true ->
        {more, rest} = Enum.split_while(rest, &paragraph_line?/1)
        blocks(rest, [{:paragraph, [line | more]} | acc])
    end
  end

  defp unquote_line(line),
    do: line |> String.trim() |> String.replace_prefix(">", "") |> String.trim()

  # A paragraph goes on until a blank line or the start of another block.
  defp paragraph_line?(line) do
    trimmed = String.trim(line)

    trimmed != "" and not String.starts_with?(trimmed, ["```", ">", "#"]) and
      list_kind(trimmed) == nil and not Regex.match?(~r/^(-{3,}|\*{3,})$/, trimmed)
  end

  defp list_kind(trimmed) do
    cond do
      Regex.match?(~r/^[-*] /, trimmed) -> :bullets
      Regex.match?(~r/^\d+[.)] /, trimmed) -> :numbers
      true -> nil
    end
  end

  # The items of a list: each starts with a marker, and lines after it
  # that are not blank and not another item belong to it.
  defp list_items([line | rest] = lines, kind, acc) do
    trimmed = String.trim(line)

    if list_kind(trimmed) == kind do
      {more, rest} = Enum.split_while(rest, &continuation?/1)
      text = Enum.join([strip_marker(trimmed) | Enum.map(more, &String.trim/1)], " ")
      list_items(rest, kind, [text | acc])
    else
      {Enum.reverse(acc), lines}
    end
  end

  defp list_items([], _kind, acc), do: {Enum.reverse(acc), []}

  defp continuation?(line) do
    trimmed = String.trim(line)
    trimmed != "" and list_kind(trimmed) == nil and String.starts_with?(line, [" ", "\t"])
  end

  defp strip_marker(trimmed), do: Regex.replace(~r/^([-*]|\d+[.)]) /, trimmed, "", global: false)

  # --- blocks as HTML --------------------------------------------------------------

  defp block_html({:paragraph, lines}, used, link),
    do: "<p>" <> inline(Enum.map_join(lines, " ", &String.trim/1), used, link) <> "</p>"

  defp block_html({{:heading, n}, [title]}, used, link),
    do: "<h#{n}>" <> inline(title, used, link) <> "</h#{n}>"

  defp block_html({:code, lines}, _used, _link),
    do: "<pre><code>" <> escape(Enum.join(lines, "\n")) <> "</code></pre>"

  defp block_html({:rule, []}, _used, _link), do: "<hr>"

  defp block_html({:quote, lines}, used, link),
    do: "<blockquote>" <> to_html(Enum.join(lines, "\n"), used, link) <> "</blockquote>"

  defp block_html({{:list, :numbers}, items}, used, link),
    do: "<ol>" <> Enum.map_join(items, &item_html(&1, used, link)) <> "</ol>"

  defp block_html({{:list, :bullets}, items}, used, link) do
    class = if Enum.all?(items, &task?/1), do: ~s( class="tasks"), else: ""
    "<ul#{class}>" <> Enum.map_join(items, &item_html(&1, used, link)) <> "</ul>"
  end

  # The owner's task boxes: [ ] to do, [x] done, [-] cancelled
  defp item_html("[ ] " <> text, used, link),
    do: ~s(<li class="todo"><span class="box">[ ]</span> #{inline(text, used, link)}</li>)

  defp item_html("[x] " <> text, used, link), do: done_item(text, used, link)
  defp item_html("[X] " <> text, used, link), do: done_item(text, used, link)

  defp item_html("[-] " <> text, used, link),
    do:
      ~s(<li class="cancelled"><span class="box">[-]</span> <del>#{inline(text, used, link)}</del></li>)

  defp item_html(text, used, link), do: "<li>" <> inline(text, used, link) <> "</li>"

  defp done_item(text, used, link),
    do: ~s(<li class="done"><span class="box">[x]</span> #{inline(text, used, link)}</li>)

  defp task?(text), do: String.starts_with?(text, ["[ ] ", "[x] ", "[X] ", "[-] "])

  # --- inline -------------------------------------------------------------------------

  # Inline markup is read left to right: at each point the first pattern
  # that matches there is taken, else one character of text. The
  # patterns are tried in this order, so `**` comes before `*`.
  @inline [
    escaped: ~r/^\\([\\`*_\[\]()#!>-])/,
    code: ~r/^`([^`]+)`/,
    image: ~r/^!\[([^\]]*)\]\((https?:\/\/[^\s)]+)\)/,
    link: ~r/^\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)/,
    strong: ~r/^\*\*(.+?)\*\*/,
    emphasis: ~r/^\*([^*\s][^*]*?)\*/,
    underscore: ~r/^_([^_\s][^_]*?)_(?![[:alnum:]])/u,
    url: ~r/^https?:\/\/[^\s<>"]+[^\s<>".,;:!?)]/
  ]

  @doc """
  The HTML of one line of text, with the inline markup only (no blocks):
  for a post's title.
  """
  @spec inline(String.t(), map, link_fun) :: String.t()
  def inline(text, used, link) do
    # Zettel links first, over the whole text, so that their positions
    # are the text's own; the parts between them get the other markup
    # none inside an address, a [text](link) or a `code` span: those keep
    # their text as it is (code review 2026-10-26: a post's own address
    # lost its link)
    links = text |> ZettelLinks.scan(used) |> Enum.reject(&inside?(&1, protected(text)))

    {html, rest_at} =
      Enum.reduce(links, {[], 0}, fn l, {acc, from} ->
        before = String.slice(text, from, l.at - from)
        {[acc, markup(before), link.(l.target, l.word)], l.at + l.length}
      end)

    IO.iodata_to_binary([html, markup(String.slice(text, rest_at..-1//1))])
  end

  # the character ranges of addresses, Markdown links and code spans
  defp protected(text) do
    ~r{`[^`]*`|\[[^\]]*\]\([^)]*\)|https?://[^\s<>"]+}
    |> Regex.scan(text, return: :index)
    |> Enum.map(fn [{start, len} | _] ->
      from = String.length(binary_part(text, 0, start))
      {from, from + String.length(binary_part(text, start, len))}
    end)
  end

  defp inside?(link, ranges), do: Enum.any?(ranges, fn {a, b} -> link.at >= a and link.at < b end)

  defp markup(""), do: ""

  defp markup(text) do
    case Enum.find_value(@inline, fn {kind, re} -> match(kind, re, text) end) do
      {html, rest} -> html <> markup(rest)
      nil -> plain(text)
    end
  end

  defp match(kind, re, text) do
    case Regex.run(re, text) do
      [whole | groups] ->
        {render(kind, groups, whole), String.slice(text, String.length(whole)..-1//1)}

      nil ->
        nil
    end
  end

  # One character of text, escaped (`String.next_grapheme/1` keeps a
  # letter with its accents together).
  defp plain(text) do
    {char, rest} = String.next_grapheme(text)
    escape(char) <> markup(rest)
  end

  defp render(:escaped, [char], _whole), do: escape(char)
  defp render(:code, [code], _whole), do: "<code>" <> escape(code) <> "</code>"

  defp render(:image, [alt, url], _whole),
    do: ~s(<img src="#{attribute(url)}" alt="#{attribute(alt)}">)

  defp render(:link, [label, url], _whole),
    do: ~s(<a href="#{attribute(url)}">#{markup(label)}</a>)

  defp render(:strong, [inner], _whole), do: "<strong>" <> markup(inner) <> "</strong>"

  defp render(kind, [inner], _whole) when kind in [:emphasis, :underscore],
    do: "<em>" <> markup(inner) <> "</em>"

  defp render(:url, [], url), do: ~s(<a href="#{attribute(url)}">#{escape(url)}</a>)

  @doc "Text made safe for HTML: `&`, `<` and `>` as entities."
  @spec escape(String.t()) :: String.t()
  def escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  @doc "Text made safe inside a double-quoted HTML attribute."
  @spec attribute(String.t()) :: String.t()
  def attribute(text), do: text |> escape() |> String.replace("\"", "&quot;")
end
