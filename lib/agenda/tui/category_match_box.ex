defmodule Agenda.TUI.CategoryMatchBox do
  @moduledoc """
  A standard category's Advanced settings (Category Properties ▸ Advanced
  settings; User's Guide 19-14 to 19-15, SPEC R16b): its own Text
  matching, Match on, Required match strength, Confirm assignments,
  Ignore suffixes and Ignore accents, each Global (the file's, shown in
  brackets) unless set. SPACE shows the next choice (the arrows move);
  every change applies at once and is one undo step. ENTER closes
  the box; ESC closes it and cancels its changes (`Agenda.TUI.BoxCancel`).
  Pure.
  """

  import Agenda.TUI.BoxNav, only: [is_move: 1]
  alias Agenda.TUI.BoxNav

  alias Agenda.Core
  alias Agenda.TUI.State

  @choices [
    enabled: [:global, true, false],
    match_on: [:global, :item, :note, :both],
    strength: [:global, :exact, :partial, :minimal],
    confirm: [:global, :never, :always, :sometimes],
    ignore_suffixes: [:global, true, false],
    ignore_accents: [:global, true, false]
  ]
  @rows Keyword.keys(@choices)

  @labels %{
    enabled: "Text matching",
    match_on: "Match on",
    strength: "Required match strength",
    confirm: "Confirm assignments",
    ignore_suffixes: "Ignore suffixes",
    ignore_accents: "Ignore accents"
  }

  def open(state, cat_id),
    do: State.push(state, %{type: :category_match, cat_id: cat_id, cursor: 0})

  def handle(state, mode, key) do
    case key do
      k when k in [:esc, :enter] -> State.pop(state)
      k when is_move(k) -> BoxNav.move(state, mode, BoxNav.column(@rows), k)
      {:char, " "} -> change(state, mode, 1)
      _ -> state
    end
  end

  defp change(state, mode, step) do
    field = Enum.at(@rows, mode.cursor)
    choices = Keyword.fetch!(@choices, field)
    current = Map.get(state.db.categories[mode.cat_id].match_overrides, field, :global)
    index = Enum.find_index(choices, &(&1 == current)) || 0
    value = Enum.at(choices, Integer.mod(index + step, length(choices)))
    {:ok, db} = Core.set_match_override(state.db, mode.cat_id, field, value)
    State.change_db(state, db)
  end

  @doc "`{label, value}` for each row."
  def lines(state, mode) do
    overrides = state.db.categories[mode.cat_id].match_overrides

    file =
      Map.put(Map.from_struct(state.db.match_settings), :confirm, state.db.confirm_assignments)

    for field <- @rows do
      value =
        case Map.fetch(overrides, field) do
          {:ok, value} -> name(field, value)
          :error -> "Global (#{name(field, file[field])})"
        end

      {@labels[field], value}
    end
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

  @doc "The highlighted field, for its help in the control panel (`Agenda.TUI.FieldHelp`)."
  def field(_state, mode), do: Enum.at(@rows, mode.cursor)
end
