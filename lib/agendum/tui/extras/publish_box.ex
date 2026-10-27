defmodule Agendum.TUI.Extras.PublishBox do
  @moduledoc """
  The Publish box (File ▸ Transfer ▸ Publish, R74): the micro-blog's
  settings, kept in the file (`Agendum.Core.Extras.Blog`). The posts are the
  items of the Posts category not in the Drafts one. Posts and Drafts
  complete a category's name as it is typed (R32; F5 takes exactly what
  was typed, made under MAIN when the box is done), and F3 or SPACE lists
  the categories; DEL leaves Drafts empty.

  ENTER keeps the settings, gives each post without a Zettel id one (its
  page's address, R73), and makes the site; Agendum then reads the folder
  and shows what publishing would change (`PublishPreviewBox`) before
  anything is written or uploaded. ESC closes the box and changes nothing.

  The box is drawn from `@layout` (`Agendum.TUI.Boxes.Template`); its
  fields are the cursor's order. A letter on a text field starts typing
  it (F2 edits what is there, SPACE too but on Posts and Drafts); SPACE on Upload shows the next
  way. Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done

  alias Agendum.Core.Extras.Blog
  alias Agendum.TUI.Boxes.{Box, FieldTyping, Template}
  alias Agendum.TUI.{State, Typing.LineEdit}

  # the rows for uploading show only for the way chosen; a row whose
  # value is nil is left out
  @layout """
   Posts category : [posts            ]   Drafts   : [drafts          ]
   Site title     : [title                                            ]
   Description    : [description                                      ]
   Author         : [author           ]   Language : [language        ]
   Base address   : [base_url                                         ]
   rel="me" links : [me                                               ]
   Folder         : [folder                                           ]
   Upload         : [upload           ]
   Upload to      : [target                                           ]
   User           : [user             ]   Folder on server: [remote_dir]
  """

  @help %{
    posts: "The category whose items are the posts. Type a name (F5 a new one) or F3 to pick.",
    drafts: "A post also in it waits until it is ready. Type a name or F3 to pick; DEL for none.",
    title: "The blog's name, on every page and in the feeds. Type it.",
    description: "A line about the blog, under its name and in the feeds. Type it.",
    author: "Your name, as the posts' author (an h-card for the fediverse). Type it.",
    language: "The language of the posts: en, sv … Type it.",
    base_url: "Where the site is on the web (https://example.com/blog/), for the feeds. Type it.",
    me:
      "Addresses of your other profiles (a Mastodon account), for rel=\"me\" links; " <>
        "spaces between. Type them.",
    folder: "Where the site is written: a folder beside this file, or any path. Type it, or F3.",
    upload: "After writing: upload by rsync over ssh, by SFTP, or not at all. SPACE switches.",
    target: "rsync: where to (me@host:www/blog). SFTP: the server (host or host:port). Type it.",
    user: "The user name on the SFTP server. Type it.",
    remote_dir: "The folder on the SFTP server the site goes into. Type it."
  }

  @text_fields ~w(posts drafts title description author language base_url me folder target user remote_dir)a

  @doc "Opens the box with the file's settings."
  @spec open(State.t()) :: State.t()
  def open(state) do
    blog = state.db.blog
    name = fn id -> if id, do: state.db.categories[id].name, else: "" end

    settings =
      blog
      |> Map.from_struct()
      |> Map.merge(%{posts: name.(blog.posts) |> default("Posts"), drafts: name.(blog.drafts)})
      |> Map.update!(:folder, &default(&1, "site"))
      |> Map.update!(:title, &default(&1, default_title(state)))

    State.push(state, %Agendum.TUI.Modes.Publish{settings: settings, cursor: 0, typing: nil})
  end

  defp default("", value), do: value
  defp default(text, _value), do: text

  defp default_title(state),
    do: if(state.path, do: Path.basename(state.path, Path.extname(state.path)), else: "My blog")

  # the fields shown, in the cursor's order
  defp fields(mode) do
    hidden =
      case mode.settings.upload do
        :none -> [:target, :user, :remote_dir]
        :rsync -> [:user, :remote_dir]
        :sftp -> []
      end

    Template.fields(@layout) -- hidden
  end

  defp current(mode), do: Enum.at(fields(mode), min(mode.cursor, length(fields(mode)) - 1))

  @impl Box
  def handle(state, mode, key) do
    if FieldTyping.typing?(mode),
      do: FieldTyping.key(state, mode, key, &typed/3),
      else: start_typing(state, mode, key)
  end

  # a character on a text field starts typing it
  defp start_typing(state, mode, {:char, c}) do
    if current(mode) in @text_fields,
      do: FieldTyping.start(state, mode, current(mode), c),
      else: state
  end

  defp start_typing(state, _mode, _key), do: state

  # Posts and Drafts complete a category's name (R32): ENTER gives the
  # match shown as `{:category, id}`, F5 exactly what was typed (a new
  # category, made when the box is done)
  defp typed(state, field, {:category, id}), do: set_category(state, field, id)

  defp typed(state, field, text) do
    mode = State.mode(state)
    State.put_mode(state, %{mode | settings: Map.put(mode.settings, field, String.trim(text))})
  end

  @impl Box
  def category_fields(_mode), do: [:posts, :drafts]

  @impl Box
  def picked(state, _mode, :folder, path),
    do: set_setting(state, :folder, beside_file(state, path))

  def picked(state, _mode, field, id), do: set_category(state, field, id)

  # a folder inside the file's (or, unsaved, the working one) is kept
  # relative to it, as the default `site` is, so the file can move
  defp beside_file(state, path) do
    base = Path.expand(if state.path, do: Path.dirname(state.path), else: ".")

    case Path.relative_to(path, base) do
      ^path -> path
      relative -> relative
    end
  end

  # Posts or Drafts set to a category picked (F3, SPACE) or completed: its
  # name, as the box keeps the settings until ENTER; the box is found by
  # its type, as it may not be on top
  defp set_category(state, field, id), do: set_setting(state, field, state.db.categories[id].name)

  defp set_setting(state, field, name) do
    i = Enum.find_index(state.modes, &(&1.type == :publish))

    %{
      state
      | modes:
          List.update_at(state.modes, i, &%{&1 | settings: Map.put(&1.settings, field, name)})
    }
  end

  @impl Box
  def keymap(_mode),
    do: Box.settings_keymap(%{{:f, 2} => :edit, {:f, 3} => :pick_category, :delete => :clear})

  @impl Box
  def commands(_mode) do
    Box.settings_commands([
      {:edit, "Edit", "Edit the setting's text"},
      {:pick_category, "Choices", "The categories or folders to pick from"},
      {:clear, "Clear", "No drafts category"},
      {:done, "Publish", "Keep settings, show what will change"},
      {:close, "Cancel", "Close without publishing"}
    ])
  end

  @impl Box
  def run(state, mode, :change), do: change(state, mode, current(mode))
  def run(state, mode, :edit), do: edit(state, mode, current(mode))
  def run(state, mode, :done), do: publish(state, mode)

  def run(state, mode, :pick_category) do
    case current(mode) do
      field when field in [:posts, :drafts] -> pick(state, field)
      :folder -> pick_folder(state, mode)
      _ -> state
    end
  end

  def run(state, mode, :clear) do
    if current(mode) == :drafts,
      do: State.put_mode(state, %{mode | settings: %{mode.settings | drafts: ""}}),
      else: state
  end

  def run(state, mode, id),
    do: Box.run_settings(state, mode, Template.grid(@layout, fields(mode)), id)

  # SPACE on Posts or Drafts opens the category list, as a category field
  # does in the clone's boxes; on another text field it edits what is there
  defp change(state, _mode, field) when field in [:posts, :drafts], do: pick(state, field)
  defp change(state, mode, field) when field in @text_fields, do: edit(state, mode, field)

  defp change(state, mode, :upload) do
    uploads = Blog.uploads()
    index = Enum.find_index(uploads, &(&1 == mode.settings.upload))
    next = Enum.at(uploads, rem(index + 1, length(uploads)))
    State.put_mode(state, %{mode | settings: %{mode.settings | upload: next}})
  end

  defp change(state, _mode, _field), do: state

  # F2: edit the text as it is (on Posts and Drafts too, without
  # completion, as Agenda's EDIT: `choice: :off`)
  defp edit(state, mode, field) when field in @text_fields do
    line = LineEdit.new(Map.fetch!(mode.settings, field))
    choice = if field in [:posts, :drafts], do: :off, else: nil
    State.put_mode(state, %{mode | typing: {field, line}, choice: choice})
  end

  defp edit(state, _mode, _field), do: state

  # F3 on Folder: the folders, from the one the setting names
  defp pick_folder(state, mode) do
    dir = folder(state, mode.settings.folder)
    Agendum.TUI.Boxes.SelectFile.open_folder(state, dir, {:box_field, :publish, :folder})
  end

  defp pick(state, field),
    do: Agendum.TUI.CategoryScreens.open_picker(state, {:box_field, :publish, field}, nil)

  # ENTER: the settings are kept and the posts get their ids, in one
  # change (one undo step); then the site is made and the folder read
  defp publish(state, mode) do
    changes =
      mode.settings
      |> Map.take([:upload | @text_fields -- [:posts, :drafts]])
      |> Map.merge(%{
        posts: category_setting(state, :posts, mode.settings.posts),
        drafts: category_setting(state, :drafts, mode.settings.drafts)
      })

    case State.command(state, {:prepare_publish, changes}) do
      {:ok, state, _changes} ->
        folder = folder(state, state.db.blog.folder)
        files = Agendum.Core.site(state.db)

        state
        |> State.pop()
        |> State.info("Reading #{state.db.blog.folder} …")
        |> State.effect({:publish_scan, folder, files})

      {:error, :no_posts_category} ->
        State.error(state, "Name the category whose items are the posts")

      {:error, :ambiguous} ->
        State.error(
          state,
          "Two categories have that name: give the posts or drafts a name of their own"
        )

      {:error, :zettels_full} ->
        State.error(state, "Every Zettel id is in use; the posts cannot all have one")

      {:error, _} ->
        State.error(state, "The posts and drafts categories must differ, and be categories")
    end
  end

  # the category the box opened with, by its id, unless the person typed
  # another name: a name another category also has must not swap it
  # (code review 2026-10-26: the drafts became a namesake's, and published)
  defp category_setting(state, field, typed) do
    id = Map.fetch!(state.db.blog, field)

    if id && state.db.categories[id] && state.db.categories[id].name == typed,
      do: id,
      else: {:name, typed}
  end

  @doc """
  Where the site is written: a relative folder is beside the file (or,
  for a file not saved yet, where Agendum was started).
  """
  @spec folder(State.t(), String.t()) :: String.t()
  def folder(state, folder) do
    if state.path != nil and Path.type(folder) == :relative and
         not String.starts_with?(folder, "~"),
       do: Path.join(Path.dirname(state.path), folder),
       else: folder
  end

  @impl Box
  def title(_state, _mode), do: "Publish the blog"

  @impl Box
  def width(state, _mode), do: min(state.width - 4, 76)

  @impl Box
  def content(_state, mode, inner, _max_rows) do
    shown = fields(mode)
    s = mode.settings

    values =
      Map.new(Template.fields(@layout), fn field ->
        value =
          cond do
            field not in shown -> nil
            field == :upload -> upload_name(s.upload)
            Map.fetch!(s, field) == "" and field == :drafts -> "(none)"
            true -> Map.fetch!(s, field)
          end

        {field, value}
      end)

    Template.render(@layout, values, [selected: current(mode)] ++ FieldTyping.editing(mode)) ++
      [[], [{:box, " " <> posts_line(mode)}], Box.hint(keys(nil, mode), inner)]
  end

  defp posts_line(mode),
    do: "The items in #{mode.settings.posts} are the posts; ENTER shows what will change."

  defp upload_name(:none), do: "None"
  defp upload_name(:rsync), do: "rsync over ssh"
  defp upload_name(:sftp), do: "SFTP"

  @impl Box
  def keys(_state, _mode), do: Box.settings_keys([{"type", "Text"}])

  @impl Box
  def help, do: @help

  @impl Box
  def field(_state, mode), do: current(mode)

  @impl Box
  def about(_state, _mode) do
    """
    Publish writes the blog from this file: the items of the posts
    category, each a post (its text the title, its note the content,
    written in Markdown), newest first by When date (else the Entry
    date). Posts also in the drafts category are left out.

    The site is plain HTML: an index, a page per post at its Zettel id
    (posts/bonalaku.html), an RSS feed and a JSON Feed, and a stylesheet
    you can change (Agendum writes it only when there is none).

    Type in a field to change it, F2 edits it. Posts and Drafts complete
    a category's name as you type (F5 takes exactly what you typed, a
    new category); SPACE or F3 lists the categories, DEL leaves Drafts
    empty. SPACE edits the other texts, and on Upload chooses rsync,
    SFTP or none. ENTER shows what publishing would add, change
    and remove before anything is written; ESC closes the box.
    """
  end
end
