defmodule Agendum.TUI.Boxes.CategoryStatsBox do
  @moduledoc """
  The Category Statistics box (Category Properties ▸ Statistics; Agenda's
  Category Statistics, screenshot 74): how much of the file uses the
  category, counts only, nothing to change: its items, children, the
  sections it heads, and the view filters, conditions and actions that
  name it (`Agendum.Core.Database.category_statistics/2`). ENTER or ESC go back
  to Category Properties. Drawn from `@layout` (`Agendum.TUI.Boxes.Template`).
  Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :return, indicator: "PROPS"

  alias Agendum.Core.Database
  alias Agendum.TUI.Boxes.{Box, Template}
  alias Agendum.TUI.State

  @layout """
   Items in category:          [items  ]
   Child categories:           [children]
   Used as section heads:      [section_heads]
   Included in view filters:   [view_filters]
   Included in conditions:     [conditions]
   Included in actions:        [actions]
  """

  def open(state, cat_id), do: State.push(state, %{type: :category_stats, cat_id: cat_id})

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
  def title(state, mode), do: "Category statistics: " <> state.db.categories[mode.cat_id].name

  # a small box, as Agenda's
  @impl Box
  def width(state, _mode), do: min(state.width - 8, 44)

  @impl Box
  def content(state, mode, _inner, _max_rows) do
    counts = Database.category_statistics(state.db, mode.cat_id)
    Template.render(@layout, Map.new(counts, fn {k, n} -> {k, Integer.to_string(n)} end))
  end

  @impl Box
  def keys(_state, _mode), do: [{"ENTER/ESC", "Return"}]

  @impl Box
  def help,
    do:
      "How much of the file uses the category: its items, children, sections, " <>
        "filters, conditions and actions."
end
