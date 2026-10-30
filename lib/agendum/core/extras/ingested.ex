defmodule Agendum.Core.Extras.Ingested do
  @moduledoc """
  Ingested categories (R75a; meeting 2026-10-26-1732, § 6; ADR 0048): the
  categories an extra fills, which the person reads but does not change or
  fill by hand. They are each feed's and each calendar's category (`own/1`),
  and the extras' families (`families/1`): Feeds and Calendars under MAIN,
  each while it holds at least one of them. A family's structure is locked
  (its name, its place, discarding it, children of the person's); a
  category the person kept from a subscription stays theirs inside it (code
  review 2026-10-26: a kept one must not unlock the family and with it the
  other subscriptions).

  Worked out from the subscriptions, never stored (as subsumption is,
  CLAUDE.md rule 4): unsubscribing the last one hands the family back by
  itself. The feed and the calendar file into them below the commands
  (`FeedSync`, `CalendarSync`); a person's command that would change one is
  refused (`Agendum.Core.Command`). Pure.
  """

  alias Agendum.Core.Database

  # the extras' families: their names under MAIN, normalised
  @families [feeds: "feeds", calendars: "calendars"]

  @doc "The ingested categories' ids: the subscriptions' own and the families."
  @spec categories(Database.t()) :: MapSet.t(Database.id())
  def categories(db), do: db |> own() |> MapSet.union(MapSet.new(families(db)))

  @doc "Each feed's and each calendar's category."
  @spec own(Database.t()) :: MapSet.t(Database.id())
  def own(db) do
    MapSet.new(
      for({_, feed} <- db.feeds, do: feed.category_id) ++
        for({_, cal} <- db.calendars, do: cal.category_id)
    )
  end

  @doc """
  The extras' families that hold a subscription now: Feeds while it holds a
  feed's category, Calendars while it holds a calendar's.
  """
  @spec families(Database.t()) :: [Database.id()]
  def families(db) do
    for {kind, name} <- @families,
        family = family(db, name),
        family != nil,
        holds?(db, family, kind),
        do: family
  end

  @doc "The extra's family of that name under MAIN (\"Feeds\", \"Calendars\"), or nil."
  @spec family(Database.t(), String.t()) :: Database.id() | nil
  def family(db, name) do
    wanted = Database.normalize(name)

    Enum.find(
      db.categories[db.main_id].children,
      &(Database.normalize(db.categories[&1].name) == wanted)
    )
  end

  defp holds?(db, family, :feeds),
    do: Enum.any?(db.feeds, fn {_, f} -> db.categories[f.category_id].parent_id == family end)

  defp holds?(db, family, :calendars),
    do: Enum.any?(db.calendars, fn {_, c} -> db.categories[c.category_id].parent_id == family end)

  @doc "Whether a category is ingested."
  @spec ingested?(Database.t(), Database.id()) :: boolean
  def ingested?(db, id), do: MapSet.member?(categories(db), id)
end
