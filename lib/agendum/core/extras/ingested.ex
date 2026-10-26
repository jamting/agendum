defmodule Agendum.Core.Extras.Ingested do
  @moduledoc """
  Ingested categories (R75a; meeting 2026-10-26-5, § 6; ADR 0048): the
  categories an extra fills, which the person reads but does not change or
  fill by hand. They are each feed's and each calendar's category, and a
  family that holds only those: the Feeds family, the Calendars family.

  Worked out from the subscriptions, never stored (as subsumption is,
  CLAUDE.md rule 4): unsubscribing hands a category back to the person by
  itself, and nothing can go out of step. The feed and the calendar file
  into them below the commands (`FeedSync`, `CalendarSync`); a person's
  command that would change one is refused (`Agendum.Core.Command`). Pure.
  """

  alias Agendum.Core.Database

  @doc "The ingested categories' ids."
  @spec categories(Database.t()) :: MapSet.t(Database.id())
  def categories(db) do
    feeds = for {_, feed} <- db.feeds, do: feed.category_id
    calendars = for {_, cal} <- db.calendars, do: cal.category_id

    own = MapSet.new(feeds ++ calendars)

    # the families that hold only those (Feeds, Calendars), never MAIN: a
    # family of the person's with a calendar among other things stays theirs
    parents =
      for id <- own,
          parent = db.categories[id] && db.categories[id].parent_id,
          parent != nil and parent != db.main_id,
          Enum.all?(db.categories[parent].children, &MapSet.member?(own, &1)),
          uniq: true,
          do: parent

    MapSet.union(own, MapSet.new(parents))
  end

  @doc "Whether a category is ingested."
  @spec ingested?(Database.t(), Database.id()) :: boolean
  def ingested?(db, id), do: MapSet.member?(categories(db), id)
end
