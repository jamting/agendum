# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Extras.Calendars.Messages do
  @moduledoc """
  What the calendars (R45) say: their prompts, questions and messages,
  kept beside the extra (UI guidelines rule 7.5; see
  `Agendum.TUI.Extras.Feeds.Messages`). Pure.
  """

  alias Agendum.TUI.Terminal.Draw

  @doc "A text without anything to fill in."
  @spec text(atom) :: String.t()
  def text(:address), do: "Calendar's web address (https:// or webcal://):"
  def text(:name), do: "Name of its category (its events go there):"
  def text(:rename), do: "New name of the calendar:"
  def text(:bad_url), do: "A calendar needs an https:// or webcal:// address"
  def text(:no_name), do: "A calendar needs a name"
  def text(:nothing_to_read), do: "No calendars to read now"

  @doc "A text naming a calendar, or how many ALT-ENTER reads."
  @spec text(atom, String.t() | non_neg_integer) :: String.t()
  # how many calendars ALT-ENTER reads
  def text(:reading_all, count), do: "Reading #{Draw.count(count, "calendar")} …"
  def text(:duplicate, name), do: "#{name} is taken: another calendar has that name"
  def text(:subscribed, name), do: "Subscribed to #{name}"
  def text(:unsubscribed, name), do: "Unsubscribed from #{name}"
  def text(:probing, url), do: "Reading #{url} …"
  def text(:unreadable, reason), do: "Not subscribed: #{reason}"
  def text(:no_changes, name), do: "#{name}: no changes"

  @doc """
  A calendar's name with what its read brought ("2 new, 1 removed") or why
  it failed; an unsubscribe's question with the items it has.
  """
  @spec text(atom, String.t(), term) :: String.t()
  def text(:read, name, parts), do: "#{name}: #{parts}"
  def text(:failed, name, message), do: "#{name}: #{message}"

  def text(:unsubscribe, name, items),
    do: "Unsubscribe from #{name}. Discard its #{Draw.count(items, "item")} too?"
end
