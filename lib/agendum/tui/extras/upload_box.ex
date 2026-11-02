# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Extras.UploadBox do
  @moduledoc """
  The Upload box (Extras ▸ Publish ▸ Upload, R74): where the file's blog
  is written and how it is uploaded, kept in the person's preferences for
  this file, by its path, never in the file
  (`Agendum.Core.Extras.Upload`; meeting 2026-11-02-1255, § 10). A file
  not saved yet has no path to keep them by, so the box asks for a save
  first.

  ENTER keeps the settings, ESC closes the box and changes nothing. A
  letter on a text field starts typing it (F2 or SPACE edits what is
  there); SPACE on Upload shows the next way; F3 on Folder lists the
  folders. The box is drawn from `@layout` (`Agendum.TUI.Boxes.Template`);
  its fields are the cursor's order. Pure.

  `move_from_file/1` moves an older file's settings here when it opens.
  """

  use Agendum.TUI.Boxes.Box, finish: :done

  alias Agendum.Core.Extras.Upload
  alias Agendum.Preferences
  alias Agendum.TUI.Boxes.{Box, FieldTyping, Template}
  alias Agendum.TUI.Extras.Publish.Messages
  alias Agendum.TUI.Extras.PublishBox
  alias Agendum.TUI.{State, Typing.LineEdit}

  # the rows for uploading show only for the way chosen; a row whose
  # value is nil is left out
  @layout """
   Folder         : [folder                                           ]
   Upload         : [method           ]
   Upload to      : [target                                           ]
   User           : [user             ]   Folder on server: [remote_dir]
  """

  @help %{
    folder: "Where the site is written: a folder beside this file, or any path. Type it, or F3.",
    method: "After writing: upload by rsync over ssh, by SFTP, or not at all. SPACE switches.",
    target: "rsync: where to (me@host:www/blog). SFTP: the server (host or host:port). Type it.",
    user: "The user name on the SFTP server. Type it.",
    remote_dir: "The folder on the SFTP server the site goes into. Type it."
  }

  @text_fields ~w(folder target user remote_dir)a

  @doc """
  Opens the box with the person's settings for this file; a file not saved
  yet is refused, as they are kept by its path.
  """
  @spec open(State.t()) :: State.t()
  def open(%State{path: nil} = state), do: State.error(state, Messages.text(:save_first))

  def open(state) do
    settings = Map.from_struct(Preferences.upload(state.prefs, state.path))

    State.push(state, %Agendum.TUI.Modes.PublishUpload{
      settings: settings,
      cursor: 0,
      typing: nil
    })
  end

  @doc """
  An older file's upload settings (format 46 and before kept them in the
  file, `Agendum.Core.moved_upload/1`) move to the person's preferences as
  it opens, saying so once (the owner's choice, 2026-11-02). Settings the
  person already has for the file are kept. The file itself is not
  changed: they are never written, so its next save leaves them out.
  """
  @spec move_from_file(State.t()) :: State.t()
  def move_from_file(state) do
    upload = Agendum.Core.moved_upload(state.db)

    cond do
      upload == nil or state.path == nil or Preferences.upload?(state.prefs, state.path) ->
        state

      # no preferences file (no home folder): they last for this session
      state.prefs.path == nil ->
        state |> keep(upload) |> State.info(Messages.text(:upload_session_only))

      true ->
        state |> keep(upload) |> State.info(Messages.text(:upload_moved))
    end
  end

  # the settings for this file in the preferences, saved when there is a
  # preferences file (`State.change_preference/3`)
  defp keep(state, upload) do
    path = state.path
    State.change_preference(state, & &1, &Preferences.put_upload(&1, path, upload))
  end

  # the fields shown, in the cursor's order
  defp fields(mode) do
    hidden =
      case mode.settings.method do
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

  defp typed(state, field, text), do: set_setting(state, field, String.trim(text))

  # F8 and ALT-F8 (R81c): the folder `site` beside the file, no upload
  @impl Box
  def defaults(_state, _mode) do
    %{
      folder: &set_setting(&1, :folder, "site"),
      method: &set_setting(&1, :method, :none)
    }
  end

  @impl Box
  def picked(state, _mode, :folder, path),
    do: set_setting(state, :folder, beside_file(state, path))

  def picked(state, _mode, _field, _id), do: state

  # a folder inside the file's is kept relative to it, as the default
  # `site` is, so the file can move
  defp beside_file(state, path) do
    base = Path.expand(Path.dirname(state.path))

    case Path.relative_to(path, base) do
      ^path -> path
      relative -> relative
    end
  end

  # the box is found by its type, as it may not be on top (the folder list
  # over it)
  defp set_setting(state, field, value) do
    i = Enum.find_index(state.modes, &(&1.type == :publish_upload))

    %{
      state
      | modes:
          List.update_at(state.modes, i, &%{&1 | settings: Map.put(&1.settings, field, value)})
    }
  end

  @impl Box
  def keymap(_mode), do: Box.settings_keymap(%{{:f, 2} => :edit, {:f, 3} => :pick_folder})

  @impl Box
  def commands(_mode) do
    Box.settings_commands([
      {:edit, "Edit", "Edit the setting's text"},
      {:pick_folder, "Choices", "The folders to pick from"},
      {:done, "Keep", "Keep the settings"},
      {:close, "Cancel", "Close, changing nothing"}
    ])
  end

  @impl Box
  def run(state, mode, :change), do: change(state, mode, current(mode))
  def run(state, mode, :edit), do: edit(state, mode, current(mode))
  def run(state, mode, :done), do: done(state, mode)

  def run(state, mode, :pick_folder) do
    if current(mode) == :folder,
      do: pick_folder(state, mode),
      else: state
  end

  def run(state, mode, id),
    do: Box.run_settings(state, mode, Template.grid(@layout, fields(mode)), id)

  # SPACE edits a text field and goes round the ways of uploading
  defp change(state, mode, field) when field in @text_fields, do: edit(state, mode, field)

  defp change(state, mode, :method) do
    methods = Agendum.Core.upload_methods()
    index = Enum.find_index(methods, &(&1 == mode.settings.method))
    next = Enum.at(methods, rem(index + 1, length(methods)))
    State.put_mode(state, %{mode | settings: %{mode.settings | method: next}})
  end

  defp change(state, _mode, _field), do: state

  defp edit(state, mode, field) when field in @text_fields do
    line = LineEdit.new(Map.fetch!(mode.settings, field))
    State.put_mode(state, %{mode | typing: {field, line}})
  end

  defp edit(state, _mode, _field), do: state

  # F3 on Folder: the folders, from the one the setting names
  defp pick_folder(state, mode) do
    dir = PublishBox.folder(state, mode.settings.folder)
    Agendum.TUI.Boxes.SelectFile.open_folder(state, dir, {:box_field, :publish_upload, :folder})
  end

  # ENTER: the settings kept in the preferences, the folder `site` when
  # left empty
  defp done(state, mode) do
    s = mode.settings
    folder = if String.trim(s.folder) == "", do: "site", else: s.folder

    upload = %Upload{
      folder: folder,
      method: s.method,
      target: s.target,
      user: s.user,
      remote_dir: s.remote_dir
    }

    state
    |> State.pop()
    |> keep(upload)
    |> State.info(Messages.text(:upload_kept, Path.basename(state.path)))
  end

  @impl Box
  def title(_state, _mode), do: "Publish: upload"

  @impl Box
  def width(state, _mode), do: min(state.width - 4, 76)

  @impl Box
  def content(state, mode, inner, _max_rows) do
    shown = fields(mode)

    values =
      Map.new(Template.fields(@layout), fn field ->
        value =
          cond do
            field not in shown -> nil
            field == :method -> method_name(mode.settings.method)
            true -> Map.fetch!(mode.settings, field)
          end

        {field, value}
      end)

    Template.render(@layout, values, [selected: current(mode)] ++ FieldTyping.editing(mode)) ++
      [[], [{:box, " " <> whose(state)}], Box.hint(keys(nil, mode), inner)]
  end

  defp whose(state), do: Messages.text(:upload_whose, Path.basename(state.path))

  @doc "The name of a way of uploading, as the boxes show it."
  @spec method_name(Upload.method()) :: String.t()
  def method_name(:none), do: "None"
  def method_name(:rsync), do: "rsync over ssh"
  def method_name(:sftp), do: "SFTP"

  @impl Box
  def keys(_state, _mode), do: Box.settings_keys([{"type", "Text"}])

  @impl Box
  def help, do: @help

  @impl Box
  def field(_state, mode), do: current(mode)

  @impl Box
  def about(_state, _mode) do
    """
    Upload says where Publish writes the blog's site, and how it then
    goes to your web server. It is yours, kept in your preferences for
    this file on this computer, not in the file: a file you share does
    not carry your server.

    Folder is where the site is written, beside the file unless you give
    a whole path (F3 lists the folders). Upload chooses rsync over ssh,
    SFTP or none (SPACE). rsync needs where to (me@host:www/blog); SFTP
    the server (host or host:port), the user and the folder there, and
    uses your ssh keys, or asks for a password it never keeps.

    Type in a field to change it, F2 edits it. ENTER keeps the settings;
    ESC closes the box and changes nothing.
    """
  end
end
