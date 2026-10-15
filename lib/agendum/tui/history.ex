defmodule Agendum.TUI.History do
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

  alias Agendum.TUI.State

  @limit 100

  @doc """
  Records `before` as an undo step if handling a key changed the database.
  Nothing is recorded when the change came from undo/redo itself (the
  stacks moved) or when a different file was started (`saved_db` changed).
  """
  @spec record(State.t(), State.t()) :: State.t()
  def record(%State{} = before, %State{history: %{step: step}} = next) when step != nil do
    # a step ended partway through the key (`State.end_step/1`): the
    # changes up to there are a step of their own, when there were any
    next = put_in(next.history.step, nil)

    if step == before.db or step == next.db or before.macro.playing > 0 do
      record(before, next)
    else
      # first from before to the step, then from the step to the end
      first = record(before, %{next | db: step})
      record(%{before | db: step, history: first.history}, %{next | history: first.history})
    end
  end

  def record(%State{} = before, %State{} = next) do
    cond do
      next.db == before.db -> next
      stacks(next) != stacks(before) -> next
      next.saved_db != before.saved_db -> put_stacks(next, [], [])
      # a macro playing: its run is one step, recorded as it began
      before.macro.playing > 0 -> next
      true -> put_stacks(next, push(snapshot(before), before.history.undo), [])
    end
  end

  @doc "A macro run starts: one undo step for all it does."
  @spec begin_run(State.t()) :: State.t()
  def begin_run(%State{macro: %{playing: 0}} = state),
    do: put_stacks(state, push(snapshot(state), state.history.undo), [])

  def begin_run(state), do: state

  @doc "A macro run ended: its step goes if it changed nothing."
  @spec end_run(State.t()) :: State.t()
  def end_run(%State{macro: %{playing: 0}, history: %{undo: [%{db: db} | rest]}} = state)
      when db == state.db,
      do: put_in(state.history.undo, rest)

  def end_run(state), do: state

  @spec undo(State.t()) :: State.t()
  def undo(%State{history: %{undo: []}} = state), do: State.error(state, "Nothing to undo")

  def undo(%State{history: %{undo: [snap | rest], redo: redo}} = state) do
    state
    |> restore(snap)
    |> put_stacks(rest, [snapshot(state) | redo])
    |> State.info("Undone" <> remaining(rest))
  end

  @spec redo(State.t()) :: State.t()
  def redo(%State{history: %{redo: []}} = state), do: State.error(state, "Nothing to redo")

  def redo(%State{history: %{undo: undo, redo: [snap | rest]}} = state) do
    state
    |> restore(snap)
    |> put_stacks(push(snapshot(state), undo), rest)
    |> State.info("Redone" <> remaining(rest))
  end

  defp stacks(state), do: {state.history.undo, state.history.redo}

  defp put_stacks(state, undo, redo),
    do: %{state | history: %{state.history | undo: undo, redo: redo}}

  defp push(snap, steps), do: Enum.take([snap | steps], @limit)

  defp snapshot(state), do: %{db: state.db, view_id: state.view_id, cursor_key: state.cursor_key}

  defp restore(state, snap) do
    %{state | db: snap.db, view_id: snap.view_id, cursor_key: snap.cursor_key, edit: nil}
  end

  defp remaining([]), do: ""
  defp remaining(rest), do: " (#{length(rest)} more)"
end
