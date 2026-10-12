defmodule Agenda.TUI.CustomizeBox do
  @moduledoc """
  The Customize box (File ▸ Customize; Agenda's Utilities Customize,
  ADR 0008): the person's own settings, for every file: Theme (R40), Date
  language and Fallback language (R14c), Input format, which opens
  `Agenda.TUI.InputFormatBox` (R41b), Display key map, Confirm mode and
  Auto-save interval (R54). A change applies at once, is not
  part of undo, and is saved to the preferences file
  (`State.change_preference/3`).

  ↑↓ choose a setting; SPACE or → shows the next choice, ← the previous
  one. ESC or ENTER closes the box. Pure.
  """

  alias Agenda.Core.DateLanguage
  alias Agenda.TUI.{InputFormatBox, State, Theme}

  @rows [:theme, :lang, :fallback, :input_format, :key_map, :confirm, :auto_save]
  # Agenda took any number of minutes from 1 to 60; these are the steps
  @auto_save [0, 1, 2, 5, 10, 15, 20, 30, 45, 60]

  def open(state), do: State.push(state, %{type: :customize, cursor: 0})

  def handle(state, mode, key) do
    row = Enum.at(@rows, mode.cursor)

    case key do
      k when k in [:esc, :enter] -> State.pop(state)
      :up -> State.put_mode(state, %{mode | cursor: max(mode.cursor - 1, 0)})
      :down -> State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, length(@rows) - 1)})
      k when k in [{:char, " "}, :right] -> change(state, row, 1)
      :left -> change(state, row, -1)
      _ -> state
    end
  end

  defp change(state, :input_format, _step), do: InputFormatBox.open(state)
  defp change(state, :key_map, _step), do: State.toggle_key_map(state)

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

  defp set_languages(state, languages),
    do:
      State.change_preference(state, &%{&1 | languages: languages}, &%{&1 | languages: languages})

  defp next(list, value, step) do
    index = Enum.find_index(list, &(&1 == value)) || 0
    Enum.at(list, Integer.mod(index + step, length(list)))
  end

  @doc "`{label, value}` for each row."
  def lines(state) do
    [main | rest] = state.languages

    [
      {"Theme", state.theme |> Atom.to_string() |> String.capitalize()},
      {"Date language", String.capitalize(main.name())},
      {"Fallback language",
       case rest do
         [fallback | _] -> String.capitalize(fallback.name())
         [] -> "None"
       end},
      {"Input format", "(SPACE)"},
      {"Display key map", yes_no(state.key_map)},
      {"Confirm mode", yes_no(state.prefs.confirm)},
      {"Auto-save interval", minutes(state.prefs.auto_save)}
    ]
  end

  defp minutes(0), do: "Off"
  defp minutes(1), do: "1 minute"
  defp minutes(n), do: "#{n} minutes"

  defp yes_no(true), do: "Yes"
  defp yes_no(false), do: "No"
end
