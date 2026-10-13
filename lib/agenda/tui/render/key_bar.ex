defmodule Agenda.TUI.Render.KeyBar do
  @moduledoc """
  The function key bar on the last line: the keys of what is on top. Pure.
  """

  alias Agenda.TUI.{Completion, Draw, State}

  # Each key has a short label, as in Agenda's 8-character slots, and may
  # have a fuller one (and a fuller name, "CTRL-N" for "^N"). The bar shows
  # the fuller ones when they all fit the screen's width, the short ones
  # otherwise: {key, label} | {key, label, full label} |
  # {key, label, full key, full label}.
  @doc "The key bar line."
  def line(state) do
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

    keys = Enum.map(keys, &attached_label(state, &1))
    full = keybar_segments(keys, fn {_, _, key, label} -> {key, label} end, " ")
    short = keybar_segments(keys, fn {key, label, _, _} -> {key, label} end, "")
    segments = if Draw.width(full) <= state.width, do: full, else: short
    Draw.line(segments, state.width, :keybar)
  end

  # a function key attached to a macro shows the macro's name, as in
  # Agenda (its first seven letters in the short bar, R50)
  defp attached_label(state, {"F" <> n = key, _, long_key, _} = entry) do
    case Integer.parse(n) do
      {number, ""} ->
        case Agenda.TUI.Macros.attached(state, {:f, number}) do
          nil -> entry
          macro -> {key, String.slice(macro.name, 0, 7), long_key, macro.name}
        end

      _ ->
        entry
    end
  end

  defp attached_label(_state, entry), do: entry

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

  defp mode_keys(%{type: :calendar, target: target}),
    do: [
      {"←→↑↓", "Day/week", "←→ ↑↓", "Day, week"},
      {"PGUP/DN", "Month", "PGUP/PGDN", "Month"},
      {"^←→", "Year", "CTRL-←→ or < >", "Year"},
      {"ENTER", if(target, do: "Select", else: "Close"),
       if(target, do: "Set the date", else: "Close")},
      {"F6", "Time", "Set a time"},
      {"type", "Go to", "Type a date to go there"},
      {"ESC", "Cancel"}
    ]

  defp mode_keys(%{type: :browse, shift: _}),
    do: [
      {"←→", "Day", "← →", "A day"},
      {"↑↓", "Week", "↑↓ or CTRL-←→", "A week"},
      {"PGUP/DN", "Month", "PGUP/PGDN", "A month"},
      {"^PGUP/DN", "Year", "CTRL-PGUP/PGDN", "A year"},
      {"A-F5", "Go to", "ALT-F5", "Go to a date"},
      {"ENTER", "Keep"},
      {"ESC", "Back"}
    ]

  defp mode_keys(%{type: :browse}),
    do: [
      {"←→", "Period", "← → or < >", "Previous / next period"},
      {"A-F5", "Go to", "ALT-F5", "Go to a date"},
      {"ENTER", "Keep", "Keep this period"},
      {"ESC", "Back", "Back to where it was"}
    ]

  defp mode_keys(%{type: :macros}),
    do: [
      {"ENTER", "Run", "Run the macro"},
      {"INS/^N", "New", "INS/CTRL-N", "New macro"},
      {"F7", "Learn", "Record its keys"},
      {"F2", "Edit", "Edit its keys"},
      {"F6", "Props", "Properties"},
      {"DEL", "Delete"},
      {"A-F5", "Sort", "ALT-F5", "Sort by name"},
      {"A-↑↓", "Move", "ALT-↑↓", "Move"},
      {"ESC", "Close"}
    ]

  defp mode_keys(%{type: :select_file}),
    do: [
      {"ENTER", "Open", "Open the folder or pick the file"},
      {"type", "Narrow", "Narrow the list"},
      {"F7", "Dates", "Show the dates"},
      {"ESC", "Back", "Back to the prompt"}
    ]

  defp mode_keys(%{type: :macro_props}),
    do: [
      {"↑↓", "Setting", "Move between settings"},
      {"ENTER", "Change", "Change the setting"},
      {"SPACE", "Yes/No", "Switch Yes/No"},
      {"DEL", "Detach", "Detach the key"},
      {"ESC", "Close"}
    ]

  defp mode_keys(%{type: :schedule}),
    do: [
      {"↑↓", "Setting", "Move between settings"},
      {"SPACE", "Change", "Change the setting"},
      {"F3", "Calendar", "Pick the date"},
      {"ENTER", "Show", "Show the schedule"},
      {"ESC", "Cancel"}
    ]

  defp mode_keys(%{type: :datebook_props}),
    do: [
      {"↑↓", "Setting", "Move between settings"},
      {"ENTER", "Pick/type", "Pick a category or type a value"},
      {"SPACE", "Next", "SPACE/→", "Next choice"},
      {"←", "Previous", "Previous choice"},
      {"DEL", "Clear", "Clear the End category"},
      {"ESC", "Close"}
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
              :column_add,
              :category_match,
              :auto_assign,
              :date_rule,
              :input_format,
              :customize,
              :file_props,
              :date_settings,
              :display_format
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

  defp mode_keys(%{type: :column_width}),
    do: [
      {"←→", "Width", "← →", "Narrower, wider"},
      {"?", "Fit", "SHIFT-?", "Fit to contents"},
      {"ENTER", "Keep"},
      {"ESC", "Cancel"}
    ]

  defp mode_keys(%{type: :move_item}),
    do: [
      {"↑↓", "Choose position", "Choose where it goes"},
      {"ENTER", "Move here"},
      {"ESC", "Cancel"}
    ]

  defp mode_keys(%{type: :prompt}), do: [{"ENTER", "Accept"}, {"ESC", "Cancel"}]
  defp mode_keys(%{type: :confirm}), do: [{"Y", "Yes"}, {"N", "No"}, {"ESC", "Cancel"}]
end
