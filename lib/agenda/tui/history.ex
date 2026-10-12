defmodule Agenda.TUI.History do
  @moduledoc """
  Undo and redo. Pure.

  The database is an immutable value, so a snapshot is simply the previous
  `Database` together with where the user was (view and cursor). Every key
  press that changes the database records one snapshot, so one undo
  reverses one user action, such as entering an item or a column entry.
  A macro run is one action too (R50): `begin_run/1` records the snapshot
  as it starts, nothing is recorded while it plays, and `end_run/1` drops
  the snapshot again if the macro changed nothing.
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
      # a macro playing: its run is one step, recorded as it began
      before.macro.playing > 0 -> next
      true -> %{next | undo: Enum.take([snapshot(before) | before.undo], @limit), redo: []}
    end
  end

  @doc "A macro run starts: one undo step for all it does."
  @spec begin_run(State.t()) :: State.t()
  def begin_run(%State{macro: %{playing: 0}} = state),
    do: %{state | undo: Enum.take([snapshot(state) | state.undo], @limit), redo: []}

  def begin_run(state), do: state

  @doc "A macro run ended: its step goes if it changed nothing."
  @spec end_run(State.t()) :: State.t()
  def end_run(%State{macro: %{playing: 0}, undo: [%{db: db} | rest]} = state)
      when db == state.db,
      do: %{state | undo: rest}

  def end_run(state), do: state

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
