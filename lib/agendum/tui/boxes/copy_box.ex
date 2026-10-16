defmodule Agendum.TUI.Boxes.CopyBox do
  @moduledoc """
  ALT-F9 COPY (R42; User's Guide 13-8 to 13-9): the Copy box lists the
  view's sections, the current one highlighted; ↑ ↓ choose one and ENTER
  puts the item, or the marked items, in it as well: they are assigned to
  its head category and keep their other sections (one undo step). It is
  the same item, not a duplicate, so an edit shows everywhere. A section
  whose head is mutually exclusive with the one the item is in takes it
  away from there, as any assignment does (R15). ESC copies nothing.

  Our choice: Agenda put the copy at the bottom of the section; the items
  of a file have one order (an item's place is the same in every
  section), so it shows in its usual place. Not in a datebook view, whose
  sections are its dates (R47). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :accept, indicator: "CHOICES"

  alias Agendum.TUI.Boxes.Box
  alias Agendum.TUI.{Terminal.Draw, Layout, State}

  @doc "Opens the box for the items `ids`."
  def open(state, ids) do
    if State.view(state).datebook do
      State.error(state, "In a datebook view, give the item another date instead")
    else
      current = (Layout.current_row(state) || %{sidx: 0}).sidx
      State.push(state, %{type: :copy_items, ids: ids, cursor: current})
    end
  end

  @impl Box
  def handle(state, _mode, _key), do: state

  @impl Box
  def about(_state, _mode) do
    """
    Copy the item (or the marked items) to another section of the view: it
    is assigned to that section's category as well, and keeps the ones it
    has. ↑ ↓ choose the section, ENTER copies, ESC does not.
    """
  end

  # R65
  @impl Box
  def keymap(_mode), do: %{:up => :up, :down => :down, :enter => :copy, :esc => :close}

  @impl Box
  def commands(_mode) do
    [{:copy, "Copy", "Copy to the highlighted section"}] ++
      Enum.take(Box.list_moves(), 2) ++ [{:close, "Cancel", "Close without copying"}]
  end

  @impl Box
  def run(state, mode, :copy), do: state |> State.pop() |> copy(mode)
  def run(state, _mode, :close), do: State.pop(state)
  def run(state, mode, id), do: Box.list_move(state, mode, length(State.view(state).sections), id)

  defp copy(state, mode) do
    cat_id = Enum.at(State.view(state).sections, mode.cursor).category_id
    name = state.db.categories[cat_id].name

    what =
      if length(mode.ids) == 1, do: "", else: Draw.count(length(mode.ids), "marked item") <> " "

    State.run(
      state,
      {:batch, Enum.map(mode.ids, &{:assign, &1, cat_id})},
      "Copied #{what}to #{name}"
    )
  end

  @impl Box
  def title(_state, _mode), do: "Copy"

  # a small box, as Agenda's
  @impl Box
  def width(state, _mode), do: min(state.width - 8, 32)

  @impl Box
  def keys(_state, _mode),
    do: [
      {"↑↓", "Section", "Choose the section"},
      {"ENTER", "Copy", "Put the item(s) there as well"},
      {"ESC", "Cancel"}
    ]

  @impl Box
  def help,
    do:
      "Highlight the section to copy the item to and press ENTER; " <>
        "it stays in its other sections."

  # the question, then the sections, the chosen one selected
  @impl Box
  def content(state, mode, _inner, _max_rows) do
    sections =
      state
      |> State.view()
      |> Map.fetch!(:sections)
      |> Enum.with_index()
      |> Enum.map(fn {section, i} ->
        style = if i == mode.cursor, do: :box_selected, else: :box
        [{:box, "   "}, {style, state.db.categories[section.category_id].name}]
      end)

    [[{:box, " Copy to which section?"}], []] ++ sections
  end
end
