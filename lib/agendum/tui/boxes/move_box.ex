# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Boxes.MoveBox do
  @moduledoc """
  ALT-F10 MOVE on an item (R26; checked in Agenda 2.0, 2026-11-01): the
  small Move box lists the view's sections, the current one highlighted;
  ↑ ↓ choose one and ENTER moves the item, or the marked items, there: each
  leaves the section it came from, joins the chosen one's head category and
  goes last in it, marked items in their order (one undo step). An item
  moved into the section it is in stays where it is. The highlight stays
  in the section the items left. ESC moves nothing.

  Refused in a view with one section, in Agenda's words (Item ▸ Reposition
  orders a section, R26a), and in a datebook view, whose sections are its
  dates (R47). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :accept

  alias Agendum.TUI.Boxes.Box
  alias Agendum.TUI.{Layout, Messages, State}

  @doc "Opens the box for the moves `{item_id, from_category}`."
  def open(state, moves) do
    view = State.view(state)

    cond do
      view.datebook ->
        State.error(state, Messages.text(:datebook_change))

      length(view.sections) < 2 ->
        State.error(state, Messages.text(:move_one_section))

      true ->
        current = (Layout.current_row(state) || %{sidx: 0}).sidx
        State.push(state, %Agendum.TUI.Modes.MoveItems{moves: moves, cursor: current})
    end
  end

  @impl Box
  def handle(state, _mode, _key), do: state

  @impl Box
  def about(_state, _mode) do
    """
    Move the item (or the marked items) to another section of the view: it
    leaves the section it is in, joins the one you choose and goes last
    there. ↑ ↓ choose the section, ENTER moves, ESC does not.
    """
  end

  # R65
  @impl Box
  def keymap(_mode), do: %{:up => :up, :down => :down, :enter => :move, :esc => :close}

  @impl Box
  def commands(_mode) do
    [{:move, "Move", "Move to the highlighted section"}] ++
      Enum.take(Box.list_moves(), 2) ++ [{:close, "Cancel", "Close without moving"}]
  end

  @impl Box
  def run(state, mode, :move), do: state |> State.pop() |> move(mode)
  def run(state, _mode, :close), do: State.pop(state)
  def run(state, mode, id), do: Box.list_move(state, mode, length(State.view(state).sections), id)

  # Each item goes after the last one the chosen section shows, the next
  # after it, so they keep their order at the end; an item already in that
  # section is left where it is. The highlight keeps its place on the
  # screen, which is now the row after the items that left.
  defp move(state, mode) do
    to = Enum.at(State.view(state).sections, mode.cursor).category_id
    last = state |> section_items(mode.cursor) |> List.last()
    moves = Enum.reject(mode.moves, fn {_id, from} -> from == to end)
    afters = [last | Enum.map(moves, &elem(&1, 0))]

    commands =
      for {{id, from}, after_id} <- Enum.zip(moves, afters),
          do: {:move_item, id, from || state.db.main_id, to, after: after_id}

    if commands == [] do
      state
    else
      cursor = state.cursor
      state = State.run(state, {:batch, commands})
      Layout.move_to(state, min(cursor, length(Layout.rows(state)) - 1))
    end
  end

  defp section_items(state, sidx),
    do: for(row <- Layout.rows(state), row.kind == :item, row.sidx == sidx, do: row.item.id)

  @impl Box
  def title(_state, _mode), do: "Move"

  # a small box, as Agenda's
  @impl Box
  def width(state, _mode), do: min(state.width - 8, 32)

  @impl Box
  def keys(_state, _mode),
    do: [
      {"↑↓", "Section", "Choose the section"},
      {"ENTER", "Move", "Move the item(s) there"},
      {"ESC", "Cancel"}
    ]

  # Agenda's words in the control panel
  @impl Box
  def help, do: "Highlight the section where you want to move the item and press ENTER."

  # a blank line, then the sections, the chosen one selected, as Agenda's;
  # a long list scrolls to keep it in the box, as Copy's does
  @impl Box
  def content(state, mode, _inner, max_rows) do
    room = max(max_rows - 1, 1)
    top = max(mode.cursor - room + 1, 0)

    sections =
      state
      |> State.view()
      |> Map.fetch!(:sections)
      |> Enum.with_index()
      |> Enum.drop(top)
      |> Enum.take(room)
      |> Enum.map(fn {section, i} ->
        style = if i == mode.cursor, do: :box_selected, else: :box
        [{:box, "  "}, {style, state.db.categories[section.category_id].name}]
      end)

    [[]] ++ sections
  end
end
