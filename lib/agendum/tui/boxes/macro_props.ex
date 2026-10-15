defmodule Agendum.TUI.Boxes.MacroProps do
  @moduledoc """
  The Macro Properties box (F6 in the macro manager; SPEC R50; Working with
  Macros 1-15 to 1-18): Name, Keystrokes, Attach to key, and where the
  macro can be run from.

    * F2 or SPACE on Name renames it; on Keystrokes edits them in the
      macro edit screen; SPACE on Attach to key asks for the key (DEL
      detaches)
    * SPACE (or → ←) switches View, Note, Category manager and
      Everywhere else between Yes and No; Everywhere else only for a macro
      attached to a key, as in Agenda
    * ENTER closes the box; ESC closes it and cancels its changes
      (`Agendum.TUI.Boxes.BoxCancel`)

  Every change is one undo step. The box is drawn from `@layout`
  (`Agendum.TUI.Boxes.Template`), whose fields are also the cursor's order. Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, indicator: "PROPS", cancels: true

  alias Agendum.TUI.Boxes.{Box, Template}

  alias Agendum.Core
  alias Agendum.TUI.{MacroKeys, Macros, State}
  alias Agendum.TUI.Update.Prompts

  @layout """
   Name                      : [name                        ]
   Keystrokes                : [keys                        ]
   Attach to key             : [key                         ]
   Run from View             : [view                        ]
   Run from Note             : [note                        ]
   Run from Category manager : [catmgr                      ]
   Run from Everywhere else  : [elsewhere                   ]
  """

  @rows Template.fields(@layout)
  @grid Template.grid(@layout, @rows)

  @help %{
    name: "The macro's name. F2 (or SPACE) renames it.",
    keys: "The keystrokes the macro plays. SPACE (or F2) edits them.",
    key: "The key that runs the macro. SPACE attaches a key, DEL detaches it.",
    view: "Whether the macro can run from views. SPACE switches.",
    note: "Whether the macro can run in notes. SPACE switches.",
    catmgr: "Whether the macro can run in the category manager. SPACE switches.",
    elsewhere: "Whether the macro's key runs it in boxes and everywhere else. SPACE switches."
  }
  # keys Agenda would not attach a macro to: they run macros themselves
  @reserved [{:alt_f, 3}, {:alt, "z"}, {:alt_f, 1}]

  def open(state, id), do: State.push(state, %{type: :macro_props, macro_id: id, cursor: 0})

  @impl Box
  # its keys are the settings box's, F2 edits, DEL detaches (R65)
  def handle(state, _mode, _key), do: state

  @impl Box
  def keymap,
    do: Box.settings_keymap(%{{:f, 2} => :edit, :delete => :detach, {:ctrl, "d"} => :detach})

  @impl Box
  def commands,
    do:
      Box.settings_commands([
        {:edit, "Edit", "Edit the name or the keystrokes"},
        {:detach, "Detach", "Detach the macro from its key"}
      ])

  # ENTER is done (ESC cancels: `Agendum.TUI.Boxes.BoxCancel`)
  @impl Box
  def run(state, mode, id) when id in [:change, :edit, :detach],
    do: command(state, id, Enum.at(@rows, mode.cursor), state.db.macros[mode.macro_id])

  def run(state, mode, id), do: Box.run_settings(state, mode, @grid, id)

  defp command(state, id, :name, macro) when id in [:change, :edit],
    do: Prompts.prompt(state, "Rename the macro to:", {:rename_macro, macro.id}, macro.name)

  defp command(state, id, :keys, macro) when id in [:change, :edit],
    do: Macros.edit_text(state, macro)

  defp command(state, :change, :key, macro) do
    Prompts.prompt(
      state,
      "Attach to key (e.g. {ShfF4}, {CtlE}):",
      {:attach_macro, macro.id},
      macro.key || ""
    )
  end

  defp command(state, :detach, :key, macro),
    do: State.change_db(state, Core.attach_macro(state.db, macro.id, nil))

  defp command(state, :change, :elsewhere, %{key: nil}),
    do: State.error(state, "Only a macro attached to a key runs everywhere else")

  defp command(state, :change, place, macro) when place in [:view, :note, :catmgr, :elsewhere] do
    State.change_db(
      state,
      Core.set_macro_run_from(state.db, macro.id, place, not macro.run_from[place])
    )
  end

  defp command(state, _id, _row, _macro), do: state

  @doc "The prompt's answer for Attach to key: one key, in the notation."
  def attach(state, id, text) do
    case MacroKeys.key(text) do
      {:ok, _text, key} when key in @reserved ->
        State.error(state, "ALT-F1, ALT-F3 and ALT-Z cannot run a macro")

      {:ok, notation, _key} ->
        State.change_db(state, Core.attach_macro(state.db, id, notation))

      :error ->
        State.error(state, "Type one key, as {F4}, {ShfF4}, {AltD} or {CtlE}")
    end
  end

  @doc "The prompt's answer for Name."
  def rename(state, id, name) do
    case Core.rename_macro(state.db, id, name) do
      {:ok, db} ->
        State.change_db(state, db)

      {:error, :name_taken} ->
        State.error(state, "A macro is already called #{String.trim(name)}")

      {:error, :name_too_long} ->
        State.error(state, "A macro's name has at most 35 characters")

      {:error, :empty_name} ->
        state
    end
  end

  @impl Box
  def title(state, mode), do: "Macro properties: #{state.db.macros[mode.macro_id].name}"

  @impl Box
  def content(state, mode, inner, _max_rows) do
    Template.render(@layout, values(state.db.macros[mode.macro_id]), selected: field(state, mode)) ++
      [[], Box.hint(keys(state, mode), inner)]
  end

  defp values(macro) do
    yes = &if(&1, do: "Yes", else: "No")
    keys = if macro.keys == "", do: "(none) ...", else: "#{String.slice(macro.keys, 0, 23)} ..."
    # a macro runs everywhere else only from a key of its own (`Map.new/2`
    # makes the four "Run from" values from the macro's places)
    run_from =
      Map.new(macro.run_from, fn
        {:elsewhere, _} when macro.key == nil -> {:elsewhere, "—"}
        {place, yes?} -> {place, yes.(yes?)}
      end)

    Map.merge(%{name: macro.name, keys: keys, key: macro.key || "(none)"}, run_from)
  end

  @impl Box
  def keys(_state, _mode),
    do: [
      {"↑↓←→", "Setting", "Move between settings"},
      {"SPACE", "Change", "Change the setting"},
      {"F2", "Edit", "Rename, or edit the keys"},
      {"DEL", "Detach", "Detach the key"},
      {"ENTER", "Done"},
      {"ESC", "Cancel"}
    ]

  @impl Box
  def help, do: @help

  @impl Box
  def field(_state, mode), do: Enum.at(@rows, mode.cursor)
end
