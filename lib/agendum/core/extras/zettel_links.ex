# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.ZettelLinks do
  @moduledoc """
  Links between zettels (R73b): where they are in a text, what they point
  at, and which items point at an item. Pure.

  Two kinds of text are links:

    * `[[bonalaku]]`, a Zettel id in double brackets: a link whether or
      not an item has the id; one no item has is *broken*;
    * a bare word that is the Zettel id of an item in the file
      (`bonalaku`); an eight-letter word no item has stays plain text.

  The case of the letters does not matter, as `Agendum.Core.Extras.ZettelId`
  reads ids.
  """

  alias Agendum.Core.Database
  alias Agendum.Core.Extras.ZettelId
  alias Agendum.Core.Facade.Extras.Zettels

  @typedoc """
  A link found in a text: where it starts and how long it is, in
  characters (graphemes), the id as written, and the item it points at
  (nil for a broken link).
  """
  @type link :: %{
          at: non_neg_integer,
          length: pos_integer,
          word: String.t(),
          target: Database.id() | nil,
          bracketed: boolean
        }

  # `[[word]]` or a word of eight letters standing alone. Domain: `\b` is a
  # word boundary, so "bonalakus" or "xbonalaku" are not ids; with the `u`
  # flag letters such as å count as word characters there too.
  @pattern ~r/\[\[([[:alpha:]]{8})\]\]|\b([[:alpha:]]{8})\b/u

  @doc """
  The links in `text`, in order. `used` is the Zettel ids in use, number
  to item (`Agendum.Core.zettels/1`), computed once by the caller when it
  scans many texts.
  """
  @spec scan(String.t(), %{optional(non_neg_integer) => Database.id()}) :: [link]
  def scan(text, used) do
    # `return: :index` gives each match as {byte offset, byte length}
    # pairs, the whole match first, then each group (unmatched: {-1, 0})
    @pattern
    |> Regex.scan(text, return: :index)
    |> at_characters(text)
    |> Enum.flat_map(fn {start, len, at} ->
      whole = binary_part(text, start, len)
      bracketed = String.starts_with?(whole, "[[")
      word = if bracketed, do: binary_part(whole, 2, len - 4), else: whole

      case {ZettelId.decode(word), bracketed} do
        {{:ok, n}, true} ->
          [link(text, start, len, at, word, Map.get(used, n), true)]

        {{:ok, n}, false} when is_map_key(used, n) ->
          [link(text, start, len, at, word, used[n], false)]

        _ ->
          []
      end
    end)
  end

  # Each match's position in characters, as the screen counts them,
  # counted on from the match before (the matches are in order): counting
  # from the text's start each time made a long text of many eight-letter
  # words take quadratic time (the parser property tests, 2026-10-26).
  defp at_characters(matches, text) do
    matches
    |> Enum.map_reduce({0, 0}, fn [{start, len} | _groups], {byte_at, char_at} ->
      at = char_at + String.length(binary_part(text, byte_at, start - byte_at))
      {{start, len, at}, {start, at}}
    end)
    |> elem(0)
  end

  defp link(text, start, len, at, word, target, bracketed) do
    %{
      at: at,
      length: String.length(binary_part(text, start, len)),
      word: word,
      target: target,
      bracketed: bracketed
    }
  end

  @doc """
  The items an item links to, from its text and then its note, each once,
  in the order they are written; broken links and links to itself left out.
  """
  @spec targets(Database.t(), Database.id()) :: [Database.id()]
  def targets(db, item_id), do: targets(db, item_id, Zettels.zettels(db))

  defp targets(db, item_id, used) do
    item = db.items[item_id]

    (scan(item.text, used) ++ scan(item.note, used))
    |> Enum.map(& &1.target)
    |> Enum.reject(&(&1 in [nil, item_id]))
    |> Enum.uniq()
  end

  @doc "The items that link to an item, in the file's order (\"Linked from\")."
  @spec linked_from(Database.t(), Database.id()) :: [Database.id()]
  def linked_from(db, item_id) do
    case db.items[item_id].zettel do
      nil ->
        []

      _ ->
        used = Zettels.zettels(db)
        Enum.filter(db.item_order, &(item_id in targets(db, &1, used)))
    end
  end

  @doc """
  The text with its bracketed links blanked out, for text matching, which
  ignores links (R73b): `[[bonalaku]]` becomes spaces of the same length.
  """
  @spec strip(String.t()) :: String.t()
  def strip(text) do
    if String.contains?(text, "[["),
      do:
        Regex.replace(
          ~r/\[\[[[:alpha:]]{8}\]\]/u,
          text,
          &String.duplicate(" ", String.length(&1))
        ),
      else: text
  end
end
