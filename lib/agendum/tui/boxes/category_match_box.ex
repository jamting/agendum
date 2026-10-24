defmodule Agendum.TUI.Boxes.CategoryMatchBox do
  @moduledoc """
  A standard category's Advanced settings (Category Properties ▸ Advanced
  settings; User's Guide 19-14 to 19-15, SPEC R16b): its own Text
  matching, Match on, Required match strength, Confirm assignments,
  Ignore suffixes and Ignore accents, each Global (the file's, shown in
  brackets) unless set. SPACE shows the next choice (the arrows move);
  every change applies at once and is one undo step. ENTER closes
  the box; ESC closes it and cancels its changes (`Agendum.TUI.Boxes.BoxCancel`).
  Drawn from `@layout` (`Agendum.TUI.Boxes.Template`). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, indicator: "PROPS", cancels: true

  alias Agendum.TUI.Boxes.{AutoAssignBox, Box, Template}

  alias Agendum.TUI.State

  @choices [
    enabled: [:global, true, false],
    match_on: [:global, :item, :note, :both],
    strength: [:global, :exact, :partial, :minimal],
    confirm: [:global, :never, :always, :sometimes],
    ignore_suffixes: [:global, true, false],
    ignore_accents: [:global, true, false]
  ]

  @layout """
   Text matching           : [enabled                         ]
   Match on                : [match_on                        ]
   Required match strength : [strength                        ]
   Confirm assignments     : [confirm                         ]
   Ignore suffixes         : [ignore_suffixes                 ]
   Ignore accents          : [ignore_accents                  ]
  """

  @rows Template.fields(@layout)
  @grid Template.grid(@layout, @rows)

  def open(state, cat_id),
    do: State.push(state, %Agendum.TUI.Modes.CategoryMatch{cat_id: cat_id, cursor: 0})

  @impl Box
  # its keys are the settings box's (R65): SPACE changes the setting
  def handle(state, _mode, _key), do: state

  @impl Box
  def keymap(_mode), do: Box.settings_keymap()

  @impl Box
  def commands(_mode), do: Box.settings_commands()

  @impl Box
  def run(state, mode, :change), do: change(state, mode, 1)
  def run(state, mode, id), do: Box.run_settings(state, mode, @grid, id)

  defp change(state, mode, step) do
    field = Enum.at(@rows, mode.cursor)
    choices = Keyword.fetch!(@choices, field)
    current = Map.get(state.db.categories[mode.cat_id].match_overrides, field, :global)
    index = Enum.find_index(choices, &(&1 == current)) || 0
    value = Enum.at(choices, Integer.mod(index + step, length(choices)))
    State.run(state, {:set_match_override, mode.cat_id, field, value})
  end

  @impl Box
  def title(state, mode), do: "Advanced settings: " <> state.db.categories[mode.cat_id].name

  @impl Box
  def content(state, mode, inner, _max_rows) do
    Template.render(@layout, values(state, mode), selected: field(state, mode)) ++
      [[], Box.hint(keys(state, mode), inner)]
  end

  # each setting the category's own, or Global with the file's in brackets
  defp values(state, mode) do
    overrides = state.db.categories[mode.cat_id].match_overrides

    file =
      Map.put(Map.from_struct(state.db.match_settings), :confirm, state.db.confirm_assignments)

    Map.new(@rows, fn field ->
      case Map.fetch(overrides, field) do
        {:ok, value} -> {field, name(field, value)}
        :error -> {field, "Global (#{name(field, file[field])})"}
      end
    end)
  end

  @impl Box
  def keys(_state, _mode), do: Box.settings_keys()

  # the file's settings' help, each starting with what Global means
  @impl Box
  def help do
    AutoAssignBox.help()
    |> Map.take(@rows)
    |> Map.new(fn {field, text} -> {field, "Global: the file's setting. " <> text} end)
  end

  @doc ~S|The category manager's mark for a Match on of its own ("T= Note").|
  def manager_tag(%{match_on: match_on}), do: "T= " <> short_match_on(match_on)
  def manager_tag(_overrides), do: nil

  defp short_match_on(:item), do: "Item"
  defp short_match_on(:note), do: "Note"
  defp short_match_on(:both), do: "Both"

  defp name(field, value) when field in [:enabled], do: if(value, do: "On", else: "Off")

  defp name(field, value) when field in [:ignore_suffixes, :ignore_accents],
    do: if(value, do: "Yes", else: "No")

  defp name(:match_on, value),
    do: %{item: "Item text", note: "Note text", both: "Both item & note"}[value]

  defp name(:strength, value),
    do:
      %{exact: "Exact match - 100%", partial: "Partial match - 50%", minimal: "Minimal match"}[
        value
      ]

  defp name(:confirm, value),
    do: %{never: "Never", always: "Always", sometimes: "Sometimes"}[value]

  @impl Box
  def field(_state, mode), do: Enum.at(@rows, mode.cursor)

  # F8 and ALT-F8 (`Agendum.TUI.Boxes.BoxDefaults`): Global, as the file's
  # Auto-assign settings say (User's Guide 2-17: File Properties sets these
  # defaults)
  @impl Box
  def defaults(_state, mode) do
    Map.new(@rows, fn field ->
      {field,
       fn state ->
         if Map.has_key?(state.db.categories[mode.cat_id].match_overrides, field),
           do: State.run(state, {:set_match_override, mode.cat_id, field, :global}),
           else: state
       end}
    end)
  end
end
