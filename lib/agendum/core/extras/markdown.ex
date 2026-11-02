# SPDX-License-Identifier: AGPL-3.0-only
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
  `[text](https://…)` links, `![alt](https://…)` images and
  `![alt](assets/owl.jpg)` ones from the site folder's `assets/` (written
  from the site's root; `Agendum.Core.Extras.Site` makes the address right
  for each page), bare `https://` addresses, and Zettel links (R73b) through the `link` function given:
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

  @doc """
  The paths of the assets `text`'s images name (`assets/owl.jpg`), in
  order, once each: those the site must have to publish it.
  """
  @spec assets(String.t()) :: [String.t()]
  def assets(text), do: text |> to_html() |> assets_in()

  @doc """
  The assets the images of a one-line text name, read as `inline/3` reads
  it (a post's title: no blocks, so a title starting with ` ``` ` is not
  a code block there).
  """
  @spec inline_assets(String.t()) :: [String.t()]
  def inline_assets(text), do: text |> inline(%{}, &default_link/2) |> assets_in()

  # Read from the HTML: an image is the only way `<img` gets into it, as
  # every `<` of the text itself is escaped, so a code span or an escaped
  # `\\![…]` names nothing.
  defp assets_in(html) do
    ~r/<img src="(assets\/[^"]*)"/
    |> Regex.scan(html, capture: :all_but_first)
    |> List.flatten()
    |> Enum.uniq()
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

  # How many > a line starts with, spaces between them allowed. Each step
  # looks at what is left of the same binary (a sub-binary), so a long run
  # is read once, not copied at every level.
  defp levels(line, n \\ 0) do
    case String.trim_leading(line) do
      ">" <> rest -> levels(rest, n + 1)
      _rest -> {n, line}
    end
  end

  # The line without its first `n` levels, as `unquote_line/1` n times
  defp strip_levels(line, 0), do: line

  defp strip_levels(line, n) do
    ">" <> rest = String.trim_leading(line)
    strip_levels(String.trim(rest), n - 1)
  end

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

  # A quote inside a quote is read again as Markdown; the levels every line
  # shares (">>> deep") are taken at once, so thousands of them cost one
  # reading, not one for each level (found by the property tests).
  defp block_html({:quote, lines}, used, link) do
    shared = lines |> Enum.map(&(&1 |> levels() |> elem(0))) |> Enum.min()
    inner = Enum.map_join(lines, "\n", &strip_levels(&1, shared))
    depth = shared + 1

    String.duplicate("<blockquote>", depth) <>
      to_html(inner, used, link) <> String.duplicate("</blockquote>", depth)
  end

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
  # patterns are tried in this order, so `**` comes before `*`. What a
  # pattern holds (a link's text, a code span) is at most 500 characters
  # long, so that a pattern never reads far ahead for its end: an opening
  # `[` or `**` with none would otherwise read the whole rest of the text,
  # at each one (our choice; a longer one is plain text).
  @inline [
    escaped: ~r/^\\([\\`*_\[\]()#!>-])/,
    code: ~r/^`([^`]{1,500})`/,
    # an asset's path holds only the characters an asset's name may have
    # (`Address.plain?/1`), so it goes into the page as it is; at most 500
    # of them, as the rest are bounded
    image: ~r/^!\[([^\]]{0,500})\]\((https?:\/\/[^\s)]+|assets\/[A-Za-z0-9._~\/-]{1,500})\)/,
    link: ~r/^\[([^\]]{1,500})\]\((https?:\/\/[^\s)]+)\)/,
    strong: ~r/^\*\*(.{1,500}?)\*\*/,
    emphasis: ~r/^\*([^*\s][^*]{0,500}?)\*/,
    underscore: ~r/^_([^_\s][^_]{0,500}?)_(?![[:alnum:]])/u,
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
    links = text |> ZettelLinks.scan(used) |> outside(protected(text))

    # the text is walked once, from link to link: `rest` is what follows
    # the last link, which starts at character `from` of the text
    {html, rest, _from} =
      Enum.reduce(links, {[], text, 0}, fn l, {acc, rest, from} ->
        {before, rest} = String.split_at(rest, l.at - from)
        {_word, rest} = String.split_at(rest, l.length)
        {[acc, markup(before), link.(l.target, l.word)], rest, l.at + l.length}
      end)

    IO.iodata_to_binary([html, markup(rest)])
  end

  # The character ranges of addresses, Markdown links and code spans, in
  # order (they do not overlap). Each match's start is counted on from the
  # one before, so the text is counted once, not from its start each time;
  # what a range holds is bounded as in `@inline`.
  defp protected(text) do
    ~r/`[^`]{0,500}`|\[[^\]]{0,500}\]\([^)]{0,500}\)|https?:\/\/[^\s<>"]+/
    |> Regex.scan(text, return: :index)
    |> Enum.map_reduce({0, 0}, fn [{start, len} | _], {byte_at, char_at} ->
      from = char_at + String.length(binary_part(text, byte_at, start - byte_at))
      to = from + String.length(binary_part(text, start, len))
      {{from, to}, {start + len, to}}
    end)
    |> elem(0)
  end

  # The links not inside a range; both lists are in order, so one walk
  # along them both does it.
  defp outside([], _ranges), do: []
  defp outside(links, []), do: links

  defp outside([l | links], [{a, _b} | _] = ranges) when l.at < a,
    do: [l | outside(links, ranges)]

  defp outside([l | links], [{_a, b} | _] = ranges) when l.at < b, do: outside(links, ranges)
  defp outside(links, [_range | ranges]), do: outside(links, ranges)

  # Each pattern starts with its own character, so only the patterns of
  # the character at hand are tried, in `@inline`'s order; most characters
  # have none and are text at once. Trying every pattern at every character
  # (and joining the HTML a character at a time) made a long paragraph
  # take quadratic time: 40,000 characters of prose took 1.6 s (the parser
  # property tests, 2026-10-26).
  @starts @inline
          |> Keyword.keys()
          |> Enum.group_by(fn
            :escaped -> ?\\
            :code -> ?`
            :image -> ?!
            :link -> ?[
            kind when kind in [:strong, :emphasis] -> ?*
            :underscore -> ?_
            :url -> ?h
          end)

  # The HTML is collected as iodata (`acc`, a nested list) and made into
  # one binary at the end, rather than copied anew at every character.
  defp markup(text), do: text |> markup([]) |> IO.iodata_to_binary()

  defp markup("", acc), do: acc

  defp markup(<<first, _::binary>> = text, acc) do
    case Enum.find_value(Map.get(@starts, first, []), &match(&1, text)) do
      {html, rest} ->
        markup(rest, [acc, html])

      # one character of text, escaped (`String.next_grapheme/1` keeps a
      # letter with its accents together)
      nil ->
        {char, rest} = String.next_grapheme(text)
        markup(rest, [acc, escape(char)])
    end
  end

  # A pattern matches at the start of the text, so what it matched is the
  # text's first `byte_size(whole)` bytes and the rest follows them.
  defp match(kind, text) do
    case Regex.run(Keyword.fetch!(@inline, kind), subject(kind, text)) do
      [whole | groups] ->
        skip = byte_size(whole)
        {render(kind, groups, whole), binary_part(text, skip, byte_size(text) - skip)}

      nil ->
        nil
    end
  end

  # The underscore's pattern is a Unicode one (`u`: a letter after the
  # closing `_` may be any language's), and such a pattern first checks
  # that all of its text is valid UTF-8. It is given only as much text as it
  # can match (500 characters of at most 4 bytes, the underscores and the
  # letter after), cut where a character starts, so that an underscore does
  # not cost the whole rest of the text.
  @window 2_010

  defp subject(:underscore, text) when byte_size(text) > @window,
    do: binary_part(text, 0, boundary(text, @window))

  defp subject(_kind, text), do: text

  # the last place at or before `at` where a UTF-8 character starts: a
  # byte 0b10xxxxxx continues the character before it
  defp boundary(text, at) do
    case :binary.at(text, at) do
      byte when Bitwise.band(byte, 0xC0) == 0x80 -> boundary(text, at - 1)
      _ -> at
    end
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

  # --- one line, for the note editor (R64h) --------------------------------------
  #
  # Domain: the site's own rules, so a line the editor shows as a list item
  # or a heading is one on the site too: the site trims a line, then reads
  # `- `, `* `, `1. ` or `1) ` as a list, `#` to `######` and a space before
  # some text as a heading (`blocks/2`); a test holds the two together. A
  # box with nothing after it (`- [ ]`) is a box here too.

  @item ~r/^(\s*)([-*] |\d+[.)] )(?:\[([ xX-])\](?: |$))?(.*)$/
  @heading ~r/^(\s*\#{1,6}\s+)(\S.*)$/

  @typedoc """
  A line as Markdown: a heading (its marker, then its text), a list item
  (its indent, its marker, its task box's mark or nil, then its text), or
  plain text.
  """
  @type line ::
          {:heading, String.t(), String.t()}
          | {:item, String.t(), String.t(), String.t() | nil, String.t()}
          | :text

  @doc "What a line of a note is, as Markdown."
  @spec line(String.t()) :: line
  def line(text) do
    cond do
      match = Regex.run(@item, text) ->
        # `Regex.run/2` gives "" for the box when there is none
        [_, indent, marker, box, rest] = match
        {:item, indent, marker, if(box == "", do: nil, else: box), rest}

      match = Regex.run(@heading, text) ->
        [_, marker, rest] = match
        {:heading, marker, rest}

      true ->
        :text
    end
  end

  @doc """
  The rows of `lines` inside a code block (between ``` lines, those
  included), as the site reads them: there a list or a heading is only
  text.
  """
  @spec code_rows([String.t()]) :: MapSet.t(non_neg_integer)
  def code_rows(lines) do
    {rows, _inside} =
      lines
      |> Enum.with_index()
      |> Enum.reduce({MapSet.new(), false}, fn {line, row}, {rows, inside} ->
        fence? = String.starts_with?(String.trim(line), "```")

        cond do
          fence? -> {MapSet.put(rows, row), not inside}
          inside -> {MapSet.put(rows, row), inside}
          true -> {rows, inside}
        end
      end)

    rows
  end

  @doc """
  What ENTER at the end of `text` does: starts the next line with the
  list's marker (a number counted on, a task box empty); on an item with
  nothing after its marker, leaves the list, keeping only its indent
  (`{:end, indent}`); or `:none`.
  """
  @spec continue(String.t()) :: {:continue, String.t()} | {:end, String.t()} | :none
  def continue(text) do
    case line(text) do
      {:item, indent, _marker, _box, ""} -> {:end, indent}
      {:item, indent, marker, box, _rest} -> {:continue, indent <> next(marker) <> box(box)}
      _other -> :none
    end
  end

  defp next(marker) do
    case Integer.parse(marker) do
      {n, rest} -> Integer.to_string(n + 1) <> rest
      :error -> marker
    end
  end

  defp box(nil), do: ""
  defp box(_mark), do: "[ ] "

  @doc """
  CTRL-T on `text`: a task box ticked or unticked (a cancelled one opened
  again), a box added to a list item without one, as `{line, at}` where
  `at` is where the change begins (the cursor before it stays); nil for
  any other line.
  """
  @spec toggle(String.t()) :: {String.t(), non_neg_integer} | nil
  def toggle(text) do
    case line(text) do
      {:item, indent, marker, box, rest} ->
        mark = if box == " ", do: "[x] ", else: "[ ] "
        {indent <> marker <> mark <> rest, String.length(indent <> marker)}

      _other ->
        nil
    end
  end
end
