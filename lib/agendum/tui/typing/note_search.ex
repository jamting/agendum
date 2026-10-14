defmodule Agendum.TUI.Typing.NoteSearch do
  @moduledoc """
  Searching and replacing text in a note (SPEC R39; User's Guide 15-6 to
  15-8).

  ALT-F6 in a note opens the Search/Replace box: the text, whether to
  replace it (then: the new text, Global replacement and Confirm
  replacement), the Direction and Ignore case. Typing goes into the text
  rows; ↑↓ or TAB move between settings and SPACE or ←→ change them; ENTER
  starts.

  A search moves the cursor to the next occurrence and highlights it;
  ALT-S finds the next one (after a single replacement: replaces it) and
  beeps when there is none. A replacement
  replaces the next occurrence, or every occurrence in the note when
  global. When confirming, each occurrence is highlighted in turn: Y
  replaces it, N skips it, ESC stops.

  The search starts at the cursor; when nothing is found there it
  continues from the top (or, backward, from the bottom). The note is
  saved when it is closed, so the whole edit is one undo step. The text
  rules are `Agendum.Core.TextSearch`. The box is a box module
  (`Agendum.TUI.Boxes.Box`), drawn from `@layout` (`Agendum.TUI.Boxes.Template`).
  Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, indicator: "SEARCH"

  alias Agendum.Core.TextSearch
  alias Agendum.TUI.Boxes.{Box, Template}
  alias Agendum.TUI.{Typing.LineEdit, State, Typing.TextEdit}

  # the replacement's rows only when Replace text is Yes
  @layout """
   Search for          : [text                                ]
   Replace text        : [replace                             ]
   Replace with        : [replacement                         ]
   Direction           : [direction                           ]
   Ignore case         : [ignore_case                         ]
   Global replacement  : [global                              ]
   Confirm replacement : [confirm                             ]

   Finds the text anywhere · ALT-S in the note: next one
  """

  @type settings :: %{
          text: String.t(),
          replace: boolean,
          replacement: String.t(),
          direction: :forward | :backward,
          ignore_case: boolean,
          global: boolean,
          confirm: boolean
        }

  @defaults %{
    text: "",
    replace: false,
    replacement: "",
    direction: :forward,
    ignore_case: true,
    global: false,
    confirm: true
  }

  @doc "Opens the Search/Replace box over the note, with the last settings."
  def open(state) do
    settings = state.searches.note || @defaults

    State.push(state, %{
      type: :note_search,
      settings: settings,
      line: LineEdit.new(settings.text),
      replacement: LineEdit.new(settings.replacement),
      cursor: 0
    })
  end

  @doc "The settings rows of the box."
  def rows(%{settings: %{replace: false}}), do: [:text, :replace, :direction, :ignore_case]

  def rows(%{settings: %{replace: true}}),
    do: [:text, :replace, :replacement, :direction, :ignore_case, :global, :confirm]

  # --- the box ---------------------------------------------------------------------

  @impl Box
  def handle(state, mode, key) do
    rows = rows(mode)
    row = Enum.at(rows, mode.cursor)

    case key do
      :esc ->
        State.pop(state)

      :enter ->
        settings = %{mode.settings | text: mode.line.text, replacement: mode.replacement.text}
        start(%{State.pop(state) | searches: %{state.searches | note: settings}}, settings)

      k when k in [:down, :tab] ->
        State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, length(rows) - 1)})

      k when k in [:up, :shift_tab] ->
        State.put_mode(state, %{mode | cursor: max(mode.cursor - 1, 0)})

      k when row in [:text, :replacement] ->
        edit_text(state, mode, row, k)

      k when k in [{:char, " "}, :right, :left] ->
        State.put_mode(state, %{mode | settings: change(mode.settings, row)})

      _ ->
        state
    end
  end

  defp edit_text(state, mode, row, key) do
    field = if row == :text, do: :line, else: :replacement

    case LineEdit.handle(Map.fetch!(mode, field), key) do
      {:ok, line} -> State.put_mode(state, Map.put(mode, field, line))
      :unhandled -> state
    end
  end

  defp change(settings, :direction),
    do: %{settings | direction: if(settings.direction == :forward, do: :backward, else: :forward)}

  defp change(settings, row), do: Map.update!(settings, row, &(not &1))

  @impl Box
  def title(_state, _mode), do: "Search/Replace in note"

  @impl Box
  def content(state, mode, inner, _max_rows) do
    s = mode.settings
    yes_no = &if(&1, do: "Yes", else: "No")
    # the rows shown; a row not in them is left out (nil)
    shown = rows(mode)

    values =
      %{
        text: mode.line.text,
        replace: yes_no.(s.replace),
        replacement: mode.replacement.text,
        direction: if(s.direction == :forward, do: "Forward", else: "Backward"),
        ignore_case: yes_no.(s.ignore_case),
        global: yes_no.(s.global),
        confirm: yes_no.(s.confirm)
      }
      |> Map.new(fn {row, value} -> {row, if(row in shown, do: value)} end)

    # the text row on the cursor is drawn as the line being typed
    row = field(state, mode)

    editing =
      case row do
        :text -> [editing: {:text, mode.line}]
        :replacement -> [editing: {:replacement, mode.replacement}]
        _ -> []
      end

    Template.render(@layout, values, [selected: row] ++ editing) ++
      [Box.hint(keys(state, mode), inner)]
  end

  @impl Box
  def keys(_state, _mode),
    do: [
      {"↑↓←→", "Setting", "Move between settings"},
      {"SPACE", "Change", "Change the setting"},
      {"ENTER", "Search"},
      {"ESC", "Cancel"}
    ]

  @impl Box
  def help, do: nil

  @impl Box
  def field(_state, mode), do: Enum.at(rows(mode), mode.cursor)

  # --- running it --------------------------------------------------------------------
  #
  # These run with the note on top of the mode stack.

  defp start(state, %{text: ""}), do: State.error(state, "Type what to search for")

  defp start(state, %{replace: false} = s) do
    case first(State.mode(state), s) do
      nil -> State.error(state, ~s(No occurrence of "#{s.text}"))
      {pos, wrapped} -> state |> highlight(pos, s) |> wrapped_message(wrapped, s)
    end
  end

  defp start(state, %{global: true, confirm: false} = s) do
    note = State.mode(state)
    {lines, count} = TextSearch.replace_all(note.edit.lines, s.text, s.replacement, s.ignore_case)
    state |> put_lines(lines, {note.edit.row, note.edit.col}) |> replaced(count)
  end

  defp start(state, %{global: global} = s) do
    note = State.mode(state)

    found =
      if global,
        do: find(note, s, edge(note, s.direction)),
        else: with({pos, _} <- first(note, s), do: pos)

    cond do
      found == nil -> State.error(state, ~s(No occurrence of "#{s.text}"))
      s.confirm -> ask(state, found, s, 0)
      true -> state |> replace(found, s) |> replaced(1)
    end
  end

  # The next occurrence from the cursor, else from the top (or bottom).
  defp first(note, s) do
    cursor = {note.edit.row, note.edit.col}

    case find(note, s, cursor) do
      nil ->
        case find(note, s, edge(note, s.direction)) do
          nil -> nil
          pos -> {pos, true}
        end

      pos ->
        {pos, false}
    end
  end

  defp find(note, s, from),
    do: TextSearch.find(note.edit.lines, s.text, from, s.direction, s.ignore_case)

  defp edge(_note, :forward), do: {0, 0}
  defp edge(note, :backward), do: {length(note.edit.lines), 0}

  defp wrapped_message(state, false, _s), do: state

  defp wrapped_message(state, true, %{direction: :forward}),
    do: State.info(state, "Search continued from the top · ALT-S finds the next")

  defp wrapped_message(state, true, %{direction: :backward}),
    do: State.info(state, "Search continued from the bottom · ALT-S finds the next")

  @doc "ALT-S in a note: the next occurrence of the last search, or a beep."
  def next(state, note) do
    case state.searches.note do
      nil ->
        State.error(state, "Nothing to search for yet; press ALT-F6")

      s ->
        # after a single replacement the cursor is already past it
        replacing = s.replace and not s.global
        {row, col} = {note.edit.row, note.edit.col}
        from = if s.direction == :forward and not replacing, do: {row, col + 1}, else: {row, col}

        case find(note, s, from) do
          nil ->
            state
            |> State.effect(:bell)
            |> State.error(~s(No more occurrences of "#{s.text}"))

          pos when replacing and s.confirm ->
            ask(state, pos, s, 0)

          pos when replacing ->
            state |> replace(pos, s) |> replaced(1)

          pos ->
            highlight(state, pos, s)
        end
    end
  end

  # --- confirming each replacement ----------------------------------------------------

  defp ask(state, pos, s, count) do
    state
    |> highlight(pos, s)
    |> put_note(&Map.put(&1, :replacing, %{settings: s, at: pos, count: count}))
    |> State.info("Replace this occurrence? (Y/N, ESC stops)")
  end

  @doc "Keys while a replacement waits for confirmation: Y, N or ESC."
  def confirm_key(state, note, key) do
    %{settings: s, at: pos, count: count} = note.replacing

    case key do
      {:char, c} when c in ["y", "Y"] ->
        state |> replace(pos, s) |> continue(s, after_replacement(pos, s), count + 1)

      {:char, c} when c in ["n", "N"] ->
        continue(state, s, after_skip(pos, s), count)

      :esc ->
        state |> stop() |> replaced(count)

      _ ->
        state
    end
  end

  defp after_replacement({row, col}, %{direction: :forward} = s),
    do: {row, col + String.length(s.replacement)}

  defp after_replacement(pos, _s), do: pos

  defp after_skip({row, col}, %{direction: :forward}), do: {row, col + 1}
  defp after_skip(pos, _s), do: pos

  defp continue(state, %{global: false}, _from, count), do: state |> stop() |> replaced(count)

  defp continue(state, s, from, count) do
    case find(State.mode(state), s, from) do
      nil -> state |> stop() |> replaced(count)
      pos -> ask(state, pos, s, count)
    end
  end

  defp stop(state), do: put_note(state, &Map.merge(&1, %{replacing: nil, match: nil}))

  # --- changing the note being edited ------------------------------------------------

  defp highlight(state, {row, col}, s) do
    put_note(state, fn note ->
      %{note | edit: %{note.edit | row: row, col: col}}
      |> Map.put(:match, {row, col, String.length(s.text)})
    end)
  end

  # The cursor goes after the replacement, or before it when searching
  # backward, so that ALT-S continues from there.
  defp replace(state, {row, col} = pos, s) do
    lines = TextSearch.replace_at(State.mode(state).edit.lines, pos, s.text, s.replacement)
    col = if s.direction == :forward, do: col + String.length(s.replacement), else: col
    put_lines(state, lines, {row, col})
  end

  defp put_lines(state, lines, {row, col}) do
    put_note(state, fn note ->
      row = min(row, length(lines) - 1)
      col = min(col, String.length(Enum.at(lines, row)))
      %{note | edit: %TextEdit{lines: lines, row: row, col: col}} |> Map.put(:match, nil)
    end)
  end

  defp put_note(state, fun), do: State.put_mode(state, fun.(State.mode(state)))

  defp replaced(state, 1), do: State.info(state, "Replaced 1 occurrence")
  defp replaced(state, n), do: State.info(state, "Replaced #{n} occurrences")
end
