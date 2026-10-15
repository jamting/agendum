defmodule Agendum.TUI.Boxes.FileStatsBox do
  @moduledoc """
  The File Statistics box (File ▸ Properties ▸ File statistics; Agenda's
  File Statistics, screenshot 140): how big the file is, counts only,
  nothing to change: its items, those with notes, its categories, and the
  average items per category and categories per item
  (`Agendum.Core.Database.file_statistics/1`). Agenda's Unused space and
  Items in trash are left out: Agendum has neither. ENTER or ESC go back
  to File Properties. Drawn from `@layout` (`Agendum.TUI.Boxes.Template`).
  Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :return, indicator: "PROPS"

  alias Agendum.Core.Database
  alias Agendum.TUI.Boxes.{Box, Template}
  alias Agendum.TUI.State

  # Agenda's rows and spacing (screenshot 140)
  @layout """

     Items:                          [items     ]
     Items with notes:               [items_with_notes]
     Categories:                     [categories]
     Average items/category:         [items_per_category]
     Average categories/item:        [categories_per_item]

  """

  def open(state), do: State.push(state, %{type: :file_stats})

  @impl Box
  def handle(state, _mode, _key), do: state

  # R65
  @impl Box
  def keymap(_mode), do: %{:enter => :close, :esc => :close}

  @impl Box
  def commands(_mode), do: [{:close, "Return", "Close the statistics"}]

  @impl Box
  def run(state, _mode, :close), do: State.pop(state)

  @impl Box
  def title(_state, _mode), do: "File statistics"

  # Agenda's box is a little narrower than File Properties
  @impl Box
  def width(state, _mode), do: min(state.width - 8, 51)

  @impl Box
  def content(state, _mode, _inner, _max_rows) do
    counts = Database.file_statistics(state.db)
    Template.render(@layout, Map.new(counts, fn {k, n} -> {k, Integer.to_string(n)} end))
  end

  @impl Box
  def keys(_state, _mode), do: [{"ENTER/ESC", "Return"}]

  @impl Box
  def help, do: "How big the file is: its items, notes and categories, and how they are assigned."
end
