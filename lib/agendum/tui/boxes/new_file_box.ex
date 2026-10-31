# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Boxes.NewFileBox do
  @moduledoc """
  Agenda's New File box (File ▸ Retrieve with a name that is not a file
  yet; User's Guide 22-3; checked in Agenda 2.0, 2026-10-25): Description
  and Password, both optional. A character starts typing a field, F2 edits
  it, ENTER takes it and stays in the box; ENTER then makes the file, with
  its description and password (ADR 0046), not saved yet; ESC keeps the
  file that is open. The password is typed hidden. Drawn from `@layout`
  (`Agendum.TUI.Boxes.Template`). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done

  alias Agendum.Core
  alias Agendum.TUI.Boxes.{Box, ErrorBox, FieldTyping, Template}
  alias Agendum.TUI.State
  alias Agendum.TUI.Update.Prompts

  @layout """

     Description:  [description                           ]
     Password:     [password    ]

  """

  @rows Template.fields(@layout)
  @grid Template.grid(@layout, @rows)

  # Agenda's help, field by field
  @help %{
    description:
      "Enter a short description of the contents of the file you are creating. " <>
        "Just press ENTER if you don't want to type a description.",
    password:
      "Type a password of up to 12 characters to protect the file, or press ENTER for none. " <>
        "A forgotten password cannot be recovered."
  }

  @doc "Opens the box for a new file at `path`."
  def open(state, path),
    do:
      State.push(state, %Agendum.TUI.Modes.NewFile{
        path: path,
        description: "",
        password: "",
        cursor: 0
      })

  @impl Box
  def handle(state, %{typing: {_, _}} = mode, key),
    do: FieldTyping.key(state, mode, key, &typed/3)

  def handle(state, mode, {:char, c}), do: FieldTyping.start(state, mode, field(state, mode), c)
  def handle(state, _mode, _key), do: state

  # a password is kept as typed, spaces too, as the other password boxes
  # keep it: opening the file then takes the same text
  defp typed(state, :password, text),
    do: State.put_mode(state, Map.put(State.mode(state), :password, text))

  defp typed(state, field, text),
    do: State.put_mode(state, Map.put(State.mode(state), field, String.trim(text)))

  @impl Box
  def typing?(_state, mode), do: FieldTyping.typing?(mode)

  @impl Box
  def keymap(_mode), do: Box.settings_keymap()

  @impl Box
  def commands(_mode), do: Box.settings_commands([{:done, "Create", "Make the new file"}])

  # the new file, with what was typed; refused as the core refuses it
  @impl Box
  def run(state, mode, :done) do
    case Core.new_file_with(mode.description, mode.password, state.prefs.defaults) do
      {:ok, db} ->
        Prompts.new_file(State.pop(state), mode.path, db)

      {:error, :too_long} ->
        ErrorBox.open(state, "A description has at most 40 characters, a password 12.")
    end
  end

  def run(state, mode, :change), do: State.put_mode(state, mode)
  def run(state, mode, id), do: Box.run_settings(state, mode, @grid, id)

  @impl Box
  def title(_state, _mode), do: "New File"

  @impl Box
  def width(state, _mode), do: min(state.width - 8, 62)

  @impl Box
  def content(_state, mode, _inner, _max_rows) do
    stars = String.duplicate("*", String.length(mode.password))
    editing = FieldTyping.editing(mode)

    # the password is drawn as stars while it is typed too
    editing =
      case editing do
        [editing: {:password, line}] ->
          [editing: {:password, %{line | text: String.duplicate("*", String.length(line.text))}}]

        other ->
          other
      end

    Template.render(
      @layout,
      %{description: mode.description, password: stars},
      [selected: field(nil, mode)] ++ editing
    )
  end

  @impl Box
  def keys(_state, _mode), do: Box.settings_keys()

  @impl Box
  def help, do: @help

  @impl Box
  def field(_state, mode), do: Enum.at(@rows, mode.cursor)
end
