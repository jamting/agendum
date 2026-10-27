defmodule Agendum.TUI.Extras.PublishPreviewBox do
  @moduledoc """
  What publishing would do (R74), before anything is written: the files
  of the site that are new, changed and to be removed in the folder, and
  where they then go (uploaded by rsync or SFTP, or only the folder). A
  post is public once uploaded, so this is the last look.

  ENTER writes the folder and uploads it; ESC changes nothing on disk
  (the posts keep the Zettel ids Publish gave them). ↑ ↓ PGUP PGDN
  scroll the list. Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :return

  alias Agendum.Core.Extras.Site
  alias Agendum.TUI.Boxes.Box
  alias Agendum.TUI.Extras.Publish.Messages
  alias Agendum.TUI.State
  alias Agendum.TUI.Terminal.Draw

  @doc "Opens the box for `files` (the site), and what they would change in `folder`."
  @spec open(State.t(), String.t(), [Site.file()], Site.changes()) :: State.t()
  def open(state, folder, files, changes) do
    State.push(state, %Agendum.TUI.Modes.PublishPreview{
      folder: folder,
      files: files,
      changes: changes,
      top: 0
    })
  end

  @doc "Whether publishing would change nothing in the folder."
  @spec nothing?(Site.changes()) :: boolean
  def nothing?(changes), do: Enum.all?(Map.values(changes), &(&1 == []))

  @doc "The changes in a few words: \"2 added, 1 changed, 0 removed\"."
  @spec summary(Site.changes()) :: String.t()
  def summary(changes),
    do:
      "#{length(changes.added)} added, #{length(changes.changed)} changed, #{length(changes.removed)} removed"

  @impl Box
  def about(_state, _mode) do
    """
    What Publish would do to the site's folder: the files it adds, those
    it changes, and those it removes (a post that is no longer a post).
    Nothing else in the folder is touched.

    ENTER writes them, and uploads the site when the Publish box says so;
    once uploaded, the posts are public. ESC changes nothing. ↑ ↓ PGUP
    PGDN scroll.
    """
  end

  @impl Box
  def handle(state, mode, key) do
    step =
      case key do
        :up -> -1
        :down -> 1
        :pgup -> -page(state)
        :pgdn -> page(state)
        _ -> 0
      end

    last = max(length(content_lines(state, mode)) - page(state), 0)
    State.put_mode(state, %{mode | top: min(max(mode.top + step, 0), last)})
  end

  defp page(state), do: max(state.height - 10, 3)

  defp content_lines(state, mode),
    do: Enum.flat_map(lines(state, mode), &Draw.wrap(&1, max(width(state, mode) - 4, 10)))

  @impl Box
  def keymap(_mode), do: %{:enter => :publish, :esc => :close}

  @impl Box
  def commands(_mode) do
    [
      {:publish, "Publish", "Write the folder and upload it"},
      {:close, "Cancel", "Write and upload nothing"}
    ]
  end

  @impl Box
  def run(state, _mode, :close),
    do: State.pop(state) |> State.info(Messages.text(:nothing_published))

  def run(state, mode, :publish), do: publish(state, mode, nil)

  @doc "Writes and uploads, with the SFTP password when one was asked for."
  @spec publish(State.t(), map, String.t() | nil) :: State.t()
  def publish(state, mode, password) do
    state
    |> State.info(Messages.text(:publishing))
    |> State.effect({:publish, mode.folder, mode.files, mode.changes, password})
  end

  @impl Box
  def title(_state, _mode), do: "Publish: what will change"

  @impl Box
  def width(state, _mode), do: min(state.width - 8, 72)

  defp lines(state, mode) do
    c = mode.changes
    blog = state.db.blog

    where =
      case blog.upload do
        :none -> "Written to #{mode.folder}; not uploaded."
        :rsync -> "Written to #{mode.folder}, then sent by rsync to #{blog.target}."
        :sftp -> "Written to #{mode.folder}, then uploaded by SFTP to #{blog.target}."
      end

    posts = Enum.count(mode.files, &String.starts_with?(elem(&1, 0), "posts/"))

    head = [
      "#{Draw.count(posts, "post")} · #{summary(c)}",
      where,
      ""
    ]

    list =
      if nothing?(c),
        do: ["The folder already holds this site: nothing to write."],
        else:
          Enum.map(c.added, &("  + " <> &1)) ++
            Enum.map(c.changed, &("  ~ " <> &1)) ++ Enum.map(c.removed, &("  − " <> &1))

    head ++ list
  end

  @impl Box
  def content(state, mode, inner, max_rows) do
    # long lines (a folder's path) wrap within the box
    lines =
      state
      |> lines(mode)
      |> Enum.flat_map(fn
        "" -> [""]
        line -> Draw.wrap(line, max(inner - 2, 10))
      end)

    room = max(max_rows - 2, 3)
    shown = lines |> Enum.drop(mode.top) |> Enum.take(room)
    below = length(lines) - mode.top - length(shown)

    rows = Enum.map(shown, &[{:box, " " <> &1}])

    rows =
      if below > 0,
        do: Enum.drop(rows, -1) ++ [[{:dim, " … #{below} more: ↓ PGDN"}]],
        else: rows

    rows ++ [[], [{:box, " ENTER publishes · ESC changes nothing"}]]
  end

  @impl Box
  def keys(_state, _mode), do: [{"ENTER", "Publish"}, {"ESC", "Cancel"}, {"↑↓", "Scroll"}]

  @impl Box
  def help,
    do: "What publishing would change in the folder. ENTER publishes; ESC changes nothing."
end
