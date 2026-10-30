# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Boxes.GoTo do
  @moduledoc """
  ALT-F5 (GO TO) in a view (SPEC R42; User's Guide 5-9): a box listing the
  view's section heads. ↑↓ or a letter (the next section starting with it)
  highlights one; ENTER highlights that section head in the view; ESC
  cancels. Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :accept

  alias Agendum.TUI.Boxes.Box
  alias Agendum.TUI.{Layout, State}

  def open(state) do
    current =
      case Layout.current_row(state) do
        %{sidx: sidx} -> Enum.find_index(sections(state), &(elem(&1, 0) == sidx)) || 0
        _ -> 0
      end

    State.push(state, %Agendum.TUI.Modes.Goto{cursor: current})
  end

  @doc "The names of the view's section heads, in the order shown."
  def names(state), do: Enum.map(sections(state), &elem(&1, 1))

  # {section index, name} of the sections shown, top to bottom.
  defp sections(state),
    do: for(%{kind: :section} = row <- Layout.rows(state), do: {row.sidx, row.category.name})

  @impl Box
  def about(_state, _mode) do
    """
    Go to a section: the view's sections in order. ↑ ↓ move, a letter goes
    to the next one starting with it. ENTER highlights it in the view; ESC
    goes back to where you were.
    """
  end

  @impl Box
  # a letter highlights the next section starting with it
  def handle(state, mode, {:char, c}),
    do: State.put_mode(state, %{mode | cursor: next_starting(state, mode.cursor, c)})

  def handle(state, _mode, _key), do: state

  # R65
  @impl Box
  def keymap(_mode) do
    %{:up => :up, :down => :down, :home => :first, :end => :last, :enter => :go, :esc => :close}
  end

  @impl Box
  def commands(_mode) do
    [{:go, "Go", "Highlight that section in the view"}] ++
      Box.list_moves() ++ [{:close, "Cancel", "Back to where you were"}]
  end

  @impl Box
  def run(state, _mode, :close), do: State.pop(state)

  def run(state, mode, :go) do
    if names(state) == [], do: state, else: state |> State.pop() |> go(mode.cursor)
  end

  def run(state, mode, id), do: Box.list_move(state, mode, length(names(state)), id)

  # The next section after `from` (wrapping) whose name starts with `letter`.
  defp next_starting(state, from, letter) do
    names = names(state)
    count = length(names)
    wanted = String.downcase(letter)

    Enum.find(1..count//1, fn step ->
      names
      |> Enum.at(rem(from + step, count))
      |> String.downcase()
      |> String.starts_with?(wanted)
    end)
    |> case do
      nil -> from
      step -> rem(from + step, count)
    end
  end

  @impl Box
  def title(_state, _mode), do: "Go to section"

  @impl Box
  def content(state, mode, _inner, max_rows) do
    top = max(mode.cursor - max_rows + 1, 0)

    state
    |> names()
    |> Enum.with_index()
    |> Enum.drop(top)
    |> Enum.take(max_rows)
    |> Enum.map(fn {name, i} ->
      [{:box, " "}, {if(i == mode.cursor, do: :box_selected, else: :box), name}]
    end)
  end

  @impl Box
  def keys(_state, _mode),
    do: [
      {"↑↓", "Highlight", "Highlight a section"},
      {"letter", "Next starting with it"},
      {"ENTER", "Go"},
      {"ESC", "Cancel"}
    ]

  @impl Box
  def help, do: "Highlight the section to go to and press ENTER, or type its first letter."

  defp go(state, position) do
    {sidx, _name} = Enum.at(sections(state), position)

    index =
      state
      |> Layout.rows()
      |> Enum.find_index(&(&1.kind == :section and &1.sidx == sidx))

    if index, do: Layout.move_to(state, index), else: state
  end
end
