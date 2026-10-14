defmodule Agendum.TUI.Boxes.CustomizeBox do
  @moduledoc """
  The Customize box (File ▸ Customize; Agenda's Utilities Customize,
  ADR 0008): the person's own settings, for every file: Theme (R40), Date
  language and Fallback language (R14c), Input format, which opens
  `Agendum.TUI.Boxes.InputFormatBox` (R41b), Display key map, Confirm mode,
  Auto-save interval and the Decimal and Thousands separators (R54). A
  change applies at once, is not part of undo, and is saved to the
  preferences file (`State.change_preference/3`).

  The box is drawn from `@layout` (`Agendum.TUI.Boxes.Template`): the rows and
  their order, for the cursor too, are the fields there.

  The arrows choose a setting (`Agendum.TUI.Boxes.BoxNav`); SPACE shows the next choice.
  ENTER closes the box; ESC closes it and cancels its changes
  (`Agendum.TUI.Boxes.BoxCancel`). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, indicator: "PROPS", cancels: true

  import Agendum.TUI.Boxes.BoxNav, only: [is_move: 1]
  alias Agendum.TUI.Boxes.{Box, BoxNav}

  alias Agendum.Core.{DateLanguage, InputFormat}
  alias Agendum.TUI.{Boxes.InputFormatBox, State, Boxes.Template, Terminal.Theme}

  @layout """
   Theme               : [theme                ]
   Date language       : [lang                 ]
   Fallback language   : [fallback             ]
   Input format        : [input_format         ]
   Display key map     : [key_map              ]
   Confirm mode        : [confirm              ]
   Auto-save interval  : [auto_save            ]
   Decimal separator   : [decimal              ]
   Thousands separator : [thousands            ]

   Saved in your preferences, not in this file.
  """
  @rows Template.fields(@layout)
  @grid Template.grid(@layout, @rows)

  @help %{
    theme: "The colours Agendum draws with, in every file. SPACE for the next theme.",
    lang:
      "The language you type dates in (\"next friday\", \"nästa fredag\"). " <>
        "SPACE for the next.",
    fallback: "A second language dates are read in as well. SPACE for the next, or None.",
    input_format:
      "How you type dates and times: the order of the numbers, the separator and the clock. " <>
        "SPACE opens the box.",
    key_map: "Whether the key bar shows at the bottom of the screen (ALT-K too). SPACE switches.",
    confirm:
      "Choose whether Agendum asks \"are you sure?\" before discarding or removing. " <>
        "SPACE switches.",
    auto_save:
      "Save the file by itself after this many minutes without a key. " <>
        "SPACE for the next interval.",
    decimal: "The character before the decimals of a number you type. SPACE switches.",
    thousands: "The character between thousands in a number you type. SPACE for the next choice."
  }
  # Agenda took any number of minutes from 1 to 60; these are the steps
  @auto_save [0, 1, 2, 5, 10, 15, 20, 30, 45, 60]

  def open(state), do: State.push(state, %{type: :customize, cursor: 0})

  @impl Box
  def handle(state, mode, key) do
    row = Enum.at(@rows, mode.cursor)

    case key do
      k when k in [:esc, :enter] -> State.pop(state)
      k when is_move(k) -> BoxNav.move(state, mode, @grid, k)
      {:char, " "} -> change(state, row, 1)
      _ -> state
    end
  end

  defp change(state, :input_format, _step), do: InputFormatBox.open(state)
  defp change(state, :key_map, _step), do: State.toggle_key_map(state)

  # the separators are part of the person's input format (R54)
  defp change(state, :decimal, step) do
    [decimal: decimal, thousands: _] = State.number_opts(state)
    set_input(state, :decimal, next(InputFormat.decimals(), decimal, step))
  end

  defp change(state, :thousands, step) do
    [decimal: decimal, thousands: thousands] = State.number_opts(state)
    set_input(state, :thousands, next(InputFormat.thousands() -- [decimal], thousands, step))
  end

  defp change(state, :auto_save, step) do
    minutes = next(@auto_save, state.prefs.auto_save, step)
    State.change_preference(state, & &1, &%{&1 | auto_save: minutes})
  end

  defp change(state, :confirm, _step) do
    on = not state.prefs.confirm
    State.change_preference(state, & &1, &%{&1 | confirm: on})
  end

  defp change(state, :theme, step) do
    theme = next(Theme.names(), state.theme, step)
    State.change_preference(state, &%{&1 | theme: theme}, &%{&1 | theme: theme})
  end

  # the main language and the fallback are saved together
  defp change(state, :lang, step) do
    [main | rest] = state.languages
    main = next(DateLanguage.packs(), main, step)
    set_languages(state, Enum.uniq([main | rest]))
  end

  defp change(state, :fallback, step) do
    [main | rest] = state.languages
    choices = [nil | DateLanguage.packs() -- [main]]
    fallback = next(choices, List.first(rest), step)
    set_languages(state, [main | List.wrap(fallback)])
  end

  defp set_input(state, field, value) do
    State.change_preference(
      state,
      &%{&1 | input: Map.put(&1.input, field, value)},
      &%{&1 | input: Map.put(&1.input, field, value)}
    )
  end

  defp set_languages(state, languages),
    do:
      State.change_preference(state, &%{&1 | languages: languages}, &%{&1 | languages: languages})

  defp next(list, value, step) do
    index = Enum.find_index(list, &(&1 == value)) || 0
    Enum.at(list, Integer.mod(index + step, length(list)))
  end

  @impl Box
  def title(_state, _mode), do: "Customize (yours, for every file)"

  @impl Box
  def content(state, mode, inner, _max_rows) do
    Template.render(@layout, values(state), selected: field(state, mode)) ++
      [Box.hint(keys(state, mode), inner)]
  end

  @impl Box
  def keys(_state, _mode), do: Box.settings_keys()

  @impl Box
  def help, do: @help

  defp values(state) do
    [main | rest] = state.languages
    numbers = State.number_opts(state)

    %{
      theme: Theme.label(state.theme),
      lang: String.capitalize(main.name()),
      fallback:
        case rest do
          [fallback | _] -> String.capitalize(fallback.name())
          [] -> "None"
        end,
      input_format: "(SPACE)",
      key_map: yes_no(state.key_map),
      confirm: yes_no(state.prefs.confirm),
      auto_save: minutes(state.prefs.auto_save),
      decimal: separator(numbers[:decimal]),
      thousands: separator(numbers[:thousands])
    }
  end

  # as Agenda listed them: ". (Dot)"
  defp separator("."), do: ". (Dot)"
  defp separator(","), do: ", (Comma)"
  defp separator(" "), do: "  (Space)"

  defp minutes(0), do: "Off"
  defp minutes(1), do: "1 minute"
  defp minutes(n), do: "#{n} minutes"

  defp yes_no(true), do: "Yes"
  defp yes_no(false), do: "No"

  @impl Box
  def field(_state, mode), do: Enum.at(@rows, mode.cursor)
end
