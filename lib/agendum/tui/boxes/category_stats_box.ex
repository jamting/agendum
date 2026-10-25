defmodule Agendum.TUI.Boxes.CategoryStatsBox do
  @moduledoc """
  The Category Statistics box (Category Properties ▸ Statistics; Agenda's
  Category Statistics, screenshot 74): how much of the file uses the
  category, counts only, nothing to change: its items, children, the
  sections it heads, and the view filters, conditions and actions that
  name it (`Agendum.Core.Database.category_statistics/2`). Any key goes back
  to Category Properties. Drawn from `@layout` (`Agendum.TUI.Boxes.Template`).
  Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :any_key, indicator: "PROPS"

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

  def open(state, cat_id), do: State.push(state, %Agendum.TUI.Modes.CategoryStats{cat_id: cat_id})

  # any key that is not ENTER or ESC closes it too, as Agenda's "Press any
  # key to continue" (R65's keymap has those two)
  @impl Box
  def handle(state, _mode, _key), do: State.pop(state)

  # R65
  @impl Box
  def keymap(_mode), do: %{:enter => :close, :esc => :close}

  @impl Box
  def commands(_mode), do: [{:close, "Return", "Close the statistics"}]

  @impl Box
  def run(state, _mode, :close), do: State.pop(state)

  @impl Box
  def title(_state, _mode), do: "Category Statistics"

  # a small box, as Agenda's
  @impl Box
  def width(state, _mode), do: min(state.width - 8, 44)

  @impl Box
  def content(state, mode, _inner, _max_rows) do
    counts = Database.category_statistics(state.db, mode.cat_id)
    Template.render(@layout, Map.new(counts, fn {k, n} -> {k, Integer.to_string(n)} end))
  end

  @impl Box
  def keys(_state, _mode), do: [{"any key", "Continue"}]

  @impl Box
  def help,
    do:
      "How much of the file uses the category: its items, children, sections, " <>
        "filters, conditions and actions."
end
