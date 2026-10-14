defmodule Agendum.TUI.Moves.SectionMove do
  @moduledoc """
  Moving a section within its view (R62; User's Guide 5-8 to 5-9): ALT-F10
  on a section head, or View ▸ Section ▸ Move from anywhere in it.

    * every section is shown collapsed (§ and its item count), so the
      heads are easy to move among
    * ↑ / ↓ (or < / >) move it one place up / down
    * ENTER keeps the new place: one undo step, and the sections open again
    * ESC puts it back

  As with moving a column (`Agendum.TUI.Moves.ColumnMove`, ADR 0026), the file is
  not changed while it moves: the mode holds the place, and `State.view/1`
  shows the view with it there (`view/2`). The highlight goes with it.
  Pure.
  """

  alias Agendum.Core
  alias Agendum.TUI.State

  @doc "Starts moving section `sidx` of the current view."
  def open(state, sidx) do
    State.push(%{state | cursor_key: {:section, sidx}}, %{
      type: :section_move,
      view_id: state.view_id,
      from: sidx,
      to: sidx,
      cursor_key: state.cursor_key
    })
  end

  @doc "A view as shown while a section moves: in its new place, every section collapsed."
  def view(%State{modes: modes} = state, view) do
    case Enum.find(modes, &match?(%{type: :section_move, view_id: id} when id == view.id, &1)) do
      nil ->
        view

      mode ->
        moved = moved(state, mode).views[view.id]
        # collapsed on the copy shown, not in the file
        %{moved | sections: Enum.map(moved.sections, &%{&1 | collapsed: true})}
    end
  end

  # the file as it would be with the section moved; kept only on ENTER
  defp moved(state, mode), do: Core.move_section(state.db, mode.view_id, mode.from, mode.to)

  def handle(state, mode, key) do
    case key do
      k when k in [:up, {:char, "<"}] ->
        step(state, mode, -1)

      k when k in [:down, {:char, ">"}] ->
        step(state, mode, 1)

      :enter ->
        %{State.change_db(State.pop(state), moved(state, mode)) | cursor_key: {:section, mode.to}}

      # the highlight goes back where it was
      :esc ->
        %{State.pop(state) | cursor_key: mode.cursor_key}

      _ ->
        state
    end
  end

  defp step(state, mode, n) do
    last = length(state.db.views[mode.view_id].sections) - 1
    to = (mode.to + n) |> max(0) |> min(last)
    %{State.put_mode(state, %{mode | to: to}) | cursor_key: {:section, to}}
  end

  @doc "The control panel's line while a section moves (the key bar has the keys)."
  def panel(state, mode) do
    section = Enum.at(state.db.views[mode.view_id].sections, mode.from)
    "Moving section #{state.db.categories[section.category_id].name}  (↑ ↓, ENTER here)"
  end
end
