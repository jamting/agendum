defmodule Agenda.TUI.Render do
  @moduledoc """
  Turns a `State` into a screen (a list of styled lines). Pure.

  Screen layout, after Agenda 2.0:

      line 0      title bar: file, view, indicators, date
      lines 1–2   control panel: menu, prompts, messages, context
      lines 3..   body: the view, or a full-screen manager
      last line   function key bar
  """

  alias Agenda.Core.{Database, DateParser}
  alias Agenda.TUI.{CategoryScreens, Completion, Draw, Layout, Menu, State}

  @full_screen [:catmgr, :viewmgr, :help, :note]
  @boxes [:picker, :profile, :props, :choice, :item_props]

  @spec render(State.t()) :: [Draw.line()]
  def render(%State{width: w} = state) do
    {base, overlays} = split_modes(state.modes)
    body = body(state, base)
    body = Enum.reduce(overlays, body, &overlay_box(state, &1, &2))

    [title_bar(state, base)] ++
      control_panel(state) ++
      Enum.map(body, &Draw.line(&1, w)) ++
      [keybar(state)]
  end

  # The base is the topmost full-screen mode (or the view); boxes above it
  # are drawn on top, bottom-up.
  defp split_modes(modes) do
    {above, rest} = Enum.split_while(modes, &(&1.type not in @full_screen))
    base = List.first(rest)
    {base, above |> Enum.filter(&(&1.type in @boxes)) |> Enum.reverse()}
  end

  # --- title bar -------------------------------------------------------------------

  defp title_bar(state, base) do
    file = if state.path, do: Path.basename(state.path), else: "(untitled)"
    file = if state.dirty, do: file <> " *", else: file
    view = State.view(state)

    hides =
      [
        {view.hide_done, "[Hide Done]"},
        {view.hide_empty, "[Hide Empty]"},
        {view.hide_inherited, "[Hide Inherited]"},
        {not state.db.auto_date, "[No Auto Dates]"}
      ]
      |> Enum.filter(&elem(&1, 0))
      |> Enum.map_join(" ", &elem(&1, 1))

    marked = if Enum.any?(Database.items(state.db), & &1.marked), do: "♦ ", else: ""

    right =
      String.trim("#{hides} #{marked}#{indicator(state, base)}  #{Date.to_iso8601(state.today)} ")

    left = " File: #{file}"
    middle = "View: #{view.name}"
    gap = max(state.width - String.length(left) - String.length(right), 0)
    mid = Draw.center(middle, gap)

    Draw.line([{:title, left}, {:title, mid}, {:indicator, right}], state.width, :title)
  end

  defp indicator(state, base) do
    top = State.mode(state)

    cond do
      Completion.matches(state) != [] -> "AUTOC"
      state.edit != nil -> "EDIT"
      top && top.type == :menu -> "MENU"
      top && top.type == :move_item -> "MOVE"
      top && top.type == :picker -> "CHOICES"
      top && top.type == :profile -> "ASSIGN"
      top && top.type in [:props, :choice, :item_props] -> "PROPS"
      base && base.type == :catmgr -> "CAT MGR"
      base && base.type == :viewmgr -> "VW MGR"
      base && base.type == :note -> "NOTE"
      base && base.type == :help -> "HELP"
      true -> "READY"
    end
  end

  # --- control panel --------------------------------------------------------------------

  defp control_panel(%State{width: w} = state) do
    {l1, l2} =
      case State.mode(state) do
        %{type: :menu} = m ->
          menu_lines(m)

        %{type: :prompt, label: label} ->
          {[{:prompt, " #{label} "}] ++
             field(state.edit.line, w - String.length(label) - 3, :edit),
           [{:dim, " ENTER accepts, ESC cancels"}]}

        %{type: :confirm, question: q} ->
          {[{:prompt, " " <> q}], []}

        _ ->
          {message_line(state), context_line(state)}
      end

    [Draw.line(l1, w), Draw.line(l2, w)]
  end

  defp message_line(%State{message: {:error, text}}), do: [{:error, " #{text} "}]
  defp message_line(%State{message: {:message, text}}), do: [{:message, " " <> text}]

  defp message_line(%State{edit: %{target: {:column_entry, _, _, _}}, modes: []} = state) do
    if Completion.column_entry?(state),
      do: completion_line(state),
      else: [{:dim, " Enter a date (e.g. friday, next week, 12/24); ENTER to set"}]
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

  defp context_line(%State{modes: []} = state) do
    case Layout.current_row(state) do
      %{kind: :item, item: item} ->
        names =
          state.db
          |> Database.explicit_categories(item.id)
          |> Enum.sort()
          |> Enum.map_join(", ", &state.db.categories[&1].name)

        [{:dim, " Assigned to: " <> if(names == "", do: "(MAIN only)", else: names)}]

      %{kind: :section, category: cat, count: count} ->
        [{:dim, " Section: #{cat.name} (#{count} item#{if count == 1, do: "", else: "s"})"}]

      nil ->
        [{:dim, " This view has no sections. Press ALT-D to add one."}]
    end
  end

  defp context_line(_), do: []

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

  defp keybar(state) do
    keys =
      cond do
        Completion.active?(state) ->
          [
            {"ENTER", "Accept"},
            {"F8/A-N", "Next"},
            {"F7/A-P", "Previous"},
            {"INS/^N", "New category"},
            {"ESC", "Cancel"}
          ]

        state.edit != nil ->
          [
            {"ENTER", "Done"},
            {"ESC", "Cancel"},
            {"←→", "Move"},
            {"^A/^E", "Start/End"},
            {"^U", "Clear"}
          ]

        true ->
          mode_keys(State.mode(state))
      end

    segments =
      Enum.flat_map(keys, fn {k, label} -> [{:keybar_key, " " <> k}, {:keybar, " " <> label}] end)

    Draw.line(segments, state.width, :keybar)
  end

  defp mode_keys(nil),
    do: [
      {"F1", "Help"},
      {"F2", "Edit"},
      {"F3", "Choices"},
      {"F4", "Done"},
      {"F5", "Note"},
      {"F6", "Props"},
      {"F7", "Mark"},
      {"F8", "VwMgr"},
      {"F9", "CatMgr"},
      {"F10", "Menu"}
    ]

  defp mode_keys(%{type: :catmgr}),
    do: [
      {"F2", "Edit"},
      {"F5", "Note"},
      {"F6", "Props"},
      {"F7", "Promote"},
      {"F8", "Demote"},
      {"INS/^N", "Add"},
      {"DEL", "Discard"},
      {"A-F10", "Move"},
      {"ESC", "Return"}
    ]

  defp mode_keys(%{type: :viewmgr}),
    do: [
      {"ENTER", "Select"},
      {"INS", "Add"},
      {"F2", "Rename"},
      {"DEL", "Discard"},
      {"A-↑↓", "Reorder"},
      {"ESC", "Return"}
    ]

  defp mode_keys(%{type: :picker}),
    do: [{"ENTER", "Select"}, {"INS", "New category"}, {"type", "Search"}, {"ESC", "Cancel"}]

  defp mode_keys(%{type: :profile}), do: [{"SPACE", "Assign/Unassign"}, {"ESC", "Return"}]
  defp mode_keys(%{type: :props}), do: [{"ENTER", "Change"}, {"ESC", "Return"}]

  defp mode_keys(%{type: :item_props}),
    do: [
      {"ENTER", "Edit"},
      {"DEL", "Remove"},
      {"type", "Assign"},
      {"F4", "Date"},
      {"F3", "Profile"},
      {"ESC", "Close"}
    ]

  defp mode_keys(%{type: :choice}),
    do: [{"↑↓", "Highlight"}, {"ENTER", "Select"}, {"ESC", "Cancel"}]

  defp mode_keys(%{type: :note}), do: [{"ESC", "Return"}, {"F5", "Return"}]

  defp mode_keys(%{type: :menu}),
    do: [{"←→", "Highlight"}, {"ENTER", "Select"}, {"letter", "Select"}, {"ESC", "Back"}]

  defp mode_keys(%{type: :help}), do: [{"↑↓", "Scroll"}, {"any other key", "Return"}]

  defp mode_keys(%{type: :move_item}),
    do: [{"↑↓", "Choose position"}, {"ENTER", "Move here"}, {"ESC", "Cancel"}]

  defp mode_keys(%{type: :prompt}), do: [{"ENTER", "Accept"}, {"ESC", "Cancel"}]
  defp mode_keys(%{type: :confirm}), do: [{"Y", "Yes"}, {"N", "No"}, {"ESC", "Cancel"}]

  # --- body ------------------------------------------------------------------------------------

  defp body(state, nil), do: fit(view_lines(state), state)
  defp body(state, %{type: :catmgr} = mode), do: fit(catmgr_lines(state, mode), state)
  defp body(state, %{type: :viewmgr} = mode), do: fit(viewmgr_lines(state, mode), state)
  defp body(state, %{type: :help} = mode), do: fit(Enum.drop(help_lines(), mode.top), state)
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

      case editing do
        %{target: {:new_item, _, key}} when selected and key == row.key ->
          lines ++ [[{:symbol, " • "}] ++ field(editing.line, tw, :edit) ++ blank_cells(columns)]

        _ ->
          lines
      end
    end)
    |> Enum.drop(state.scroll)
  end

  defp row_lines(state, %{kind: :section} = row, index, selected, editing, tw, columns) do
    cat = row.category
    style = if selected and state.col == 0, do: :cursor, else: :section

    name_part =
      case editing do
        %{target: {:rename_category, id}} when selected and id == cat.id ->
          [{:normal, " "}] ++ field(editing.line, tw + 1, :edit)

        _ ->
          suffix = if row.collapsed, do: " §#{row.count}", else: ""
          [{:normal, " "}, {style, Draw.pad(cat.name <> suffix, tw + 1)}]
      end

    heads =
      Enum.flat_map(columns, fn c ->
        [
          {:normal, " "},
          {:column_head, Draw.pad(state.db.categories[c.category_id].name, c.width)}
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
              [
                {if(selected and state.col == i, do: :cursor_cell, else: :cell),
                 Draw.pad(cell, column.width)}
              ]
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
    visible = State.body_height(state) - 1
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

        line = name ++ [{:dim, category_tags(db, cat)}]

        case state.edit do
          %{target: {:new, parent, _}} when selected ->
            new_indent = String.duplicate("   ", Database.depth(db, parent) + 1)
            [line, [{:normal, " " <> new_indent}] ++ field(state.edit.line, 30, :edit)]

          _ ->
            [line]
        end
      end)
      |> Enum.drop(top)

    [
      [{:section, " Category Manager"}, {:dim, "  (#{map_size(db.categories)} categories)"}]
      | lines
    ]
  end

  defp category_tags(db, cat) do
    count =
      if Database.date_field(db, cat.id), do: nil, else: length(Database.items_in(db, cat.id))

    [
      cat.kind == :date && "date",
      cat.exclusive && "exclusive",
      cat.short_name && "aka #{cat.short_name}",
      cat.conditions != [] && "if " <> conditions_text(db, cat),
      cat.also_assign != [] &&
        "→ " <> Enum.map_join(cat.also_assign, ", ", &db.categories[&1].name),
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

    [[{:section, " View Manager"}], []] ++ views
  end

  # --- notes ---------------------------------------------------------------------------------------

  defp note_lines(state, mode) do
    edit = mode.edit
    visible = State.body_height(state) - 2
    top = max(edit.row - visible + 1, 0)

    lines =
      edit.lines
      |> Enum.with_index()
      |> Enum.map(fn {text, row} ->
        if row == edit.row,
          do: [{:normal, " "}] ++ Draw.field(text, edit.col, :normal),
          else: [{:normal, " " <> text}]
      end)
      |> Enum.drop(top)

    [[{:section, " Note: " <> mode.title}], []] ++ lines
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
     F7            Mark item
     F8 / F9       View manager / category manager
     F10 or /      Menu
     DEL           Remove from section or column   fn-⌫
     ALT-F4        Discard item                    CTRL-D
     ALT-F2        Set the When date (or menu Item When)
     ALT-F10       Move item to another section
     ALT-− / ALT-= Collapse / expand section (twice: all)
     ALT-D / ALT-U Add section below / above
     ALT-R / ALT-L Add column right / left
     ←→ TAB        Move between item and columns
     In a column   Type a name: the first match shows; ENTER accepts,
                   F8/ALT-N and F7/ALT-P cycle, INS/^N makes it a new one
     CTRL-PGUP/DN  Previous / next section         ⌥↑ / ⌥↓

   Everywhere
     CTRL-Z / CTRL-Y   Undo / redo
     CTRL-S            Save              CTRL-O   Open (retrieve) a file
     CTRL-P            Print to file     CTRL-Q   Quit

   In the category manager (F9)
     Type / INS    Add a category below            CTRL-N
     F2            Rename                          CTRL-E
     F7 / F8       Promote / demote
     ALT-↑ ALT-↓   Reorder among siblings          ⌥↑ / ⌥↓
     ALT-− / ALT-= Collapse / expand family (twice: all)   ESC - / ESC =
     ALT-F10       Move under another parent
     DEL           Discard category                CTRL-D
     F6            Properties (exclusive, short name, links)
     ESC / F9      Return to the view

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

  defp help_lines, do: @help |> String.split("\n") |> Enum.map(&[{:normal, &1}])

  # --- boxes -------------------------------------------------------------------------------------------

  defp overlay_box(state, mode, body) do
    inner = min(state.width - 8, 60)
    max_rows = max(State.body_height(state) - 4, 3)
    content = box_content(state, mode, inner, max_rows)
    box = Draw.box(box_title(state, mode), content, inner)
    left = div(state.width - inner - 2, 2)
    Draw.overlay(Enum.map(body, &Draw.line(&1, state.width)), box, 1, left)
  end

  defp box_title(state, %{type: :picker, purpose: purpose}) do
    case purpose do
      {:add_section, _} -> "Section head"
      {:change_section, _} -> "Change section head"
      {:add_column, _} -> "Column head"
      {:assign_column, _, head} -> "Choose " <> state.db.categories[head].name
      {:new_view, name} -> "First section for view #{name}"
      {:move_category, id} -> "New parent for " <> state.db.categories[id].name
      {:also_assign, id} -> "Also assign items of #{state.db.categories[id].name} to"
      {:condition, id} -> "Conditions for #{state.db.categories[id].name}"
    end
  end

  defp box_title(_state, %{type: :item_props}), do: "Item properties"

  defp box_title(state, %{type: :profile, item_id: id}),
    do: "Assignments: " <> String.slice(state.db.items[id].text, 0, 40)

  defp box_title(state, %{type: :choice, kind: :move, cat_id: id}),
    do: "Moving #{state.db.categories[id].name} creates a conflict"

  defp box_title(state, %{type: :choice, cat_id: id}),
    do: "Make children of #{state.db.categories[id].name} mutually exclusive"

  defp box_title(state, %{type: :props, cat_id: id}),
    do: "Category properties: " <> state.db.categories[id].name

  defp box_content(state, %{type: type} = mode, inner, max_rows)
       when type in [:picker, :profile] do
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

  defp box_content(state, %{type: :item_props} = mode, inner, max_rows) do
    item = state.db.items[mode.item_id]
    rows = Agenda.TUI.ItemProperties.rows(state, mode)
    cursor = min(mode.cursor, length(rows) - 1)
    value_width = inner - 16
    assignments = Agenda.Core.item_assignments(state.db, item.id)
    entered = Agenda.Core.DateParser.format(item.entry)

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
              {"Statistics", "#{length(assignments)} categories · entered #{entered}"}

            {:assigned, a} ->
              {if(a == hd(assignments), do: "Assigned to", else: ""),
               assignment_text(state.db, a)}

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
      exclusive: yes_no.(cat.exclusive),
      match_name: yes_no.(cat.match_name),
      also_assign:
        if(cat.also_assign == [],
          do: "(none)",
          else: Enum.map_join(cat.also_assign, ", ", &state.db.categories[&1].name)
        ),
      conditions: if(cat.conditions == [], do: "(none)", else: conditions_text(state.db, cat)),
      note: if(cat.note == "", do: "(none)", else: "#{String.length(cat.note)} characters")
    }

    labels = %{
      name: "Category name",
      short_name: "Short name",
      exclusive: "Children mutually exclusive",
      match_name: "Assign items mentioning it",
      also_assign: "Also assign items to",
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

      _ when elem(mode.purpose, 0) == :condition ->
        [{:box, " ENTER cycles: + assigned · - not assigned · none"}]

      _ ->
        [{:box, " ENTER selects · INS creates · type to search"}]
    end
  end

  defp box_footer(_state, %{type: :profile}, _inner),
    do: [{:box, " * assigned  c by a condition  + via subcategory  SPACE"}]

  defp profile_marker(state, %{type: :profile, item_id: item_id}, id) do
    db = state.db

    cond do
      field = Database.date_field(db, id) ->
        if Map.get(db.items[item_id], field), do: "◊", else: " "

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

  defp profile_marker(state, %{type: :picker, purpose: {:condition, cat_id}}, id) do
    case List.keyfind(state.db.categories[cat_id].conditions, id, 0) do
      {_, :assigned} -> "+"
      {_, :not_assigned} -> "-"
      nil -> " "
    end
  end

  defp profile_marker(state, %{type: :picker, purpose: {:also_assign, cat_id}}, id) do
    if id in state.db.categories[cat_id].also_assign, do: "*", else: " "
  end

  defp profile_marker(_state, _mode, _id), do: " "

  # "Taxes, not People": a category's assignment conditions in words.
  defp conditions_text(db, cat) do
    Enum.map_join(cat.conditions, ", ", fn
      {id, :assigned} -> db.categories[id].name
      {id, :not_assigned} -> "not " <> db.categories[id].name
    end)
  end

  # One assignment in the Item Properties box: "When (2026-10-13)",
  # "Anna Lasky (c)" for a conditional one.
  defp assignment_text(db, %{category: id, kind: kind, date: date}) do
    name = db.categories[id].name

    case kind do
      :date -> "#{name} (#{Agenda.Core.DateParser.format(date)})"
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
    |> Agenda.Core.ViewModel.build(view)
    |> Enum.map_join("\n\n", fn section ->
      header = Enum.join([section.category.name | heads], " | ")

      items =
        Enum.map(section.rows, fn row ->
          extra =
            row.cells
            |> Enum.zip(heads)
            |> Enum.reject(&(elem(&1, 0) == ""))
            |> Enum.map_join("; ", fn {c, h} -> "#{h}: #{c}" end)

          done = if row.item.done, do: " (done #{DateParser.format(row.item.done)})", else: ""
          "  • " <> row.item.text <> done <> if(extra == "", do: "", else: "  [#{extra}]")
        end)

      Enum.join([header | items], "\n")
    end)
    |> Kernel.<>("\n")
  end
end
