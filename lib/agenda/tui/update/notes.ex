defmodule Agenda.TUI.Update.Notes do
  @moduledoc """
  Keys in the full-screen note of an item, a category or a macro: editing,
  ALT-D / ALT-T, ALT-N / ALT-P to the next note, and saving on close. Pure.
  """

  alias Agenda.Core
  alias Agenda.Core.DateFormat
  alias Agenda.TUI.{CategoryScreens, Layout, NoteSearch, State, TextEdit}
  alias Agenda.TUI.Update.Actions

  # --- notes --------------------------------------------------------------------

  @doc "A key in a note (or in its Search/Replace question)."
  def note_key(state, %{replacing: replacing} = mode, key) when replacing != nil,
    do: NoteSearch.confirm_key(state, mode, key)

  def note_key(state, mode, key) do
    case key do
      {:alt_f, 6} ->
        NoteSearch.open(state)

      {:alt, "s"} ->
        NoteSearch.next(state, mode)

      k when k in [:esc, {:f, 5}, {:f, 4}] ->
        close_note(state, mode)

      {:alt, "d"} ->
        type_in_note(state, mode, DateFormat.date(state.today, state.db.date_format))

      {:alt, "t"} ->
        type_in_note(
          state,
          mode,
          DateFormat.time(NaiveDateTime.to_time(state.now), state.db.date_format)
        )

      {:alt, "n"} ->
        step_note(state, mode, 1)

      {:alt, "p"} ->
        step_note(state, mode, -1)

      {:alt, "q"} ->
        state |> close_note(mode) |> Actions.perform(:quit)

      {:alt, "k"} ->
        State.toggle_key_map(state)

      _ ->
        case TextEdit.handle(mode.edit, key) do
          {:ok, edit} -> State.put_mode(state, Map.merge(mode, %{edit: edit, match: nil}))
          :unhandled -> state
        end
    end
  end

  # Saves the note and closes it.
  defp close_note(state, mode) do
    text = TextEdit.text(mode.edit)

    db =
      case mode.target do
        {:item, id} -> Core.set_note(state.db, id, text, State.context(state))
        {:category, id} -> Core.set_category_note(state.db, id, text)
        {:macro, id} -> Core.set_macro_keys(state.db, id, text)
      end

    if db == state.db, do: State.pop(state), else: state |> State.pop() |> State.change_db(db)
  end

  defp type_in_note(state, mode, text) do
    {:ok, edit} = TextEdit.handle(mode.edit, {:char, text})
    State.put_mode(state, %{mode | edit: edit})
  end

  # ALT-N / ALT-P: save this note and show the note of the next / previous
  # item (or section) in the view, or category in the category manager.
  defp step_note(state, mode, step) do
    below = state.modes |> Enum.drop(1) |> List.first()

    case {below, next_note_target(state, below, mode.target, step)} do
      {_, :unsupported} ->
        State.error(
          state,
          "ALT-N / ALT-P work in notes opened from a view or the category manager"
        )

      {_, nil} ->
        state |> State.effect(:bell) |> State.error("No more notes in this direction")

      {nil, index} ->
        state |> close_note(mode) |> Layout.move_to(index) |> Actions.perform(:note)

      {%{type: :catmgr}, {index, id}} ->
        state = close_note(state, mode)

        state
        |> State.put_mode(%{State.mode(state) | cursor: index})
        |> CategoryScreens.open_note(id)
    end
  end

  defp next_note_target(state, nil, target, step) do
    kind = if match?({:item, _}, target), do: :item, else: :section
    rows = Layout.rows(state)

    candidates =
      if step > 0,
        do: (state.cursor + 1)..(length(rows) - 1)//1,
        else: (state.cursor - 1)..0//-1

    Enum.find(candidates, &(Enum.at(rows, &1).kind == kind))
  end

  defp next_note_target(state, %{type: :catmgr} = catmgr, {:category, _}, step) do
    rows = CategoryScreens.rows(state, catmgr)
    index = catmgr.cursor + step

    case Enum.at(rows, index) do
      {id, _} when index >= 0 -> {index, id}
      _ -> nil
    end
  end

  defp next_note_target(_state, _below, _target, _step), do: :unsupported
end
