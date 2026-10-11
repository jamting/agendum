defmodule Agenda.TUI.Render do
  @moduledoc """
  Turns a `State` into a screen (a list of styled lines). Pure.

  Screen layout, after Agenda 2.0:

      lines 0–1   control panel: the file, indicators and time, and the
                  view (or the manager, note, help) shown; the menu,
                  prompts, questions and messages take it over
      lines 2..   body: the view, or a full-screen manager
      last line   function key bar
  """

  alias Agenda.Core.{Database, DateFormat, ViewModel}
  alias Agenda.TUI.{CategoryScreens, Completion, Draw, Layout, Menu, State}

  @full_screen [:catmgr, :viewmgr, :help, :note, :devtools]
  @boxes [
    :picker,
    :profile,
    :props,
    :choice,
    :item_props,
    :group_profile,
    :scope,
    :sort,
    :search_box,
    :note_search,
    :file_props,
    :input_format,
    :customize,
    :calendars,
    :date_rule,
    :category_match,
    :auto_assign,
    :goto,
    :range_filter,
    :action_box,
    :execute,
    :questions,
    :column_props,
    :date_column_props,
    :alarm_list
  ]

  @spec render(State.t()) :: [Draw.line()]
  def render(%State{width: w} = state) do
    {base, overlays} = split_modes(state.modes)
    {styles, fill} = surface(base)
    body = Enum.map(body(state, base), &(&1 |> Draw.paint(styles) |> Draw.line(w, fill)))
    # behind a box, the screen fades (Agenda greys it out)
    body = if overlays == [], do: body, else: Enum.map(body, &Draw.paint(&1, :backdrop))

    body =
      overlays
      |> Enum.with_index()
      |> Enum.reduce(body, fn {mode, depth}, body ->
        overlay_box(state, mode, depth, depth == length(overlays) - 1, body)
      end)

    control_panel(state, base) ++
      Enum.map(body, &Draw.line(&1, w)) ++
      if(state.key_map, do: [keybar(state)], else: [])
  end

  # The colours of a full screen: the category manager is cyan, help
  # yellow on blue (Agenda 2.0); the rest is the view's grey.
  defp surface(%{type: :catmgr}),
    do:
      {%{normal: :catmgr, item: :catmgr, dim: :catmgr_note, section: :catmgr_head, edit: :row},
       :catmgr}

  defp surface(%{type: :help}), do: {%{normal: :help}, :help}
  defp surface(_base), do: {%{}, :normal}

  # The base is the topmost full-screen mode (or the view); boxes above it
  # are drawn on top, bottom-up.
  defp split_modes(modes) do
    {above, rest} = Enum.split_while(modes, &(&1.type not in @full_screen))
    base = List.first(rest)
    {base, above |> Enum.filter(&(&1.type in @boxes)) |> Enum.reverse()}
  end

  # --- control panel ---------------------------------------------------------------------

  # white and yellow on blue
  @panel %{normal: :panel, dim: :panel_hint, box: :panel}

  # Agenda's two top lines. Normally the file, with the indicators and the
  # time on the right, then what is shown: the view (with its filter and
  # hide settings), or the manager, note or help. The menu, a prompt and its
  # field, a question, a message or a hint take them over while they last.
  defp control_panel(%State{width: w} = state, base) do
    {l1, l2} =
      case State.mode(state) do
        %{type: :menu} = m ->
          menu_lines(m)

        %{type: :prompt, label: label} ->
          {beside_indicators(state, base, [{:prompt, " " <> label}]),
           [{:panel, " "}] ++ field(state.edit.line, w - 2, :edit)}

        %{type: :confirm, question: q} ->
          text_lines(state, base, :prompt, q)

        _ ->
          case message_line(state) do
            [] -> {file_line(state, base), where_line(state, base)}
            [{style, text} | _] -> text_lines(state, base, style, String.trim(text))
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
        {not Agenda.Core.auto_dating?(state.db), "[No Auto Dates]"}
      ]
      |> Enum.filter(&elem(&1, 0))
      |> Enum.map_join(" ", &elem(&1, 1))

    right = if hides == "", do: "", else: hides <> " "
    # at least two spaces between the view's name and filter and the rest
    room = max(state.width - String.length(right) - 2, 0)
    left = Draw.truncate(" View: " <> view.name <> filter_text(state, view.filter), room)
    Draw.line([{:title, left}], state.width - String.length(right), :title) ++ [{:title, right}]
  end

  defp where_line(state, %{type: :catmgr}) do
    count = " #{map_size(state.db.categories)} categories "
    width = state.width - String.length(count)
    Draw.line([{:title, " Category Manager"}], width, :title) ++ [{:title, count}]
  end

  defp where_line(_state, %{type: :viewmgr}), do: [{:title, " View Manager"}]
  defp where_line(_state, %{type: :note, title: title}), do: [{:title, " Note for: " <> title}]
  defp where_line(_state, %{type: :help}), do: [{:title, " Help"}]
  defp where_line(_state, %{type: :devtools}), do: [{:title, " Developer tools"}]

  # "?" while there are suggested assignments to confirm (User's Guide 19-9).
  defp questions_marker(state),
    do: if(Agenda.Core.questions(state.db) == [], do: "", else: "? ")

  # "#" while the highlight is in a numeric column (User's Guide 8-3).
  defp numeric_marker(%State{modes: [], col: col} = state) when col > 0 do
    case Enum.at(State.view(state).columns, col - 1) do
      nil -> ""
      column -> if numeric?(state, column), do: "# ", else: ""
    end
  end

  defp numeric_marker(_state), do: ""

  # One branch per mode indicator (READY, EDIT, MENU …).
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp indicator(state, base) do
    top = State.mode(state)

    cond do
      Completion.matches(state) != [] ->
        "AUTOC"

      state.edit != nil ->
        "EDIT"

      top && top.type == :menu ->
        "MENU"

      top && top.type == :move_item ->
        "MOVE"

      top && top.type in [:picker, :scope] ->
        "CHOICES"

      top && top.type in [:profile, :group_profile] ->
        "ASSIGN"

      top &&
          top.type in [
            :props,
            :choice,
            :item_props,
            :file_props,
            :input_format,
            :customize,
            :calendars,
            :date_rule,
            :category_match,
            :auto_assign,
            :column_props,
            :date_column_props,
            :range_filter,
            :action_box,
            :execute
          ] ->
        "PROPS"

      top && top.type == :sort ->
        "SORT"

      top && top.type in [:search_box, :searching, :note_search] ->
        "SEARCH"

      base && base.type == :catmgr ->
        "CAT MGR"

      base && base.type == :viewmgr ->
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

  # --- key bar -----------------------------------------------------------------------------

  # Each key has a short label, as in Agenda's 8-character slots, and may
  # have a fuller one (and a fuller name, "CTRL-N" for "^N"). The bar shows
  # the fuller ones when they all fit the screen's width, the short ones
  # otherwise: {key, label} | {key, label, full label} |
  # {key, label, full key, full label}.
  defp keybar(state) do
    keys =
      cond do
        Completion.active?(state) ->
          [
            {"ENTER", "Accept", "Accept the name"},
            {"F8/A-N", "Next", "F8/ALT-N", "Next match"},
            {"F7/A-P", "Previous", "F7/ALT-P", "Previous match"},
            {"INS/^N", "New category", "INS/CTRL-N", "New category"},
            {"ESC", "Cancel"}
          ]

        state.edit != nil ->
          [
            {"ENTER", "Done", "Finish"},
            {"ESC", "Cancel"},
            {"←→", "Move", "Move the cursor"},
            {"^A/^E", "Start/End", "CTRL-A/CTRL-E", "Start/end of the line"},
            {"^U", "Clear", "CTRL-U", "Clear the line"}
          ]

        true ->
          mode_keys(State.mode(state))
      end
      |> Enum.map(&full_entry/1)

    full = keybar_segments(keys, fn {_, _, key, label} -> {key, label} end, " ")
    short = keybar_segments(keys, fn {key, label, _, _} -> {key, label} end, "")
    segments = if Draw.width(full) <= state.width, do: full, else: short
    Draw.line(segments, state.width, :keybar)
  end

  defp full_entry({key, label}), do: {key, label, key, label}
  defp full_entry({key, label, full}), do: {key, label, key, full}
  defp full_entry({_, _, _, _} = entry), do: entry

  defp keybar_segments(keys, pick, gap) do
    keys
    |> Enum.map(pick)
    |> Enum.map_intersperse([{:keybar, gap}], fn {k, label} ->
      [{:keybar_key, " " <> k}, {:keybar, " " <> label}]
    end)
    |> List.flatten()
  end

  defp mode_keys(nil),
    do: [
      {"F1", "Help"},
      {"F2", "Edit"},
      {"F3", "Choices"},
      {"F4", "Done"},
      {"F5", "Note"},
      {"F6", "Props", "Properties"},
      {"F7", "Mark"},
      {"F8", "VwMgr", "View manager"},
      {"F9", "CatMgr", "Category manager"},
      {"F10", "Menu"}
    ]

  defp mode_keys(%{type: :catmgr}),
    do: [
      {"F2", "Edit", "Rename"},
      {"F5", "Note"},
      {"F6", "Props", "Properties"},
      {"F7", "Promote"},
      {"F8", "Demote"},
      {"INS/^N", "Add", "INS/CTRL-N", "Add a category"},
      {"DEL", "Discard"},
      {"A-F10", "Move", "ALT-F10", "Move"},
      {"ESC", "Return"}
    ]

  defp mode_keys(%{type: :viewmgr}),
    do: [
      {"ENTER", "Select", "Show the view"},
      {"INS", "Add", "Add a view"},
      {"F2", "Rename"},
      {"DEL", "Discard"},
      {"A-↑↓", "Reorder", "ALT-↑↓", "Reorder"},
      {"ESC", "Return", "Back to the view"}
    ]

  defp mode_keys(%{type: :picker}),
    do: [
      {"ENTER", "Select"},
      {"INS", "New category"},
      {"type", "Search", "Search by name"},
      {"ESC", "Cancel"}
    ]

  defp mode_keys(%{type: type}) when type in [:profile, :group_profile],
    do: [
      {"SPACE", "Assign/Unassign", "Assign or unassign"},
      {"ESC", "Return", "Done"}
    ]

  defp mode_keys(%{type: :alarm_list}),
    do: [{"DEL", "Remove past alarm"}, {"ALT-A", "Cancel alarm"}, {"ESC", "Close"}]

  defp mode_keys(%{type: :search_box}),
    do: [
      {"ENTER", "Search"},
      {"TAB/↓", "Next setting"},
      {"SPACE", "Change", "Change the setting"},
      {"ESC", "Cancel"}
    ]

  defp mode_keys(%{type: :searching}),
    do: [
      {"ALT-N", "Next", "Next match"},
      {"ALT-P", "Previous", "Previous match"},
      {"F7", "Mark", "Mark the item"},
      {"ENTER/ESC", "End search"}
    ]

  defp mode_keys(%{type: :sort}),
    do: [
      {"ENTER", "Change", "Change the setting"},
      {"↑↓", "Setting", "Move between settings"},
      {"ESC", "Close"}
    ]

  defp mode_keys(%{type: :scope}),
    do: [
      {"M", "Marked items"},
      {"C", "Current item", "The highlighted item"},
      {"ENTER", "Select"},
      {"ESC", "Cancel"}
    ]

  defp mode_keys(%{type: :props}),
    do: [{"ENTER", "Change", "Change the setting"}, {"ESC", "Return", "Close"}]

  defp mode_keys(%{type: :item_props}),
    do: [
      {"ENTER", "Edit"},
      {"DEL", "Remove", "Remove the assignment"},
      {"type", "Assign", "Assign to a category"},
      {"F4", "Date", "Set the date"},
      {"F3", "Profile", "Assignment profile"},
      {"ESC", "Close"}
    ]

  defp mode_keys(%{type: :choice}),
    do: [{"↑↓", "Highlight", "Highlight a choice"}, {"ENTER", "Select"}, {"ESC", "Cancel"}]

  defp mode_keys(%{type: :note, replacing: r}) when r != nil,
    do: [{"Y", "Replace"}, {"N", "Skip", "Skip this one"}, {"ESC", "Stop"}]

  defp mode_keys(%{type: :note}),
    do: [
      {"ESC", "Return", "Save and return"},
      {"F5", "Return", "Save and return"},
      {"ALT-F6", "Search", "Search and replace"},
      {"ALT-S", "Next", "Next occurrence"}
    ]

  defp mode_keys(%{type: :questions}),
    do: [
      {"SPACE", "Pick", "Pick a suggestion"},
      {"TAB", "All", "Pick all"},
      {"ENTER", "Assign", "Assign the picked"},
      {"ESC", "Stop"}
    ]

  defp mode_keys(%{type: :execute}),
    do: [
      {"↑↓", "Setting", "Move between settings"},
      {"SPACE", "Change", "Change the setting"},
      {"ENTER", "Run"},
      {"ESC", "Cancel"}
    ]

  defp mode_keys(%{type: type}) when type in [:action_box, :range_filter],
    do: [
      {"↑↓", "Setting", "Move between settings"},
      {"SPACE", "Change", "Change the setting"},
      {"ENTER", "Apply"},
      {"DEL", "Remove"},
      {"ESC", "Cancel"}
    ]

  defp mode_keys(%{type: :goto}),
    do: [
      {"↑↓", "Highlight", "Highlight a section"},
      {"letter", "Next starting with it"},
      {"ENTER", "Go"},
      {"ESC", "Cancel"}
    ]

  defp mode_keys(%{type: :calendars}),
    do: [
      {"INS", "Subscribe", "Subscribe to a calendar"},
      {"ENTER", "Read now"},
      {"F", "How often", "How often to read it"},
      {"A", "Ahead", "How far ahead"},
      {"DEL", "Unsubscribe"},
      {"ESC", "Close"}
    ]

  defp mode_keys(%{type: :note_search}),
    do: [
      {"↑↓", "Setting", "Move between settings"},
      {"SPACE", "Change", "Change the setting"},
      {"ENTER", "Search"},
      {"ESC", "Cancel"}
    ]

  # the settings boxes: one setting per line, SPACE cycles its choices
  defp mode_keys(%{type: type})
       when type in [
              :column_props,
              :date_column_props,
              :category_match,
              :auto_assign,
              :date_rule,
              :input_format,
              :customize,
              :file_props
            ],
       do: [
         {"↑↓", "Setting", "Move between settings"},
         {"SPACE", "Next", "SPACE/→", "Next choice"},
         {"←", "Previous", "Previous choice"},
         {"ESC", "Close"}
       ]

  defp mode_keys(%{type: :menu}),
    do: [
      {"←→", "Highlight", "Highlight a command"},
      {"ENTER", "Select"},
      {"letter", "Select", "first letter", "Select"},
      {"ESC", "Back", "Back a level"}
    ]

  defp mode_keys(%{type: :devtools}),
    do: [
      {"↑↓ PGUP PGDN", "Scroll"},
      {"any key", "Show it", "Show what it sends"},
      {"ESC", "Return"}
    ]

  defp mode_keys(%{type: :help}), do: [{"↑↓", "Scroll"}, {"any other key", "Return"}]

  defp mode_keys(%{type: :move_item}),
    do: [
      {"↑↓", "Choose position", "Choose where it goes"},
      {"ENTER", "Move here"},
      {"ESC", "Cancel"}
    ]

  defp mode_keys(%{type: :prompt}), do: [{"ENTER", "Accept"}, {"ESC", "Cancel"}]
  defp mode_keys(%{type: :confirm}), do: [{"Y", "Yes"}, {"N", "No"}, {"ESC", "Cancel"}]

  # --- body ------------------------------------------------------------------------------------

  defp body(state, nil), do: fit(view_lines(state), state)
  defp body(state, %{type: :catmgr} = mode), do: fit(catmgr_lines(state, mode), state)
  defp body(state, %{type: :viewmgr} = mode), do: fit(viewmgr_lines(state, mode), state)
  defp body(state, %{type: :help} = mode), do: fit(Enum.drop(help_lines(), mode.top), state)

  defp body(state, %{type: :devtools} = mode) do
    lines =
      state
      |> Agenda.TUI.DevTools.lines(mode)
      |> Enum.map(fn
        "" -> []
        {label, value} -> [{:normal, " " <> Draw.pad(label, 16) <> ": " <> value}]
        heading -> [{:section, " " <> heading}]
      end)

    fit(Enum.drop(lines, mode.top), state)
  end

  defp body(state, %{type: :note} = mode), do: fit(note_lines(state, mode), state)

  defp fit(lines, state) do
    h = State.body_height(state)
    lines = Enum.take(lines, h)
    lines ++ List.duplicate([], h - length(lines))
  end

  # --- the view ----------------------------------------------------------------------------------

  defp view_lines(state) do
    rows = Layout.rows(state)
    tw = Layout.text_width(state)
    columns = State.view(state).columns
    editing = state.modes == [] && state.edit

    rows
    |> Enum.with_index()
    |> Enum.flat_map(fn {row, index} ->
      selected = index == state.cursor
      lines = row_lines(state, row, index, selected, editing, tw, columns)
      lines = if selected, do: Enum.map(lines, &tint(&1, state.width)), else: lines

      lines =
        case editing do
          %{target: {:new_item, _, key}} when selected and key == row.key ->
            lines ++
              [[{:symbol, " • "}] ++ field(editing.line, tw, :edit) ++ blank_cells(columns)]

          _ ->
            lines
        end

      lines ++ calc_lines(Map.get(row, :calcs, []), tw, columns)
    end)
    |> Enum.drop(state.scroll)
  end

  # The highlighted line is a lighter shade across the screen, so the eye
  # finds it when the highlight is in a column (Agenda drew a » instead).
  @tint %{
    normal: :row,
    symbol: :row,
    item: :row,
    item_done: :row_done,
    cell: :row_cell,
    section: :row_cell,
    column_head: :row_cell
  }

  defp tint([], _width), do: []
  defp tint(line, width), do: line |> Draw.paint(@tint) |> Draw.line(width, :row)

  # A section's calculations (R29): the label under the item text, each
  # result under its column.
  defp calc_lines(calcs, tw, columns) do
    Enum.map(calcs, fn {calc, cells} ->
      label = Agenda.Core.NumberFormat.label(calc)

      [{:normal, "   "}, {:calc, String.pad_leading(label <> " ", tw)}] ++
        Enum.flat_map(Enum.zip(columns, cells), fn {column, cell} ->
          [{:normal, " "}, {:calc, right(cell, column.width)}]
        end)
    end)
  end

  defp right(text, width), do: text |> String.pad_leading(width) |> Draw.pad(width)

  defp numeric?(state, column), do: state.db.categories[column.category_id].kind == :numeric

  defp row_lines(state, %{kind: :section} = row, index, selected, editing, tw, columns) do
    cat = row.category
    style = if selected and state.col == 0, do: :cursor, else: :section

    name_part =
      case editing do
        %{target: {:rename_category, id}} when selected and id == cat.id ->
          [{:normal, " "}] ++ field(editing.line, tw + 1, :edit)

        _ ->
          section = Enum.at(State.view(state).sections, row.sidx)

          suffix =
            if(row.collapsed, do: " §#{row.count}", else: "") <>
              filter_text(state, section.filter)

          [{:normal, " "}, {style, Draw.pad(cat.name <> suffix, tw + 1)}]
      end

    heads =
      Enum.flat_map(columns, fn c ->
        [
          {:normal, " "},
          {:column_head,
           Draw.pad(ViewModel.column_label(state.db, c.category_id, c.width), c.width)}
        ]
      end)

    head = name_part ++ heads
    if index == 0, do: [head], else: [[], head]
  end

  defp row_lines(state, %{kind: :item, item: item} = row, _index, selected, editing, tw, columns) do
    symbol =
      cond do
        item.done -> "√"
        item.marked -> "♦"
        Agenda.Core.waiting?(state.db, item.id) -> "&"
        item.alarm_minutes != nil -> "@"
        true -> "•"
      end

    note = if item.note != "", do: "♪", else: " "
    text_style = if item.done, do: :item_done, else: :item

    text_lines =
      case editing do
        %{target: {:edit_item, id}} when id == item.id ->
          [field(editing.line, tw, :edit)]

        _ ->
          item.text
          |> Draw.wrap(tw)
          |> Enum.map(
            &[{if(selected and state.col == 0, do: :cursor, else: text_style), Draw.pad(&1, tw)}]
          )
      end

    cells =
      columns
      |> Enum.zip(row.cells)
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {{column, cell}, i} ->
        cell_part =
          case editing do
            %{target: {:column_entry, id, head, _}}
            when selected and id == item.id and head == column.category_id and state.col == i ->
              completion_field(state, editing.line, column.width)

            _ ->
              text =
                if numeric?(state, column),
                  do: right(cell, column.width),
                  else: Draw.pad(cell, column.width)

              [{if(selected and state.col == i, do: :cursor_cell, else: :cell), text}]
          end

        [{:normal, " "} | cell_part]
      end)

    [first | rest] = text_lines
    first_line = [{:symbol, " " <> symbol}, {:symbol, note}] ++ first ++ cells
    [first_line | Enum.map(rest, &([{:normal, "   "}] ++ &1))]
  end

  defp blank_cells(columns),
    do: Enum.flat_map(columns, &[{:normal, " "}, {:normal, Draw.spaces(&1.width)}])

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

  # A column cell being typed into, with the rest of the shown completion
  # in grey after the cursor ("Me" + "dium").
  defp completion_field(state, line, width) do
    shown = Completion.shown(state)
    typed = line.text
    name = if shown, do: state.db.categories[shown].name, else: ""
    rest = String.slice(name, String.length(typed)..-1//1)

    if shown && line.pos == String.length(typed) && String.length(typed) < width && rest != "" do
      {first, after_} = String.split_at(rest, 1)
      Draw.line([{:edit, typed}, {:edit_cursor, first}, {:edit_hint, after_}], width, :edit)
    else
      field(line, width, :edit)
    end
  end

  # A one-line edit field that scrolls horizontally to keep the cursor visible.
  defp field(line, width, style) do
    width = max(width, 1)
    offset = max(line.pos - width + 1, 0)
    visible = String.slice(line.text, offset, width)
    segments = Draw.field(visible, line.pos - offset, style)
    Draw.line(segments, width, style)
  end

  # --- category manager --------------------------------------------------------------------------

  defp catmgr_lines(state, mode) do
    rows = CategoryScreens.rows(state, mode)
    visible = State.body_height(state)
    top = max(mode.cursor - visible + 1, 0)
    db = state.db

    lines =
      rows
      |> Enum.with_index()
      |> Enum.flat_map(fn {{id, depth}, i} ->
        cat = db.categories[id]
        selected = i == mode.cursor
        indent = String.duplicate("   ", depth)

        name =
          case state.edit do
            %{target: {:rename, ^id}} ->
              [{:normal, " " <> indent}] ++ field(state.edit.line, 30, :edit)

            _ ->
              [
                {:normal, " " <> indent},
                {if(selected, do: :cursor, else: :item), cat.name <> ellipsis(state, cat)}
              ]
          end

        line = name ++ [{:dim, category_tags(state, cat)}]

        case state.edit do
          %{target: {:new, parent, _}} when selected ->
            new_indent = String.duplicate("   ", Database.depth(db, parent) + 1)
            [line, [{:normal, " " <> new_indent}] ++ field(state.edit.line, 30, :edit)]

          _ ->
            [line]
        end
      end)
      |> Enum.drop(top)

    lines
  end

  defp category_tags(%State{db: db} = state, cat) do
    count =
      if Database.date_field(db, cat.id), do: nil, else: length(Database.items_in(db, cat.id))

    [
      cat.kind == :date && "date",
      cat.exclusive && "exclusive",
      cat.short_name && "aka #{cat.short_name}",
      cat.conditions != [] && "if " <> conditions_text(state, cat),
      (cat.also_assign != [] or cat.actions != []) && "→ " <> actions_text(db, cat),
      cat.excludes != [] && "not with " <> names_text(db, cat.excludes),
      Agenda.TUI.CategoryMatchBox.manager_tag(cat.match_overrides),
      cat.note != "" && "♪",
      count && "#{count}"
    ]
    |> Enum.filter(& &1)
    |> case do
      [] -> ""
      tags -> "   " <> Enum.join(tags, " · ")
    end
  end

  # --- view manager ------------------------------------------------------------------------------

  defp viewmgr_lines(state, mode) do
    views =
      state.db
      |> Database.views()
      |> Enum.with_index()
      |> Enum.map(fn {v, i} ->
        selected = i == mode.cursor
        current = if v.id == state.view_id, do: "►", else: " "

        name =
          case state.edit do
            %{target: id} when id == v.id -> field(state.edit.line, 30, :edit)
            _ -> [{if(selected, do: :cursor, else: :item), Draw.pad(v.name, 30)}]
          end

        sections = Enum.map_join(v.sections, ", ", &state.db.categories[&1.category_id].name)
        [{:symbol, " #{current} "}] ++ name ++ [{:dim, "  Sections: " <> sections}]
      end)

    [[] | views]
  end

  # --- notes ---------------------------------------------------------------------------------------

  defp note_lines(state, mode) do
    edit = mode.edit
    visible = State.body_height(state)
    top = max(edit.row - visible + 1, 0)

    lines =
      edit.lines
      |> Enum.with_index()
      |> Enum.map(fn {text, row} ->
        case Map.get(mode, :match) do
          {^row, col, len} ->
            {before, rest} = String.split_at(text, col)
            {found, after_} = String.split_at(rest, len)
            [{:normal, " " <> before}, {:edit_cursor, found}, {:normal, after_}]

          _ when row == edit.row ->
            [{:normal, " "}] ++ Draw.field(text, edit.col, :normal)

          _ ->
            [{:normal, " " <> text}]
        end
      end)
      |> Enum.drop(top)

    lines
  end

  # --- help ------------------------------------------------------------------------------------------

  @help """
   AGENDA KEYS                     (↑↓ PGUP PGDN scroll · any other key returns)

   In a view                         Mac / no-INS alternative
     Type          Add an item, or an entry in the highlighted column
     INS           New item / extra column entry   CTRL-N
     F2            Edit item, section head, entry  CTRL-E
     F3            Choices: column box / item's profile
     F4            Mark item done                  CTRL-K
     F5            Note
     F6            Item / category properties      ESC 6
     F7            Mark item (on a section: all)  ALT-F7 unmark all, ALT-J next
     F8 / F9       View manager / category manager
     F10 or /      Menu
     DEL           Remove from section or column   fn-⌫
     ALT-F4        Discard item                    CTRL-D
     ALT-M         Assign to a category (MakeAssign)   ESC m
     With marked items, F4 DEL ALT-F2 ALT-F4 ALT-F10 ALT-M F3 ask:
                   marked items (M) or the current item (C)
     ALT-F2        Set the When date (or menu Item When)
     ALT-F10       Move item to another section
     ALT-− / ALT-= Collapse / expand section (twice: all)
     ALT-F5        Go to a section (GO TO)           ESC %
     ALT-N / ALT-P Next / previous view              ESC n / ESC p
     ALT-V         Show / hide empty sections        ESC v
     ALT-I         Insert an item (like INS)         ESC i
     ALT-W / ALT-G Save / retrieve a file            ESC w / ESC g
     ALT-F6        Search (then ALT-N / ALT-P, F7 mark)  ESC ^
     ALT-F8        Back to the previous view        ESC *
     ALT-A         Set or cancel an alarm            ESC a
     ALT-O         Depend on the marked items (&); with none marked,
                   clear the item's dependencies     ESC o
     ALT-X / ALT-E Execute all conditions and actions / the section's
                   category's, on all items (Category ▸ Execute)
     ALT-D / ALT-U Add section below / above
     ALT-R / ALT-L Add column right / left
     ←→ TAB        Move between item and columns
     In a column   Type a name: the first match shows; ENTER accepts,
                   F8/ALT-N and F7/ALT-P cycle, INS/^N makes it a new one
     Numeric column Type a number; F2 edits, DEL removes it; the format and
                   totals are in View ▸ Column ▸ Properties
     CTRL-PGUP/DN  Previous / next section         ⌥↑ / ⌥↓

   Everywhere
     CTRL-Z / CTRL-Y   Undo / redo
     CTRL-S            Save              CTRL-O   Open (retrieve) a file
     CTRL-P            Print to file     CTRL-Q   Quit (also ALT-Q)
     ALT-K             Show / hide the function key map

   In the category manager (F9)
     Type / INS    Add a category below            CTRL-N, ALT-D, ALT-I
     ALT-U         Add a category above            ESC u
     ALT-R / ALT-L Add a child / a new family after the parent
     F2            Rename                          CTRL-E
     F7 / F8       Promote / demote
     ALT-↑ ALT-↓   Reorder among siblings          ⌥↑ / ⌥↓
     ALT-− / ALT-= Collapse / expand family (twice: all)   ESC - / ESC =
     ALT-F10       Move under another parent
     DEL           Discard category                CTRL-D
     F6            Properties (exclusive, short name, links)
     ESC / F9      Return to the view

   In a note (F5)
     ALT-F6        Search / replace text            ESC ^
     ALT-S         Find the next occurrence         ESC s
                   (after a single replacement: replace it)
     ALT-D / ALT-T Insert today's date / the time   ESC d / ESC t
     ALT-N / ALT-P Save; next / previous item's note
     ESC / F5      Save the note and return

   While typing
     ←→ HOME END   Move          CTRL-A / CTRL-E   Start / end of line
     ⌥← ⌥→         Word left / right
     CTRL-K        Delete to end  CTRL-W / ⌥⌫      Delete word   CTRL-U  Clear

   Function keys can also be typed as ESC then a digit (ESC 1 = F1 ...
   ESC 0 = F10), and ALT-F1..ALT-F10 as ESC then a shifted digit (! .. )).
   ⌘ shortcuts (⌘N, ⌘Z, ⌘S ...) work once your terminal maps them to the
   CTRL keys above; see docs/KEYBOARD.md.

   Items are assigned to the section they are typed in, and automatically to
   any category whose name (or short name) appears in their text. The first
   date in the text ("call Bob next Friday") becomes the When date. Typing a
   name in a column assigns the item to that subcategory, creating it if new.
  """

  @doc false
  def help_line_count, do: @help |> String.split("\n") |> length()

  @doc "The F1 help text."
  def help_text, do: @help

  defp help_lines, do: @help |> String.split("\n") |> Enum.map(&[{:normal, &1}])

  # --- boxes -------------------------------------------------------------------------------------------

  # A box opened from another box (`depth` 1, 2 …) sits a line lower and
  # two columns further right, so the one beneath still shows; the titles
  # of the boxes beneath are dimmed, the active box's is not.
  defp overlay_box(state, mode, depth, active?, body) do
    inner = min(state.width - 8, 60)
    top = 1 + depth
    max_rows = max(State.body_height(state) - 4 - depth, 3)
    content = box_content(state, mode, inner, max_rows)
    box = Draw.box(box_title(state, mode), content, inner)
    box = if active?, do: box, else: Enum.map(box, &Draw.paint(&1, %{box_title: :box_title_dim}))
    left = min(div(state.width - inner - 2, 2) + 2 * depth, max(state.width - inner - 2, 0))

    body
    |> Draw.overlay(box, top, left)
    |> Draw.shadow(top, left, length(box), inner + 2)
  end

  defp box_title(state, %{type: :picker, purpose: purpose}) do
    case purpose do
      {:add_section, _} ->
        "Section head"

      {:change_section, _} ->
        "Change section head"

      {:add_column, _} ->
        "Column head"

      {:assign_column, _, head} ->
        "Choose " <> state.db.categories[head].name

      {:new_view, name} ->
        "First section for view #{name}"

      {:move_category, id} ->
        "New parent for " <> state.db.categories[id].name

      {:also_assign, id} ->
        "Actions for items joining #{state.db.categories[id].name}"

      {:excludes, id} ->
        "Categories that may not share items with #{state.db.categories[id].name}"

      {:assign_items, [_]} ->
        "Assign the item to"

      {:assign_items, ids} ->
        "Assign #{Draw.count(length(ids), "marked item")} to"

      {:condition, id} ->
        "Conditions for #{state.db.categories[id].name}"

      {:filter, :view} ->
        "Filter the view"

      {:filter, {:section, i}} ->
        "Filter the #{section_name(state, i)} section"

      {:sort_category, _, _} ->
        "Sort by the children of"

      {:sort_note, _, _} ->
        "Choose the category whose notes to sort by"

      :execute_root ->
        "Apply the conditions of this category and its children"
    end
  end

  defp box_title(_state, %{type: :item_props}), do: "Item properties"

  defp box_title(_state, %{type: :group_profile, item_ids: ids}),
    do: "Assignments: #{Draw.count(length(ids), "marked item")}"

  defp box_title(_state, %{type: :scope}), do: "Marked items"
  defp box_title(_state, %{type: :alarm_list}), do: "Alarm list"
  defp box_title(_state, %{type: :search_box, scope: :view}), do: "Search this view"
  defp box_title(_state, %{type: :note_search}), do: "Search/Replace in note"
  defp box_title(_state, %{type: :file_props}), do: "File properties"
  defp box_title(_state, %{type: :input_format}), do: "Input format (yours, for every file)"
  defp box_title(_state, %{type: :customize}), do: "Customize (yours, for every file)"
  defp box_title(_state, %{type: :calendars}), do: "Calendars"

  defp box_title(_state, %{type: :auto_assign}), do: "Auto-assign settings"

  defp box_title(state, %{type: :category_match, cat_id: id}),
    do: "Advanced settings: " <> state.db.categories[id].name

  defp box_title(state, %{type: :date_rule, cat_id: id}),
    do: "Advanced settings: " <> state.db.categories[id].name

  defp box_title(_state, %{type: :questions}), do: "Suggested assignments"
  defp box_title(_state, %{type: :goto}), do: "Go to section"

  defp box_title(_state, %{type: :execute}), do: "Execute conditions and actions"

  defp box_title(state, %{type: :action_box} = mode) do
    kind = if Agenda.TUI.ActionBox.numeric?(state, mode), do: "Numeric", else: "Date"
    "#{kind} action: #{state.db.categories[mode.target].name}"
  end

  defp box_title(state, %{type: :range_filter} = mode) do
    kind = if Agenda.TUI.RangeFilterBox.numeric?(state, mode), do: "Numeric", else: "Date"
    what = if match?({:condition, _}, mode.purpose), do: "condition", else: "filter"
    "#{kind} #{what}: #{state.db.categories[mode.cat_id].name}"
  end

  defp box_title(state, %{type: :column_props} = mode),
    do:
      "Numeric column: " <>
        state.db.categories[Agenda.TUI.ColumnProperties.column(state, mode).category_id].name

  defp box_title(state, %{type: :date_column_props} = mode),
    do:
      "Date column: " <>
        state.db.categories[Agenda.TUI.DateColumnBox.column(state, mode).category_id].name

  defp box_title(_state, %{type: :search_box, scope: :file}),
    do: "Search the whole file (Show View)"

  defp box_title(_state, %{type: :sort, scope: :view}), do: "Sort items in all sections"

  defp box_title(state, %{type: :sort, scope: {:section, i}}),
    do: "Sort items in #{section_name(state, i)}"

  defp box_title(state, %{type: :profile, item_id: id}),
    do: "Assignments: " <> String.slice(state.db.items[id].text, 0, 40)

  defp box_title(state, %{type: :choice, kind: :move, cat_id: id}),
    do: "Moving #{state.db.categories[id].name} creates a conflict"

  defp box_title(state, %{type: :choice, kind: :type, cat_id: id}),
    do: "Category type: #{state.db.categories[id].name}"

  defp box_title(state, %{type: :choice, cat_id: id}),
    do: "Make children of #{state.db.categories[id].name} mutually exclusive"

  defp box_title(state, %{type: :props, cat_id: id}),
    do: "Category properties: " <> state.db.categories[id].name

  defp box_content(state, %{type: type} = mode, inner, max_rows)
       when type in [:picker, :profile, :group_profile] do
    rows = CategoryScreens.rows(state, mode)
    cursor = min(mode.cursor, max(length(rows) - 1, 0))
    top = max(cursor - max_rows + 1, 0)

    list =
      rows
      |> Enum.with_index()
      |> Enum.drop(top)
      |> Enum.take(max_rows)
      |> Enum.map(fn {{id, depth}, i} ->
        style = if i == cursor, do: :box_selected, else: :box
        cat = state.db.categories[id]
        name = String.duplicate("  ", depth) <> cat.name <> ellipsis(state, cat)

        [
          {:box, " " <> profile_marker(state, mode, id) <> " "},
          {style, Draw.pad(name, inner - 6)}
        ]
      end)

    list =
      if list == [], do: [[{:box, "  (no categories yet — press INS to create one)"}]], else: list

    list ++ [[], box_footer(state, mode, inner)]
  end

  # "Marked items or current item?" (User's Guide 13-2)
  defp box_content(state, %{type: :alarm_list} = mode, inner, _max_rows) do
    rows = Agenda.TUI.AlarmList.rows(state)
    cursor = min(mode.cursor, max(length(rows) - 1, 0))

    lines =
      rows
      |> Enum.with_index()
      |> Enum.map(fn {{kind, id}, i} ->
        item = state.db.items[id]

        when_text =
          case kind do
            :current ->
              at = NaiveDateTime.add(Agenda.Core.when_at(item), -item.alarm_minutes * 60)
              "rings " <> DateFormat.datetime(at, state.db.date_format)

            :past ->
              "rang " <>
                DateFormat.time(NaiveDateTime.to_time(item.alarm_rung_at), state.db.date_format)
          end

        text = Draw.pad(item.text, max(inner - 28, 10))

        {kind,
         [
           {:box, " "},
           {if(i == cursor, do: :box_selected, else: :box), text},
           {:box, " " <> when_text}
         ]}
      end)

    current = for {:current, line} <- lines, do: line
    past = for {:past, line} <- lines, do: line
    none = [[{:box, "   (none)"}]]

    [[{:box, " Current alarms"}]] ++
      if(current == [], do: none, else: current) ++
      [[], [{:box, " Past alarms today"}]] ++
      if(past == [], do: none, else: past) ++
      [[], [{:box, " DEL removes a past alarm · ALT-A cancels a current one"}]]
  end

  defp box_content(_state, %{type: :search_box} = mode, inner, _max_rows) do
    values = %{
      on: %{item: "Item text", note: "Note text", both: "Both item & note"}[mode.search.on],
      direction:
        %{forward: "Forward", backward: "Backward", beginning: "Search from beginning"}[
          mode.direction
        ],
      ignore_case: if(mode.search.ignore_case, do: "Yes", else: "No")
    }

    labels = %{
      text: "Search for",
      on: "Match on",
      direction: "Direction",
      ignore_case: "Ignore case"
    }

    rows =
      mode
      |> Agenda.TUI.SearchBox.rows()
      |> Enum.with_index()
      |> Enum.map(fn {row, i} ->
        label = [{:box, " " <> Draw.pad(labels[row], 12) <> ": "}]

        value =
          if row == :text,
            do: field(mode.line, inner - 16, :edit),
            else: [{if(i == mode.cursor, do: :box_selected, else: :box), values[row]}]

        label ++ value
      end)

    rows ++ [[], [{:box, " Pat* finds Pat, Patty… · (a phrase) · ENTER searches"}]]
  end

  defp box_content(state, %{type: :column_props} = mode, _inner, _max_rows) do
    rows =
      state
      |> Agenda.TUI.ColumnProperties.lines(mode)
      |> Enum.with_index()
      |> Enum.map(fn {{label, value}, i} ->
        [
          {:box, " " <> Draw.pad(label, 19) <> ": "},
          {if(i == mode.cursor, do: :box_selected, else: :box), value}
        ]
      end)

    rows ++
      [
        [],
        [{:box, " Sample: " <> Agenda.TUI.ColumnProperties.sample(state, mode)}],
        [{:box, " SPACE/→ next choice · ← previous · ESC closes"}]
      ]
  end

  defp box_content(state, %{type: :date_column_props} = mode, _inner, _max_rows) do
    rows =
      state
      |> Agenda.TUI.DateColumnBox.lines(mode)
      |> Enum.with_index()
      |> Enum.map(fn {{label, value}, i} ->
        [
          {:box, " " <> Draw.pad(label, 20) <> ": "},
          {if(i == mode.cursor, do: :box_selected, else: :box), value}
        ]
      end)

    rows ++
      [
        [],
        [{:box, " Sample: " <> Agenda.TUI.DateColumnBox.sample(state, mode)}],
        [{:box, " SPACE/→ next choice · ← previous · ESC closes"}]
      ]
  end

  defp box_content(state, %{type: :questions} = mode, inner, _max_rows) do
    item = state.db.items[mode.item]

    cats =
      state
      |> Agenda.TUI.QuestionsBox.suggestions(mode)
      |> Enum.with_index()
      |> Enum.map(fn {cat, i} ->
        mark = if cat in mode.picked, do: "*", else: " "

        [
          {:box, " #{mark} "},
          {if(i == mode.cursor, do: :box_selected, else: :box), state.db.categories[cat].name}
        ]
      end)

    [[{:box, " " <> String.slice(item.text, 0, inner - 2)}], [], [{:box, " Assign to:"}]] ++
      cats ++ [[], [{:box, " SPACE picks · TAB picks all · ENTER assigns · ESC stops"}]]
  end

  defp box_content(state, %{type: :execute} = mode, _inner, _max_rows) do
    rows =
      state
      |> Agenda.TUI.ExecuteBox.lines(mode)
      |> Enum.with_index()
      |> Enum.map(fn {{label, value}, i} ->
        [
          {:box, " " <> Draw.pad(label, 20) <> ": "},
          {if(i == mode.cursor, do: :box_selected, else: :box), value}
        ]
      end)

    rows ++ [[], [{:box, " ENTER runs · on the first row: choose · SPACE changes"}]]
  end

  defp box_content(state, %{type: :action_box} = mode, inner, _max_rows) do
    rows =
      state
      |> Agenda.TUI.ActionBox.lines(mode)
      |> Enum.with_index()
      |> Enum.map(fn {{label, value}, i} ->
        label = [{:box, " " <> Draw.pad(label, 12) <> ": "}]

        case value do
          {:line, line} when i == mode.cursor -> label ++ field(line, inner - 16, :edit)
          {:line, line} -> label ++ [{:box, line.text}]
          text -> label ++ [{if(i == mode.cursor, do: :box_selected, else: :box), text}]
        end
      end)

    rows ++ [[], [{:box, " SPACE changes · ENTER applies · DEL removes · ESC cancels"}]]
  end

  defp box_content(state, %{type: :range_filter} = mode, inner, _max_rows) do
    rows =
      state
      |> Agenda.TUI.RangeFilterBox.lines(mode)
      |> Enum.with_index()
      |> Enum.map(fn {{label, value}, i} ->
        label = [{:box, " " <> Draw.pad(label, 16) <> ": "}]

        case value do
          {:line, line} when i == mode.cursor -> label ++ field(line, inner - 20, :edit)
          {:line, line} -> label ++ [{:box, line.text}]
          text -> label ++ [{if(i == mode.cursor, do: :box_selected, else: :box), text}]
        end
      end)

    rows ++ [[], [{:box, " Blank = open · ENTER applies · DEL removes · ESC cancels"}]]
  end

  defp box_content(state, %{type: :goto} = mode, _inner, max_rows) do
    names = Agenda.TUI.GoTo.names(state)
    top = max(mode.cursor - max_rows + 1, 0)

    names
    |> Enum.with_index()
    |> Enum.drop(top)
    |> Enum.take(max_rows)
    |> Enum.map(fn {name, i} ->
      [{:box, " "}, {if(i == mode.cursor, do: :box_selected, else: :box), name}]
    end)
  end

  defp box_content(state, %{type: :category_match} = mode, _inner, _max_rows) do
    rows =
      state
      |> Agenda.TUI.CategoryMatchBox.lines(mode)
      |> Enum.with_index()
      |> Enum.map(fn {{label, value}, i} ->
        [
          {:box, " " <> Draw.pad(label, 24) <> ": "},
          {if(i == mode.cursor, do: :box_selected, else: :box), value}
        ]
      end)

    rows ++ [[], [{:box, " SPACE/→ next choice · ← previous · ESC closes"}]]
  end

  defp box_content(state, %{type: :auto_assign} = mode, _inner, _max_rows) do
    rows =
      state
      |> Agenda.TUI.AutoAssignBox.lines()
      |> Enum.with_index()
      |> Enum.map(fn {{label, value}, i} ->
        [
          {:box, " " <> Draw.pad(label, 24) <> ": "},
          {if(i == mode.cursor, do: :box_selected, else: :box), value}
        ]
      end)

    rows ++ [[], [{:box, " SPACE/→ next choice · ← previous · ESC closes"}]]
  end

  defp box_content(state, %{type: :date_rule} = mode, _inner, _max_rows) do
    rows =
      state
      |> Agenda.TUI.DateRuleBox.lines(mode)
      |> Enum.with_index()
      |> Enum.map(fn {{label, value}, i} ->
        [
          {:box, " " <> Draw.pad(label, 23) <> ": "},
          {if(i == mode.cursor, do: :box_selected, else: :box), value}
        ]
      end)

    rows ++ [[], [{:box, " SPACE/→ next choice · ← previous · ESC closes"}]]
  end

  defp box_content(state, %{type: :calendars} = mode, _inner, _max_rows) do
    rows =
      state
      |> Agenda.TUI.CalendarsBox.lines(mode)
      |> Enum.map(fn {style, text} ->
        [{if(style == :selected, do: :box_selected, else: :box), " " <> text}]
      end)

    rows ++
      [
        [],
        [{:box, " INS subscribe · ENTER read now · DEL unsubscribe"}],
        [{:box, " F how often · A how far ahead"}]
      ]
  end

  defp box_content(state, %{type: type} = mode, _inner, _max_rows)
       when type in [:input_format, :customize] do
    lines =
      if type == :customize,
        do: Agenda.TUI.CustomizeBox.lines(state),
        else: Agenda.TUI.InputFormatBox.lines(state)

    rows =
      lines
      |> Enum.with_index()
      |> Enum.map(fn {{label, value}, i} ->
        [
          {:box, " " <> Draw.pad(label, 20) <> ": "},
          {if(i == mode.cursor, do: :box_selected, else: :box), value}
        ]
      end)

    rows ++
      [
        [],
        [{:box, " Saved in your preferences, not in this file."}],
        [{:box, " SPACE/→ next choice · ← previous · ESC closes"}]
      ]
  end

  defp box_content(state, %{type: :file_props} = mode, _inner, _max_rows) do
    rows =
      state
      |> Agenda.TUI.FileProperties.lines()
      |> Enum.with_index()
      |> Enum.map(fn {{label, value}, i} ->
        [
          {:box, " " <> Draw.pad(label, 20) <> ": "},
          {if(i == mode.cursor, do: :box_selected, else: :box), value}
        ]
      end)

    # the sample sits under the display settings it shows
    sample = [
      {:box, " " <> Draw.pad("  Sample", 20) <> ": " <> DateFormat.sample(state.db.date_format)}
    ]

    {display, rest} = Enum.split(rows, length(Agenda.TUI.DateFormatRows.rows()))

    display ++
      [sample] ++ rest ++ [[], [{:box, " SPACE/→ next choice · ← previous · ESC closes"}]]
  end

  defp box_content(_state, %{type: :note_search} = mode, inner, _max_rows) do
    rows =
      mode
      |> Agenda.TUI.NoteSearch.lines()
      |> Enum.with_index()
      |> Enum.map(fn {{label, value}, i} ->
        label = [{:box, " " <> Draw.pad(label, 19) <> ": "}]

        case value do
          {:line, line} when i == mode.cursor -> label ++ field(line, inner - 23, :edit)
          {:line, line} -> label ++ [{:box, line.text}]
          text -> label ++ [{if(i == mode.cursor, do: :box_selected, else: :box), text}]
        end
      end)

    rows ++ [[], [{:box, " Finds the text anywhere · ALT-S in the note: next one"}]]
  end

  defp box_content(state, %{type: :sort} = mode, inner, _max_rows) do
    rows =
      state
      |> Agenda.TUI.SortBox.lines(mode)
      |> Enum.with_index()
      |> Enum.map(fn {{label, value}, i} ->
        [
          {:box, " " <> Draw.pad(label, 16) <> ": "},
          {if(i == mode.cursor, do: :box_selected, else: :box),
           String.slice(value, 0, inner - 20)}
        ]
      end)

    rows ++ [[], [{:box, " ENTER changes the highlighted setting · ESC closes"}]]
  end

  defp box_content(_state, %{type: :scope} = mode, _inner, _max_rows) do
    options = ["Marked items (#{length(mode.marked)})", "Current item"]

    choices =
      options
      |> Enum.with_index()
      |> Enum.map(fn {label, i} ->
        [{:box, "   "}, {if(i == mode.cursor, do: :box_selected, else: :box), " #{label} "}]
      end)

    [[{:box, " " <> scope_question(mode.action)}], []] ++ choices
  end

  defp box_content(state, %{type: :item_props} = mode, inner, max_rows) do
    item = state.db.items[mode.item_id]
    rows = Agenda.TUI.ItemProperties.rows(state, mode)
    cursor = min(mode.cursor, length(rows) - 1)
    value_width = inner - 16
    assignments = Agenda.Core.item_assignments(state.db, item.id)
    entered = DateFormat.date(item.entry, state.db.date_format)

    lines =
      rows
      |> Enum.with_index()
      |> Enum.map(fn {row, i} ->
        selected = i == cursor
        # the name being typed shows on the highlighted assignment or the add row
        assign_row = row == :add or (selected and is_tuple(row))

        {label, value} =
          case row do
            :text ->
              {"Item text", item.text}

            :note ->
              {"Note",
               if(item.note == "", do: "(none)", else: item.note |> String.split("\n") |> hd())}

            :stats ->
              {"Statistics",
               "#{Draw.count(length(assignments), "category", "categories")} · entered #{entered}"}

            {kind, id} when kind in [:prerequisite, :dependent] ->
              {dependency_label(rows, row), dependency_text(state.db, id)}

            {:assigned, a} ->
              {if(a == hd(assignments), do: "Assigned to", else: ""),
               assignment_text(state.db, a, item)}

            :add ->
              {if(assignments == [], do: "Assigned to", else: ""),
               "(type a category name to add)"}
          end

        value_part =
          case state.edit do
            %{target: {:item_text, _}} when row == :text ->
              field(state.edit.line, value_width, :edit)

            %{target: {:assign_category, _}} when assign_row ->
              completion_field(state, state.edit.line, value_width)

            _ ->
              [{if(selected, do: :box_selected, else: :box), String.slice(value, 0, value_width)}]
          end

        separator = if label == "", do: "  ", else: ": "
        [{:box, " " <> Draw.pad(label, 12) <> separator}] ++ value_part
      end)

    top = max(cursor - max_rows + 1, 0)
    Enum.drop(lines, top) ++ [[], [{:box, " " <> item_props_hint(state)}]]
  end

  defp box_content(_state, %{type: :choice} = mode, _inner, _max_rows) do
    options = CategoryScreens.choice_options(mode)
    [problem, question] = CategoryScreens.choice_lines(mode)
    {_, description, _} = Enum.at(options, mode.cursor)

    choices =
      options
      |> Enum.with_index()
      |> Enum.map(fn {{label, _, _}, i} ->
        [{:box, "   "}, {if(i == mode.cursor, do: :box_selected, else: :box), " #{label} "}]
      end)

    [[{:box, " " <> problem}], [], [{:box, " " <> question}]] ++
      choices ++ [[], [{:box, " " <> description}]]
  end

  defp box_content(state, %{type: :props} = mode, inner, _max_rows) do
    cat = state.db.categories[mode.cat_id]
    yes_no = fn b -> if b, do: "Yes", else: "No" end

    values = %{
      name: cat.name,
      # an empty value would leave the highlighted row invisible
      short_name: cat.short_name || "(none)",
      type: cat.kind |> Atom.to_string() |> String.capitalize(),
      exclusive: yes_no.(cat.exclusive),
      match_name: yes_no.(cat.match_name),
      also_match: if(cat.also_match == "", do: "(none)", else: cat.also_match),
      special: %{nil => "None", done: "Mark items done", discard: "Discard items"}[cat.special],
      also_assign:
        if(cat.also_assign == [] and cat.actions == [],
          do: "(none)",
          else: actions_text(state.db, cat)
        ),
      conditions: if(cat.conditions == [], do: "(none)", else: conditions_text(state, cat)),
      excludes: if(cat.excludes == [], do: "(none)", else: names_text(state.db, cat.excludes)),
      advanced:
        if(cat.kind == :date,
          do: Agenda.TUI.DateRuleBox.summary(cat.date_rule),
          else: Agenda.TUI.CategoryMatchBox.summary(cat.match_overrides)
        ),
      note: if(cat.note == "", do: "(none)", else: "#{String.length(cat.note)} characters")
    }

    labels = %{
      name: "Category name",
      short_name: "Short name",
      type: "Type",
      exclusive: "Children mutually exclusive",
      match_name: "Assign items mentioning it",
      also_match: "Also match",
      also_assign: "Assignment actions",
      excludes: "Excludes",
      advanced: "Advanced settings",
      special: "Special action",
      conditions: "Assignment conditions",
      note: "Note"
    }

    CategoryScreens.props_fields()
    |> Enum.with_index()
    |> Enum.map(fn {prop, i} ->
      label = [{:box, " " <> Draw.pad(labels[prop], 28) <> ": "}]

      value =
        case state.edit do
          %{target: ^prop} -> field(state.edit.line, inner - 32, :edit)
          _ -> [{if(i == mode.cursor, do: :box_selected, else: :box), values[prop]}]
        end

      label ++ value
    end)
  end

  defp box_footer(state, %{type: :picker} = mode, inner) do
    case state.edit do
      %{target: :new_pick} ->
        [{:box, " New category: "}] ++ field(state.edit.line, inner - 16, :edit)

      _ when mode.search != "" ->
        [{:box, " Search: " <> mode.search}]

      _ when elem(mode.purpose, 0) == :also_assign ->
        [{:box, " ENTER cycles: + assign · - remove · none (dates, numbers: a box)"}]

      _ when elem(mode.purpose, 0) == :excludes ->
        [{:box, " ENTER toggles: x may not share items"}]

      _ when elem(mode.purpose, 0) in [:condition, :filter] ->
        [{:box, " ENTER cycles: + assigned · - not assigned · none"}]

      _ ->
        [{:box, " ENTER selects · INS creates · type to search"}]
    end
  end

  defp box_footer(_state, %{type: :group_profile}, _inner),
    do: [{:box, " N = marked items assigned · SPACE assigns or unassigns all"}]

  defp box_footer(_state, %{type: :profile}, _inner),
    do: [{:box, " * assigned  c by a condition  + via subcategory  SPACE"}]

  defp profile_marker(state, %{type: :group_profile, item_ids: ids}, id) do
    case CategoryScreens.group_count(state.db, ids, id) do
      0 -> " "
      n when n < 10 -> Integer.to_string(n)
      _ -> "+"
    end
  end

  defp profile_marker(state, %{type: :profile, item_id: item_id}, id) do
    db = state.db

    cond do
      Database.date_category?(db, id) ->
        if Database.item_date(db, item_id, id), do: "◊", else: " "

      Database.conditional?(db, item_id, id) ->
        "c"

      Database.explicit?(db, item_id, id) ->
        "*"

      Database.member?(db, item_id, id) ->
        "+"

      true ->
        " "
    end
  end

  defp profile_marker(state, %{type: :picker, purpose: {:filter, scope}}, id) do
    view = State.view(state)

    filter =
      if scope == :view, do: view.filter, else: Enum.at(view.sections, elem(scope, 1)).filter

    case List.keyfind(filter, id, 0) do
      {_, :not_assigned} -> "-"
      {_, _assigned_or_range} -> "+"
      nil -> " "
    end
  end

  defp profile_marker(state, %{type: :picker, purpose: {:condition, cat_id}}, id) do
    case List.keyfind(state.db.categories[cat_id].conditions, id, 0) do
      {_, :not_assigned} -> "-"
      {_, _assigned_or_range} -> "+"
      nil -> " "
    end
  end

  defp profile_marker(state, %{type: :picker, purpose: {:also_assign, cat_id}}, id) do
    cat = state.db.categories[cat_id]

    cond do
      id in cat.also_assign -> "+"
      List.keyfind(cat.actions, id, 0) in [{id, :remove}, {id, :clear}] -> "-"
      List.keymember?(cat.actions, id, 0) -> "="
      true -> " "
    end
  end

  defp profile_marker(state, %{type: :picker, purpose: {:excludes, cat_id}}, id),
    do: if(id in state.db.categories[cat_id].excludes, do: "x", else: " ")

  defp profile_marker(_state, _mode, _id), do: " "

  defp names_text(db, ids), do: Enum.map_join(ids, ", ", &db.categories[&1].name)

  # "Taxes, not People": a category's assignment conditions in words.
  # "Sales, -Receivables, When=tomorrow, Amount=150" (R15b)
  defp actions_text(db, cat) do
    name = &db.categories[&1].name

    Enum.map(cat.also_assign, name)
    |> Enum.concat(
      Enum.map(cat.actions, fn
        {id, action} when action in [:remove, :clear] ->
          "-" <> name.(id)

        {id, {:set, value}} when is_number(value) ->
          name.(id) <> "=" <> Agenda.TUI.Update.number_text(value)

        {id, {:set, value}} ->
          name.(id) <> "=" <> value
      end)
    )
    |> Enum.join(", ")
  end

  defp conditions_text(%State{db: db} = state, cat) do
    Enum.map_join(cat.conditions, ", ", fn
      {id, :assigned} ->
        db.categories[id].name

      {id, :not_assigned} ->
        "not " <> db.categories[id].name

      {id, range} ->
        db.categories[id].name <>
          " " <> Agenda.Core.RangeFilter.describe(db, range, State.context(state))
    end)
  end

  # One assignment in the Item Properties box: "When (2026-10-13)",
  # "Anna Lasky (c)" for a conditional one.
  defp assignment_text(db, %{category: id}, item) when id == db.special.when do
    db.categories[id].name <>
      " (#{DateFormat.date_time(item.when, item.when_time, db.date_format)})" <>
      recurrence_note(item) <> alarm_note(item)
  end

  defp assignment_text(db, a, _item), do: assignment_text(db, a)

  # R43: the first row of each kind is labelled
  defp dependency_label(rows, {kind, _} = row) do
    cond do
      Enum.find(rows, &match?({^kind, _}, &1)) != row -> ""
      kind == :prerequisite -> "Depends on"
      true -> "Needed by"
    end
  end

  defp dependency_text(db, id) do
    item = db.items[id]
    if item.done, do: "√ " <> item.text, else: item.text
  end

  defp recurrence_note(%{recurrence: nil}), do: ""
  defp recurrence_note(%{recurrence: rule}), do: " · " <> Agenda.Core.Recurrence.describe(rule)

  defp alarm_note(%{alarm_minutes: nil}), do: ""
  defp alarm_note(%{alarm_minutes: m}), do: " · alarm #{m} min before"

  defp assignment_text(db, %{category: id, kind: :numeric, number: number}),
    do:
      "#{db.categories[id].name} (#{Agenda.Core.NumberFormat.format(number, %Agenda.Core.NumberFormat{})})"

  defp assignment_text(db, %{category: id, kind: kind, date: date}) do
    name = db.categories[id].name

    case kind do
      :date -> "#{name} (#{DateFormat.date(date, db.date_format)})"
      :conditional -> name <> " (c)"
      :explicit -> name
    end
  end

  defp item_props_hint(state) do
    case state.edit do
      %{target: {:assign_category, _}} ->
        n = length(Completion.matches(state))
        text = String.trim(state.edit.line.text)

        cond do
          text == "" -> "Type a category name"
          n == 0 -> "New category: #{text} · ENTER creates it"
          true -> "#{n} match · ENTER accepts · F8/F7 cycle · INS new"
        end

      _ ->
        "ENTER edit · DEL remove · type to assign · F3 profile"
    end
  end

  # " [High, -People]": a filter as Agenda shows it beside the view name
  defp filter_text(_state, []), do: ""

  defp filter_text(%State{db: db} = state, filter) do
    names =
      Enum.map_join(filter, ", ", fn
        {id, :assigned} ->
          db.categories[id].name

        {id, :not_assigned} ->
          "-" <> db.categories[id].name

        {id, range} ->
          db.categories[id].name <>
            " " <> Agenda.Core.RangeFilter.describe(db, range, State.context(state))
      end)

    " [#{names}]"
  end

  defp section_name(state, index) do
    section = Enum.at(State.view(state).sections, index)
    state.db.categories[section.category_id].name
  end

  defp scope_question(action) do
    case action do
      :done -> "Mark as done:"
      :discard -> "Discard:"
      :remove -> "Remove from this section:"
      :when -> "Set the When date of:"
      :move_item -> "Move:"
      :make_assign -> "Assign to a category:"
      :profile -> "Show the assignments of:"
    end
  end

  # "..." after a collapsed family's parent (User's Guide 16-8).
  defp ellipsis(state, cat) do
    if cat.children != [] and MapSet.member?(state.collapsed, cat.id), do: "...", else: ""
  end

  # --- export ----------------------------------------------------------------------------------------------

  @doc "Plain-text rendering of the whole current view (for File Print)."
  @spec export_text(State.t()) :: String.t()
  def export_text(state) do
    view = State.view(state)
    heads = Enum.map(view.columns, &state.db.categories[&1.category_id].name)

    state.db
    |> Agenda.Core.ViewModel.build(view, State.context(state))
    |> Enum.map_join("\n\n", fn section ->
      header = Enum.join([section.category.name | heads], " | ")

      items =
        Enum.map(section.rows, fn row ->
          extra =
            row.cells
            |> Enum.zip(heads)
            |> Enum.reject(&(elem(&1, 0) == ""))
            |> Enum.map_join("; ", fn {c, h} -> "#{h}: #{c}" end)

          done =
            if row.item.done,
              do: " (done #{DateFormat.date(row.item.done, state.db.date_format)})",
              else: ""

          "  • " <> row.item.text <> done <> if(extra == "", do: "", else: "  [#{extra}]")
        end)

      calcs =
        Enum.map(section.calcs, fn {calc, cells} ->
          results =
            cells
            |> Enum.zip(heads)
            |> Enum.reject(&(elem(&1, 0) == ""))
            |> Enum.map_join("; ", fn {c, h} -> "#{h}: #{c}" end)

          "  #{Agenda.Core.NumberFormat.label(calc)}  [#{results}]"
        end)

      Enum.join([header | items] ++ calcs, "\n")
    end)
    |> Kernel.<>("\n")
  end
end
