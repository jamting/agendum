defmodule Agendum.TUI.Boxes.QuestionsBox do
  @moduledoc """
  Utilities Questions (SPEC R16; User's Guide 19-12): with Confirm
  assignments set to Always, items that matched categories by their text
  wait here, one at a time, with the suggested categories. ↑↓ move, SPACE
  picks a category, TAB picks them all, ENTER assigns the picked ones and
  shows the next item, ESC stops (the rest stay suggested).

  Drawn as Agenda's Questions box (checked in Agenda 2.0, 2026-10-25):
  'Suggested categories for "the item"', then each category as
  Parent:Child, ? before it until it is picked (*); "Press ENTER to
  accept" in the bottom edge. With none waiting, the box says so and any
  key closes it. Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :enter_accept

  alias Agendum.Core
  alias Agendum.TUI.Boxes.Box
  alias Agendum.TUI.State

  def open(state) do
    case Core.questions(state.db) do
      # Agenda's box saying there are none (`item: nil`)
      [] ->
        State.push(state, %Agendum.TUI.Modes.Questions{item: nil, picked: [], cursor: 0})

      [{item, _} | _] ->
        State.push(state, %Agendum.TUI.Modes.Questions{item: item, picked: [], cursor: 0})
    end
  end

  @doc "The suggested categories of the item shown."
  def suggestions(state, mode), do: Map.get(state.db.suggestions, mode.item, [])

  # with none waiting, any key closes the box
  @impl Box
  def handle(state, %{item: nil}, _key), do: State.pop(state)
  def handle(state, _mode, _key), do: state

  @impl Box
  def finish(%{item: nil}), do: :any_key
  def finish(_mode), do: :enter_accept

  @impl Box
  def about(_state, _mode) do
    """
    Agendum found categories that may fit the item's text, and asks before
    assigning it to them.

    SPACE picks or unpicks the highlighted category, TAB picks them all.
    ENTER assigns the item to the ones picked. ESC asks again later.
    """
  end

  # R65; with none waiting, every key goes to `handle/3`
  @impl Box
  def keymap(%{item: nil}), do: %{}

  def keymap(_mode) do
    %{
      :up => :up,
      :down => :down,
      {:char, " "} => :pick,
      :tab => :pick_all,
      :enter => :done,
      :esc => :close
    }
  end

  @impl Box
  def commands(_mode) do
    [
      {:pick, "Pick", "Pick or unpick the category"},
      {:pick_all, "Pick all", "Pick every category"},
      {:done, "Done", "Assign the picked ones"}
    ] ++ Enum.take(Box.list_moves(), 2) ++ [{:close, "Later", "Close; ask again later"}]
  end

  @impl Box
  def run(state, _mode, :close), do: State.pop(state)

  def run(state, mode, :pick) do
    cat = Enum.at(suggestions(state, mode), mode.cursor)
    picked = if cat in mode.picked, do: List.delete(mode.picked, cat), else: mode.picked ++ [cat]
    State.put_mode(state, %{mode | picked: picked})
  end

  def run(state, mode, :pick_all),
    do: State.put_mode(state, %{mode | picked: suggestions(state, mode)})

  def run(state, mode, :done) do
    state |> State.pop() |> State.run({:answer_question, mode.item, mode.picked}) |> open_next()
  end

  def run(state, mode, id), do: Box.list_move(state, mode, length(suggestions(state, mode)), id)

  @impl Box
  def title(_state, _mode), do: "Questions"

  @impl Box
  def content(_state, %{item: nil}, _inner, _max_rows),
    do: [[], [{:box, " There are no assignments to be confirmed."}], []]

  # the item, then its suggested categories: ? before each, * once picked
  def content(state, mode, inner, _max_rows) do
    item = state.db.items[mode.item]
    head = ~s(Suggested categories for "#{item.text}")

    cats =
      state
      |> suggestions(mode)
      |> Enum.with_index()
      |> Enum.map(fn {cat, i} ->
        mark = if cat in mode.picked, do: " * ", else: "  ?"

        [
          {:box, mark <> "│  "},
          {if(i == mode.cursor, do: :box_selected, else: :box), qualified(state.db, cat)}
        ]
      end)

    [[{:box, String.slice(head, 0, inner)}]] ++ cats ++ [[{:box, "   │"}]]
  end

  # "Contact:Anna Lasky", as Agenda names a suggestion; a category right
  # under MAIN goes by its name alone (Agenda's form for it is unchecked)
  defp qualified(db, id) do
    cat = db.categories[id]

    case cat.parent_id do
      parent when parent in [nil, db.main_id] -> cat.name
      parent -> db.categories[parent].name <> ":" <> cat.name
    end
  end

  @impl Box
  def keys(_state, _mode),
    do: [
      {"SPACE", "Pick", "Pick a suggestion"},
      {"TAB", "All", "Pick all"},
      {"ENTER", "Assign", "Assign the picked"},
      {"ESC", "Stop"}
    ]

  @impl Box
  def help,
    do:
      "Pick the categories to assign the item to: SPACE one, TAB all. " <>
        "ENTER assigns them and shows the next item."

  defp open_next(state) do
    case Core.questions(state.db) do
      [] -> State.info(state, "All suggested assignments answered")
      _ -> open(state)
    end
  end
end
