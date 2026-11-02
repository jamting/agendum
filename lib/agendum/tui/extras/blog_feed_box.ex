# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Extras.BlogFeedBox do
  @moduledoc """
  One of the blog's own feeds, its properties (Extras ▸ Publish ▸ Feeds,
  ENTER; R74, meeting 2026-11-02-1255, § 10): its title, a line about it,
  and its folder on the site, kept in the file. Changing the folder moves
  the feed at the next publish (the owner's choice, 2026-11-02).

  ENTER keeps the settings (one undo step), ESC changes nothing. A letter
  on a field starts typing it, F2 or SPACE edits what is there. The box is
  drawn from `@layout` (`Agendum.TUI.Boxes.Template`). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done

  alias Agendum.TUI.Boxes.{Box, FieldTyping, Template}
  alias Agendum.TUI.Extras.Publish.Messages
  alias Agendum.TUI.{State, Typing.LineEdit}

  @layout """
   Title          : [title                                            ]
   Description    : [description                                      ]
   Folder         : [slug                     ]
  """

  @help %{
    title:
      "The feed's name on its page and in its feeds. Type it; empty for the category's name.",
    description: "A line about the feed, on its page and in its feeds. Type it.",
    slug:
      "Its folder on the site: a-z, 0-9 and -. Changing it moves the feed when you publish. Type it."
  }

  @fields ~w(title description slug)a

  @doc "Opens the box for `feed` (as `Agendum.Core.blog_feeds/2` gives it)."
  @spec open(State.t(), map) :: State.t()
  def open(state, feed) do
    # the folder as set: empty while it is still to be made from the name
    # (at the first publish), so opening and keeping the box does not fix it
    slug = if feed.made, do: "", else: feed.slug

    State.push(state, %Agendum.TUI.Modes.PublishFeed{
      category: feed.category,
      made: feed.slug,
      settings: %{title: feed.title, description: feed.description, slug: slug},
      cursor: 0,
      typing: nil
    })
  end

  defp current(mode), do: Enum.at(Template.fields(@layout), mode.cursor)

  @impl Box
  def handle(state, mode, key) do
    if FieldTyping.typing?(mode),
      do: FieldTyping.key(state, mode, key, &typed/3),
      else: start_typing(state, mode, key)
  end

  defp start_typing(state, mode, {:char, c}), do: FieldTyping.start(state, mode, current(mode), c)
  defp start_typing(state, _mode, _key), do: state

  defp typed(state, field, text) do
    mode = State.mode(state)
    State.put_mode(state, %{mode | settings: Map.put(mode.settings, field, String.trim(text))})
  end

  @impl Box
  def keymap(_mode), do: Box.settings_keymap(%{{:f, 2} => :edit})

  @impl Box
  def commands(_mode) do
    Box.settings_commands([
      {:edit, "Edit", "Edit the setting's text"},
      {:done, "Keep", "Keep the feed's settings"},
      {:close, "Cancel", "Close, changing nothing"}
    ])
  end

  @impl Box
  def run(state, mode, id) when id in [:change, :edit] do
    field = current(mode)
    line = LineEdit.new(Map.fetch!(mode.settings, field))
    State.put_mode(state, %{mode | typing: {field, line}})
  end

  def run(state, mode, :done) do
    case State.command(state, {:set_blog_feed, mode.category, mode.settings}) do
      {:ok, state, _changes} -> state |> State.pop() |> State.info(Messages.text(:feed_kept))
      {:error, :bad_slug} -> State.error(state, Messages.text(:bad_slug))
      {:error, _} -> State.error(state, Messages.text(:bad_categories))
    end
  end

  def run(state, mode, id),
    do: Box.run_settings(state, mode, Template.grid(@layout, @fields), id)

  @impl Box
  def title(state, mode), do: "Feed: " <> state.db.categories[mode.category].name

  @impl Box
  def width(state, _mode), do: min(state.width - 4, 76)

  @impl Box
  def content(_state, mode, inner, _max_rows) do
    values = Map.new(@fields, &{&1, Map.fetch!(mode.settings, &1)})

    Template.render(@layout, values, [selected: current(mode)] ++ FieldTyping.editing(mode)) ++
      [
        [],
        [{:box, " " <> where(mode)}],
        Box.hint(keys(nil, mode), inner)
      ]
  end

  # where its page and feeds go; a folder still to be made says which
  defp where(%{settings: %{slug: ""}} = mode), do: Messages.text(:feed_made, mode.made)
  defp where(mode), do: Messages.text(:feed_where, mode.settings.slug)

  @impl Box
  def keys(_state, _mode), do: Box.settings_keys([{"type", "Text"}])

  @impl Box
  def help, do: @help

  @impl Box
  def field(_state, mode), do: current(mode)

  @impl Box
  def about(_state, _mode) do
    """
    One of the blog's own feeds: a category under the posts category. Its
    posts get an index page and their own RSS and JSON Feed in its folder.

    Title is its name there (empty: the category's), Description a line
    about it, Folder where it is on the site (a-z, 0-9 and -). A feed
    moved to another folder is written there at the next publish, and its
    old folder's files removed: whoever followed the old address loses
    it. ENTER keeps the settings; ESC closes the box, changing nothing.
    """
  end
end
