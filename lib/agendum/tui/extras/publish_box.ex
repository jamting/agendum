# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Extras.PublishBox do
  @moduledoc """
  Publishing the micro-blog (Extras ▸ Publish, R74): `publish/1` (Publish
  ▸ Publish) and the Site box (Publish ▸ Site), the blog's settings kept
  in the file (`Agendum.Core.Extras.Blog`). Where the site is written and
  how it is uploaded are the person's (`Agendum.TUI.Extras.UploadBox`).
  The posts are the items of the Posts category not in the Drafts one.
  Posts and Drafts complete a category's name as it is typed (R32; F5
  takes exactly what was typed, made under MAIN when the box is done), and
  F3 or SPACE lists the categories; DEL leaves Drafts empty.

  ENTER keeps the settings (one undo step); ESC closes the box and changes
  nothing. Opened by the first Publish, before the blog has settings, its
  ENTER goes on to publish (the owner's choice, 2026-11-02).

  Publishing gives each post without a Zettel id one (its page's address,
  R73) and makes the site; Agendum then reads the folder and shows what
  publishing would change (`PublishPreviewBox`) before anything is written
  or uploaded.

  The box is drawn from `@layout` (`Agendum.TUI.Boxes.Template`); its
  fields are the cursor's order. A letter on a text field starts typing
  it (F2 edits what is there, SPACE too but on Posts and Drafts). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done

  alias Agendum.TUI.Boxes.{Box, FieldTyping, Template}
  alias Agendum.TUI.Extras.Publish.Messages
  alias Agendum.TUI.{State, Typing.LineEdit}

  @layout """
   Posts category : [posts            ]   Drafts   : [drafts          ]
   Site title     : [title                                            ]
   Description    : [description                                      ]
   Author         : [author           ]   Language : [language        ]
   Base address   : [base_url                                         ]
   rel="me" links : [me                                               ]
   Address        : [address                                          ]
  """

  @help %{
    posts: "The category whose items are the posts. Type a name (F5 a new one) or F3 to pick.",
    drafts: "A post also in it waits until it is ready. Type a name or F3 to pick; DEL for none.",
    title: "The blog's name, on every page and in the feeds. Type it.",
    description: "A line about the blog, under its name and in the feeds. Type it.",
    author: "Your name, as the posts' author (an h-card for the fediverse). Type it.",
    language: "The language of the posts: en, sv … Type it.",
    base_url:
      "Where the site is on the web (https://example.com/blog/): the feeds and your name's link need it. Type it.",
    me:
      "Addresses of your other profiles (a Mastodon account), for rel=\"me\" links; " <>
        "spaces between. Type them.",
    address:
      "Where a post's page goes, made once: {zettel} {slug} {year} {month} {day}, ending .html. Type it."
  }

  @text_fields ~w(posts drafts title description author language base_url me address)a

  @doc """
  Publish ▸ Publish: the site made and the folder read, for the preview;
  before the blog has settings (no posts category), the Site box first,
  whose ENTER then goes on to publish.
  """
  @spec publish(State.t()) :: State.t()
  def publish(%State{db: %{blog: %{posts: nil}}} = state), do: open(state, then_publish: true)

  def publish(state) do
    case State.command(state, {:prepare_publish, %{}}) do
      {:ok, state, _changes} -> scan(state)
      {:error, reason} -> State.error(state, error_text(reason))
    end
  end

  @doc "Opens the Site box with the file's settings; `then_publish: true` publishes on ENTER."
  @spec open(State.t(), keyword) :: State.t()
  def open(state, opts \\ []) do
    blog = state.db.blog
    name = fn id -> if id, do: state.db.categories[id].name, else: "" end

    settings =
      blog
      |> Map.from_struct()
      |> Map.merge(%{posts: name.(blog.posts) |> default("Posts"), drafts: name.(blog.drafts)})
      |> Map.update!(:title, &default(&1, default_title(state)))

    State.push(state, %Agendum.TUI.Modes.Publish{
      settings: settings,
      cursor: 0,
      typing: nil,
      then_publish: Keyword.get(opts, :then_publish, false)
    })
  end

  defp default("", value), do: value
  defp default(text, _value), do: text

  defp default_title(state),
    do: if(state.path, do: Path.basename(state.path, Path.extname(state.path)), else: "My blog")

  # the fields, in the cursor's order
  defp fields(_mode), do: Template.fields(@layout)

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

  # F8 and ALT-F8 (R81c): what a new blog has, as the box opens with it
  # (the owner, 2026-10-27); Author, Description and the others have none
  @impl Box
  def defaults(state, _mode) do
    %{
      posts: &set_setting(&1, :posts, "Posts"),
      drafts: &set_setting(&1, :drafts, ""),
      title: &set_setting(&1, :title, default_title(state)),
      address: &set_setting(&1, :address, Agendum.Core.blog_address_default())
    }
  end

  # a feed's or a calendar's category is never the blog's (R75a): the
  # core refuses it, so it is not offered
  @impl Box
  def category_choice?(state, _mode, _field, id), do: not Agendum.Core.ingested?(state.db, id)

  @impl Box
  def picked(state, _mode, field, id), do: set_category(state, field, id)

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
      {:pick_category, "Choices", "The categories to pick from"},
      {:clear, "Clear", "No drafts category"},
      {:done, "Keep", "Keep the settings"},
      {:close, "Cancel", "Close without publishing"}
    ])
  end

  @impl Box
  def run(state, mode, :change), do: change(state, mode, current(mode))
  def run(state, mode, :edit), do: edit(state, mode, current(mode))
  def run(state, mode, :done), do: keep(state, mode)

  def run(state, mode, :pick_category) do
    case current(mode) do
      field when field in [:posts, :drafts] -> pick(state, field)
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
  defp change(state, _mode, _field), do: state

  # F2: edit the text as it is (on Posts and Drafts too, without
  # completion, as Agenda's EDIT: `choice: :off`)
  defp edit(state, mode, field) when field in @text_fields do
    line = LineEdit.new(Map.fetch!(mode.settings, field))
    choice = if field in [:posts, :drafts], do: :off, else: nil
    State.put_mode(state, %{mode | typing: {field, line}, choice: choice})
  end

  defp edit(state, _mode, _field), do: state

  defp pick(state, field),
    do: Agendum.TUI.CategoryScreens.open_picker(state, {:box_field, :publish, field}, nil)

  # ENTER: the settings kept (one undo step); opened by the first
  # Publish, it then publishes, in the same key
  defp keep(state, mode) do
    changes =
      mode.settings
      |> Map.take(@text_fields -- [:posts, :drafts])
      |> Map.merge(%{
        posts: category_setting(state, :posts, mode.settings.posts),
        drafts: category_setting(state, :drafts, mode.settings.drafts)
      })

    case State.command(state, {:set_blog, changes}) do
      {:ok, state, _changes} ->
        state = State.pop(state)

        if mode.then_publish,
          do: publish(state),
          else: State.info(state, Messages.text(:site_kept))

      {:error, reason} ->
        State.error(state, error_text(reason))
    end
  end

  # the site made from the file, and the folder read: the preview comes
  # when the shell has read it (`Publish.Results.publish_scanned/4`)
  defp scan(state) do
    upload = Agendum.Preferences.upload(state.prefs, state.path)
    files = Agendum.Core.site(state.db, state.today)

    state
    |> State.info(Messages.text(:reading, upload.folder))
    |> State.effect({:publish_scan, folder(state, upload.folder), files})
  end

  defp error_text(:no_posts_category), do: Messages.text(:no_posts_category)
  defp error_text(:ambiguous), do: Messages.text(:ambiguous)
  defp error_text(:ingested), do: Messages.text(:ingested)
  defp error_text(:zettels_full), do: Messages.text(:zettels_full)
  defp error_text(:bad_address), do: Messages.text(:bad_address)
  defp error_text(_reason), do: Messages.text(:bad_categories)

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
  def title(_state, _mode), do: "Publish: the site"

  @impl Box
  def width(state, _mode), do: min(state.width - 4, 76)

  @impl Box
  def content(_state, mode, inner, _max_rows) do
    s = mode.settings

    values =
      Map.new(Template.fields(@layout), fn field ->
        value = Map.fetch!(s, field)
        {field, if(field == :drafts and value == "", do: "(none)", else: value)}
      end)

    Template.render(@layout, values, [selected: current(mode)] ++ FieldTyping.editing(mode)) ++
      [[], [{:box, " " <> posts_line(mode)}], Box.hint(keys(nil, mode), inner)]
  end

  defp posts_line(%{then_publish: true} = mode),
    do: "The items in #{mode.settings.posts} are the posts; ENTER shows what will change."

  defp posts_line(mode),
    do: "The items in #{mode.settings.posts} are the posts; ENTER keeps the settings."

  @impl Box
  def keys(_state, _mode), do: Box.settings_keys([{"type", "Text"}])

  @impl Box
  def help, do: @help

  @impl Box
  def field(_state, mode), do: current(mode)

  @impl Box
  def about(_state, _mode) do
    """
    Site holds what the blog is made from, kept in the file: the items
    of the posts category, each a post (its text the title, its note the
    content, written in Markdown), newest first by When date (else the
    Entry date). A note that starts with "# A title" gives the post that
    title instead. A post whose When is still to come waits for its day.
    Posts also in the drafts category are left out. The title,
    description, author and language go on every page and in the feeds;
    the base address makes the feeds' links whole.

    Address is where a post's page goes: posts/{zettel}.html, or say
    {year}/{month}/{day}-{slug}.html. A post keeps the address it was
    first published at, so changing it moves only new posts.

    The site is plain HTML: an index, a page per post at its Zettel id
    (posts/bonalaku.html), an RSS feed and a JSON Feed, and a stylesheet
    you can change (Agendum writes it only when there is none). Where it
    is written and uploaded is Publish ▸ Upload, yours, not the file's.

    Type in a field to change it, F2 edits it. Posts and Drafts complete
    a category's name as you type (F5 takes exactly what you typed, a
    new category); SPACE or F3 lists the categories, DEL leaves Drafts
    empty. SPACE edits the other texts. ENTER keeps the settings (and,
    the first time, goes on to show what publishing would change); ESC
    closes the box.
    """
  end
end
