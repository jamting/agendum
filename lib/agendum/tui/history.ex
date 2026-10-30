# SPDX-License-Identifier: AGPL-3.0-only
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
  stacks moved) or when a different file was started (`saved.db` changed).
  """
  # Two clauses: this one only when a key ended a step partway (`step` is
  # not nil, checked by the guard); the second one otherwise. The first
  # calls `record/2` again with `step` cleared, so the second clause does
  # the real work.
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

  # `cond` runs the first branch whose condition is true. `==` compares two
  # databases by value, all the way down; the order of the branches is the
  # order of the questions: did the key change the file at all, was it undo
  # or redo itself, was another file opened, is a macro playing?
  def record(%State{} = before, %State{} = next) do
    cond do
      next.db == before.db -> next
      stacks(next) != stacks(before) -> next
      next.saved.db != before.saved.db -> put_stacks(next, [], [])
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

  @doc """
  A settings box closed (`Agendum.TUI.Boxes.BoxCancel.settle/2`): the steps
  recorded since it opened (`opened`, with the undo steps of then) become
  one, back to the file as it was then, or none when it is unchanged. A
  macro run (`in_run`) is one step already, recorded as it began, perhaps
  after the box opened: the steps stay as they are.
  """
  @spec squash(State.t(), map, boolean) :: State.t()
  def squash(state, _opened, true), do: state

  def squash(state, opened, false) do
    if state.db == opened.db do
      put_stacks(state, opened.undo, state.history.redo)
    else
      # the snapshot of how things were when the box opened
      then = Map.merge(state, Map.take(opened, [:db, :view_id, :cursor_key]))
      put_stacks(state, push(snapshot(then), opened.undo), [])
    end
  end

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

  # Domain: a snapshot keeps the whole database, not a diff. That is cheap
  # because data never changes in place: the new database shares every
  # part the key did not touch with the old one, so 100 snapshots cost
  # little more than the parts that changed.
  defp push(snap, steps), do: Enum.take([snap | steps], @limit)

  defp snapshot(state), do: %{db: state.db, view_id: state.view_id, cursor_key: state.cursor_key}

  defp restore(state, snap) do
    %{state | db: snap.db, view_id: snap.view_id, cursor_key: snap.cursor_key, edit: nil}
  end

  defp remaining([]), do: ""
  defp remaining(rest), do: " (#{length(rest)} more)"
end
