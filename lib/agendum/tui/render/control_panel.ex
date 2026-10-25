defmodule Agendum.TUI.Render.ControlPanel do
  @moduledoc """
  The control panel: Agenda's two top lines. Normally the file, with the
  indicators (marks, mode, time) on the right, then what is shown; the menu,
  a prompt, a question, a message or a hint take them over while they last.
  While a box is open they are the box's alone, as Agenda's: the help for
  its highlighted field (`Agendum.TUI.Boxes.FieldHelp`), or EDIT while a
  field is typed in. Pure.
  """

  alias Agendum.Core.{Database, DateFormat}
  alias Agendum.TUI.{Typing.Completion, Terminal.Draw, Menu, State}
  alias Agendum.TUI.Render.Text

  # white and yellow on blue
  @panel %{normal: :panel, dim: :panel_hint, box: :panel}

  # the modes that are boxes: while one is on top the two lines are its own
  @boxes Agendum.TUI.Boxes.Box.registry()

  @doc "The two lines, for the base screen `base` (nil for the view)."
  # Agenda's two top lines. Normally the file, with the indicators and the
  # time on the right, then what is shown: the view (with its filter and
  # hide settings), or the manager, note or help. The menu, a prompt and its
  # field, a question, a message or a hint take them over while they last.
  def lines(%State{width: w} = state, base) do
    {l1, l2} =
      case State.mode(state) do
        %{type: :menu} = m ->
          menu_lines(m, w)

        %{type: :prompt, label: label, action: action} ->
          # a file name can be picked from a list (R51), as Agenda said
          label =
            if Agendum.TUI.Boxes.SelectFile.file_prompt?(action),
              do: label <> "  F3 lists files",
              else: label

          # a password shows as stars (R72)
          line =
            if Agendum.TUI.Update.Prompts.password_prompt?(state),
              do: %{
                state.edit.line
                | text: String.duplicate("*", String.length(state.edit.line.text))
              },
              else: state.edit.line

          {beside_indicators(state, base, [{:prompt, " " <> label}]),
           [{:panel, " "}] ++ Draw.input(line, w - 2, :edit)}

        %{type: :column_width} = m ->
          text_lines(state, base, :panel_hint, Agendum.TUI.Moves.ColumnWidth.panel(m))

        %{type: :column_move} = m ->
          text_lines(state, base, :panel_hint, Agendum.TUI.Moves.ColumnMove.panel(state, m))

        %{type: :section_move} = m ->
          text_lines(state, base, :panel_hint, Agendum.TUI.Moves.SectionMove.panel(state, m))

        %{type: :browse, date: %Date{}} ->
          period = State.view(state).datebook.period
          hint = "← → another #{period} · ENTER keeps · ESC back"
          text_lines(state, base, :panel_hint, hint)

        %{type: :browse} ->
          # short, so the view's line with the dates being moved stays in sight
          hint = "← → ↑↓ PGUP PGDN · ENTER keeps · ESC back"

          text_lines(state, base, :panel_hint, hint)

        mode when is_map_key(@boxes, mode.type) ->
          box_lines(state, mode)

        _ ->
          # a message first; else the help for a box's highlighted field, or
          # on an item's profile why it is in the highlighted category (R67)
          help =
            Agendum.TUI.Boxes.FieldHelp.text(state) ||
              Agendum.TUI.CategoryScreens.Profile.reason(state) ||
              link_under_cursor(state)

          case {message_line(state), help} do
            {[], nil} ->
              {file_line(state, base), where_line(state, base)}

            # in a note the header stays, and a hint goes under it (R64a)
            {[], help} when base.type == :note ->
              {file_line(state, base), [{:panel_hint, " " <> help}]}

            {[], help} ->
              text_lines(state, base, :panel_hint, help)

            {[{style, text} | _], _} ->
              text_lines(state, base, style, String.trim(text))
          end
      end

    Enum.map([l1, l2], &(&1 |> Draw.paint(@panel) |> Draw.line(w, :panel)))
  end

  # A box on top has the two lines to itself, as Agenda's (checked in Agenda
  # 2.0, 2026-10-25, in View and Item Properties, the view manager and the
  # assignment profile): no file, time or view. A message first; else,
  # while a field is typed in, line 1 is blank but for EDIT at the right;
  # else the highlighted field's help, going on into line 2 when long.
  defp box_lines(state, mode) do
    typed = typed_in?(state, mode)

    # the mode word as anywhere (LEARN, AUTOC …), and EDIT while a field
    # of the box's own is typed in; never the time
    word =
      case {indicator(state), typed} do
        {nil, true} -> "EDIT "
        {nil, false} -> ""
        {word, _} -> word <> " "
      end

    case message_line(state) do
      [{style, text} | _] ->
        box_text(state, style, String.trim(text), word)

      [] when typed ->
        box_text(state, :panel_hint, "", word)

      [] ->
        help =
          Agendum.TUI.Boxes.FieldHelp.text(state) ||
            Agendum.TUI.CategoryScreens.Profile.reason(state) || ""

        box_text(state, :panel_hint, help, word)
    end
  end

  # A field being typed in (F2, or a first key typed in it); a box whose
  # row is always a typing line (Search) is not, so its help stays
  defp typed_in?(state, mode), do: state.edit != nil or Map.get(mode, :typing) != nil

  defp box_text(state, style, text, word) do
    room = max(state.width - String.length(word) - 2, 10)
    # Draw.wrap/2 gives one line or more; the rest goes on line 2
    [first | rest] = Draw.wrap(text, room) ++ [""]
    rest = Enum.reject(rest, &(&1 == ""))

    l1 =
      Draw.line([{style, " " <> first}], state.width - String.length(word), :panel) ++
        [{:indicator, word}]

    {l1, if(rest == [], do: [], else: [{style, " " <> Enum.join(rest, " ")}])}
  end

  # A question, message or hint, left of the indicators; a long one goes
  # on into the second line, like Agenda's two-line help.
  defp text_lines(state, base, style, text) do
    room = state.width - String.length(indicators(state, base)) - 2

    case Draw.wrap(text, max(room, 10)) do
      [line] ->
        {beside_indicators(state, base, [{style, " " <> line}]), where_line(state, base)}

      [first | rest] ->
        {beside_indicators(state, base, [{style, " " <> first}]),
         [{style, " " <> Enum.join(rest, " ")}]}
    end
  end

  defp beside_indicators(state, base, left) do
    right = indicators(state, base)
    Draw.line(left, state.width - String.length(right), :panel) ++ [{:indicator, right}]
  end

  # the marks, Agenda's mode word (EDIT …) and the time, at the top right;
  # in a note (on top), as Agenda: the line the cursor is on, INS and EDIT,
  # without the time (R64a)
  defp indicators(state, base) do
    marked = if Enum.any?(Database.items(state.db), & &1.marked), do: "♦ ", else: ""
    marks = "  #{marked}#{if state.alarm_rang, do: "@ ", else: ""}#{questions_marker(state)}"

    case State.mode(state) do
      %{type: :note, edit: edit} when state.edit == nil and state.macro.learning == nil ->
        typing = if edit.overwrite, do: "OVR", else: "INS"
        marks <> "Line #{String.pad_leading(Integer.to_string(edit.row + 1), 4)} #{typing} EDIT "

      # the category manager shows neither a word nor the time, as Agenda's
      %{type: :catmgr} when base.type == :catmgr ->
        marks

      _ ->
        word = if word = indicator(state), do: word <> "  ", else: ""

        marks <> word <> DateFormat.datetime(state.now, state.db.date_format) <> " "
    end
  end

  # a note's line 1 (R64a): "Note for:" and what the note is of, padded as
  # Agenda's to where "Note file:" (step 7) will start its path
  defp file_line(state, %{type: :note} = note) do
    # the macro editor is the same editor: "Edit macro:" in Agenda
    label = if match?({:macro, _}, note.target), do: " Edit macro:  ", else: " Note for:   "
    room = max(state.width - String.length(indicators(state, note)) - 1, 1)
    beside_indicators(state, note, [{:title, Draw.truncate(label <> note.title, room)}])
  end

  defp file_line(state, base) do
    file = (state.path || "(untitled)") <> if(state.dirty, do: " *", else: "")
    room = max(state.width - String.length(indicators(state, base)) - 7, 1)
    # a long path loses its beginning, which matters least
    file =
      if String.length(file) > room,
        do: "…" <> String.slice(file, -(room - 1)..-1//1),
        else: file

    beside_indicators(state, base, [{:title, " File: " <> file}])
  end

  defp where_line(state, nil) do
    view = State.view(state)
    # ours, not Agenda's: a warning that new items get no dates (R6b)
    auto = if Agendum.Core.auto_dating?(state.db), do: "", else: "[No Auto Dates] "

    # Agenda's two marks at the right (checked in Agenda 2.0, 2026-10-25):
    # # on a numeric value or ☼ on a date, then ♪ when what is highlighted
    # has a note (User's Guide 12-2)
    note = if Agendum.TUI.Layout.note_here?(state), do: "♪", else: " "

    # (columns 72 and 73 of 80, six blank after them, as Agenda's)
    marks =
      if value_marker(state) <> note == "  ",
        do: "",
        else: value_marker(state) <> note <> String.duplicate(" ", 6)

    right = auto <> marks
    # at least two spaces between the view's name and filter and the rest
    room = max(state.width - String.length(right) - 2, 0)

    left =
      case view.datebook do
        nil ->
          view_name(state, view, room)

        # a datebook view names its Section from column 40, as Agenda's
        # (R47; "Datebook For: Task"), the name and hides cut to fit before
        d ->
          section = state.db.categories[d.section_category].name
          name = view_name(state, view, min(39, room))
          String.pad_trailing(name, 40) <> "Datebook For: " <> section
      end

    left = Draw.truncate(left, room)
    Draw.line([{:title, left}], state.width - String.length(right), :title) ++ [{:title, right}]
  end

  # Agenda's second line in the manager: its name only
  defp where_line(state, %{type: :catmgr}),
    do: Draw.line([{:title, " Category Manager"}], state.width, :title)

  # Agenda's second line in a note is its font, which Agendum has not; the
  # note's own file goes here (NOTE_EDITOR.md, step 7)
  defp where_line(_state, %{type: :note}), do: []
  defp where_line(_state, %{type: :help}), do: [{:title, " Help"}]
  defp where_line(_state, %{type: :devtools}), do: [{:title, " Developer tools"}]

  # " View: Projects [Hide empty, done]": the view's name, its filter, then
  # its hide settings in one bracket, as Agenda's (checked in Agenda 2.0,
  # 2026-10-25): Hide written once, the settings in Agenda's order, right
  # after a filter ("[-Contact List][Hide done]"). When the bracket does
  # not fit in `room` it loses its space and is cut short with "..", as
  # Agenda's ("View: Tomorrow[Hide empty, done, in..]").
  defp view_name(state, view, room) do
    name = " View: " <> view.name <> Text.filter_text(state, view.filter)

    hides =
      [
        {view.hide_empty, "empty"},
        {view.hide_done, "done"},
        {view.hide_inherited, "inherited"},
        {view.hide_dependent, "dependent"}
      ]
      |> Enum.filter(&elem(&1, 0))
      |> Enum.map(&elem(&1, 1))

    # a space after the name, none after a filter's "]"
    gap = if view.filter == [], do: " ", else: ""
    bracket = if hides == [], do: "", else: "[Hide " <> Enum.join(hides, ", ") <> "]"
    left = room - String.length(name)

    cond do
      bracket == "" -> Draw.truncate(name, room)
      String.length(gap <> bracket) <= left -> name <> gap <> bracket
      # room for "[Hide" and the ".." at least
      left >= 8 -> name <> String.slice(bracket, 0, left - 3) <> "..]"
      true -> Draw.truncate(name, room)
    end
  end

  # "?" while there are suggested assignments to confirm (User's Guide 19-9).
  defp questions_marker(state),
    do: if(Agendum.Core.questions(state.db) == [], do: "", else: "? ")

  # "#" while the highlight is in a numeric column (User's Guide 8-3), "☼"
  # in a date column (Agenda's, its help writing it *), else a space
  defp value_marker(%State{modes: [], col: col} = state) when col > 0 do
    case Agendum.TUI.Layout.current_column(state) do
      nil ->
        " "

      {column, _at} ->
        cond do
          Text.numeric?(state, column) -> "#"
          Database.date_category?(state.db, column.category_id) -> "☼"
          true -> " "
        end
    end
  end

  defp value_marker(_state), do: " "

  # Agenda's mode words, and only those (checked in Agenda 2.0, 2026-10-25;
  # the owner's choice): none when ready, in boxes, menus and managers
  defp indicator(state) do
    cond do
      state.macro.learning -> "LEARN"
      Completion.matches(state) != [] -> "AUTOC"
      state.edit != nil -> "EDIT"
      match?(%{type: :browse}, State.mode(state)) -> "BROWSE"
      # a calendar or feed read in the background: Agenda's WRKG
      state.fetching != %{} -> "WRKG"
      true -> nil
    end
  end

  defp message_line(%State{message: {:error, text}}), do: [{:error, " #{text} "}]
  defp message_line(%State{message: {:message, text}}), do: [{:message, " " <> text}]

  defp message_line(%State{edit: %{target: {:column_entry, _, head, _}}, modes: []} = state) do
    cond do
      Completion.column_entry?(state) ->
        completion_line(state)

      state.db.categories[head].kind == :numeric ->
        [{:dim, " Enter a number (e.g. 120, 1,234.50, -3); ENTER to set"}]

      true ->
        [{:dim, " Enter a date (e.g. friday, next week, 12/24); ENTER to set"}]
    end
  end

  defp message_line(%State{edit: %{target: target}, modes: []}) do
    hint =
      case target do
        {:new_item, _, _} -> "Type the new item; ENTER to finish, ESC to cancel"
        {:edit_item, _} -> "Edit the item; ENTER to finish, ESC to cancel"
        {:rename_category, _} -> "Edit the category name; ENTER to finish"
        # a Category note column's cell (R56): the line written into
        {:note_line, _, _, n} -> "Type line #{n} of the category's note; ENTER to set"
      end

    [{:dim, " " <> hint}]
  end

  defp message_line(_), do: []

  defp menu_lines(mode, width) do
    entries = Menu.entries(mode)

    pieces =
      entries
      |> Enum.with_index()
      |> Enum.map(fn {{label, _, _}, i} ->
        [{if(i == mode.selected, do: :menu_selected, else: :menu), " #{label} "}, {:menu, " "}]
      end)

    {_, desc, children} = Enum.at(entries, mode.selected)
    l2 = if is_list(children), do: Enum.map_join(children, "  ", &elem(&1, 0)), else: desc
    {menu_line(pieces, mode.selected, width), [{:menu_help, " " <> l2}]}
  end

  # A menu wider than the screen scrolls so that the highlighted entry
  # shows, ◄ and ► saying that there is more to the left or the right
  defp menu_line(pieces, selected, width) do
    if Draw.width(List.flatten(pieces)) + 1 <= width do
      [{:menu, " "} | List.flatten(pieces)]
    else
      widths = Enum.map(pieces, &Draw.width/1)
      room = width - 2
      # the first entry shown: the leftmost from which the highlighted
      # one still fits
      first =
        Enum.find(0..selected, fn start ->
          widths |> Enum.slice(start..selected) |> Enum.sum() <= room
        end) || selected

      # as many entries as fit after it
      count =
        widths
        |> Enum.drop(first)
        |> Enum.scan(&(&1 + &2))
        |> Enum.count(&(&1 <= room))

      shown = pieces |> Enum.slice(first, count) |> List.flatten()
      left = if first > 0, do: "◄", else: " "
      right = if first + count < length(pieces), do: "►", else: " "
      [{:menu, left}] ++ shown ++ [{:menu, Draw.spaces(room - Draw.width(shown))}, {:menu, right}]
    end
  end

  # Automatic completion (R32): the top line says how many categories match
  # and how to choose.
  defp completion_line(state) do
    text = String.trim(state.edit.line.text)

    case length(Completion.matches(state)) do
      0 when text == "" ->
        [{:dim, " Type a category name; ENTER to assign"}]

      0 ->
        [{:dim, " New category: #{text} · ENTER creates it"}]

      1 ->
        [{:dim, " 1 category begins with \"#{text}\" · ENTER accepts · INS new category"}]

      n ->
        [
          {:dim,
           " #{n} categories begin with \"#{text}\" · ENTER accepts · F8/ALT-N next · F7/ALT-P previous · INS new"}
        ]
    end
  end

  # R73b: on a Zettel link in a note, or in an item being edited, the
  # control panel says what it points at
  defp link_under_cursor(state) do
    with {text, col} <- cursor_text(state),
         %{} = link <- link_at(state.db, text, col) do
      case link.target do
        nil -> "[[#{link.word}]]: no item has this Zettel id"
        id -> "→ #{String.downcase(link.word)}: #{state.db.items[id].text}"
      end
    else
      _ -> nil
    end
  end

  defp cursor_text(state) do
    case {State.mode(state), state.edit} do
      {%{type: :note, edit: edit}, _} -> {Enum.at(edit.lines, edit.row), edit.col}
      {nil, %{target: {:edit_item, _}, line: line}} -> {line.text, line.pos}
      _ -> nil
    end
  end

  # the link the cursor is in, or just after
  defp link_at(db, text, col) do
    text
    |> Agendum.Core.zettel_links(Agendum.Core.zettels(db))
    |> Enum.find(&(col >= &1.at and col <= &1.at + &1.length))
  end
end
