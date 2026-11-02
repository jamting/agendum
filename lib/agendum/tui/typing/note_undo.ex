# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Typing.NoteUndo do
  @moduledoc """
  Undo and redo inside the note editor (R64g; ours, Agenda had no undo).
  Pure.

  The note keeps its own steps, in its mode (`undo`, `redo`), as the file
  keeps its (`Agendum.TUI.History`). Each step is how the note was before
  it: `edit` (text and cursor) and `title`, and `file`, the file's undo
  steps the same key recorded, newest first, or `[]` when only the text
  changed. A step that changed the file (ALT-F7, ALT-F9, Clear, a
  replacement …) is undone with the file's own undo, so file and note go
  back together.

  Typing is grouped into words (`chunk`, the kind of the last change): a
  word and the spaces after it are one step, a run of deletions is one,
  anything else (a paste, a date, Import …) is one of its own, and moving
  the cursor ends a step. Like the file's history, the steps are recorded
  in one place (`track/3`, called by `Agendum.TUI.Update` after each key),
  never by the commands themselves. They end with the note: once it is
  closed, the whole note is one file step again (R30).
  """

  alias Agendum.TUI.{History, Keymap, State}

  @limit 500

  @doc """
  Records what the key did to the note open (if any): a new step, a word
  typed on, or nothing. `before` and `next` are the states around the key.
  """
  @spec track(State.t(), term, State.t()) :: State.t()
  def track(before, key, next) do
    with {_i, b} <- note(before),
         {i, n} <- note(next),
         true <- same_session?(b, n) do
      track_note(before, key, next, i, b, n)
    else
      _ -> next
    end
  end

  # The same note, and its steps not moved by undo or redo themselves
  # (ALT-N opens another note, with no steps).
  defp same_session?(b, n),
    do: b.target == n.target and b.undo == n.undo and b.redo == n.redo

  defp track_note(before, key, next, i, b, n) do
    cond do
      (steps = new_file_steps(before.history.undo, next.history.undo)) != [] ->
        next |> drop_redo(n) |> push(i, n, step(b, steps), nil)

      b.edit.lines != n.edit.lines ->
        kind = kind(before, key)

        if continues?(n.chunk, kind),
          do: put_note(next, i, %{n | chunk: kind}),
          else: next |> drop_redo(n) |> push(i, n, step(b, []), kind)

      {b.edit.row, b.edit.col} != {n.edit.row, n.edit.col} ->
        put_note(next, i, %{n | chunk: nil})

      true ->
        next
    end
  end

  # Domain: what kind of change a key made, for the word rule. Only a key
  # pressed in the note itself counts as typing; a key in a box over it
  # (Word, Line or All text) made a change of its own.
  defp kind(before, key) do
    on_top? = match?(%{type: :note}, State.mode(before))

    cond do
      not on_top? -> :other
      match?({:char, c} when is_binary(c), key) -> char_kind(elem(key, 1))
      true -> key_kind(Keymap.lookup(:text, key))
    end
  end

  defp char_kind(c) do
    cond do
      String.length(c) != 1 -> :other
      String.trim(c) == "" -> :space
      true -> :type
    end
  end

  defp key_kind(:new_line), do: :space
  defp key_kind(id) when id in [:delete_back, :delete], do: :delete
  defp key_kind(_id), do: :other

  # `Buy ` then `m`: a word followed by spaces ends at the next letter
  defp continues?(:type, :type), do: true
  defp continues?(chunk, :space) when chunk in [:type, :space], do: true
  defp continues?(:delete, :delete), do: true
  defp continues?(_chunk, _kind), do: false

  # The file's undo steps the key added, newest first: those above the
  # step that was on top before (`History` may have dropped the oldest).
  defp new_file_steps([], after_undo), do: after_undo
  defp new_file_steps(same, same), do: []

  defp new_file_steps([top | _], after_undo),
    do: Enum.take_while(after_undo, &(&1 != top))

  defp step(note, file), do: %{edit: note.edit, title: note.title, file: file}

  defp push(state, i, note, step, chunk) do
    note = %{note | undo: Enum.take([step | note.undo || []], @limit), redo: [], chunk: chunk}
    put_note(state, i, note)
  end

  # A new step drops what could be redone; the file's redo steps that
  # belonged to the note's go too, so CTRL-Y in the view cannot bring
  # back what the note gave up.
  defp drop_redo(state, note) do
    file = Enum.flat_map(note.redo || [], & &1.file)

    if file != [] and Enum.take(state.history.redo, length(file)) == file,
      do: put_in(state.history.redo, Enum.drop(state.history.redo, length(file))),
      else: state
  end

  @doc "CTRL-Z in the note: its last step goes back, with the file's when it had one."
  @spec undo(State.t()) :: State.t()
  def undo(state), do: move(state, :undo)

  @doc "CTRL-Y in the note: the last step undone comes back."
  @spec redo(State.t()) :: State.t()
  def redo(state), do: move(state, :redo)

  defp move(state, way) do
    {i, note} = note(state)

    case Map.get(note, way) || [] do
      [] ->
        State.error(state, "Nothing to #{way} in this note")

      [step | rest] ->
        case file_move(state, way, step.file) do
          {:ok, state, file} ->
            back = step(note, file)
            other = if way == :undo, do: :redo, else: :undo
            note = %{note | edit: step.edit, title: step.title, chunk: nil, match: nil}

            note =
              note
              |> Map.put(way, rest)
              |> Map.put(other, [back | Map.get(note, other) || []])

            state |> put_note(i, note) |> State.info(done(way))

          :changed ->
            State.error(state, "The file changed since; close the note, then CTRL-Z")
        end
    end
  end

  defp done(:undo), do: "Undone"
  defp done(:redo), do: "Redone"

  # The file's steps go back (or come again) only when they are still the
  # last ones: something else may have changed the file since. The steps
  # for the other way are taken as `History` leaves them.
  defp file_move(state, _way, []), do: {:ok, state, []}

  defp file_move(state, way, file) do
    {stack, run, other} =
      case way do
        :undo -> {state.history.undo, &History.undo/1, :redo}
        :redo -> {state.history.redo, &History.redo/1, :undo}
      end

    n = length(file)

    if Enum.take(stack, n) == file do
      # `Enum.reduce/3` over 1..n: the file's undo (or redo), n times
      moved = Enum.reduce(1..n, state, fn _, s -> run.(s) end)
      {:ok, moved, Enum.take(Map.fetch!(moved.history, other), n)}
    else
      :changed
    end
  end

  # the note on the stack (under a box too), with its place
  defp note(state) do
    case Enum.find_index(state.modes, &(&1.type == :note)) do
      nil -> nil
      i -> {i, Enum.at(state.modes, i)}
    end
  end

  defp put_note(state, i, note), do: %{state | modes: List.replace_at(state.modes, i, note)}
end
