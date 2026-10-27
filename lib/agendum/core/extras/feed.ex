defmodule Agendum.Core.Extras.Feed do
  @moduledoc """
  A feed subscription (R75): an RSS or Atom feed on the web whose entries
  become items in a category of their own, Feeds ▸ its name. Like a
  calendar subscription (`Agendum.Core.Extras.Calendar`, R45).

    * `url`: where it is read from (`feed://` is read as `https://`)
    * `category_id`: the category its items go in
    * `keep_days`: how long an entry stays, from its publish date, unless
      the person kept it (30; nil: for ever). See `Agendum.Core.Extras.FeedSync`
    * `refresh_minutes`: how often it is read while Agendum runs (60), or
      nil for only on request
    * `entries`: for each entry (by its id) its item and publish date, and
      fingerprints of the title and note the feed last wrote:
      `%{item: id, published, title_print, note_print}` (`snapshot/2`;
      ADR 0048, format 46), so a refresh can tell the person's edits from the
      feed's without a copy of the text. Once the entry faded or the person
      discarded it, only `%{item: nil, published}` is kept (`forget/1`), so
      a refresh does not bring it back (format 45)
    * `refreshed_at`, `error`: when it was last read, and why that failed

  Pure.
  """

  alias Agendum.Core.Extras.Fingerprint

  # Domain: `|` between two map types: a snapshot is one shape or the
  # other, a live entry with its text, or a forgotten one without
  @type snapshot ::
          %{
            item: pos_integer,
            published: Date.t(),
            title_print: Fingerprint.t(),
            note_print: Fingerprint.t()
          }
          | %{item: nil, published: Date.t()}
  @type t :: %__MODULE__{
          id: pos_integer | nil,
          name: String.t(),
          url: String.t(),
          category_id: pos_integer,
          keep_days: pos_integer | nil,
          refresh_minutes: pos_integer | nil,
          entries: %{optional(String.t()) => snapshot},
          refreshed_at: NaiveDateTime.t() | nil,
          error: String.t() | nil
        }
  defstruct [
    :id,
    :name,
    :url,
    :category_id,
    keep_days: 30,
    refresh_minutes: 60,
    entries: %{},
    refreshed_at: nil,
    error: nil
  ]

  @refresh [nil, 60, 360, 1440]
  @keep [7, 30, 90, 365, nil]

  @doc """
  What is kept of a live entry: its item, its publish date, and
  fingerprints of the title and note the feed wrote (`wanted`, with `title`,
  `note` and `published`).
  """
  # `optional(atom) => term`: the map may have other keys too (the link,
  # an old snapshot's item); a map type without it allows only those named
  @spec snapshot(pos_integer, %{
          :title => String.t(),
          :note => String.t(),
          :published => Date.t(),
          optional(atom) => term
        }) :: snapshot
  def snapshot(item, wanted),
    do: %{
      item: item,
      published: wanted.published,
      title_print: Fingerprint.of(wanted.title),
      note_print: Fingerprint.of(wanted.note)
    }

  @doc """
  What is kept of an entry whose item faded or was discarded: its publish
  date, no item, and none of its text, which only the item needed. A faded
  entry is remembered so that a refresh does not bring it back; in a file
  with many feeds, the text was most of the file (13,184 such entries, 12.7
  of 17 MB as a term, in the owner's file on 2026-10-26).
  """
  @spec forget(map) :: snapshot
  def forget(%{published: published}), do: %{item: nil, published: published}

  @doc "The choices for how often to read a feed (minutes; nil: only on request)."
  @spec refresh_choices() :: [pos_integer | nil]
  def refresh_choices, do: @refresh

  @doc "The choices for how long entries stay (days; nil: for ever)."
  @spec keep_choices() :: [pos_integer | nil]
  def keep_choices, do: @keep

  @doc "A feed's address made readable: `feed://` as `https://`; `:error` for no web address."
  @spec normalize_url(String.t()) :: {:ok, String.t()} | :error
  def normalize_url(url) do
    url = String.trim(url)

    cond do
      String.starts_with?(String.downcase(url), "feed://") ->
        {:ok, "https://" <> String.slice(url, 7..-1//1)}

      Regex.match?(~r{^https?://\S+$}i, url) ->
        {:ok, url}

      true ->
        :error
    end
  end

  @doc "Whether the feed is due to be read at `now`."
  @spec due?(t, NaiveDateTime.t()) :: boolean
  def due?(%__MODULE__{refresh_minutes: nil}, _now), do: false
  def due?(%__MODULE__{refreshed_at: nil}, _now), do: true

  def due?(%__MODULE__{refreshed_at: at, refresh_minutes: minutes}, now),
    do: NaiveDateTime.diff(now, at, :second) >= minutes * 60

  @doc "The next (1) or previous (-1) choice for a setting."
  @spec cycle(t, :refresh_minutes | :keep_days, integer) :: t
  def cycle(feed, :refresh_minutes, step),
    do: %{feed | refresh_minutes: next(@refresh, feed.refresh_minutes, step)}

  def cycle(feed, :keep_days, step), do: %{feed | keep_days: next(@keep, feed.keep_days, step)}

  defp next(list, value, step) do
    index = Enum.find_index(list, &(&1 == value)) || 0
    Enum.at(list, Integer.mod(index + step, length(list)))
  end
end
