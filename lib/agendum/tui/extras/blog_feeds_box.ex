# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Extras.BlogFeedsBox do
  @moduledoc """
  The blog's own feeds (Extras ▸ Publish ▸ Feeds, R74; meeting
  2026-11-02-1255, §§ 9–10): one for each child category of Posts, each
  with its own index page and feeds in its folder. A list whose ENTER (or
  F6) opens the highlighted feed's properties box
  (`Agendum.TUI.Extras.BlogFeedBox`), as the view manager opens a view's
  (ADR 0049). A new feed is a new category under Posts, made in the
  category manager. ESC closes the box. Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :none

  alias Agendum.TUI.{Boxes.Box, Boxes.Scroll, Terminal.Draw, State}
  alias Agendum.TUI.Extras.Publish.Messages

  @doc "Opens the list; before the blog has a posts category it says so instead."
  @spec open(State.t()) :: State.t()
  def open(%State{db: %{blog: %{posts: nil}}} = state),
    do: State.error(state, Messages.text(:no_posts_category))

  def open(state) do
    count = length(feeds(state))
    State.push(state, %Agendum.TUI.Modes.PublishFeeds{cursor: 0, count: count})
  end

  defp feeds(state), do: Agendum.Core.blog_feeds(state.db, state.today)

  @impl Box
  def handle(state, _mode, _key), do: state

  @impl Box
  def keymap(_mode) do
    %{
      :up => :up,
      :down => :down,
      :home => :first,
      :end => :last,
      :enter => :properties,
      {:f, 6} => :properties,
      :esc => :close
    }
  end

  @impl Box
  def commands(_mode) do
    [{:properties, "Properties", "Its title, description and folder"}] ++
      Box.list_moves() ++ [{:close, "Return", "Back to the view"}]
  end

  @impl Box
  def run(state, _mode, :close), do: State.pop(state)

  # the number of feeds as the list opened: a key moving the highlight
  # does not work them all out again (feeds change only in the category
  # manager, not while the list is open)
  def run(state, mode, id) when id in [:up, :down, :first, :last],
    do: Box.list_move(state, mode, max(mode.count, 1), id)

  def run(state, mode, :properties) do
    case Enum.at(feeds(state), mode.cursor) do
      nil -> state
      feed -> Agendum.TUI.Extras.BlogFeedBox.open(state, feed)
    end
  end

  def run(state, _mode, _id), do: state

  @impl Box
  def title(_state, _mode), do: "Publish: feeds"

  @impl Box
  def width(state, _mode), do: min(state.width - 4, 76)

  @impl Box
  def content(state, mode, inner, max_rows) do
    rows =
      case feeds(state) do
        [] ->
          [[{:normal, Messages.text(:no_feeds, posts_name(state))}]]

        feeds ->
          feeds
          |> Enum.with_index()
          |> Enum.map(fn {feed, i} ->
            style = if i == mode.cursor, do: :selected, else: :normal
            count = Draw.count(length(feed.posts), "post")
            [{style, Draw.pad(feed.title, 28) <> " /#{feed.slug}/  " <> count}]
          end)
      end
      |> Enum.map(fn group -> Enum.map(group, &row/1) end)
      |> Scroll.window(mode.cursor, max(max_rows - 2, 4), &row({:normal, &1}))

    rows ++ [[], Box.hint(keys(state, mode), inner)]
  end

  defp posts_name(state), do: state.db.categories[state.db.blog.posts].name

  defp row({style, text}),
    do: [{if(style == :selected, do: :box_selected, else: :box), " " <> text}]

  @impl Box
  def keys(_state, _mode), do: [{"ENTER", "Properties", "properties"}, {"ESC", "Close"}]

  @impl Box
  def help, do: "The blog's own feeds: each category under Posts. ENTER shows a feed's settings."

  @impl Box
  def about(_state, _mode) do
    """
    The blog's own feeds: each category right under the posts category is
    one, with its own index page and its own RSS and JSON Feed in a
    folder of its own (devlog/). The site's main index and feeds keep
    every post, and its index names these feeds.

    A new feed is a new category under the posts category: add it in the
    category manager (F9, INS). ENTER or F6 shows the highlighted feed's
    settings: its title, a line about it, and its folder. ESC goes back.
    """
  end
end
