defmodule Agendum.TUI.Boxes.ChoiceListBox do
  @moduledoc """
  F3 (CHOICES) on a setting of a box (User's Guide 2-17,
  `Agendum.TUI.Boxes.BoxChoices`): its choices, one a line, the current one
  first. ↑↓ (or ← →) choose, HOME / END the first / last; ENTER takes the
  highlighted one (as that many presses of SPACE, one change), ESC leaves
  the setting as it was. Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :accept, indicator: "CHOICES"

  alias Agendum.TUI.Boxes.{Box, BoxChoices}
  alias Agendum.TUI.State

  @doc "Opens the list of `labels`, for the setting called `title`."
  def open(state, labels, title),
    do: State.push(state, %{type: :choice_list, labels: labels, title: title, cursor: 0})

  @impl Box
  def handle(state, mode, key) do
    last = length(mode.labels) - 1

    case key do
      :esc ->
        State.pop(state)

      :enter ->
        state |> State.pop() |> BoxChoices.choose(mode.cursor)

      k when k in [:up, :left] ->
        State.put_mode(state, %{mode | cursor: max(mode.cursor - 1, 0)})

      k when k in [:down, :right] ->
        State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, last)})

      :home ->
        State.put_mode(state, %{mode | cursor: 0})

      :end ->
        State.put_mode(state, %{mode | cursor: last})

      _ ->
        state
    end
  end

  @impl Box
  def title(_state, %{title: ""}), do: "Choices"
  def title(_state, %{title: title}), do: "Choices: " <> title

  # a small box, as Agenda's
  @impl Box
  def width(state, _mode), do: min(state.width - 8, 32)

  @impl Box
  def content(_state, mode, _inner, max_rows) do
    top = max(mode.cursor - max_rows + 1, 0)

    mode.labels
    |> Enum.with_index()
    |> Enum.drop(top)
    |> Enum.take(max_rows)
    |> Enum.map(fn {label, i} ->
      [{:box, " "}, {if(i == mode.cursor, do: :box_selected, else: :box), label}]
    end)
  end

  @impl Box
  def keys(_state, _mode),
    do: [{"↑↓", "Highlight", "Highlight a choice"}, {"ENTER", "Select"}, {"ESC", "Cancel"}]

  @impl Box
  def help, do: "Highlight the choice and press ENTER."
end
