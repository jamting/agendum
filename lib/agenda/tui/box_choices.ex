defmodule Agenda.TUI.BoxChoices do
  @moduledoc """
  Choosing a setting's value in a box as Agenda (User's Guide 2-17): the
  first letter of a choice picks it (the next one starting with that
  letter), and F3 (CHOICES) lists the choices in a box of their own.

  A setting's choices are what SPACE goes through. Rather than each box
  listing them again, they are found by trying SPACE on the box, without
  keeping anything, and reading the highlighted value after each press,
  until it comes back to where it started. A setting is a list of choices
  only when SPACE changes it in place and comes back round: one where
  SPACE opens a box, asks a question or starts typing, or that only grows
  (a width), is not, and its keys go to the box as before.

  Picking a choice is SPACE pressed that many times, as one change (one
  undo step); preferences changed on the way are saved once. Pure.
  """

  alias Agenda.TUI.{BoxCancel, State}
  alias Agenda.TUI.Render.Boxes

  # the longest list of choices: Date format has 20
  @max 30

  # boxes with settings that SPACE cycles, besides those ESC cancels
  @boxes [:execute, :search_box, :range_filter, :action_box, :schedule, :column_add]

  @doc """
  A key on a box: a letter picks a choice, F3 lists them; `:pass` when the
  key or the setting is not for this.
  """
  @spec key(State.t(), term) :: State.t() | :pass
  def key(state, {:char, c}) do
    with true <- letter?(c),
         [_ | _] = choices <- choices(state) do
      pick(state, choices, c)
    else
      _ -> :pass
    end
  end

  def key(state, {:f, 3}) do
    case choices(state) do
      [_ | _] = choices ->
        labels = Enum.map(choices, &elem(&1, 0))
        title = Boxes.selected_name(state)
        State.push(state, %{type: :choice_list, labels: labels, title: title, cursor: 0})

      _ ->
        :pass
    end
  end

  def key(_state, _key), do: :pass

  @doc "A key in the list of choices: ↑↓ choose, ENTER takes it, ESC leaves it."
  @spec list_key(State.t(), map, term) :: State.t()
  def list_key(state, mode, key) do
    last = length(mode.labels) - 1

    case key do
      :esc ->
        State.pop(state)

      :enter ->
        state |> State.pop() |> press(mode.cursor)

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

  # a letter, in any alphabet (a digit is typed into a number instead)
  defp letter?(c), do: String.match?(c, ~r/^\p{L}$/u)

  # the next choice after the current one whose label starts with the letter
  defp pick(state, choices, c) do
    wanted = String.downcase(c)

    case Enum.find(tl(choices), fn {label, _} -> initial(label) == wanted end) do
      {_label, steps} -> press(state, steps)
      nil -> State.error(state, "No choice starts with #{String.upcase(c)}")
    end
  end

  # the label's first letter: "<Day> #" is under D, "(none)" under N
  defp initial(label) do
    case Regex.run(~r/\p{L}/u, label) do
      [l] -> String.downcase(l)
      nil -> nil
    end
  end

  @doc """
  The choices of the highlighted setting, `{label, presses}`, the current
  one first (0 presses); `[]` when the setting is not a list of choices.
  """
  @spec choices(State.t()) :: [{String.t(), non_neg_integer}]
  def choices(%State{edit: nil} = state) do
    case State.mode(state) do
      %{type: type} = mode when type != nil ->
        if cycles?(mode) and Map.get(mode, :typing) == nil,
          do: go_round(state, [{Boxes.selected_value(state), 0}], 1),
          else: []

      _ ->
        []
    end
  end

  def choices(_state), do: []

  defp cycles?(%{type: type}), do: BoxCancel.cancels?(type) or type in @boxes

  # SPACE once more from where the last press left it, until the first
  # label comes back; a press that leaves the box, or no change, ends it
  defp go_round(state, [{first, 0} | _] = found, n) do
    next = space(state, n)
    label = next && Boxes.selected_value(next)
    {last, _} = List.last(found)

    cond do
      next == nil or label == last -> []
      label == first -> found
      n >= @max -> []
      true -> go_round(state, found ++ [{label, n}], n + 1)
    end
  end

  # SPACE pressed n times on the box, or nil when that leaves the box (opens
  # another, asks, starts typing): those settings are not lists
  defp space(state, n) do
    Enum.reduce_while(1..n, state, fn _, s ->
      next = Agenda.TUI.Update.box_key(s, {:char, " "})

      if same_box?(s, next), do: {:cont, next}, else: {:halt, nil}
    end)
  end

  defp same_box?(before, after_) do
    length(after_.modes) == length(before.modes) and after_.edit == nil and
      State.mode(after_).type == State.mode(before).type and
      Map.get(State.mode(after_), :typing) == nil
  end

  # the choice `n` presses on, as one change; a preference saved once
  defp press(state, n) do
    pressed = space(state, n) || state
    {saves, others} = Enum.split_with(pressed.effects, &match?({:save_preferences, _, _}, &1))
    %{pressed | effects: others ++ Enum.take(saves, -1), message: nil}
  end
end
