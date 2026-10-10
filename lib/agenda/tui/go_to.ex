defmodule Agenda.TUI.GoTo do
  @moduledoc """
  ALT-F5 (GO TO) in a view (SPEC R42; User's Guide 5-9): a box listing the
  view's section heads. ↑↓ or a letter (the next section starting with it)
  highlights one; ENTER highlights that section head in the view; ESC
  cancels. Pure.
  """

  alias Agenda.TUI.{Layout, State}

  def open(state) do
    current =
      case Layout.current_row(state) do
        %{sidx: sidx} -> Enum.find_index(sections(state), &(elem(&1, 0) == sidx)) || 0
        _ -> 0
      end

    State.push(state, %{type: :goto, cursor: current})
  end

  @doc "The names of the view's section heads, in the order shown."
  def names(state), do: Enum.map(sections(state), &elem(&1, 1))

  # {section index, name} of the sections shown, top to bottom.
  defp sections(state),
    do: for(%{kind: :section} = row <- Layout.rows(state), do: {row.sidx, row.category.name})

  def handle(state, mode, key) do
    count = length(names(state))

    case key do
      :esc -> State.pop(state)
      :enter when count > 0 -> state |> State.pop() |> go(mode.cursor)
      :up -> State.put_mode(state, %{mode | cursor: max(mode.cursor - 1, 0)})
      :down -> State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, count - 1)})
      :home -> State.put_mode(state, %{mode | cursor: 0})
      :end -> State.put_mode(state, %{mode | cursor: count - 1})
      {:char, c} -> State.put_mode(state, %{mode | cursor: next_starting(state, mode.cursor, c)})
      _ -> state
    end
  end

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

  defp go(state, position) do
    {sidx, _name} = Enum.at(sections(state), position)

    index =
      state
      |> Layout.rows()
      |> Enum.find_index(&(&1.kind == :section and &1.sidx == sidx))

    if index, do: Layout.move_to(state, index), else: state
  end
end
