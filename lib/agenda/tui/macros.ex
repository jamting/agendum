defmodule Agenda.TUI.Macros do
  @moduledoc """
  Learn-mode macros in the TUI (SPEC R50; Working with Macros, chapter 1).

    * ALT-F3 (MACRO) opens the macro manager: the file's macros. INS (or
      CTRL-N, or typing) names a new one; F7 (LEARN) records keystrokes into
      the highlighted macro, asking whether to replace or append when it has
      some; ENTER runs it; ESC closes the manager
    * in Learn mode every key is recorded and also does its usual work;
      LEARN shows at the top right; ALT-F3 (or ALT-Z) stops and keeps the
      keystrokes
    * ALT-Z runs the macro run last

  A run hands its keys to the shell (`{:play, keys}`), which plays them one
  by one, effects in between, then `:macro_done`. The run is one undo step
  (`Agenda.TUI.History`). Within a run ALT-Z does nothing, and runs started
  from runs stop eight deep. Pure.
  """

  alias Agenda.Core
  alias Agenda.Core.Database
  alias Agenda.TUI.{History, MacroKeys, State, Update}

  @max_depth 8

  @doc """
  The macro keys, before anything else sees a key: ALT-F3, ALT-Z and the
  end of a run. `:pass` for every other key.
  """
  def key(state, :macro_done), do: done(state)
  # the developer tools' key tester sees every key
  def key(%State{modes: [%{type: :devtools} | _]}, _key), do: :pass

  def key(%State{macro: %{learning: %{}}} = state, k) when k in [{:alt_f, 3}, {:alt, "z"}],
    do: stop(state)

  # not over a line being typed, a prompt, a question or the menu: they would
  # lose what is being typed
  def key(%State{} = state, k) when k in [{:alt_f, 3}, {:alt, "z"}] and state.edit != nil,
    do: :pass

  def key(%State{modes: [%{type: t} | _]}, k)
      when k in [{:alt_f, 3}, {:alt, "z"}] and t in [:prompt, :confirm, :menu],
      do: :pass

  def key(state, {:alt_f, 3}), do: open(state)
  def key(%State{macro: %{playing: n}} = state, {:alt, "z"}) when n > 0, do: state
  def key(state, {:alt, "z"}), do: run_last(state)

  # {CALL Name} in a macro runs that macro
  def key(state, {:call, name}) do
    case Database.find_macro(state.db, name) do
      nil -> State.error(state, "No macro is called #{name}")
      macro -> run(state, macro)
    end
  end

  # a key attached to a macro runs it, where the macro may run; within a
  # run the key does its own work, as in Agenda
  def key(%State{macro: %{playing: 0}} = state, key) do
    case attached(state, key) do
      nil -> :pass
      macro -> run(state, macro)
    end
  end

  def key(_state, _key), do: :pass

  @doc """
  In Learn mode, `key` is recorded into the macro (after it did its work);
  a key attached to a macro is recorded as a call to it ({CALL Name}).
  """
  # (keys a run plays are not the user's: only the call is recorded)
  def record(
        %State{macro: %{learning: %{} = l, playing: 0}} = before,
        key,
        %State{macro: %{learning: %{}}} = next
      )
      when key not in [:macro_done, {:alt_f, 3}, {:alt, "z"}] do
    recorded =
      case attached(before, key) do
        nil -> key
        macro -> {:call, macro.name}
      end

    %{next | macro: %{next.macro | learning: %{l | keys: [recorded | l.keys]}}}
  end

  def record(_before, _key, next), do: next

  @doc "The macro a key is attached to, if it may run here."
  def attached(state, key) do
    with place when place != :none <- place(state),
         notation when notation != "" <- MacroKeys.encode([key]) do
      Enum.find(Database.macros(state.db), &(&1.key == notation and &1.run_from[place]))
    else
      _ -> nil
    end
  end

  @doc """
  Where the user is, for where a macro may run: `:view`, `:note`,
  `:catmgr` or `:elsewhere` (boxes, typing); `:none` in the macro manager
  and while a macro's text or key is being edited.
  """
  def place(state) do
    case {state.edit, State.mode(state)} do
      {_, %{type: t}} when t in [:macros, :macro_props, :devtools] -> :none
      {_, %{type: :note, target: {:macro, _}}} -> :none
      {_, %{type: :prompt, action: {:attach_macro, _}}} -> :none
      {%{}, _} -> :elsewhere
      {nil, nil} -> :view
      {nil, %{type: :note}} -> :note
      {nil, %{type: :catmgr}} -> :catmgr
      _ -> :elsewhere
    end
  end

  # --- the macro manager -------------------------------------------------------------------

  def open(state), do: State.push(state, %{type: :macros, cursor: 0})

  defp current(state, mode), do: state.db |> Database.macros() |> Enum.at(mode.cursor)

  def handle(state, mode, key) do
    count = length(Database.macros(state.db))
    mode = %{mode | cursor: mode.cursor |> min(count - 1) |> max(0)}
    state = State.put_mode(state, mode)

    case {key, current(state, mode)} do
      {:esc, _} ->
        State.pop(state)

      {:up, _} ->
        State.put_mode(state, %{mode | cursor: max(mode.cursor - 1, 0)})

      {:down, _} ->
        State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, max(count - 1, 0))})

      {k, _} when k in [:insert, {:ctrl, "n"}] ->
        Update.prompt(state, "Name of the new macro:", :new_macro)

      {{:char, c}, _} when c != " " ->
        Update.prompt(state, "Name of the new macro:", :new_macro, c)

      {_, nil} ->
        state

      {:enter, macro} ->
        run(State.pop(state), macro)

      {{:f, 2}, macro} ->
        edit_text(state, macro)

      {{:f, 6}, macro} ->
        Agenda.TUI.MacroProps.open(state, macro.id)

      {k, macro} when k in [:delete, {:ctrl, "d"}] ->
        Update.confirm(state, "Delete the macro #{macro.name}? (Y/N)", {:delete_macro, macro.id})

      {{:alt_f, 5}, macro} ->
        state |> State.change_db(Core.sort_macros(state.db)) |> follow(macro.id)

      {{:alt, :up}, macro} ->
        state
        |> State.change_db(Core.move_macro(state.db, macro.id, mode.cursor - 1))
        |> follow(macro.id)

      {{:alt, :down}, macro} ->
        state
        |> State.change_db(Core.move_macro(state.db, macro.id, mode.cursor + 1))
        |> follow(macro.id)

      {{:f, 7}, %{keys: ""} = macro} ->
        learn(state, macro, :replace)

      {{:f, 7}, macro} ->
        State.push(state, %{type: :choice, kind: :learn, macro_id: macro.id, cursor: 0})

      _ ->
        state
    end
  end

  @doc "The prompt's answer: a new macro, highlighted."
  def create(state, name) do
    case Core.add_macro(state.db, name) do
      {:ok, db, id} ->
        index = Enum.find_index(db.macro_order, &(&1 == id))
        state |> State.change_db(db) |> select(index) |> State.info("F7 learns its keystrokes")

      {:error, :name_taken} ->
        State.error(state, "A macro is already called #{String.trim(name)}")

      {:error, :name_too_long} ->
        State.error(state, "A macro's name has at most 35 characters")

      {:error, :empty_name} ->
        state
    end
  end

  # the highlight stays on a macro that moved
  defp follow(state, id), do: select(state, Enum.find_index(state.db.macro_order, &(&1 == id)))

  @doc """
  The macro edit screen (F2): the note editor with the macro's text, a line
  after each {ENTER}; line breaks are not keys, so the text reads the same.
  """
  def edit_text(state, macro) do
    text = Regex.replace(~r/\{ENTER\}(?! )/i, macro.keys, "{ENTER}\n")

    State.push(state, %{
      type: :note,
      target: {:macro, macro.id},
      title: macro.name,
      edit: Agenda.TUI.TextEdit.new(text)
    })
  end

  defp select(state, index) do
    case Enum.find_index(state.modes, &(&1.type == :macros)) do
      nil -> state
      i -> %{state | modes: List.update_at(state.modes, i, &%{&1 | cursor: index})}
    end
  end

  # --- Learn mode ------------------------------------------------------------------------------

  @doc "Starts recording into a macro, replacing or appending to its keystrokes."
  def learn(state, macro, how) do
    learning = %{id: macro.id, keys: [], how: how}

    %{(state |> close_manager()) | macro: %{state.macro | learning: learning}}
    |> State.info("Learning #{macro.name}: ALT-F3 stops")
  end

  defp close_manager(state) do
    case Enum.find_index(state.modes, &(&1.type == :macros)) do
      nil -> state
      i -> %{state | modes: Enum.drop(state.modes, i + 1), edit: nil}
    end
  end

  # ALT-F3 (or ALT-Z) in Learn mode: the keystrokes go into the macro
  defp stop(%State{macro: %{learning: l}} = state) do
    macro = state.db.macros[l.id]
    recorded = l.keys |> Enum.reverse() |> MacroKeys.encode()
    keys = if l.how == :append, do: macro.keys <> recorded, else: recorded
    count = length(l.keys)

    %{state | macro: %{state.macro | learning: nil}}
    |> State.change_db(Core.set_macro_keys(state.db, l.id, keys))
    |> State.info(
      "Learn mode is off: #{macro.name} has #{Agenda.TUI.Draw.count(count, "new key")}"
    )
  end

  # --- running ----------------------------------------------------------------------------------

  @doc "Runs a macro: its keys go to the shell to play, one undo step."
  def run(state, macro) do
    cond do
      MacroKeys.decode(macro.keys) == [] ->
        State.info(state, "#{macro.name} has no keystrokes yet (F7 in the macro manager)")

      state.macro.playing >= @max_depth ->
        State.error(state, "Macros started #{@max_depth} deep; stopped")

      true ->
        state
        |> History.begin_run()
        |> then(&%{&1 | macro: %{&1.macro | playing: &1.macro.playing + 1, last: macro.id}})
        |> State.effect({:play, MacroKeys.decode(macro.keys)})
    end
  end

  defp run_last(state) do
    case state.macro.last && state.db.macros[state.macro.last] do
      nil -> State.error(state, "No macro run yet (ALT-F3 shows them)")
      macro -> run(state, macro)
    end
  end

  # the shell's word that a run's keys have all been played
  defp done(state) do
    state = %{state | macro: %{state.macro | playing: max(state.macro.playing - 1, 0)}}
    History.end_run(state)
  end

  # --- drawing -----------------------------------------------------------------------------------

  @doc "The manager's lines: each macro's name, and the key it is attached to."
  def lines(state, mode) do
    case Database.macros(state.db) do
      [] ->
        [{:box, "No macros yet · INS (or type a name) makes one"}]

      macros ->
        macros
        |> Enum.with_index()
        |> Enum.map(fn {m, i} ->
          text = Agenda.TUI.Draw.pad(m.name, 36) <> (m.key || "")
          {if(i == mode.cursor, do: :box_selected, else: :box), text}
        end)
    end
  end
end
