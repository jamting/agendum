defmodule Agendum.TUI.Boxes.MacroProps do
  @moduledoc """
  The Macro Properties box (F6 in the macro manager; SPEC R50; Working with
  Macros 1-15 to 1-18), laid out as Agenda's (checked in Agenda 2.0,
  2026-10-25): Name, Contents, Attach to key, and under "Macro can be run
  from:" View, Note, Category manager and, ours, Everywhere else. Agenda's
  Macro file and protection are left out.

    * F2 or SPACE on Name renames it; on Contents ("...", as Agenda's)
      edits the keystrokes in the macro edit screen; SPACE on Attach to
      key asks for the key (DEL detaches)
    * SPACE (or → ←) switches View, Note, Category manager and
      Everywhere else between Yes and No; Everywhere else only for a macro
      attached to a key, as in Agenda
    * ENTER closes the box; ESC closes it and cancels its changes
      (`Agendum.TUI.Boxes.BoxCancel`)

  Every change is one undo step. The box is drawn from `@layout`
  (`Agendum.TUI.Boxes.Template`), whose fields are also the cursor's order. Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, cancels: true

  alias Agendum.TUI.Boxes.{Box, Template}

  alias Agendum.TUI.{MacroKeys, Macros, State}
  alias Agendum.TUI.Update.Prompts

  @layout """

   Name:        [name                              ]
   Contents:    [keys                              ]

   Attach to key:  [key                    ]

   Macro can be run from:
        View:                      [view     ]
        Note:                      [note     ]
        Category manager:          [catmgr   ]
        Everywhere else:           [elsewhere]
  """

  @rows Template.fields(@layout)
  @grid Template.grid(@layout, @rows)

  @help %{
    name: "The macro's name. F2 (or SPACE) renames it.",
    keys: "The keystrokes the macro plays. SPACE (or F2) opens them to edit.",
    key: "The key that runs the macro. SPACE attaches a key, DEL detaches it.",
    view: "Whether the macro can run from views. SPACE switches.",
    note: "Whether the macro can run in notes. SPACE switches.",
    catmgr: "Whether the macro can run in the category manager. SPACE switches.",
    elsewhere: "Whether the macro's key runs it in boxes and everywhere else. SPACE switches."
  }
  # keys Agenda would not attach a macro to: they run macros themselves
  @reserved [{:alt_f, 3}, {:alt, "z"}, {:alt_f, 1}]

  def open(state, id),
    do: State.push(state, %Agendum.TUI.Modes.MacroProps{macro_id: id, cursor: 0})

  @impl Box
  # its keys are the settings box's, F2 edits, DEL detaches (R65)
  def handle(state, _mode, _key), do: state

  @impl Box
  def keymap(_mode),
    do: Box.settings_keymap(%{{:f, 2} => :edit, :delete => :detach, {:ctrl, "d"} => :detach})

  @impl Box
  def commands(_mode),
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
    do: State.run(state, {:attach_macro, macro.id, nil})

  defp command(state, :change, :elsewhere, %{key: nil}),
    do: State.error(state, "Only a macro attached to a key runs everywhere else")

  defp command(state, :change, place, macro) when place in [:view, :note, :catmgr, :elsewhere] do
    State.run(state, {:set_macro_run_from, macro.id, place, not macro.run_from[place]})
  end

  defp command(state, _id, _row, _macro), do: state

  @doc "The prompt's answer for Attach to key: one key, in the notation."
  def attach(state, id, text) do
    case MacroKeys.key(text) do
      {:ok, _text, key} when key in @reserved ->
        State.error(state, Agendum.TUI.Messages.text(:macro_key_reserved))

      {:ok, notation, _key} ->
        State.run(state, {:attach_macro, id, notation})

      :error ->
        State.error(state, Agendum.TUI.Messages.text(:macro_one_key))
    end
  end

  @doc "The prompt's answer for Name."
  def rename(state, id, name) do
    case State.command(state, {:rename_macro, id, name}) do
      {:ok, state, _} ->
        state

      {:error, :name_taken} ->
        State.error(state, "A macro is already called #{String.trim(name)}")

      {:error, :name_too_long} ->
        State.error(state, "A macro's name has at most 35 characters")

      {:error, :empty_name} ->
        state
    end
  end

  @impl Box
  def title(_state, _mode), do: "Macro Properties"

  @impl Box
  def content(state, mode, inner, _max_rows) do
    Template.render(@layout, values(state.db.macros[mode.macro_id]), selected: field(state, mode)) ++
      [[], Box.hint(keys(state, mode), inner)]
  end

  defp values(macro) do
    yes = &if(&1, do: "Yes", else: "No")
    # a macro runs everywhere else only from a key of its own (`Map.new/2`
    # makes the four "Run from" values from the macro's places)
    run_from =
      Map.new(macro.run_from, fn
        {:elsewhere, _} when macro.key == nil -> {:elsewhere, "—"}
        {place, yes?} -> {place, yes.(yes?)}
      end)

    # Contents shows "...", as Agenda's: SPACE opens them; no key is blank
    Map.merge(%{name: macro.name, keys: "...", key: macro.key || ""}, run_from)
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

  # F8 and ALT-F8 (`Agendum.TUI.Boxes.BoxDefaults`): a new macro's: no key
  # attached, run from a view, a note and the category manager; the name and
  # the keystrokes have none
  @impl Box
  def defaults(_state, mode) do
    id = mode.macro_id
    places = %Agendum.Core.Macro{}.run_from

    run_from =
      Map.new(places, fn {place, default} ->
        {place,
         fn state ->
           if state.db.macros[id].run_from[place] == default,
             do: state,
             else: State.run(state, {:set_macro_run_from, id, place, default})
         end}
      end)

    Map.put(run_from, :key, fn state ->
      if state.db.macros[id].key == nil,
        do: state,
        else: State.run(state, {:attach_macro, id, nil})
    end)
  end
end
