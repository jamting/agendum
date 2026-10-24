defmodule Agendum.TUI.Render.KeyBar do
  @moduledoc """
  The function key bar on the last two lines: the keys of what is on top
  (SPEC § The key bar). Pure.

  In a view, a note and the category and view managers it is Agenda's: ten
  fixed slots, one per function key, the key above its label, `│` between
  them; a key that does nothing there leaves its slot empty, so F8 is always
  in the same place. Elsewhere (boxes, the menu, typing, moves) the bottom
  line names the keys side by side, until each place is compared with
  Agenda's; what does not fit is left out whole, never cut mid-word.
  """

  alias Agendum.TUI.{Commands, Keymap, Typing.Completion, Terminal.Draw, State}

  # boxes with a module of their own (`Agendum.TUI.Boxes.Box`) list their keys
  @boxes Agendum.TUI.Boxes.Box.registry()

  # Each key has a short label, as in Agenda's 8-character slots, and may
  # have a fuller one (and a fuller name, "CTRL-N" for "^N"). The bar shows
  # the fuller ones when the extras are on (R77) and they all fit the
  # screen's width, the short ones otherwise: {key, label} | {key, label, full label} |
  # {key, label, full key, full label}.
  @doc "The key bar's two lines."
  @spec lines(State.t()) :: [Draw.line()]
  def lines(state) do
    case slotted(state) do
      nil -> [Draw.line([], state.width, :keybar), hint_line(state)]
      place -> slot_lines(state, place)
    end
  end

  # The place whose bar has Agenda's slots, or nil for a bar of hints.
  defp slotted(state) do
    if state.edit == nil and not Completion.active?(state), do: place(State.mode(state))
  end

  defp place(nil), do: :view
  defp place(%{type: type}) when type in [:note, :catmgr, :viewmgr], do: type
  defp place(_mode), do: nil

  @doc """
  The ten slots of `place`'s bar (`:view`, `:note`, `:catmgr`, `:viewmgr`)
  with `held` (`:none`, `:alt`, `:ctrl` or `:shift`), each `{label, fuller
  label}`, `{"", ""}` when its key does nothing there. Made from the keymaps
  (ADR 0045): the command the place binds the key to (or every screen
  does), with its short label; a macro attached to the key, by its name
  (R50). An extra's command is left out while the extras are off (R77).
  """
  @spec slots(State.t(), atom, :none | :alt | :ctrl | :shift) :: [{String.t(), String.t()}]
  def slots(state, place, held) do
    for n <- 1..10 do
      key = slot_key(held, n)

      case Agendum.TUI.Macros.attached(state, key) do
        nil -> command_slot(state, place, key)
        macro -> {String.slice(macro.name, 0, 7), macro.name}
      end
    end
  end

  defp slot_key(:none, n), do: {:f, n}
  defp slot_key(:alt, n), do: {:alt_f, n}
  defp slot_key(:ctrl, n), do: {:ctrl_f, n}
  defp slot_key(:shift, n), do: {:shift_f, n}

  # the place's own binding first, then the keys of every screen; `with`
  # stops at the first step that does not match, giving the empty slot
  defp command_slot(state, place, key) do
    with id when id != nil <- Keymap.lookup(place, key) || Keymap.lookup(:global, key),
         %{label: label} = command when label != nil <-
           Commands.get(place, id) || Commands.get(:global, id),
         false <- command.extra and not state.prefs.extras do
      {label, command.name}
    else
      _ -> {"", ""}
    end
  end

  # Domain: Agenda's slots are 8 columns at 80 (7 for the text, 1 for the
  # `│`); a wider screen widens them evenly. The fuller labels are an extra
  # (R77), and show only when every one fits its slot.
  defp slot_lines(state, place) do
    text = div(state.width, 10) - 1
    slots = slots(state, place, :none)

    full? =
      state.prefs.extras and Enum.all?(slots, fn {_, full} -> String.length(full) <= text end)

    labels = Enum.map(slots, fn {short, full} -> if full?, do: full, else: short end)

    [
      slot_line(Enum.map(1..10, &"F#{&1}"), text, :keybar_key, state.width),
      slot_line(labels, text, :keybar, state.width)
    ]
  end

  # the texts centred in their slots (a spare column goes on the right, as
  # Agenda's " Help  "), cut to the slot on a narrow screen
  defp slot_line(texts, width, style, screen_width) do
    texts
    |> Enum.map(fn text ->
      text = String.slice(text, 0, width)
      left = div(width - String.length(text), 2)
      {style, Draw.pad(String.duplicate(" ", left) <> text, width)}
    end)
    |> Enum.intersperse({:keybar, "│"})
    |> Draw.line(screen_width, :keybar)
  end

  # The one-line bar of the places without slots.
  defp hint_line(state) do
    # a box on top names ENTER and ESC in its bottom edge too
    box? = state.edit == nil and not Completion.active?(state) and box_on_top?(state)

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
          case State.mode(state) do
            mode when is_map_key(@boxes, mode.type) -> @boxes[mode.type].keys(state, mode)
            mode -> mode_keys(mode)
          end
      end
      |> Enum.map(&full_entry/1)

    keys = Enum.map(keys, &attached_label(state, &1))
    full = keybar_segments(keys, fn {_, _, key, label} -> {key, label} end, " ")
    # the fuller labels are an extra (R77): Agenda's short ones otherwise
    segments =
      if state.prefs.extras and Draw.width(full) <= state.width,
        do: full,
        else: short_fitting(keys, state.width, box?)

    Draw.line(segments, state.width, :keybar)
  end

  defp box_on_top?(state) do
    case State.mode(state) do
      nil -> false
      mode -> is_map_key(@boxes, mode.type)
    end
  end

  # The short bar with as many whole entries as fit `width`, never a label
  # cut mid-word: all of them; in a box, without ENTER and ESC (its bottom
  # edge names them); then one fewer from the end at a time.
  # `Stream.iterate/2` makes the ever shorter lists lazily, `Enum.find/2`
  # stops at the first that fits; an empty bar always does.
  defp short_fitting(keys, width, box?) do
    keys = if box? and not fits?(keys, width), do: Enum.reject(keys, &closing?/1), else: keys

    keys
    |> Stream.iterate(&Enum.drop(&1, -1))
    |> Enum.find(&fits?(&1, width))
    |> short_segments()
  end

  defp fits?(keys, width), do: Draw.width(short_segments(keys)) <= width

  defp short_segments(keys),
    do: keybar_segments(keys, fn {key, label, _, _} -> {key, label} end, "")

  defp closing?({key, _, _, _}), do: key in ["ENTER", "ESC"]

  # a function key attached to a macro shows the macro's name, as in
  # Agenda (its first seven letters in the short bar, R50)
  defp attached_label(state, {"F" <> n = key, _, long_key, _} = entry) do
    case Integer.parse(n) do
      {number, ""} ->
        case Agendum.TUI.Macros.attached(state, {:f, number}) do
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

  defp mode_keys(%{type: :browse, shift: %{}}),
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

  defp mode_keys(%{type: :searching}),
    do: [
      {"ALT-N", "Next", "Next match"},
      {"ALT-P", "Previous", "Previous match"},
      {"F7", "Mark", "Mark the item"},
      {"ENTER/ESC", "End search"}
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

  defp mode_keys(%{type: :help, page: :commands}),
    do: [{"↑↓", "Move"}, {"← →", "More"}, {"ENTER", "Run"}, {"ESC", "Return"}]

  defp mode_keys(%{type: :help, page: :describe}),
    do: [{"any key", "Describe it"}, {"ESC", "Return"}]

  defp mode_keys(%{type: :help, page: :all}),
    do: [{"↑↓", "Scroll"}, {"any other key", "Return"}]

  defp mode_keys(%{type: :help}),
    do: [
      {"↑↓", "Scroll"},
      {"c", "Commands"},
      {"d", "Describe key"},
      {"a", "All keys"},
      {"any other key", "Return"}
    ]

  defp mode_keys(%{type: :column_width}),
    do: [
      {"←→", "Width", "← →", "Narrower, wider"},
      {"?", "Fit", "SHIFT-?", "Fit to contents"},
      {"ENTER", "Keep"},
      {"ESC", "Cancel"}
    ]

  defp mode_keys(%{type: :column_move}),
    do: [
      {"←→", "Move", "← → or < >", "Move the column"},
      {"ENTER", "Here", "Keep it here"},
      {"ESC", "Cancel", "Put it back"}
    ]

  defp mode_keys(%{type: :section_move}),
    do: [
      {"↑↓", "Move", "↑ ↓ or < >", "Move the section"},
      {"ENTER", "Here", "Keep it here"},
      {"ESC", "Cancel", "Put it back"}
    ]

  defp mode_keys(%{type: :move_item}),
    do: [
      {"↑↓", "Choose position", "Choose where it goes"},
      {"ENTER", "Move here"},
      {"ESC", "Cancel"}
    ]

  defp mode_keys(%{type: :prompt}), do: [{"ENTER", "Accept"}, {"ESC", "Cancel"}]
end
