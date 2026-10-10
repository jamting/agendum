defmodule Agenda.TUI.SearchBox do
  @moduledoc """
  Searching (SPEC R37; User's Guide 15-1 to 15-5).

  The Search box asks what to search for, where (item text, note text or
  both), in which direction (forward, backward, from the beginning; view
  search only) and whether to ignore case. Typing goes into the text; ↑↓
  or TAB move between settings and SPACE or ←→ change them; ENTER starts.

  Searching the view highlights the first match and enters search mode:
  ALT-N / ALT-P go to the next / previous match, F7 marks the highlighted
  item, ENTER or ESC ends. Searching the file fills the Show View.
  The matching rules are `Agenda.Core.Search`. Pure.
  """

  alias Agenda.Core
  alias Agenda.Core.Search
  alias Agenda.TUI.{Layout, LineEdit, State}

  @directions [:forward, :backward, :beginning]
  @ons [:item, :note, :both]

  def open(state, scope) do
    search = state.last_search || %Search{}

    State.push(state, %{
      type: :search_box,
      scope: scope,
      search: search,
      direction: :forward,
      line: LineEdit.new(search.text),
      cursor: 0
    })
  end

  @doc "The settings rows for a scope."
  def rows(%{scope: :view}), do: [:text, :on, :direction, :ignore_case]
  def rows(%{scope: :file}), do: [:text, :on, :ignore_case]

  def handle(state, mode, key) do
    rows = rows(mode)
    row = Enum.at(rows, mode.cursor)

    case key do
      :esc ->
        State.pop(state)

      :enter ->
        start(State.pop(state), %{mode | search: %{mode.search | text: mode.line.text}})

      k when k in [:down, :tab] ->
        State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, length(rows) - 1)})

      k when k in [:up, :shift_tab] ->
        State.put_mode(state, %{mode | cursor: max(mode.cursor - 1, 0)})

      k when row != :text and k in [{:char, " "}, :right] ->
        State.put_mode(state, change(mode, row, 1))

      :left when row != :text ->
        State.put_mode(state, change(mode, row, -1))

      _ when row == :text ->
        edit_text(state, mode, key)

      _ ->
        state
    end
  end

  defp edit_text(state, mode, key) do
    case LineEdit.handle(mode.line, key) do
      {:ok, line} -> State.put_mode(state, %{mode | line: line})
      :unhandled -> state
    end
  end

  defp change(mode, :on, step), do: put_in(mode.search.on, cycle(@ons, mode.search.on, step))

  defp change(mode, :direction, step),
    do: %{mode | direction: cycle(@directions, mode.direction, step)}

  defp change(mode, :ignore_case, _step),
    do: put_in(mode.search.ignore_case, not mode.search.ignore_case)

  defp cycle(list, value, step) do
    index = Enum.find_index(list, &(&1 == value))
    Enum.at(list, Integer.mod(index + step, length(list)))
  end

  # --- running a search ---------------------------------------------------------

  defp start(state, %{search: search} = mode) do
    state = %{state | last_search: search}

    cond do
      String.trim(search.text) == "" -> State.error(state, "Type what to search for")
      mode.scope == :file -> show_match(state, search)
      true -> first_match(state, search, mode.direction)
    end
  end

  defp show_match(state, search) do
    {db, view_id} = Core.show_match(state.db, search)
    state = state |> State.change_db(db) |> State.switch_view(view_id)
    count = state |> Layout.rows() |> Enum.count(&(&1.kind == :item))

    State.info(
      state,
      "#{count} item(s) contain \"#{String.trim(search.text)}\" · ALT-F8 returns to the last view"
    )
  end

  defp first_match(state, search, direction) do
    found = matches(state, search)

    index =
      case direction do
        :forward -> Enum.find(found, &(&1 >= state.cursor))
        :backward -> found |> Enum.reverse() |> Enum.find(&(&1 <= state.cursor))
        :beginning -> List.first(found)
      end

    if index do
      state
      |> State.push(%{type: :searching, search: search})
      |> Layout.move_to(index)
      |> report(found, index)
    else
      State.error(state, "No item in this view contains \"#{String.trim(search.text)}\"")
    end
  end

  @doc "Keys while searching: next / previous match, mark, end."
  def searching_key(state, mode, key, view_key) do
    case key do
      k when k in [{:alt, "n"}, {:f, 8}] ->
        step(state, mode.search, 1)

      {:alt, "p"} ->
        step(state, mode.search, -1)

      {:f, 7} ->
        mark_current(state)

      k when k in [:enter, :esc] ->
        state |> State.pop() |> State.info("Search ended")

      k when k in [:up, :down, :pgup, :pgdn, :home, :end, :ctrl_pgup, :ctrl_pgdn] ->
        view_key.(state, k)

      _ ->
        state
    end
  end

  defp step(state, search, direction) do
    found = matches(state, search)

    candidates =
      if direction > 0,
        do: Enum.filter(found, &(&1 > state.cursor)),
        else: found |> Enum.filter(&(&1 < state.cursor)) |> Enum.reverse()

    case candidates do
      [index | _] -> state |> Layout.move_to(index) |> report(found, index)
      [] when direction > 0 -> State.error(state, "No more matches after this one")
      [] -> State.error(state, "No more matches before this one")
    end
  end

  defp mark_current(state) do
    case Layout.current_row(state) do
      %{kind: :item, item: item} -> State.change_db(state, Core.toggle_mark(state.db, item.id))
      _ -> state
    end
  end

  # Row indices of the view's items that match.
  defp matches(state, search) do
    state
    |> Layout.rows()
    |> Enum.with_index()
    |> Enum.filter(fn {row, _} -> row.kind == :item and Search.matches?(row.item, search) end)
    |> Enum.map(&elem(&1, 1))
  end

  defp report(state, found, index) do
    position = Enum.find_index(found, &(&1 == index)) + 1

    State.info(
      state,
      "Match #{position} of #{length(found)} · ALT-N next · ALT-P previous · F7 mark · ENTER ends"
    )
  end
end
