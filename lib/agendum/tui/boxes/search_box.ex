defmodule Agendum.TUI.Boxes.SearchBox do
  @moduledoc """
  Searching (SPEC R37; User's Guide 15-1 to 15-5).

  The Search box asks what to search for, where (item text, note text or
  both), in which direction (forward, backward, from the beginning; view
  search only) and whether to ignore case. Typing goes into the text; ↑↓
  or TAB move between settings (← → too, off the text) and SPACE changes
  them; ENTER starts.

  Searching the view highlights the first match and enters search mode:
  ALT-N / ALT-P go to the next / previous match, F7 marks the highlighted
  item, ENTER or ESC ends. Searching the file fills the Show View.
  The matching rules are `Agendum.Core.Search`. The box is drawn from
  `@layout` (`Agendum.TUI.Boxes.Template`). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, indicator: "SEARCH", choices: true

  alias Agendum.Core
  alias Agendum.Core.Search
  alias Agendum.TUI.Boxes.{Box, Template}
  alias Agendum.TUI.{Keymap, Layout, Typing.LineEdit, State}

  # Direction only when searching the view
  @layout """
   Search for  : [text                                        ]
   Match on    : [on                                          ]
   Direction   : [direction                                   ]
   Ignore case : [ignore_case                                 ]

   Pat* finds Pat, Patty… · (a phrase)
  """

  @help %{
    text: "Type the text to search for. Pat* finds Pat and Patty. ENTER searches.",
    on: "Choose whether to search the item text, the note, or both. SPACE changes it.",
    direction: "Search forward, backward, or from the beginning of the view. SPACE changes it.",
    ignore_case: "Whether capital and small letters match alike. SPACE switches."
  }

  @directions [:forward, :backward, :beginning]
  @ons [:item, :note, :both]

  def open(state, scope) do
    search = state.searches.view || %Search{}

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

  @impl Box
  # On the text the person types: ← → HOME END move in it, other keys
  # edit it; ↑ ↓ TAB still move between settings, ENTER and ESC end.
  def handle(state, mode, key) when key in [:up, :down, :tab, :shift_tab, :enter, :esc],
    do: run(state, mode, Map.fetch!(keymap(mode), key))

  def handle(state, mode, key), do: edit_text(state, mode, key)

  @impl Box
  def typing?(_state, mode), do: Enum.at(rows(mode), mode.cursor) == :text

  # the settings box's keys; ENTER searches (R65)
  @impl Box
  def keymap(_mode), do: Box.settings_keymap()

  @impl Box
  def commands(_mode),
    do:
      Box.settings_commands([
        {:done, "Search", "Search for the text"},
        {:close, "Cancel", "Close without searching"}
      ])

  @impl Box
  def run(state, mode, :done),
    do: start(State.pop(state), %{mode | search: %{mode.search | text: mode.line.text}})

  def run(state, mode, :change) do
    case Enum.at(rows(mode), mode.cursor) do
      :text -> state
      row -> State.put_mode(state, change(mode, row, 1))
    end
  end

  def run(state, mode, id),
    do: Box.run_settings(state, mode, Template.grid(@layout, rows(mode)), id)

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
    state = %{state | searches: %{state.searches | view: search}}

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
  def searching_key(state, mode, key, _view_key) do
    case Keymap.lookup(:searching, key) do
      nil -> state
      id -> searching(state, mode, id)
    end
  end

  @doc "F1's text while searching the view (R65)."
  @spec about_searching() :: String.t()
  def about_searching do
    """
    You are searching the view. ALT-N or F8 goes to the next match, ALT-P
    to the one before; F7 marks the highlighted item, so the matches can be
    worked on together.

    ENTER or ESC ends the search.
    """
  end

  @doc "Runs a command while searching the view (`Agendum.TUI.Commands`)."
  @spec run_searching(State.t(), atom) :: State.t()
  def run_searching(state, id), do: searching(state, State.mode(state), id)

  defp searching(state, mode, :next_match), do: step(state, mode.search, 1)
  defp searching(state, mode, :previous_match), do: step(state, mode.search, -1)
  defp searching(state, _mode, :mark), do: mark_current(state)
  defp searching(state, _mode, :close), do: state |> State.pop() |> State.info("Search ended")
  defp searching(state, _mode, :help), do: Agendum.TUI.HelpScreen.open(state)
  # the highlight moves as in the view
  defp searching(state, _mode, id), do: Agendum.TUI.Update.ViewKeys.run(state, id)

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
      %{kind: :item, item: item} -> State.run(state, {:toggle_mark, item.id})
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

  # --- the box -------------------------------------------------------------------

  @impl Box
  def title(_state, %{scope: :view}), do: "Search this view"
  def title(_state, %{scope: :file}), do: "Search the whole file (Show View)"

  @impl Box
  def content(state, mode, inner, _max_rows) do
    values = %{
      # the text is always typed in, so it is drawn as the input line
      text: "",
      on: %{item: "Item text", note: "Note text", both: "Both item & note"}[mode.search.on],
      # nil leaves the row out: searching the file has no direction
      direction:
        if(mode.scope == :view,
          do:
            %{forward: "Forward", backward: "Backward", beginning: "Search from beginning"}[
              mode.direction
            ]
        ),
      ignore_case: if(mode.search.ignore_case, do: "Yes", else: "No")
    }

    Template.render(@layout, values, selected: field(state, mode), editing: {:text, mode.line}) ++
      [Box.hint(keys(state, mode), inner)]
  end

  @impl Box
  def keys(_state, _mode),
    do: [
      {"ENTER", "Search"},
      {"TAB/↓", "Next setting"},
      {"SPACE", "Change", "Change the setting"},
      {"ESC", "Cancel"}
    ]

  @impl Box
  def help, do: @help

  @impl Box
  def field(_state, mode), do: Enum.at(rows(mode), mode.cursor)
end
