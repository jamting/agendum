defmodule Agendum.Core.Feed do
  @moduledoc """
  A feed subscription (R75): an RSS or Atom feed on the web whose entries
  become items in a category of their own, Feeds ▸ its name. Like a
  calendar subscription (`Agendum.Core.Calendar`, R45).

    * `url`: where it is read from (`feed://` is read as `https://`)
    * `category_id`: the category its items go in
    * `keep_days`: how long an entry stays, from its publish date, unless
      the person kept it (30; nil: for ever). See `Agendum.Core.FeedSync`
    * `refresh_minutes`: how often it is read while Agendum runs (60), or
      nil for only on request
    * `entries`: what each entry (by its id) looked like when last read,
      and its item: `%{item: id | nil, title, note, link, published}`; the
      item is nil once the entry faded or the person discarded it, so a
      refresh does not bring it back
    * `refreshed_at`, `error`: when it was last read, and why that failed

  Pure.
  """

  @type snapshot :: %{
          item: pos_integer | nil,
          title: String.t(),
          note: String.t(),
          link: String.t(),
          published: Date.t()
        }
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
  @spec cycle(t, :refresh_minutes | :keep_days, 1 | -1) :: t
  def cycle(feed, :refresh_minutes, step),
    do: %{feed | refresh_minutes: next(@refresh, feed.refresh_minutes, step)}

  def cycle(feed, :keep_days, step), do: %{feed | keep_days: next(@keep, feed.keep_days, step)}

  defp next(list, value, step) do
    index = Enum.find_index(list, &(&1 == value)) || 0
    Enum.at(list, Integer.mod(index + step, length(list)))
  end
end
