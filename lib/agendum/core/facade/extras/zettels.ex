# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Facade.Extras.Zettels do
  @moduledoc """
  Zettel ids (R73, ADR 0039): giving items their Quadsyl-24 ids
  (`Agendum.Core.Extras.ZettelId`) and finding an item by its id.

  An item's `zettel` is the number its id spells; the file's `next_zettel`
  is the next number to give. Numbers are never given twice: an item that
  is discarded takes its id with it, and the counter only goes up.

  Called through `Agendum.Core`.
  """

  alias Agendum.Core.Database
  alias Agendum.Core.Extras.ZettelId

  @typep db :: Agendum.Core.db()
  @typep id :: Agendum.Core.id()

  @doc """
  Gives each of the items that has no Zettel id the next one, in the
  order given, skipping the reserved words; an item that has one keeps it.
  Returns the ids given, `{item, word}`, in order (`[]` when every item
  had one), or `{:error, :zettels_full}` when the 24-bit space is used up.
  """
  @spec attach_zettels(db, [id]) :: {:ok, db, [{id, ZettelId.id()}]} | {:error, :zettels_full}
  def attach_zettels(db, ids) do
    # `Enum.reduce_while/3` stops early with `{:halt, acc}`: here when the
    # counter has run out, so the whole command is refused, not half done
    ids
    |> Enum.uniq()
    |> Enum.reject(&db.items[&1].zettel)
    |> Enum.reduce_while({:ok, db, []}, fn id, {:ok, db, given} ->
      case ZettelId.next_unreserved(db.next_zettel) do
        {:error, :out_of_range} ->
          {:halt, {:error, :zettels_full}}

        n ->
          db = Database.update_item(db, id, &%{&1 | zettel: n})
          {:cont, {:ok, %{db | next_zettel: n + 1}, [{id, ZettelId.encode!(n)} | given]}}
      end
    end)
    |> case do
      {:ok, db, given} -> {:ok, db, Enum.reverse(given)}
      error -> error
    end
  end

  # Links between zettels (R73b), from `Agendum.Core.Extras.ZettelLinks`: the
  # facade reaches the extras only through this area (ADR 0044).
  defdelegate zettel_links(text, used), to: Agendum.Core.Extras.ZettelLinks, as: :scan
  defdelegate link_targets(db, id), to: Agendum.Core.Extras.ZettelLinks, as: :targets
  defdelegate linked_from(db, id), to: Agendum.Core.Extras.ZettelLinks

  @doc "An item's Zettel id as its word (`\"bonalaku\"`), or nil when it has none."
  @spec zettel(Agendum.Core.Item.t()) :: ZettelId.id() | nil
  def zettel(%{zettel: nil}), do: nil
  def zettel(%{zettel: n}), do: spell(n)

  @doc """
  The item whose Zettel id is `word` (any case, as `ZettelId.decode/1`
  reads it), or nil when no item has it.
  """
  @spec item_by_zettel(db, String.t()) :: id | nil
  def item_by_zettel(db, word) do
    case ZettelId.decode(word) do
      {:ok, n} -> Map.get(zettels(db), n)
      {:error, _} -> nil
    end
  end

  @doc "The Zettel ids in use: each number to the item that has it."
  @spec zettels(db) :: %{optional(non_neg_integer) => id}
  def zettels(db), do: for({id, %{zettel: n}} <- db.items, n != nil, into: %{}, do: {n, id})

  # A number the file holds is spelled even when it is a reserved word (a
  # special id, which `encode/1` refuses to give out): `scramble` and the
  # spelling are the same for every number.
  defp spell(n) do
    case ZettelId.encode(n) do
      {:ok, word} -> word
      {:error, :reserved} -> reserved_word(n)
    end
  end

  defp reserved_word(n),
    do: Enum.find_value(ZettelId.reserved(), fn {word, m} -> if m == n, do: word end)
end
