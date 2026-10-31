# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Terminal.Width do
  @moduledoc """
  How many terminal columns text takes. A grapheme (a character with its
  accents) takes one column, or two when it is wide: CJK ideographs, kana,
  Hangul, fullwidth forms and most emoji (Unicode's East Asian Width "W"
  and "F", and a grapheme shown as emoji with U+FE0F). Terminals draw those
  two columns wide, so `String.length/1` would measure them short.

  The table is the usual one (as `wcwidth` has it), slightly simplified;
  terminals themselves differ on a few emoji. Text with no character from
  U+1100 up is all narrow and measured as `String.length/1` does, so
  ordinary text costs no more than before. Pure.
  """

  # The wide ranges, first to last
  @wide [
    {0x1100, 0x115F},
    {0x231A, 0x231B},
    {0x2329, 0x232A},
    {0x23E9, 0x23EC},
    {0x23F0, 0x23F0},
    {0x23F3, 0x23F3},
    {0x25FD, 0x25FE},
    {0x2614, 0x2615},
    {0x2648, 0x2653},
    {0x267F, 0x267F},
    {0x2693, 0x2693},
    {0x26A1, 0x26A1},
    {0x26AA, 0x26AB},
    {0x26BD, 0x26BE},
    {0x26C4, 0x26C5},
    {0x26CE, 0x26CE},
    {0x26D4, 0x26D4},
    {0x26EA, 0x26EA},
    {0x26F2, 0x26F3},
    {0x26F5, 0x26F5},
    {0x26FA, 0x26FA},
    {0x26FD, 0x26FD},
    {0x2705, 0x2705},
    {0x270A, 0x270B},
    {0x2728, 0x2728},
    {0x274C, 0x274C},
    {0x274E, 0x274E},
    {0x2753, 0x2755},
    {0x2757, 0x2757},
    {0x2795, 0x2797},
    {0x27B0, 0x27B0},
    {0x27BF, 0x27BF},
    {0x2B1B, 0x2B1C},
    {0x2B50, 0x2B50},
    {0x2B55, 0x2B55},
    {0x2E80, 0x303E},
    {0x3041, 0x33FF},
    {0x3400, 0x4DBF},
    {0x4E00, 0x9FFF},
    {0xA000, 0xA4CF},
    {0xA960, 0xA97F},
    {0xAC00, 0xD7A3},
    {0xF900, 0xFAFF},
    {0xFE10, 0xFE19},
    {0xFE30, 0xFE6F},
    {0xFF00, 0xFF60},
    {0xFFE0, 0xFFE6},
    {0x16FE0, 0x16FE4},
    {0x17000, 0x18CFF},
    {0x1B000, 0x1B2FF},
    {0x1F004, 0x1F004},
    {0x1F0CF, 0x1F0CF},
    {0x1F18E, 0x1F18E},
    {0x1F191, 0x1F19A},
    # a flag is two regional indicators, one grapheme, drawn two wide
    {0x1F1E6, 0x1F1FF},
    {0x1F200, 0x1F2FF},
    {0x1F300, 0x1F64F},
    {0x1F680, 0x1F6FF},
    {0x1F7E0, 0x1F7EB},
    {0x1F90C, 0x1F9FF},
    {0x1FA70, 0x1FAFF},
    {0x20000, 0x2FFFD},
    {0x30000, 0x3FFFD}
  ]

  @doc ~S'The columns text takes: `of("abc")` is 3, `of("日本")` 4.'
  @spec of(String.t()) :: non_neg_integer
  def of(text) do
    cond do
      # most text on the screen: one byte, one column
      ascii?(text) -> byte_size(text)
      narrow?(text) -> String.length(text)
      true -> text |> String.graphemes() |> Enum.map(&grapheme/1) |> Enum.sum()
    end
  end

  @doc """
  The longest start of `text` that fits in `columns`, in whole graphemes,
  and the columns it takes: one less than asked when a wide character
  would have been cut in half.
  """
  @spec take(String.t(), integer) :: {String.t(), non_neg_integer}
  def take(_text, columns) when columns <= 0, do: {"", 0}

  def take(text, columns) do
    cond do
      ascii?(text) ->
        taken = binary_part(text, 0, min(columns, byte_size(text)))
        {taken, byte_size(taken)}

      narrow?(text) ->
        taken = String.slice(text, 0, columns)
        {taken, String.length(taken)}

      true ->
        take_wide(String.graphemes(text), columns, [], 0)
    end
  end

  # Prepending to `acc` and reversing once at the end is the usual way to
  # build a list in Elixir: adding to the front is cheap, to the end is not.
  defp take_wide([g | rest], room, acc, used) do
    w = grapheme(g)
    if w <= room, do: take_wide(rest, room - w, [g | acc], used + w), else: done(acc, used)
  end

  defp take_wide([], _room, acc, used), do: done(acc, used)

  defp done(acc, used), do: {acc |> Enum.reverse() |> Enum.join(), used}

  @doc """
  `text` without its first `columns` columns. A wide character cut in half
  leaves its right half as a space, so the rest starts where it should.
  """
  @spec drop(String.t(), integer) :: String.t()
  def drop(text, columns) when columns <= 0, do: text

  def drop(text, columns) do
    if narrow?(text),
      do: String.slice(text, columns..-1//1),
      else: drop_wide(String.graphemes(text), columns)
  end

  defp drop_wide(graphemes, 0), do: Enum.join(graphemes)
  defp drop_wide([], _skip), do: ""

  defp drop_wide([g | rest], skip) do
    case grapheme(g) do
      w when w <= skip -> drop_wide(rest, skip - w)
      # skip is 1, the grapheme 2 wide: its second column stays, blank
      _ -> " " <> Enum.join(rest)
    end
  end

  # Whether every byte is ASCII (below 128), checked a byte at a time. CR
  # is left to the careful path: CR LF is one grapheme, drawn as one glyph
  # (`Draw.clean/1`), but two bytes.
  defp ascii?(<<b, rest::binary>>) when b < 128 and b != ?\r, do: ascii?(rest)
  defp ascii?(<<>>), do: true
  defp ascii?(_text), do: false

  # Whether every character is below U+1100, where nothing is wide. A
  # binary is matched a UTF-8 character at a time (`c::utf8`); invalid
  # bytes fall to the last clause, and so to the slow, careful path.
  defp narrow?(<<c::utf8, rest::binary>>) when c < 0x1100, do: narrow?(rest)
  defp narrow?(<<>>), do: true
  defp narrow?(_text), do: false

  defp grapheme(<<c::utf8, rest::binary>>) do
    if wide?(c) or String.contains?(rest, "️"), do: 2, else: 1
  end

  defp grapheme(_invalid), do: 1

  # One function clause per range, written out at compile time: `for` here
  # runs while the module compiles, and `unquote` puts each range's numbers
  # into its clause's guard.
  for {first, last} <- @wide do
    defp wide?(c) when c >= unquote(first) and c <= unquote(last), do: true
  end

  defp wide?(_c), do: false
end
