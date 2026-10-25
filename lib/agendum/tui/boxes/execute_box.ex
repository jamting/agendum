defmodule Agendum.TUI.Boxes.ExecuteBox do
  @moduledoc """
  Utilities Execute (SPEC R15e; User's Guide 20-19 to 20-21, 21-17):
  applies conditions, text conditions and actions to items that were in
  the file before those were set.

  The Execute box (Utilities ▸ Execute) has three settings: Apply conditions
  of (a category and its children; MAIN for all, ENTER opens the category
  box), Against (all items, the current item, the marked items, the items
  in the section or in the view) and Apply actions to (new assignments
  only, or old and new). SPACE changes a setting (on the first row: picks
  the category); the arrows move; ENTER runs it, ESC
  cancels. ALT-X runs everything on all items; ALT-E runs the highlighted
  category's family on all items. Drawn from `@layout`
  (`Agendum.TUI.Boxes.Template`). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, choices: true

  alias Agendum.Core
  alias Agendum.TUI.Boxes.{Box, Template}
  alias Agendum.TUI.{CategoryScreens, Layout, State}

  @layout """
   Apply conditions attached to
     category and children of: [root                          ]
   Against:                    [against                        ]
   Apply actions to:    [actions                               ]
  """

  @rows Template.fields(@layout)
  @grid Template.grid(@layout, @rows)
  @against [:all, :current, :marked, :section, :view]

  @help %{
    root: "Apply the conditions of this category and its children. SPACE picks a category.",
    against:
      "The items to apply them to: all, the current item, the marked ones, " <>
        "the section or the view. SPACE.",
    actions:
      "Apply actions to new assignments only, or to old and new ones. SPACE switches. " <>
        "ENTER runs it."
  }

  def open(state),
    do:
      State.push(state, %Agendum.TUI.Modes.Execute{
        root: state.db.main_id,
        against: :all,
        old: false,
        cursor: 0
      })

  @impl Box
  # its keys are the settings box's; ENTER executes (R65)
  def handle(state, _mode, _key), do: state

  @impl Box
  def keymap(_mode), do: Box.settings_keymap()

  @impl Box
  def commands(_mode),
    do:
      Box.settings_commands([
        {:done, "Execute", "Run the conditions and actions"},
        {:close, "Cancel", "Close without executing"}
      ])

  @impl Box
  def run(state, mode, :done),
    do: state |> State.pop() |> execute(mode.root, mode.against, mode.old)

  def run(state, mode, :change), do: change(state, mode, field(state, mode))
  def run(state, mode, id), do: Box.run_settings(state, mode, @grid, id)

  defp change(state, _mode, :root), do: CategoryScreens.open_picker(state, :execute_root, nil)

  defp change(state, mode, :against) do
    index = Enum.find_index(@against, &(&1 == mode.against))
    State.put_mode(state, %{mode | against: Enum.at(@against, Integer.mod(index + 1, 5))})
  end

  defp change(state, mode, :actions), do: State.put_mode(state, %{mode | old: not mode.old})

  @doc "Sets the category whose conditions apply (from the category box)."
  def set_root(state, cat_id), do: State.put_mode(state, %{State.mode(state) | root: cat_id})

  @doc "Runs Execute from the view: `root`'s family on the chosen items."
  def execute(state, root, against, old \\ false) do
    ids = items(state, against)

    state = State.run(state, {:execute, ids, root: root, old_assignments: old})

    what =
      if root == state.db.main_id,
        do: "",
        else: state.db.categories[root].name <> " "

    State.info(
      state,
      "Executed #{what}for #{Agendum.TUI.Terminal.Draw.count(length(ids), "item")}"
    )
  end

  defp items(state, :all), do: state.db.item_order
  defp items(state, :marked), do: Core.marked_items(state.db)

  defp items(state, :current) do
    case Layout.current_row(state) do
      %{kind: :item, item: item} -> [item.id]
      _ -> []
    end
  end

  defp items(state, :section) do
    case Layout.current_row(state) do
      %{sidx: sidx} ->
        for %{kind: :item, sidx: ^sidx} = r <- Layout.rows(state), uniq: true, do: r.item.id

      _ ->
        []
    end
  end

  defp items(state, :view),
    do: for(%{kind: :item} = r <- Layout.rows(state), uniq: true, do: r.item.id)

  @impl Box
  def title(_state, _mode), do: "Execute"

  @impl Box
  def content(state, mode, inner, _max_rows) do
    Template.render(@layout, values(state, mode), selected: field(state, mode)) ++
      [[], Box.hint(keys(state, mode), inner)]
  end

  defp values(state, mode) do
    root =
      if mode.root == state.db.main_id,
        do: "MAIN (all categories)",
        else: state.db.categories[mode.root].name

    against =
      %{
        all: "All items",
        current: "Current item",
        marked: "Marked items",
        section: "Items in section",
        view: "Items in view"
      }[mode.against]

    %{
      root: root,
      against: against,
      actions: if(mode.old, do: "Old & new assignments", else: "New assignments only")
    }
  end

  @impl Box
  def keys(_state, _mode),
    do: [
      {"↑↓←→", "Setting", "Move between settings"},
      {"SPACE", "Change", "Change the setting"},
      {"ENTER", "Run"},
      {"ESC", "Cancel"}
    ]

  @impl Box
  def help, do: @help

  @impl Box
  def field(_state, mode), do: Enum.at(@rows, mode.cursor)
end
