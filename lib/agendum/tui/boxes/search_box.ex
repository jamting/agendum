# SPDX-License-Identifier: AGPL-3.0-only
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
  `@layouts` (`Agendum.TUI.Boxes.Template`), one for each scope, as
  Agenda's Search and Show Match boxes. Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, choices: true

  alias Agendum.Core.Search
  alias Agendum.TUI.Boxes.{Box, ErrorBox, FieldTyping, Template}
  alias Agendum.TUI.{Keymap, Layout, Typing.LineEdit, State, Update.Prompts}

  # Agenda's Search and Show Match boxes (checked in Agenda 2.0,
  # 2026-10-26): Show Match has no Direction, its row left blank
  @layouts %{
    view: """

       Search for:    [text                                        ]
       Match on:      [on                                          ]
       Direction:     [direction                                   ]
       Ignore case:   [ignore_case                                 ]

    """,
    file: """

       Search for:    [text                                        ]
       Match on:      [on                                          ]

       Ignore case:   [ignore_case                                 ]

    """
  }

  # Agenda's help lines, field by field
  @help %{
    text: "Enter the text to search for.",
    on: "Press F3 to choose which text to search.",
    direction: "Choose the direction of the search from the position of the cursor.",
    ignore_case:
      "Choose whether to include matches if the use of upper/lowercase letters " <>
        "isn't the same as you typed in SEARCH FOR."
  }

  @directions [:forward, :backward, :beginning]
  @ons [:item, :note, :both]

  def open(state, scope) do
    search = state.searches.view || %Search{}

    State.push(state, %Agendum.TUI.Modes.SearchBox{
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
  # Search for is typed as Agenda's fields are (checked in Agenda 2.0,
  # 2026-10-26): a character starts typing over the text, F2 edits it, and
  # ENTER takes it and stays in the box; a second ENTER searches
  def handle(state, %{typing: {_, _}} = mode, key),
    do: FieldTyping.key(state, mode, key, &typed/3)

  def handle(state, mode, {:char, c}) do
    if field(state, mode) == :text,
      do: FieldTyping.start(state, mode, :text, c),
      else: state
  end

  def handle(state, _mode, _key), do: state

  defp typed(state, :text, text),
    do: State.put_mode(state, %{State.mode(state) | line: LineEdit.new(text)})

  @impl Box
  def typing?(_state, mode), do: FieldTyping.typing?(mode)

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
    do: Box.run_settings(state, mode, Template.grid(@layouts[mode.scope], rows(mode)), id)

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
      mode.scope == :file -> Prompts.replace_show_view(state, {__MODULE__, :show_match, [search]})
      true -> first_match(state, search, mode.direction)
    end
  end

  @doc "Fills the Show View with a search's matches (`Prompts.replace_show_view/2`)."
  def show_match(state, search) do
    {:ok, state, %{new: view_id}} = State.command(state, {:show_match, search})
    State.switch_view(state, view_id)
  end

  defp first_match(state, search, direction) do
    found = matches(state, search)

    # Agenda's searches start after (before) the highlighted item, not on
    # it (checked in Agenda 2.0, 2026-10-26)
    index =
      case direction do
        :forward -> Enum.find(found, &(&1 > state.cursor))
        :backward -> found |> Enum.reverse() |> Enum.find(&(&1 < state.cursor))
        :beginning -> List.first(found)
      end

    # quiet, as Agenda's: no message while searching
    if index do
      state
      |> State.push(%Agendum.TUI.Modes.Searching{search: search})
      |> Layout.move_to(index)
    else
      ErrorBox.open(state, Agendum.TUI.Messages.text(:no_matches))
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
  defp searching(state, _mode, :close), do: State.pop(state)
  defp searching(state, _mode, :help), do: Agendum.TUI.HelpScreen.open(state)
  # the highlight moves as in the view
  defp searching(state, _mode, id), do: Agendum.TUI.Update.ViewKeys.run(state, id)

  defp step(state, search, direction) do
    found = matches(state, search)

    candidates =
      if direction > 0,
        do: Enum.filter(found, &(&1 > state.cursor)),
        else: found |> Enum.filter(&(&1 < state.cursor)) |> Enum.reverse()

    # past the last match: Agenda's error beep and nothing else
    case candidates do
      [index | _] -> Layout.move_to(state, index)
      [] -> State.effect(state, {:sound, :error})
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
    matching? = Search.matcher(search)

    state
    |> Layout.rows()
    |> Enum.with_index()
    |> Enum.filter(fn {row, _} -> row.kind == :item and matching?.(row.item) end)
    |> Enum.map(&elem(&1, 1))
  end

  # --- the box -------------------------------------------------------------------

  @impl Box
  def title(_state, %{scope: :view}), do: "Search"
  def title(_state, %{scope: :file}), do: "Show Match"

  @impl Box
  def content(state, mode, _inner, _max_rows) do
    values = %{
      text: mode.line.text,
      on: %{item: "Item text", note: "Note text", both: "Both item & note"}[mode.search.on],
      # nil leaves the row out: searching the file has no direction
      direction:
        %{forward: "Forward", backward: "Backward", beginning: "Search from beginning"}[
          mode.direction
        ],
      ignore_case: if(mode.search.ignore_case, do: "Yes", else: "No")
    }

    Template.render(
      @layouts[mode.scope],
      values,
      [selected: field(state, mode)] ++ FieldTyping.editing(mode)
    )
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
