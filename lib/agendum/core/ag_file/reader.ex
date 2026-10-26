defmodule Agendum.Core.AgFile.Reader do
  @moduledoc """
  Reads a Lotus Agenda 2.0 data file (`.AG`) into plain maps (R72): its
  items, categories, views, macros and file settings, as Agenda stored
  them. A port of the reference reader `tools/agformat/agdump.py`, which
  follows `docs/AGENDA_FILE_FORMAT.md`; the maps have the same keys as its
  JSON (atoms here), so the two can be compared on the same files.
  Turning them into an Agendum file is `Agendum.Core.AgFile.Convert`.

  Pure: bytes in, maps out. The file is a dump of Agenda's memory pool: a
  1024-byte header, 64-byte blocks numbered from 0, then 512-byte pages of
  28-byte link records; blocks and links point at each other by number.
  Every walk along such pointers stops at a number seen before (kept in a
  plain map, `%{n => true}`), so a damaged file cannot make it loop.
  """

  import Bitwise

  alias Agendum.Core.AgFile.CP437

  @header 0x400
  @block 64
  @page 512
  @link 28
  @links_mark <<0xFF, 0xFF, "LINKS", 0xFF>>

  # system categories: !Trash! is block 1, !Current Alarms! block 5
  @trash 1
  @current_alarms 5
  @item 1

  @category_types %{0 => "standard", 1 => "unindexed", 2 => "numeric", 3 => "date"}
  @weekdays ~w(? Monday Tuesday Wednesday Thursday Friday Saturday Sunday)
  @months ~w(? January February March April May June July August September October November December)
  @date_units %{
    2 => "named month",
    4 => "hours",
    5 => "days",
    6 => "working days",
    7 => "weekday",
    9 => "weeks",
    10 => "fortnights",
    11 => "months",
    13 => "quarters",
    14 => "years"
  }
  @positions %{0 => nil, 1 => "beginning", 2 => "end", 3 => "whole"}

  @typedoc "A file being read: its bytes, a few header words and its link records."
  @type file :: %{data: binary, last_block: non_neg_integer, links: %{pos_integer => binary}}

  @doc """
  Reads a file: `{:ok, map}` with `:description`, `:password` (nil when
  there is none), `:created`, `:saved`, `:settings`, `:categories` (the
  tree from MAIN), `:items`, `:views` and `:macros`; or
  `{:error, :not_an_agenda_file}`.
  """
  @spec read(binary) :: {:ok, map} | {:error, :not_an_agenda_file}
  def read(<<"T", _::binary>> = data) when byte_size(data) >= @header do
    f = open(data)

    {:ok,
     %{
       description: cstr(binary_part(data, 2, 0x2B - 2)),
       password: password(data),
       created: lotus_date(double(data, 0x170)),
       saved: lotus_date(double(data, 0x168)),
       settings: settings(f),
       categories: category(f, word(data, 0x40)),
       items: items(f),
       views: views(f),
       macros: macros(f)
     }}
  rescue
    # Domain: a file that only looks like Agenda's (it starts with "T") may
    # still be cut short or point nowhere; reading it then fails somewhere
    # deep inside, and that is the same answer as for any other file.
    _ in [ArgumentError, MatchError, FunctionClauseError, KeyError, ArithmeticError] ->
      {:error, :not_an_agenda_file}
  end

  def read(_data), do: {:error, :not_an_agenda_file}

  # --- the container -----------------------------------------------------------

  defp open(data) do
    last_block = word(data, 0x3A)
    # the link pages start at the 512-byte boundary after the last block
    blocks_end = @header + (last_block + 1) * @block
    links_start = div(blocks_end + @page - 1, @page) * @page
    %{data: data, last_block: last_block, links: link_pages(data, links_start, %{})}
  end

  # A page holds 18 records and ends with FF FF "LINKS" FF; the pages go on
  # while that mark does. A record's first word is its number (0: unused).
  defp link_pages(data, p, links) do
    if byte_size(data) >= p + @page and binary_part(data, p + 0x1F8, 8) == @links_mark do
      links =
        Enum.reduce(0..17, links, fn k, links ->
          rec = binary_part(data, p + k * @link, @link)

          case word(rec, 0) do
            0 -> links
            id -> Map.put(links, id, rec)
          end
        end)

      link_pages(data, p + @page, links)
    else
      links
    end
  end

  # --- primitives --------------------------------------------------------------

  # `<<x::little-16>>` is a binary pattern: it reads two bytes as a
  # little-endian 16-bit number. `_::binary-size(off)` skips `off` bytes.
  defp word(bin, off) do
    <<_::binary-size(^off), w::little-16, _::binary>> = bin
    w
  end

  defp signed(bin, off) do
    <<_::binary-size(^off), w::little-signed-16, _::binary>> = bin
    w
  end

  # An 8-byte IEEE double; bytes that are not a number (NaN, infinity) are
  # nil, as an unused date would be.
  defp double(bin, off) do
    case bin do
      <<_::binary-size(^off), d::little-float-64, _::binary>> -> d
      _ -> nil
    end
  end

  # A block, padded with zeros when the file is shorter than its number says.
  defp block(f, n) do
    off = @header + n * @block
    have = max(min(@block, byte_size(f.data) - off), 0)
    part = if have > 0, do: binary_part(f.data, off, have), else: <<>>
    part <> :binary.copy(<<0>>, @block - have)
  end

  # A block's or a link record's words, as a tuple: `elem(w, 9)` is word 9.
  defp bw(f, n), do: words(block(f, n))
  defp lw(f, n), do: words(Map.get(f.links, n, :binary.copy(<<0>>, @link)))

  defp words(bin), do: for(<<w::little-16 <- bin>>, do: w) |> List.to_tuple()

  defp rec(f, n), do: Map.get(f.links, n, :binary.copy(<<0>>, @link))

  defp tail(bin, from), do: binary_part(bin, from, byte_size(bin) - from)

  # A C string: up to the first NUL, in the DOS code page.
  defp cstr(bin), do: bin |> :binary.split(<<0>>) |> hd() |> CP437.to_string()

  defp password(data) do
    for(<<b <- binary_part(data, 0x2B, 0x38 - 0x2B)>>, into: <<>>, do: <<bxor(b, 0xAB)>>)
    |> cstr()
    |> case do
      "" -> nil
      password -> password
    end
  end

  # Text in a chain of text blocks (word 2: the next), each a C string from
  # byte 8; `head` is text kept in the owner's own block, read first.
  defp chain(f, first, head \\ nil) do
    start = if head, do: cstr(head), else: ""
    walk_chain(f, first, %{}, [start])
  end

  defp walk_chain(f, n, seen, acc) do
    if n != 0 and n <= f.last_block and not Map.has_key?(seen, n) do
      walk_chain(f, elem(bw(f, n), 2), Map.put(seen, n, true), [cstr(tail(block(f, n), 8)) | acc])
    else
      acc |> Enum.reverse() |> Enum.join()
    end
  end

  # Data blocks: word 2 the next, word 3 the bytes used in this one.
  defp blob(f, n, seen \\ %{}) do
    if n != 0 and not Map.has_key?(seen, n) do
      w = bw(f, n)

      binary_part(block(f, n), 8, min(elem(w, 3), 56)) <>
        blob(f, elem(w, 2), Map.put(seen, n, true))
    else
      <<>>
    end
  end

  # The numbers along a list: from `first`, the next one in word `next` of
  # each (a block's or a link's, by `getter`), until 0 or one seen before.
  defp walk(f, first, next, getter) do
    Stream.unfold({first, %{}}, fn {n, seen} ->
      if n != 0 and not Map.has_key?(seen, n),
        do: {n, {elem(getter.(f, n), next), Map.put(seen, n, true)}}
    end)
    |> Enum.to_list()
  end

  @doc """
  A Lotus 1-2-3 serial date (days since 1899-12-30, the fraction the time
  of day) as an ISO 8601 moment to the minute, or nil for none.
  """
  @spec lotus_date(float | nil) :: String.t() | nil
  def lotus_date(days) when is_float(days) and days >= 1 do
    microseconds = round(days * 86_400_000_000)

    ~N[1899-12-30 00:00:00]
    |> NaiveDateTime.add(microseconds, :microsecond)
    |> NaiveDateTime.truncate(:second)
    |> Map.put(:second, 0)
    |> NaiveDateTime.to_iso8601()
    |> String.slice(0, 16)
  end

  def lotus_date(_days), do: nil

  # hour | minute << 5; hour 24 means no time
  defp time_word(w) do
    {hour, minute} = {w &&& 0x1F, w >>> 5 &&& 0x3F}

    if hour == 24,
      do: nil,
      else: "#{String.pad_leading("#{hour}", 2, "0")}:#{String.pad_leading("#{minute}", 2, "0")}"
  end

  # How a date was given (8 bytes): kind 0 an absolute date (its lowest
  # byte has 0x80 when a time was given), 1 relative, 2 recurring.
  defp date_expression(<<b0, _::binary>>, 0),
    do: %{kind: "absolute", time_given: (b0 &&& 0x80) != 0}

  defp date_expression(<<b0, b1, _::binary>> = raw, _kind) do
    unit_code = b0 &&& 0x0F
    unit = Map.get(@date_units, unit_code, "unit #{unit_code}")
    recurring = (b0 &&& 0xC0) == 0xC0
    out = %{kind: if(recurring, do: "recurring", else: "relative"), unit: unit}

    out =
      if recurring do
        out = Map.put(out, :interval, :binary.at(raw, 4))
        if unit_code == 7, do: Map.put(out, :weekday, Enum.at(@weekdays, b1 &&& 7)), else: out
      else
        relative(out, raw, b0, b1, unit_code)
      end

    case time_word(word(raw, 6)) do
      nil -> out
      t -> Map.put(out, :time, t)
    end
  end

  defp relative(out, raw, b0, b1, unit_code) do
    {index, position} = {b1 >>> 4, b1 &&& 3}

    [
      {:count, signed(raw, 2)},
      {:position, @positions[position]},
      {:weekday, if(unit_code == 7 and index != 0, do: Enum.at(@weekdays, index &&& 7))},
      {:month, if(unit_code == 2 and index != 0, do: month(index))},
      {:day_of_month, if((b0 &&& 0x40) != 0, do: :binary.at(raw, 4) + 1)},
      {:this, if((:binary.at(raw, 5) &&& 0x10) != 0, do: true)}
    ]
    |> Enum.reject(fn {_key, value} -> value == nil end)
    |> Enum.into(out)
  end

  defp month(index) when index < 13, do: Enum.at(@months, index)
  defp month(index), do: index

  # --- objects -----------------------------------------------------------------

  defp category_name(f, c), do: chain(f, elem(bw(f, c), 2))

  # A note: its text, or the name of the note file it is kept in.
  defp note(f, owner) do
    case elem(owner, 3) do
      0 ->
        nil

      n ->
        w = bw(f, n)
        if elem(w, 9) == 1, do: %{file: chain(f, elem(w, 4))}, else: chain(f, elem(w, 2))
    end
  end

  defp date_range(f, b) do
    raw = block(f, b)

    for {name, off, rel} <- [{:start, 6, 22}, {:end, 24, 40}],
        # a one-element list as a generator binds a name inside `for`
        date <- [lotus_date(double(raw, off + 8))],
        date != nil,
        reduce: %{} do
      out ->
        out
        |> Map.put(name, date)
        |> Map.put(
          :"#{name}_given_as",
          date_expression(binary_part(raw, off, 8), :binary.at(raw, rel))
        )
    end
  end

  defp filter_elements(f, first) do
    for l <- walk(f, first, 4, &lw/2) do
      w = lw(f, l)
      element = %{category: elem(w, 2), assigned: (elem(w, 8) &&& 1) == 0}

      if elem(w, 9) != 0,
        do:
          Map.merge(element, %{
            range: date_range(f, elem(w, 9)),
            inside_range: (elem(w, 8) &&& 2) == 0
          }),
        else: element
    end
  end

  defp sort_key(_f, 0), do: nil

  defp sort_key(f, l) do
    w = lw(f, l)
    flags = elem(w, 9)

    on =
      cond do
        (flags &&& 0x180) == 0x180 -> "category note"
        (flags &&& 0x100) != 0 -> "category"
        (flags &&& 0x80) != 0 -> "item text"
        true -> "0x" <> String.downcase(Integer.to_string(flags, 16))
      end

    key = %{on: on, descending: (flags &&& 2) != 0, "n/a first": (flags &&& 0x20) != 0}

    if elem(w, 2) != 0 do
      sequence =
        Enum.at(["category hierarchy", "alphabetic", "numeric", "date"], flags >>> 2 &&& 3)

      Map.merge(key, %{category: elem(w, 2), sequence: sequence})
    else
      key
    end
  end

  defp sort_keys(f, a, b), do: Enum.reject([sort_key(f, a), sort_key(f, b)], &is_nil/1)

  @assign_date [
    "never",
    "when entered",
    "item text edited",
    "note edited",
    "item or note edited",
    "when assigned",
    "assigned or edited",
    "from item text",
    "from note text",
    "from item or note text"
  ]

  defp category_settings(w) do
    w23 = elem(w, 23)
    w26 = elem(w, 26)
    w28 = elem(w, 28)
    type = w26 >>> 2 &&& 3

    common = [
      exclusive_children: type == 0 and (w26 &&& 1) == 0,
      assignment_actions: %{0 => nil, 0x400 => false, 0x800 => true}[w26 &&& 0xC00],
      apply_conditions:
        Map.get(%{0 => nil, 0x40 => "on demand", 0x80 => "never"}, w26 &&& 0xC0, "automatically"),
      protected: %{0 => nil, 1 => false, 2 => true}[w23 &&& 3]
    ]

    own =
      if type == 3 do
        [
          assign_item_date: Enum.at(@assign_date, min(w23 >>> 9 &&& 15, 9)),
          which_date_in_text: elem(w, 30) + 1,
          set_from_done_key: (w23 &&& 0x80) != 0,
          set_from_when_key: (w23 &&& 0x100) != 0,
          recurring_dates: (w23 &&& 0x4000) != 0,
          conflicts: %{0 => nil, 0x20 => "keep old", 0x40 => "override"}[w23 &&& 0x60]
        ]
      else
        [
          match_name: (w28 &&& 0x08) == 0,
          match_short_name: (w28 &&& 0x10) == 0,
          text_matching: %{0 => nil, 0x4000 => false, 0x8000 => true}[w28 &&& 0xC000],
          match_on: Enum.at([nil, "item text", "note text", "item and note"], w28 &&& 3),
          allow_explicit: (w28 &&& 0x80) == 0,
          relationship: %{0 => nil, 0x20 => "or", 0x40 => "and"}[w28 &&& 0x60],
          confirm: %{0 => nil, 0x200 => "always", 0x400 => "sometimes"}[w28 &&& 0x600],
          match_strength: Enum.at([nil, "exact", "partial", "minimal"], w23 >>> 7 &&& 3),
          assignment_conditions:
            if(type == 0, do: %{0 => nil, 1 => false, 2 => true}[elem(w, 29)])
        ]
      end

    for {key, value} <- common ++ own, value != nil, into: %{}, do: {key, value}
  end

  # A condition/action set: conditions (type 6 links), actions (type 7) and
  # the special action.
  defp conditions(_f, 0), do: nil

  defp conditions(f, set) do
    w = bw(f, set)

    out = %{
      conditions:
        for(
          l <- walk(f, elem(w, 11), 4, &lw/2),
          do: %{category: elem(lw(f, l), 2), assigned: elem(lw(f, l), 8) == 0}
        ),
      actions:
        for(
          l <- walk(f, elem(w, 13), 4, &lw/2),
          do: %{category: elem(lw(f, l), 2), assign: elem(lw(f, l), 8) == 0}
        )
    }

    special =
      Map.get(
        %{0 => nil, 8 => "discard", 0x10 => "done", 0x18 => "export"},
        elem(w, 15),
        elem(w, 15)
      )

    cond do
      special == nil ->
        out

      elem(w, 9) != 0 ->
        Map.merge(out, %{special_action: special, export_file: chain(f, elem(w, 9))})

      true ->
        Map.put(out, :special_action, special)
    end
  end

  # The categories, depth first from the root (word 17 a category's first
  # child, word 15 the next sibling). Each block is read once, however many
  # parents a damaged file points at it from (code review 2026-10-26: a
  # crafted file made the reading grow without bound).
  defp category(f, root),
    do:
      root
      |> depth_first(
        fn c -> walk(f, elem(bw(f, c), 17), 15, &bw/2) end,
        &category_node(f, &1, &2)
      )
      |> elem(0)

  @doc """
  A tree read depth first from `node`: `children` gives a node's children,
  `build` makes a node from it and its children built. Each node is visited
  once, by one set shared by the whole walk, so a node reachable along
  several paths, or a cycle, costs nothing more. Returns the tree and the
  nodes visited.
  """
  @spec depth_first(term, (term -> [term]), (term, [term] -> term), MapSet.t()) ::
          {term, MapSet.t()}
  def depth_first(node, children, build, seen \\ MapSet.new()) do
    seen = MapSet.put(seen, node)

    {kids, seen} =
      Enum.reduce(children.(node), {[], seen}, fn child, {kids, seen} ->
        if MapSet.member?(seen, child) do
          {kids, seen}
        else
          {kid, seen} = depth_first(child, children, build, seen)
          {[kid | kids], seen}
        end
      end)

    {build.(node, Enum.reverse(kids)), seen}
  end

  # A category with its children built. Its name text is "name;short
  # name;also match…". Empty values are left out, as agdump.py leaves them
  # out.
  defp category_node(f, c, children) do
    w = bw(f, c)
    parts = String.split(category_name(f, c), ";")

    [
      id: c,
      name: hd(parts),
      short_name: Enum.at(parts, 1) |> blank_nil(),
      also_match: parts |> Enum.drop(2) |> Enum.reject(&(&1 == "")),
      type: @category_types[(w |> elem(26)) >>> 2 &&& 3],
      note: note(f, w),
      settings: category_settings(w),
      conditions: conditions(f, elem(w, 19)),
      children: children
    ]
    |> Enum.reject(fn {_key, value} -> value in [nil, [], %{}] end)
    |> Map.new()
  end

  defp blank_nil(""), do: nil
  defp blank_nil(value), do: value

  # An assignment's value, by its flags: unindexed text (in a data block),
  # a date (in a type-12 link), or a number (a double in the link itself).
  defp value(f, w) do
    flags = elem(w, 8)

    cond do
      (flags &&& 0x180) == 0x180 -> f |> blob(elem(w, 9)) |> cstr()
      (flags &&& 0x100) != 0 -> lotus_date(double(rec(f, elem(w, 9)), 18))
      (flags &&& 0x80) != 0 -> double(rec(f, elem(w, 0)), 18)
      true -> nil
    end
  end

  defp how(flags) when (flags &&& 0x40) != 0, do: "automatic"

  defp how(flags) do
    case flags &&& 0x3F do
      0 -> "explicit"
      1 -> "text match"
      2 -> "condition"
      other -> "0x" <> String.downcase(Integer.to_string(other, 16))
    end
  end

  # Every block that is an item: its own number in word 0, type 1, and not
  # one of Agenda's built-in summary rows (0x40 in word 24).
  defp items(f) do
    for n <- 1..f.last_block//1,
        w <- [bw(f, n)],
        elem(w, 0) == n and elem(w, 1) == @item and (elem(w, 24) &&& 0x40) == 0 do
      {assignments, alarm} = assignments(f, elem(w, 9))

      item = %{
        id: n,
        text: chain(f, elem(w, 2), binary_part(block(f, n), 50, 12)),
        note: note(f, w),
        assignments: assignments,
        # discarded items stay in the file, assigned only to !Trash!
        trashed: Enum.any?(assignments, &(&1.category == @trash))
      }

      if alarm, do: Map.put(item, :alarm, alarm), else: item
    end
  end

  defp assignments(f, first) do
    {assignments, alarm} =
      Enum.reduce(walk(f, first, 4, &lw/2), {[], nil}, fn l, {acc, alarm} ->
        w = lw(f, l)

        if elem(w, 2) == @current_alarms and (elem(w, 8) &&& 0x200) != 0 do
          al = lw(f, elem(w, 9))
          {acc, %{date_category: elem(al, 5), minutes_before: elem(al, 6)}}
        else
          {[assignment(f, w) | acc], alarm}
        end
      end)

    {Enum.reverse(assignments), alarm}
  end

  defp assignment(f, w) do
    a = %{category: elem(w, 2), how: how(elem(w, 8))}

    case value(f, w) do
      nil ->
        a

      v when (elem(w, 8) &&& 0x180) == 0x100 ->
        # a date: how it was typed, kept in its type-12 link
        # (kind 0 absolute, 1 relative, 2 recurring; others, as an Entry
        # date's, say nothing an import needs)
        r = rec(f, elem(w, 9))

        case word(r, 26) do
          kind when kind in 0..2 ->
            Map.merge(a, %{value: v, given_as: date_expression(binary_part(r, 10, 8), kind)})

          _other ->
            Map.put(a, :value, v)
        end

      v ->
        Map.put(a, :value, v)
    end
  end

  @date_display ["date", "date time", "time date", "time"]

  # A date format word: a date column's w10, or the file's global one at
  # header 0x182 (decoded 2026-10-26 by changing each field of Agenda's
  # Display Format box, as agdump.py's `date_format`): bits 0-4 the date
  # format, 1 MMDDYY … 20 Relative # in the box's order, 0 the global
  # default (columns); 5-7 the separator; 0x100 the time separator hm;
  # 0x400 a 12-hour clock; 0x800 am/pm; 0x1000 the day of week; 13-14 what
  # is displayed.
  @separators ["/", "-", ".", ",", " ", ":", "?", "?"]

  defp date_format(d) do
    %{
      display: Enum.at(@date_display, d >>> 13 &&& 3),
      format: if((d &&& 0x1F) == 0, do: "global", else: d &&& 0x1F),
      separator: Enum.at(@separators, d >>> 5 &&& 7),
      time_separator: if((d &&& 0x100) != 0, do: "hm", else: ":"),
      day_of_week: (d &&& 0x1000) != 0,
      clock_12h: (d &&& 0x400) != 0,
      am_pm: (d &&& 0x800) != 0
    }
  end

  defp column(f, l) do
    w = lw(f, l)
    col = %{category: elem(w, 2), width: elem(w, 8) - 1}

    case (f |> bw(elem(w, 2)) |> elem(26)) >>> 2 &&& 3 do
      3 ->
        Map.put(col, :date_format, date_format(elem(w, 10)))

      2 ->
        n = elem(w, 11)

        Map.put(col, :number_format, %{
          decimals: n >>> 4 &&& 31,
          label: Enum.at([nil, "%", "$", "?"], n &&& 3),
          thousands_separator: (n &&& 0x8000) != 0,
          negative_parentheses: (n &&& 0x4000) != 0,
          percent_of_total: (n &&& 0x1000) != 0
        })

      _ ->
        col
    end
  end

  defp views(f) do
    for v <- walk(f, word(f.data, 0x42), 9, &bw/2) do
      w = bw(f, v)

      name =
        cstr(tail(block(f, v), 44)) <> if(elem(w, 2) != 0, do: chain(f, elem(w, 2)), else: "")

      {f20, f21} = {elem(w, 20), elem(w, 21)}

      view = %{
        id: v,
        name: name,
        hide_empty_sections: (f20 &&& 0x8000) != 0,
        hide_done: (f20 &&& 1) != 0,
        hide_dependent: (f20 &&& 0x40) != 0,
        hide_inherited: (f20 &&& 2) != 0,
        hide_column_heads: (f21 &&& 0x40) != 0,
        section_separators: (f20 &&& 0x80) != 0,
        number_items: (f21 &&& 0x20) != 0,
        section_sorting:
          Enum.at([nil, "category order", "alphabetic", "numeric"], f21 >>> 1 &&& 3),
        sort: sort_keys(f, elem(w, 10), elem(w, 11)),
        sort_new_items:
          Enum.at(["on leaving section", "when entered", "on demand", "?"], elem(w, 12) &&& 3),
        filter: if(elem(w, 5) != 0, do: filter_elements(f, elem(w, 5)), else: []),
        sections: for(s <- walk(f, elem(w, 3), 4, &bw/2), do: section(f, s))
      }

      if (elem(w, 12) &&& 0x300) != 0, do: Map.put(view, :datebook, datebook(w)), else: view
    end
  end

  defp section(f, s) do
    w = bw(f, s)

    sec = %{
      category: elem(w, 2),
      columns: for(c <- walk(f, elem(w, 8), 7, &lw/2), do: column(f, c))
    }

    sec = if elem(w, 5) != 0, do: Map.put(sec, :filter, filter_elements(f, elem(w, 5))), else: sec

    if elem(w, 10) != 0,
      do: Map.put(sec, :sort, sort_keys(f, elem(w, 10), elem(w, 11))),
      else: sec
  end

  # A day runs from hour w15 to hour w16 (0xC8hh); a longer period from
  # weekday w15 to w16 (0 is Sunday).
  defp datebook(w) do
    period = Enum.at(["day", "week", "month", "quarter"], elem(w, 12) >>> 4 &&& 3)
    {from, to} = {elem(w, 15), elem(w, 16)}

    {a, b} =
      if period == "day",
        do: {"#{from &&& 0xFF}:00", "#{to &&& 0xFF}:00"},
        else: {weekday_or_sunday(from), weekday_or_sunday(to)}

    %{period: period, from: a, to: b}
  end

  defp weekday_or_sunday(0), do: "Sunday"
  defp weekday_or_sunday(n), do: Enum.at(@weekdays, n, "Sunday")

  defp macros(f) do
    for m <- walk(f, word(f.data, 0x9A), 5, &bw/2) do
      f |> chain(elem(bw(f, m), 2), tail(block(f, m), 24)) |> String.split("\r") |> hd()
    end
  end

  # File settings, from the header (File Properties and its boxes).
  defp settings(f) do
    w = &word(f.data, &1)

    %{
      tab_size: w.(0x7C),
      backup_on_open: w.(0x5E) != 0,
      empty_trash:
        %{
          0 => "on demand",
          0x40 => "when file closed",
          0x80 => "end of day",
          0xC0 => "when discarded"
        }[
          w.(0x8C) &&& 0xC0
        ],
      process_done_items:
        %{0 => "no action", 0x200 => "discard", 0x800 => "export"}[w.(0x8C) &&& 0xE00],
      text_matching: (w.(0x8C) &&& 0x4000) != 0,
      assignment_conditions: (w.(0x8C) &&& 0x2000) != 0,
      assignment_actions: (w.(0x98) &&& 2) != 0,
      relationship: %{1 => "or", 2 => "and"}[w.(0x8E) &&& 3],
      week: [weekday_or_sunday(w.(0x18E)), Enum.at(@weekdays, w.(0x190), "?")],
      morning: "#{w.(0x186) &&& 0xFF}:00",
      afternoon: "#{w.(0x18A) &&& 0xFF}:00",
      evening: "#{w.(0x188) &&& 0xFF}:00",
      month_alone_means: if((w.(0x192) &&& 1) != 0, do: "last day", else: "first day"),
      date_format: date_format(w.(0x182))
    }
  end
end
