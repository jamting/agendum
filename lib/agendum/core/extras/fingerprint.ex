# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.Fingerprint do
  @moduledoc """
  A short fingerprint of a text (ADR 0048): what an extra keeps of the text
  it filed into an item, to tell later whether the item still says it,
  without keeping a copy (the item holds the text). A feed's snapshots kept
  copies until format 46: 3.6 MB as a term in the owner's file, against 2.0
  MB for all the items (2026-10-26). Pure.
  """

  # Domain: `:erlang.phash2/2` is the same on every machine and Erlang
  # version, so a fingerprint saved today still matches tomorrow; with 2^32
  # values, two different texts sharing one is about a one in four billion
  # chance, enough to tell "changed or not", not to trust for security
  @range 4_294_967_296

  @typedoc "A fingerprint: an integer from 0 to 2^32 − 1."
  @type t :: non_neg_integer

  @doc "The fingerprint of `text`."
  @spec of(String.t()) :: t
  def of(text) when is_binary(text), do: :erlang.phash2(text, @range)
end
