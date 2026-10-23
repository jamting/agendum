defmodule Agendum.TUI.Boxes.ViewStatsBox do
  @moduledoc """
  The View Statistics box (View Properties ▸ View statistics; R78; Help
  "View Statistics Box"; checked in Agenda 2.0, 2026-10-23): the marked
  items the view shows, its sections (empty ones too) and the items its
  sections show (`Agendum.Core.view_statistics/3`). Nothing to change: any
  key goes back to View Properties, as Agenda's "Press any key to
  continue". Drawn from `@layout` (`Agendum.TUI.Boxes.Template`). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :return, indicator: "PROPS"

  alias Agendum.Core
  alias Agendum.TUI.Boxes.{Box, Template}
  alias Agendum.TUI.State

  # Agenda's rows and spacing
  @layout """

    Marked items:              [marked    ]
    Sections in view:          [sections  ]
    Items in view:             [items     ]

  """

  @doc "Opens the box for view `view_id`."
  @spec open(State.t(), Agendum.Core.Database.id()) :: State.t()
  def open(state, view_id),
    do: State.push(state, %Agendum.TUI.Modes.ViewStats{view_id: view_id})

  # any key that is not ENTER or ESC closes it too (R65's keymap has those)
  @impl Box
  def handle(state, _mode, _key), do: State.pop(state)

  @impl Box
  def keymap(_mode), do: %{:enter => :close, :esc => :close}

  @impl Box
  def commands(_mode), do: [{:close, "Return", "Close the statistics"}]

  @impl Box
  def run(state, _mode, :close), do: State.pop(state)

  @impl Box
  def title(_state, _mode), do: "View Statistics"

  # Agenda's box is narrower than View Properties
  @impl Box
  def width(state, _mode), do: min(state.width - 8, 45)

  @impl Box
  def content(state, mode, _inner, _max_rows) do
    counts = Core.view_statistics(state.db, mode.view_id, State.context(state))
    Template.render(@layout, Map.new(counts, fn {k, n} -> {k, Integer.to_string(n)} end))
  end

  @impl Box
  def keys(_state, _mode), do: [{"ENTER/ESC", "Return"}]

  @impl Box
  def help, do: "How many marked items, sections and items the view has."
end
