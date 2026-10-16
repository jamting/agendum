defmodule Agendum.TUI.Boxes.ViewManager do
  @moduledoc """
  The view manager (F8): switch between, add, rename and discard views. A
  box over the view, as Agenda's (screenshot 40).

  Typing highlights a view (R53; User's Guide 9-5, Starter Applications
  1-10): the first letter the next view starting with it, round the list;
  more letters narrow it down; BACKSPACE takes one back. A letter that
  fits no view starts again from it, so the same letter again goes on to
  the next view with it. Moving forgets what was typed. Other keys run
  commands through the view manager's keymap (R65).

  F5 lists the views by when they were last shown instead, the view shown
  first, and back (R68; meeting 2026-10-16, § 8): only the list changes,
  not the file's order, which ALT-N, ALT-P and hop keep to. Moving and
  sorting the views wait for the person's own order.
  """

  # ENTER shows the view, ESC goes back to the one shown, as in Agenda
  use Agendum.TUI.Boxes.Box, finish: :done, indicator: "VW MGR"

  alias Agendum.Core.Database
  alias Agendum.TUI.{Boxes.Box, Keymap, Terminal.Draw, Typing.LineEdit, State}
  alias Agendum.TUI.Update.Prompts

  def open(state) do
    index = Enum.find_index(order(state), &(&1 == state.view_id)) || 0
    State.push(state, %Agendum.TUI.Modes.Viewmgr{cursor: index, typed: "", from: index})
  end

  @impl Box
  def handle(%State{edit: edit} = state, _mode, key) when edit != nil do
    case key do
      :esc ->
        %{state | edit: nil}

      :enter ->
        name = String.trim(edit.line.text)
        state = %{state | edit: nil}

        if name == "",
          do: state,
          else: State.run(state, {:rename_view, edit.target, name})

      _ ->
        case LineEdit.handle(edit.line, key) do
          {:ok, line} -> %{state | edit: %{edit | line: line}}
          :unhandled -> state
        end
    end
  end

  def handle(state, mode, {:char, c}), do: find(state, mode, mode.typed <> c, c)

  def handle(state, %{typed: typed} = mode, :backspace) when typed != "",
    do: find(state, mode, String.slice(typed, 0..-2//1), nil)

  # any other key runs the command the view manager's keymap binds it to
  # (`Agendum.TUI.Keymap`, R65)
  def handle(state, _mode, key) do
    case Keymap.lookup(:viewmgr, key) do
      nil -> clamp(state)
      id -> run(state, id)
    end
  end

  @doc "F1's text in the view manager (R65)."
  @spec about() :: String.t()
  def about do
    """
    The view manager lists the file's views; ► marks the one shown. ENTER
    shows the highlighted one; type the start of a name to find it.

    INS adds a view, F2 renames one, DEL (or F4) discards one: its items
    stay in the file. ALT-↑ and ALT-↓ move a view in the list, ALT-F5 sorts
    them by name. F5 lists them by when you last used them, and back: the
    order of the file stays as it is.

    ESC or F8 goes back to the view you were in.
    """
  end

  @doc "Runs a view manager command (`Agendum.TUI.Commands`) on the highlighted view."
  @spec run(State.t(), atom) :: State.t()
  def run(state, command) do
    state = clamp(state)
    mode = State.mode(state)
    command(state, mode, command, Enum.at(order(state), mode.cursor))
  end

  @doc """
  The views as the view manager lists them: the file's order, or, with
  `state.views.by_recent`, the views last shown first (the one shown now at the
  top), then the others in the file's order (R68).
  """
  @spec order(State.t()) :: [Database.id()]
  def order(%State{views: %{by_recent: false}} = state), do: state.db.view_order

  def order(state) do
    # a view used once but discarded since is left out (`--` takes away)
    used = Enum.uniq([state.view_id | state.views.recent])
    recent = Enum.filter(used, &Map.has_key?(state.db.views, &1))
    recent ++ (state.db.view_order -- recent)
  end

  @recent_order "Listed by recently used: F5 shows your order"

  @doc """
  The view manager's commands that cannot run on the highlighted view,
  each with why (R65a): F1 `c` greys them.
  """
  @spec unavailable(State.t()) :: %{atom => String.t()}
  def unavailable(state) do
    cursor = State.mode(clamp(state)).cursor
    last = length(state.db.view_order) - 1
    recent = state.views.by_recent && @recent_order

    [
      move_up: recent || (cursor == 0 && "Already the first view"),
      move_down: recent || (cursor == last && "Already the last view"),
      sort: recent,
      discard: last == 0 && "A file must have at least one view"
    ]
    |> Enum.filter(fn {_id, reason} -> is_binary(reason) end)
    |> Map.new()
  end

  # undo can remove views while the manager is open; any key but a letter
  # forgets what was typed
  defp clamp(state) do
    mode = State.mode(state)
    count = length(order(state))
    State.put_mode(state, %{mode | cursor: min(mode.cursor, count - 1), typed: ""})
  end

  defp command(state, _mode, :close, _view_id), do: State.pop(state)
  defp command(state, _mode, :help, _view_id), do: Agendum.TUI.HelpScreen.open(state)

  defp command(state, mode, :up, _),
    do: State.put_mode(state, %{mode | cursor: max(mode.cursor - 1, 0)})

  defp command(state, mode, :down, _) do
    last = length(state.db.view_order) - 1
    State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, last)})
  end

  defp command(state, mode, :first, _), do: State.put_mode(state, %{mode | cursor: 0})

  defp command(state, mode, :last, _),
    do: State.put_mode(state, %{mode | cursor: length(state.db.view_order) - 1})

  defp command(state, _mode, :show, view_id),
    do: state |> State.pop() |> State.switch_view(view_id)

  defp command(state, _mode, :add, _), do: Prompts.prompt(state, "Name of new view:", :add_view)

  defp command(state, _mode, :rename, view_id),
    do: %{state | edit: %{target: view_id, line: LineEdit.new(state.db.views[view_id].name)}}

  # the order of the file is the person's to change, so not while the
  # list shows another one
  defp command(%State{views: %{by_recent: true}} = state, _mode, id, _)
       when id in [:sort, :move_up, :move_down],
       do: State.error(state, @recent_order)

  defp command(state, mode, :sort, _),
    do: state |> State.run(:sort_views) |> State.put_mode(%{mode | cursor: 0})

  defp command(state, mode, :move_up, _), do: reorder(state, mode, -1)
  defp command(state, mode, :move_down, _), do: reorder(state, mode, 1)

  # F5: the other order, the highlight staying on its view; kept with
  # where the person left the file, and saved at once (`Update` saves the
  # preferences when the place changes)
  defp command(state, mode, :order, view_id) do
    state = put_in(state.views.by_recent, not state.views.by_recent)
    cursor = Enum.find_index(order(state), &(&1 == view_id)) || 0

    state
    |> State.put_mode(%{mode | cursor: cursor})
    |> Agendum.TUI.Places.remember()
  end

  defp command(state, _mode, :discard, view_id) do
    Prompts.confirm(
      state,
      "Discard view #{state.db.views[view_id].name}? Items are kept.",
      {:discard_view, view_id}
    )
  end

  # highlights the first view after `from` whose name starts with `typed`;
  # failing that, starts again from the letter just typed
  defp find(state, mode, typed, letter) do
    from = if mode.typed == "", do: mode.cursor, else: mode.from

    case {typed, match(state, from, typed), letter && match(state, mode.cursor, letter)} do
      {"", _, _} ->
        State.put_mode(state, %{mode | typed: "", cursor: from})

      {_, i, _} when i != nil ->
        State.put_mode(state, %{mode | typed: typed, from: from, cursor: i})

      {_, nil, i} when i != nil ->
        State.put_mode(state, %{mode | typed: letter, from: mode.cursor, cursor: i})

      _ ->
        state
    end
  end

  defp match(state, from, typed) do
    order = order(state)
    count = length(order)
    typed = String.downcase(typed)

    Enum.find(Enum.map(1..count//1, &rem(from + &1, count)), fn i ->
      state.db.views[Enum.at(order, i)].name |> String.downcase() |> String.starts_with?(typed)
    end)
  end

  defp reorder(state, mode, delta) do
    order = state.db.view_order
    target = mode.cursor + delta

    if target < 0 or target >= length(order) do
      state
    else
      state
      |> State.run({:move_view, Enum.at(order, mode.cursor), target})
      |> State.put_mode(%{mode | cursor: target})
    end
  end

  @impl Box
  def title(%State{views: %{by_recent: true}}, _mode), do: "View Manager: recently used"
  def title(_state, _mode), do: "View Manager"

  @impl Box
  def width(state, _mode), do: min(state.width - 8, 50)

  # Agenda's (screenshot 40): the views' names in order, * before a
  # datebook view (R47), ► before the view shown (ours, R68), the name being renamed as an input line; an arrow
  # at the left where the list goes on above or below, and what was typed
  # to find a view
  @impl Box
  def content(state, mode, inner, max_rows) do
    views = Enum.map(order(state), &state.db.views[&1])
    find = if mode.typed == "", do: [], else: [[], [{:dim, " Find: " <> mode.typed}]]
    rows = max(max_rows - length(find), 1)
    top = mode.cursor |> Kernel.-(rows - 1) |> max(0)
    shown = views |> Enum.with_index() |> Enum.drop(top) |> Enum.take(rows)
    last = top + length(shown) - 1

    lines =
      Enum.map(shown, fn {v, i} ->
        arrow =
          cond do
            i == top and top > 0 -> "↑"
            i == last and last < length(views) - 1 -> "↓"
            true -> " "
          end

        # the view shown keeps its marker wherever the highlight goes (R68)
        current = if v.id == state.view_id, do: "►", else: " "
        star = if v.datebook, do: "*", else: " "

        name =
          case state.edit do
            %{target: id} when id == v.id -> Draw.input(state.edit.line, inner - 7, :edit)
            _ -> [{if(i == mode.cursor, do: :box_selected, else: :box), v.name}]
          end

        [{:box, " #{arrow} #{current}#{star} "}] ++ name
      end)

    lines ++ find
  end

  @impl Box
  def keys(state, _mode),
    do: [
      {"ENTER", "Select", "Show the view"},
      {"INS", "Add", "Add a view"},
      {"F2", "Rename"},
      {"DEL/F4", "Discard"},
      if(state.views.by_recent, do: {"F5", "Your order"}, else: {"F5", "Recent"}),
      {"A-↑↓", "Reorder", "ALT-↑↓", "Reorder"},
      {"ESC", "Return", "Back to the view"}
    ]

  @impl Box
  def help,
    do:
      "To display a view, highlight the view name and press ENTER. " <>
        "Press INS to create a new view."
end
