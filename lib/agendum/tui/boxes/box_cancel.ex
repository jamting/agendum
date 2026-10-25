defmodule Agendum.TUI.Boxes.BoxCancel do
  @moduledoc """
  ESC cancels a settings box, as in Agenda, whose boxes said "Press ENTER
  when done, ESC to cancel" (SPEC §5).

  The settings boxes apply each change at once inside, but the screen
  behind them is drawn as it was when the outermost one opened (`behind/2`),
  so the changes show there on ENTER, as Agenda's (checked in Agenda 2.0,
  2026-10-22; ADR 0030, amended). When such a box opens, the file, the
  person's preferences and the undo steps so far are kept with its mode
  (`:opened`); ESC closes the box and puts them back as they were. When
  the outermost box closes (`settle/2`), the steps recorded while it was
  open become one, the whole box, after ENTER, and none after ESC. A box
  opened from a box keeps its own snapshot, so ESC there cancels only its
  own changes.

  Work done in a full screen opened from a box (a note, the macro edit
  screen) is kept: coming back from it starts the box's snapshot again.

  ESC while a field is being typed in only stops the typing, and ESC while
  something is being moved in a box (`moving`, View Properties' Sections)
  only puts it down; the box handles those itself. Pure.
  """

  alias Agendum.TUI.State

  # full screens a box can open, whose work stays
  @screens [:note, :catmgr, :viewmgr, :help]
  # the view shown and the highlight's place in it
  @place [:view_id, :cursor, :cursor_key, :col, :scroll]

  @doc """
  Whether ESC cancels the changes made in a box of this type: those whose
  changes apply at once (`cancels: true`); the others (Column Add, the range
  filters, actions, Execute, Schedule, Search) apply only on ENTER.
  """
  @spec cancels?(atom) :: boolean
  def cancels?(type) do
    case Agendum.TUI.Boxes.Box.registry() do
      %{^type => box} -> box.cancels?()
      _ -> false
    end
  end

  @doc "ESC on a settings box with nothing being typed: the box closes and its changes go."
  @spec cancel(State.t(), term) :: State.t() | :pass
  def cancel(%State{edit: nil} = state, :esc) do
    case State.mode(state) do
      %{type: type, opened: opened} = mode when opened != nil ->
        cond do
          not cancels?(type) -> :pass
          Map.get(mode, :typing) -> :pass
          Map.get(mode, :moving) -> :pass
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
      {_, true} when top.opened == nil ->
        State.put_mode(state, Map.put(top, :opened, opened(before)))

      {%{type: screen}, true} when screen in @screens ->
        State.put_mode(state, %{top | opened: opened(state)})

      _ ->
        state
    end
  end

  # the snapshot, and the undo steps there were (`settle/2` comes back to
  # them)
  defp opened(state), do: Map.put(snapshot(state), :undo, state.history.undo)

  @doc """
  The state to draw the screen behind the boxes with: the file (and, in the
  same view, the place in it) as when the lowest settings box among
  `boxes` opened, so its changes show there only once it closes with ENTER.
  """
  @spec behind(State.t(), [map]) :: State.t()
  def behind(state, boxes) do
    case Enum.find(boxes, &opened?/1) do
      nil ->
        state

      # a view the box's own key made (View ▸ Add) is not in the snapshot:
      # it is drawn as it is now
      %{opened: opened} when not is_map_key(opened.db.views, state.view_id) ->
        state

      %{opened: opened} ->
        place = if opened.view_id == state.view_id, do: Map.take(opened, @place), else: %{}
        Map.merge(%{state | db: opened.db}, place)
    end
  end

  @doc """
  After a key (`before` the state it found): when the outermost settings
  box open then has closed, the undo steps recorded while it was open
  become one, from how things were when it opened, or none when nothing
  changed (ESC, or ENTER with no change). A macro run is one step already
  (`Agendum.TUI.History.begin_run/1`), so within one nothing is added.
  """
  @spec settle(State.t(), State.t()) :: State.t()
  def settle(before, state) do
    # `List.last/1` of the boxes with a snapshot: the outermost, opened first
    case before.modes |> Enum.filter(&opened?/1) |> List.last() do
      nil ->
        state

      %{opened: opened} = box ->
        if still_open?(before, state, box),
          do: state,
          else: Agendum.TUI.History.squash(state, opened, state.macro.playing > 0)
    end
  end

  # The box is still there: at the same depth of the stack, the same kind of
  # box. Not its snapshot: a box shown again after a full screen (a macro's
  # keys edited from Macro Properties) takes a new one (`track/2`), and is
  # still the same box (found by the fuzz walks, 2026-10-26: the steps made
  # in it before were folded into one).
  defp still_open?(before, state, box) do
    depth = length(before.modes) - Enum.find_index(before.modes, &(&1 == box))
    now = Enum.at(state.modes, length(state.modes) - depth)
    match?(%{type: type} when type == box.type, now) and opened?(now)
  end

  defp opened?(mode), do: cancels?(mode.type) and Map.get(mode, :opened) != nil

  # the file, the view shown and where in it, and the person's own settings,
  # which a box can change (View ▸ Add makes a view and opens its settings
  # with one key; F6 in the view manager shows the view whose properties
  # it opens)
  defp snapshot(state),
    do:
      Map.take(state, [
        :db,
        :view_id,
        :cursor,
        :cursor_key,
        :col,
        :scroll,
        :theme,
        :reader,
        :key_map,
        :prefs
      ])

  defp restore(state, opened) do
    state = if state.db == opened.db, do: state, else: State.change_db(state, opened.db)

    # a view the cancelled change made is gone, or the box showed another
    # view (F6 in the view manager): the view shown before, where it was
    state =
      if Map.has_key?(state.db.views, state.view_id) and state.view_id == opened.view_id,
        do: state,
        else: Map.merge(state, Map.take(opened, @place))

    prefs = Map.drop(opened, [:db, :undo | @place])

    if Map.take(state, Map.keys(prefs)) == prefs,
      do: state,
      else: State.change_preference(state, &Map.merge(&1, prefs), fn _ -> prefs.prefs end)
  end
end
