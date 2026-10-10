defmodule Agenda.TUI.QuestionsBox do
  @moduledoc """
  Utilities Questions (SPEC R16; User's Guide 19-12): with Confirm
  assignments set to Always, items that matched categories by their text
  wait here, one at a time, with the suggested categories. ↑↓ move, SPACE
  picks a category, TAB picks them all, ENTER assigns the picked ones and
  shows the next item, ESC stops (the rest stay suggested). Pure.
  """

  alias Agenda.Core
  alias Agenda.TUI.State

  def open(state) do
    case Core.questions(state.db) do
      [] -> State.info(state, "No suggested assignments")
      [{item, _} | _] -> State.push(state, %{type: :questions, item: item, picked: [], cursor: 0})
    end
  end

  @doc "The suggested categories of the item shown."
  def suggestions(state, mode), do: Map.get(state.db.suggestions, mode.item, [])

  def handle(state, mode, key) do
    cats = suggestions(state, mode)

    case key do
      :esc ->
        State.pop(state)

      :up ->
        State.put_mode(state, %{mode | cursor: max(mode.cursor - 1, 0)})

      :down ->
        State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, length(cats) - 1)})

      {:char, " "} ->
        cat = Enum.at(cats, mode.cursor)

        picked =
          if cat in mode.picked, do: List.delete(mode.picked, cat), else: mode.picked ++ [cat]

        State.put_mode(state, %{mode | picked: picked})

      :tab ->
        State.put_mode(state, %{mode | picked: cats})

      :enter ->
        db = Core.answer_question(state.db, mode.item, mode.picked, State.context(state))
        state |> State.pop() |> State.change_db(db) |> open_next()

      _ ->
        state
    end
  end

  defp open_next(state) do
    case Core.questions(state.db) do
      [] -> State.info(state, "All suggested assignments answered")
      _ -> open(state)
    end
  end
end
