defmodule Agendum.TUI.Render.ControlPanel do
  @moduledoc """
  The control panel: Agenda's two top lines. Normally the file, with the
  indicators (marks, mode, time) on the right, then what is shown; the menu,
  a prompt, a question, a message or a hint take them over while they last,
  and in a box the help for its highlighted field (`Agendum.TUI.Boxes.FieldHelp`).
  Pure.
  """

  alias Agendum.Core.{Database, DateFormat}
  alias Agendum.TUI.{Typing.Completion, Terminal.Draw, Menu, State}
  alias Agendum.TUI.Render.Text

  # white and yellow on blue
  @panel %{normal: :panel, dim: :panel_hint, box: :panel}

  @doc "The two lines, for the base screen `base` (nil for the view)."
  # Agenda's two top lines. Normally the file, with the indicators and the
  # time on the right, then what is shown: the view (with its filter and
  # hide settings), or the manager, note or help. The menu, a prompt and its
  # field, a question, a message or a hint take them over while they last.
  def lines(%State{width: w} = state, base) do
    {l1, l2} =
      case State.mode(state) do
        %{type: :menu} = m ->
          menu_lines(m)

        %{type: :prompt, label: label, action: action} ->
          # a file name can be picked from a list (R51), as Agenda said
          label =
            if Agendum.TUI.Boxes.SelectFile.file_prompt?(action),
              do: label <> "  F3 lists files",
              else: label

          {beside_indicators(state, base, [{:prompt, " " <> label}]),
           [{:panel, " "}] ++ Draw.input(state.edit.line, w - 2, :edit)}

        %{type: :column_width} = m ->
          text_lines(state, base, :panel_hint, Agendum.TUI.Moves.ColumnWidth.panel(m))

        %{type: :column_move} = m ->
          text_lines(state, base, :panel_hint, Agendum.TUI.Moves.ColumnMove.panel(state, m))

        %{type: :section_move} = m ->
          text_lines(state, base, :panel_hint, Agendum.TUI.Moves.SectionMove.panel(state, m))

        %{type: :browse, date: _} ->
          period = State.view(state).datebook.period
          hint = "← → another #{period} · ENTER keeps · ESC back"
          text_lines(state, base, :panel_hint, hint)

        %{type: :browse} ->
          # short, so the view's line with the dates being moved stays in sight
          hint = "← → ↑↓ PGUP PGDN · ENTER keeps · ESC back"

          text_lines(state, base, :panel_hint, hint)

        _ ->
          # a message first; else the help for a box's highlighted field
          case {message_line(state), Agendum.TUI.Boxes.FieldHelp.text(state)} do
            {[], nil} -> {file_line(state, base), where_line(state, base)}
            {[], help} -> text_lines(state, base, :panel_hint, help)
            {[{style, text} | _], _} -> text_lines(state, base, style, String.trim(text))
          end
      end

    Enum.map([l1, l2], &(&1 |> Draw.paint(@panel) |> Draw.line(w, :panel)))
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

  # the marks, the mode (READY, EDIT …) and the time, at the top right
  defp indicators(state, base) do
    marked = if Enum.any?(Database.items(state.db), & &1.marked), do: "♦ ", else: ""

    "  #{marked}#{if state.alarm_rang, do: "@ ", else: ""}#{questions_marker(state)}" <>
      "#{numeric_marker(state)}#{indicator(state, base)}  " <>
      DateFormat.datetime(state.now, state.db.date_format) <> " "
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

    hides =
      [
        {view.hide_done, "[Hide Done]"},
        {view.hide_empty, "[Hide Empty]"},
        {view.hide_inherited, "[Hide Inherited]"},
        {view.hide_dependent, "[Hide Dependent]"},
        {not Agendum.Core.auto_dating?(state.db), "[No Auto Dates]"}
      ]
      |> Enum.filter(&elem(&1, 0))
      |> Enum.map_join(" ", &elem(&1, 1))

    # a datebook view names its Section at the top right, as Agenda did (R47)
    datebook =
      case view.datebook do
        nil -> ""
        d -> "Datebook for: #{state.db.categories[d.section_category].name}  "
      end

    # ♪ when what is highlighted has a note (User's Guide 12-2)
    note = if Agendum.TUI.Layout.note_here?(state), do: "♪ ", else: ""
    right = if hides == "", do: datebook <> note, else: datebook <> hides <> " " <> note
    # at least two spaces between the view's name and filter and the rest
    room = max(state.width - String.length(right) - 2, 0)
    left = Draw.truncate(" View: " <> view.name <> Text.filter_text(state, view.filter), room)
    Draw.line([{:title, left}], state.width - String.length(right), :title) ++ [{:title, right}]
  end

  defp where_line(state, %{type: :catmgr}) do
    count = " #{map_size(state.db.categories)} categories "
    width = state.width - String.length(count)
    Draw.line([{:title, " Category Manager"}], width, :title) ++ [{:title, count}]
  end

  defp where_line(_state, %{type: :note, target: {:macro, _}, title: title}),
    do: [{:title, " Macro: " <> title}]

  defp where_line(_state, %{type: :note, title: title}), do: [{:title, " Note for: " <> title}]
  defp where_line(_state, %{type: :help}), do: [{:title, " Help"}]
  defp where_line(_state, %{type: :devtools}), do: [{:title, " Developer tools"}]

  # "?" while there are suggested assignments to confirm (User's Guide 19-9).
  defp questions_marker(state),
    do: if(Agendum.Core.questions(state.db) == [], do: "", else: "? ")

  # "#" while the highlight is in a numeric column (User's Guide 8-3).
  defp numeric_marker(%State{modes: [], col: col} = state) when col > 0 do
    case Agendum.TUI.Layout.current_column(state) do
      nil -> ""
      {column, _at} -> if Text.numeric?(state, column), do: "# ", else: ""
    end
  end

  defp numeric_marker(_state), do: ""

  # One branch per mode indicator (READY, EDIT, MENU …).
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp indicator(state, base) do
    top = State.mode(state)

    cond do
      state.macro.learning ->
        "LEARN"

      Completion.matches(state) != [] ->
        "AUTOC"

      state.edit != nil ->
        "EDIT"

      top && top.type == :menu ->
        "MENU"

      # a box module's own; nil leaves the one of what is beneath
      indicator = box_indicator(top) ->
        indicator

      top && top.type in [:move_item, :column_move, :section_move] ->
        "MOVE"

      top && top.type in [:scope, :calendar, :select_file] ->
        "CHOICES"

      top && top.type == :browse ->
        "BROWSE"

      top &&
          top.type in [
            :choice,
            :calendars
          ] ->
        "PROPS"

      top && top.type in [:searching] ->
        "SEARCH"

      base && base.type == :catmgr ->
        "CAT MGR"

      top && top.type == :viewmgr ->
        "VW MGR"

      base && base.type == :note ->
        "NOTE"

      base && base.type == :help ->
        "HELP"

      base && base.type == :devtools ->
        "DEV"

      true ->
        "READY"
    end
  end

  defp box_indicator(mode) do
    case Agendum.TUI.Boxes.Box.module(mode) do
      nil -> nil
      box -> box.indicator()
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

  defp menu_lines(mode) do
    entries = Menu.entries(mode)

    l1 =
      entries
      |> Enum.with_index()
      |> Enum.flat_map(fn {{label, _, _}, i} ->
        [{if(i == mode.selected, do: :menu_selected, else: :menu), " #{label} "}, {:menu, " "}]
      end)

    {_, desc, children} = Enum.at(entries, mode.selected)
    l2 = if is_list(children), do: Enum.map_join(children, "  ", &elem(&1, 0)), else: desc
    {[{:menu, " "} | l1], [{:menu_help, " " <> l2}]}
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
end
