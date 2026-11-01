# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Extras.Feeds.Messages do
  @moduledoc """
  What the feeds (R75) say: their prompts, questions and messages, kept
  beside the extra, not in `Agendum.TUI.Messages` (Agenda's words), so an
  extra keeps its texts with it (UI guidelines rule 7.5; the owner,
  2026-10-27: separation, for modularity). Pure.
  """

  alias Agendum.TUI.Terminal.Draw

  @doc "A text without anything to fill in."
  @spec text(atom) :: String.t()
  def text(:address), do: "Feed's web address (https:// or feed://):"

  def text(:read_while_typing),
    do: "Not subscribed: the feed was read while you typed. INS adds it"

  def text(:name), do: "Name of the feed (its category under Feeds):"
  def text(:rename), do: "New name of the feed:"
  def text(:import_opml), do: "OPML file to import:"
  def text(:export_opml), do: "Write the feed list (OPML) to:"
  def text(:bad_url), do: "A feed needs an https:// or feed:// address"
  def text(:no_name), do: "A feed needs a name"
  def text(:nothing_to_read), do: "No feeds to read now"

  @doc "A text naming a feed or a file, or how many ALT-ENTER reads."
  @spec text(atom, String.t() | non_neg_integer) :: String.t()
  # how many feeds ALT-ENTER reads
  def text(:reading_all, count), do: "Reading #{Draw.count(count, "feed")} …"
  def text(:duplicate, name), do: "#{name} is taken: another feed has that name"
  def text(:subscribed, name), do: "Subscribed to #{name}"
  def text(:unsubscribed, name), do: "Unsubscribed from #{name}"
  def text(:probing, url), do: "Reading #{url} …"
  def text(:unreadable, reason), do: "Not subscribed: #{reason}"

  def text(:nothing_new, name), do: "#{name}: nothing new"
  def text(:no_new_feeds, file), do: "#{file}: no feeds the file does not have already"
  def text(:not_opml, file), do: "#{file} is not an OPML feed list"

  @doc """
  A text with two things to fill in: a feed's name and what its read
  brought ("3 new, 1 faded") or why it failed; an unsubscribe's question
  with the items it has; the feeds an OPML list subscribed to.
  """
  @spec text(atom, String.t(), term) :: String.t()
  def text(:read, name, parts), do: "#{name}: #{parts}"
  def text(:failed, name, message), do: "#{name}: #{message}"

  def text(:unsubscribe, name, items),
    do: "Unsubscribe from #{name}. Discard its #{Draw.count(items, "item")} too?"

  def text(:opml_subscribed, file, count),
    do: "Subscribed to #{Draw.count(count, "feed")} from #{file}"
end
