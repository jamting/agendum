defmodule Agenda.TUI.MacroProps do
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
      (`Agenda.TUI.BoxCancel`)

  Every change is one undo step. Pure.
  """

  alias Agenda.Core
  alias Agenda.Core.Macro
  alias Agenda.TUI.{MacroKeys, Macros, State}
  alias Agenda.TUI.Update.Prompts

  @rows [:name, :keys, :key, :view, :note, :catmgr, :elsewhere]
  @place_names %{
    view: "View",
    note: "Note",
    catmgr: "Category manager",
    elsewhere: "Everywhere else"
  }
  # keys Agenda would not attach a macro to: they run macros themselves
  @reserved [{:alt_f, 3}, {:alt, "z"}, {:alt_f, 1}]

  def open(state, id), do: State.push(state, %{type: :macro_props, macro_id: id, cursor: 0})

  def handle(state, mode, key) do
    macro = state.db.macros[mode.macro_id]
    row = Enum.at(@rows, mode.cursor)

    case {key, row} do
      # ENTER is done (ESC cancels: `Agenda.TUI.BoxCancel`)
      {k, _} when k in [:esc, :enter] ->
        State.pop(state)

      {:up, _} ->
        State.put_mode(state, %{mode | cursor: max(mode.cursor - 1, 0)})

      {:down, _} ->
        State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, length(@rows) - 1)})

      {k, :name} when k in [{:f, 2}, {:char, " "}] ->
        Prompts.prompt(state, "Rename the macro to:", {:rename_macro, macro.id}, macro.name)

      {k, :keys} when k in [{:f, 2}, {:char, " "}] ->
        Macros.edit_text(state, macro)

      {{:char, " "}, :key} ->
        Prompts.prompt(
          state,
          "Attach to key (e.g. {ShfF4}, {CtlE}):",
          {:attach_macro, macro.id},
          macro.key || ""
        )

      {k, :key} when k in [:delete, {:ctrl, "d"}] ->
        State.change_db(state, Core.attach_macro(state.db, macro.id, nil))

      {k, :elsewhere} when k in [{:char, " "}, :right, :left] and macro.key == nil ->
        State.error(state, "Only a macro attached to a key runs everywhere else")

      {k, place}
      when k in [{:char, " "}, :right, :left] and
             place in [:view, :note, :catmgr, :elsewhere] ->
        State.change_db(
          state,
          Core.set_macro_run_from(state.db, macro.id, place, not macro.run_from[place])
        )

      _ ->
        state
    end
  end

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

  def title(state, mode), do: "Macro properties: #{state.db.macros[mode.macro_id].name}"

  @doc "`{label, value}` for each row."
  def lines(state, mode) do
    m = state.db.macros[mode.macro_id]
    yes = &if(&1, do: "Yes", else: "No")
    keys = if m.keys == "", do: "(none) ...", else: "#{String.slice(m.keys, 0, 30)} ..."

    [
      {"Name", m.name},
      {"Keystrokes", keys},
      {"Attach to key", m.key || "(none)"}
    ] ++
      Enum.map(Macro.places(), fn place ->
        value =
          if place == :elsewhere and m.key == nil, do: "—", else: yes.(m.run_from[place])

        {"Run from " <> @place_names[place], value}
      end)
  end

  @doc "The highlighted field, for its help in the control panel (`Agenda.TUI.FieldHelp`)."
  def field(_state, mode), do: Enum.at(@rows, mode.cursor)
end
