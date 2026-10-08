defmodule Agenda.TUI.History do
  @moduledoc """
  Undo and redo. Pure.

  The database is an immutable value, so a snapshot is simply the previous
  `Database` together with where the user was (view and cursor). Every key
  press that changes the database records one snapshot, so one undo
  reverses one user action, such as entering an item or a column entry.
  """

  alias Agenda.TUI.State

  @limit 100

  @doc """
  Records `before` as an undo step if handling a key changed the database.
  Nothing is recorded when the change came from undo/redo itself (the
  stacks moved) or when a different file was started (`saved_db` changed).
  """
  @spec record(State.t(), State.t()) :: State.t()
  def record(%State{} = before, %State{} = next) do
    cond do
      next.db == before.db -> next
      {next.undo, next.redo} != {before.undo, before.redo} -> next
      next.saved_db != before.saved_db -> %{next | undo: [], redo: []}
      true -> %{next | undo: Enum.take([snapshot(before) | before.undo], @limit), redo: []}
    end
  end

  @spec undo(State.t()) :: State.t()
  def undo(%State{undo: []} = state), do: State.error(state, "Nothing to undo")

  def undo(%State{undo: [snap | rest]} = state) do
    %{restore(state, snap) | undo: rest, redo: [snapshot(state) | state.redo]}
    |> State.info("Undone" <> remaining(rest))
  end

  @spec redo(State.t()) :: State.t()
  def redo(%State{redo: []} = state), do: State.error(state, "Nothing to redo")

  def redo(%State{redo: [snap | rest]} = state) do
    %{restore(state, snap) | redo: rest, undo: [snapshot(state) | state.undo]}
    |> State.info("Redone" <> remaining(rest))
  end

  defp snapshot(state), do: %{db: state.db, view_id: state.view_id, cursor_key: state.cursor_key}

  defp restore(state, snap) do
    %{state | db: snap.db, view_id: snap.view_id, cursor_key: snap.cursor_key, edit: nil}
  end

  defp remaining([]), do: ""
  defp remaining(rest), do: " (#{length(rest)} more)"
end
