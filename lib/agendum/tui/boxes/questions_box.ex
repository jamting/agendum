defmodule Agendum.TUI.Boxes.QuestionsBox do
  @moduledoc """
  Utilities Questions (SPEC R16; User's Guide 19-12): with Confirm
  assignments set to Always, items that matched categories by their text
  wait here, one at a time, with the suggested categories. ↑↓ move, SPACE
  picks a category, TAB picks them all, ENTER assigns the picked ones and
  shows the next item, ESC stops (the rest stay suggested). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :none, indicator: nil

  alias Agendum.Core
  alias Agendum.TUI.Boxes.Box
  alias Agendum.TUI.State

  def open(state) do
    case Core.questions(state.db) do
      [] -> State.info(state, "No suggested assignments")
      [{item, _} | _] -> State.push(state, %{type: :questions, item: item, picked: [], cursor: 0})
    end
  end

  @doc "The suggested categories of the item shown."
  def suggestions(state, mode), do: Map.get(state.db.suggestions, mode.item, [])

  @impl Box
  def handle(state, _mode, _key), do: state

  # R65
  @impl Box
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
    db = Core.answer_question(state.db, mode.item, mode.picked, State.context(state))
    state |> State.pop() |> State.change_db(db) |> open_next()
  end

  def run(state, mode, id), do: Box.list_move(state, mode, length(suggestions(state, mode)), id)

  @impl Box
  def title(_state, _mode), do: "Suggested assignments"

  # the item, then its suggested categories, * before the picked ones
  @impl Box
  def content(state, mode, inner, _max_rows) do
    item = state.db.items[mode.item]

    cats =
      state
      |> suggestions(mode)
      |> Enum.with_index()
      |> Enum.map(fn {cat, i} ->
        mark = if cat in mode.picked, do: "*", else: " "

        [
          {:box, " #{mark} "},
          {if(i == mode.cursor, do: :box_selected, else: :box), state.db.categories[cat].name}
        ]
      end)

    [[{:box, " " <> String.slice(item.text, 0, inner - 2)}], [], [{:box, " Assign to:"}]] ++
      cats ++ [[], Box.hint(keys(state, mode), inner)]
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
