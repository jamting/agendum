# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.Utf8 do
  @moduledoc """
  Text from outside made valid UTF-8, before a parser reads it: a calendar
  or a feed sent in an 8-bit encoding (Latin-1, Windows-1252), or with a
  stray byte, would otherwise put bytes that are no text into items, and
  Elixir's Unicode regular expressions raise on them (text matching, the
  XML reader; the parser property tests, 2026-10-26).

  Valid UTF-8 is kept as it is; each byte that does not start a valid UTF-8
  character is read as Latin-1, the commonest 8-bit encoding, so `Café` in
  Latin-1 still reads `Café`. Control characters among them are shown as
  DOS glyphs on the screen (R82c). Pure.
  """

  @doc """
  The text as valid UTF-8.

      iex> Agendum.Core.Extras.Utf8.repair("Caf" <> <<0xE9>>)
      "Café"

      iex> Agendum.Core.Extras.Utf8.repair("Café")
      "Café"
  """
  @spec repair(binary) :: String.t()
  def repair(text) do
    # String.valid?/1 scans quickly; most text is already fine and is
    # returned as it came, without being copied
    if String.valid?(text), do: text, else: repair(text, [])
  end

  # `<<c::utf8, rest::binary>>` matches one whole UTF-8 character (never a
  # surrogate or a value past U+10FFFF); a byte that does not start one is
  # matched by the next clause and written as the Latin-1 character of the
  # same number (`<<byte::utf8>>` encodes the number as UTF-8). The pieces
  # are collected as iodata, a nested list, and joined once at the end.
  defp repair(<<c::utf8, rest::binary>>, acc), do: repair(rest, [acc, <<c::utf8>>])
  defp repair(<<byte, rest::binary>>, acc), do: repair(rest, [acc, <<byte::utf8>>])
  defp repair(<<>>, acc), do: IO.iodata_to_binary(acc)
end
