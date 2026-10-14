defmodule Agendum.TUI.ExecuteBox do
  @moduledoc """
  Utilities Execute (SPEC R15e; User's Guide 20-19 to 20-21, 21-17):
  applies conditions, text conditions and actions to items that were in
  the file before those were set.

  The Execute box (Category ▸ Execute) has three settings: Apply conditions
  of (a category and its children; MAIN for all, ENTER opens the category
  box), Against (all items, the current item, the marked items, the items
  in the section or in the view) and Apply actions to (new assignments
  only, or old and new). SPACE changes a setting (on the first row: picks
  the category); the arrows move; ENTER runs it, ESC
  cancels. ALT-X runs everything on all items; ALT-E runs the highlighted
  category's family on all items. Pure.
  """

  import Agendum.TUI.BoxNav, only: [is_move: 1]
  alias Agendum.TUI.BoxNav

  alias Agendum.Core
  alias Agendum.TUI.{CategoryScreens, Layout, State}

  @rows [:root, :against, :actions]
  @against [:all, :current, :marked, :section, :view]

  def rows, do: @rows

  def open(state),
    do:
      State.push(state, %{
        type: :execute,
        root: state.db.main_id,
        against: :all,
        old: false,
        cursor: 0
      })

  def handle(state, mode, key) do
    row = Enum.at(@rows, mode.cursor)

    case key do
      :esc ->
        State.pop(state)

      :enter ->
        state |> State.pop() |> run(mode.root, mode.against, mode.old)

      k when is_move(k) ->
        BoxNav.move(state, mode, BoxNav.column(@rows), k)

      {:char, " "} when row == :root ->
        CategoryScreens.open_picker(state, :execute_root, nil)

      {:char, " "} when row == :against ->
        index = Enum.find_index(@against, &(&1 == mode.against))
        State.put_mode(state, %{mode | against: Enum.at(@against, Integer.mod(index + 1, 5))})

      {:char, " "} when row == :actions ->
        State.put_mode(state, %{mode | old: not mode.old})

      _ ->
        state
    end
  end

  @doc "Sets the category whose conditions apply (from the category box)."
  def set_root(state, cat_id), do: State.put_mode(state, %{State.mode(state) | root: cat_id})

  @doc "Runs Execute from the view: `root`'s family on the chosen items."
  def run(state, root, against, old \\ false) do
    ids = items(state, against)

    db =
      Core.execute(state.db, ids,
        root: root,
        old_assignments: old,
        clock: State.context(state)
      )

    what =
      if root == state.db.main_id,
        do: "",
        else: state.db.categories[root].name <> " "

    state
    |> State.change_db(db)
    |> State.info("Executed #{what}for #{Agendum.TUI.Draw.count(length(ids), "item")}")
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

  @doc "`{label, value}` for each row."
  def lines(state, mode) do
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

    [
      {"Apply conditions of", root},
      {"Against", against},
      {"Apply actions to",
       if(mode.old, do: "Old & new assignments", else: "New assignments only")}
    ]
  end

  @doc "The highlighted field, for its help in the control panel (`Agendum.TUI.FieldHelp`)."
  def field(_state, mode), do: Enum.at(@rows, mode.cursor)
end
