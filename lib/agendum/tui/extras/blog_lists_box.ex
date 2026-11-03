# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Extras.BlogListsBox do
  @moduledoc """
  The blog's lists (Extras ▸ Publish ▸ Lists, R74e; meeting
  2026-11-02-2244, § 6, the owner's choices of 2026-11-03): any of the
  person's own categories, each published as its switches say. A list
  whose ENTER (or F6) opens the highlighted list's box
  (`Agendum.TUI.Extras.BlogListBox`), as the view manager opens a view's
  (ADR 0049); INS or CTRL-N opens it for a new list, DEL or CTRL-D removes
  the highlighted one after asking, as the Feeds box subscribes and
  unsubscribes. ESC closes the box. Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :none

  alias Agendum.TUI.{Boxes.Box, Boxes.Scroll, Terminal.Draw, State}
  alias Agendum.TUI.Extras.Publish.Messages

  @doc "Opens the list; before the blog has a posts category it says so instead."
  @spec open(State.t()) :: State.t()
  def open(%State{db: %{blog: %{posts: nil}}} = state),
    do: State.error(state, Messages.text(:no_posts_category))

  def open(state), do: State.push(state, %Agendum.TUI.Modes.PublishLists{cursor: 0})

  defp lists(state), do: Agendum.Core.blog_lists(state.db, state.today)

  # Domain: how many lists there are, from the file's settings alone: a key
  # moving the highlight does not work out every list's items again
  defp count(state), do: map_size(state.db.blog.lists)

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
      :insert => :add,
      {:ctrl, "n"} => :add,
      :delete => :remove,
      {:ctrl, "d"} => :remove,
      :esc => :close
    }
  end

  @impl Box
  def commands(_mode) do
    [
      {:properties, "Properties", "Its switches, fields, folder and more"},
      {:add, "Add", "Make one of your categories a list"},
      {:remove, "Remove", "No longer a list; the category stays"}
    ] ++ Box.list_moves() ++ [{:close, "Return", "Back to the view"}]
  end

  @impl Box
  def run(state, _mode, :close), do: State.pop(state)
  def run(state, _mode, :add), do: Agendum.TUI.Extras.BlogListBox.open_new(state)

  def run(state, mode, id) when id in [:up, :down, :first, :last],
    do: Box.list_move(state, mode, max(count(state), 1), id)

  def run(state, mode, id) when id in [:properties, :remove] do
    # the highlight kept on a list after one was removed below it
    mode = %{mode | cursor: mode.cursor |> min(count(state) - 1) |> max(0)}
    state = State.put_mode(state, mode)

    case Enum.at(lists(state), mode.cursor) do
      nil -> state
      list when id == :properties -> Agendum.TUI.Extras.BlogListBox.open(state, list)
      list -> remove(state, list)
    end
  end

  def run(state, _mode, _id), do: state

  # DEL: asked first, as unsubscribing is (the owner, 2026-11-03)
  defp remove(state, list) do
    Agendum.TUI.Update.Prompts.ask(
      state,
      Messages.text(:remove_list, list.title),
      {:remove_blog_list, list.category}
    )
  end

  @impl Box
  def title(_state, _mode), do: "Publish: lists"

  @impl Box
  def width(state, _mode), do: min(state.width - 4, 76)

  @impl Box
  def content(state, mode, inner, max_rows) do
    rows =
      case lists(state) do
        [] ->
          [[{:normal, Messages.text(:no_lists)}]]

        lists ->
          lists
          |> Enum.with_index()
          |> Enum.map(fn {list, i} ->
            style = if i == mode.cursor, do: :selected, else: :normal
            [{style, line(list)}]
          end)
      end
      |> Enum.map(fn group -> Enum.map(group, &row/1) end)
      |> Scroll.window(mode.cursor, max(max_rows - 2, 4), &row({:normal, &1}))

    rows ++ [[], Box.hint(keys(state, mode), inner)]
  end

  # "Devlog   /devlog/   12 items  index feeds pages tags notes"
  defp line(list) do
    switches =
      [index: "index", feeds: "feeds", item_pages: "pages", tag_pages: "tags", notes: "notes"]
      |> Enum.filter(fn {key, _word} -> Map.fetch!(list, key) end)
      |> Enum.map_join(" ", &elem(&1, 1))

    Draw.pad(list.title, 18) <>
      " " <>
      Draw.pad("/#{list.slug}/", 15) <>
      Draw.pad(Draw.count(length(list.items), "item"), 10) <> switches
  end

  defp row({style, text}),
    do: [{if(style == :selected, do: :box_selected, else: :box), " " <> text}]

  @impl Box
  def keys(_state, _mode),
    do: [
      {"ENTER", "Properties", "properties"},
      {"INS", "Add", "add"},
      {"DEL", "Remove", "remove"},
      {"ESC", "Close"}
    ]

  @impl Box
  def help,
    do: "The blog's lists: your categories published. ENTER its settings, INS adds, DEL removes."

  @impl Box
  def about(_state, _mode) do
    """
    The blog's lists: any of your own categories, its items published as
    the list says. Each can have an index page, its own RSS and JSON Feed,
    and a page per item, in a folder of its own (devlog/), and it says
    whether its items' notes go out and which of their fields (Role,
    Email) the templates see; nothing else leaves the file. The site's
    main index names the lists with feeds.

    ENTER or F6 shows the highlighted list's settings. INS (or CTRL-N)
    makes another of your categories a list, starting with only its index
    page; DEL (or CTRL-D) removes one after asking: its pages go from the
    site at the next publish, the category and its items stay. ESC goes
    back.
    """
  end
end
