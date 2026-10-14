defmodule Agendum.TUI.Boxes.BoxCancel do
  @moduledoc """
  ESC cancels a settings box, as in Agenda, whose boxes said "Press ENTER
  when done, ESC to cancel" (SPEC §5).

  The settings boxes apply each change at once, so the screen behind them
  shows it. When such a box opens, the file and the person's preferences
  are kept with its mode (`:opened`); ESC closes the box and puts them
  back as they were, as one change (so one undo step brings the changes
  back). ENTER closes it and keeps them. A box opened from a box keeps its
  own snapshot, so ESC there cancels only its own changes.

  Work done in a full screen opened from a box (a note, the macro edit
  screen) is kept: coming back from it starts the box's snapshot again.

  ESC while a field is being typed in only stops the typing; the box
  handles that itself. Pure.
  """

  alias Agendum.TUI.State

  # the boxes whose changes apply at once; the others (Column Add, the
  # range filters, actions, Execute, Schedule, Search) apply only on ENTER
  @boxes [
    :datebook_props,
    :column_props,
    :props,
    :item_props
  ]

  # full screens a box can open, whose work stays
  @screens [:note, :catmgr, :viewmgr, :help]

  @doc "Whether ESC cancels the changes made in a box of this type."
  @spec cancels?(atom) :: boolean
  def cancels?(type) do
    case Agendum.TUI.Boxes.Box.registry() do
      %{^type => box} -> box.cancels?()
      _ -> type in @boxes
    end
  end

  @doc "ESC on a settings box with nothing being typed: the box closes and its changes go."
  @spec cancel(State.t(), term) :: State.t() | :pass
  def cancel(%State{edit: nil} = state, :esc) do
    case State.mode(state) do
      %{type: type, opened: opened} = mode ->
        cond do
          not cancels?(type) -> :pass
          Map.get(mode, :typing) -> :pass
          true -> state |> State.pop() |> restore(opened)
        end

      _ ->
        :pass
    end
  end

  def cancel(_state, _key), do: :pass

  @doc """
  After a key: a settings box that has just appeared on top keeps how
  things were before the key (`before`); one shown again after a full
  screen keeps how they are now.
  """
  @spec track(State.t(), State.t()) :: State.t()
  def track(before, %State{} = state) do
    top = State.mode(state)

    case {State.mode(before), top && cancels?(top.type)} do
      {_, true} when not is_map_key(top, :opened) ->
        State.put_mode(state, Map.put(top, :opened, snapshot(before)))

      {%{type: screen}, true} when screen in @screens ->
        State.put_mode(state, %{top | opened: snapshot(state)})

      _ ->
        state
    end
  end

  # the file, the view shown and the person's own settings, which a box can
  # change (View ▸ Add makes a view and opens its settings with one key)
  defp snapshot(state),
    do: Map.take(state, [:db, :view_id, :theme, :languages, :input, :key_map, :prefs])

  defp restore(state, opened) do
    state = if state.db == opened.db, do: state, else: State.change_db(state, opened.db)

    # a view the cancelled change made is gone: show the one shown before
    state =
      if Map.has_key?(state.db.views, state.view_id),
        do: state,
        else: %{state | view_id: opened.view_id}

    prefs = Map.drop(opened, [:db, :view_id])

    if Map.take(state, Map.keys(prefs)) == prefs,
      do: state,
      else: State.change_preference(state, &Map.merge(&1, prefs), fn _ -> prefs.prefs end)
  end
end
