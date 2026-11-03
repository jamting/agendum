# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Extras.Prompts do
  @moduledoc """
  The extras' answers to the control panel's prompts and questions:
  subscribing to a calendar (R45) or a feed (R75), renaming one, a feed
  list (OPML) to import or export, the SFTP server's password (R74),
  unsubscribing, and removing one of the blog's lists (R74e). Kept beside the extras (the owner's modularity,
  2026-10-27); `Agendum.TUI.Update.Prompts` hands them over. Pure.
  """

  alias Agendum.TUI.State
  alias Agendum.TUI.Extras.{CalendarsBox, FeedsBox, PublishPreviewBox}

  @doc "A prompt of the extras answered with `text`."
  @spec answered(State.t(), atom | tuple, String.t()) :: State.t()
  def answered(state, action, text)

  # the SFTP server's password (R74): the publish of the preview it was
  # asked for is tried again with it
  def answered(state, {:sftp_password, preview}, text),
    do: PublishPreviewBox.publish(state, preview, text)

  # Calendars (R45): the address, then a name for its category
  def answered(state, :calendar_url, text), do: CalendarsBox.address_typed(state, text)

  def answered(state, {:calendar_name, url, events}, name),
    do: CalendarsBox.name_typed(state, url, events, name)

  # Feeds (R75): the address, then, once it is read, its name (its
  # category under Feeds): the logic beside the extra, in its box
  def answered(state, :feed_url, text), do: FeedsBox.address_typed(state, text)

  def answered(state, {:feed_name, url, entries}, name),
    do: FeedsBox.name_typed(state, url, entries, name)

  # F2 in the Feeds and Calendars boxes (R75a): the name, and its category's
  def answered(state, {rename, id}, text) when rename in [:rename_feed, :rename_calendar] do
    case State.command(state, {rename, id, text}) do
      {:ok, state, _} ->
        State.info(state, "Renamed #{String.trim(text)}")

      {:error, :empty_text} ->
        State.error(state, "A name cannot be empty")

      {:error, :duplicate} ->
        State.error(state, "#{String.trim(text)} is taken: choose another name")
    end
  end

  def answered(state, :import_opml, text),
    do: State.effect(state, {:read_opml, String.trim(text)})

  def answered(state, :export_opml, text),
    do:
      State.effect(
        state,
        {:write_text, Path.expand(String.trim(text)), Agendum.Core.export_opml(state.db)}
      )

  @doc """
  Unsubscribing from a feed or a calendar, answered: `discard` says
  whether its items go too.
  """
  @spec confirmed(State.t(), tuple, boolean) :: State.t()
  def confirmed(state, {:unsubscribe_feed, id}, discard) do
    name = state.db.feeds[id].name

    State.run(
      state,
      {:unsubscribe_feed, id, discard},
      Agendum.TUI.Extras.Feeds.Messages.text(:unsubscribed, name)
    )
  end

  # one of the blog's lists removed (R74e), when the answer is Yes
  def confirmed(state, {:remove_blog_list, id}, true) do
    title = Agendum.Core.blog_lists(state.db, state.today) |> Enum.find(&(&1.category == id))

    State.run(
      state,
      {:remove_blog_list, id},
      Agendum.TUI.Extras.Publish.Messages.text(:list_removed, (title && title.title) || "")
    )
  end

  def confirmed(state, {:remove_blog_list, _id}, false), do: state

  def confirmed(state, {:unsubscribe_calendar, id}, discard) do
    name = state.db.calendars[id].name

    State.run(
      state,
      {:unsubscribe_calendar, id, discard},
      Agendum.TUI.Extras.Calendars.Messages.text(:unsubscribed, name)
    )
  end
end
