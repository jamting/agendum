defmodule Agenda.TUI.AutoAssignBox do
  @moduledoc """
  File Properties ▸ Auto-assign settings (User's Guide 19-7 to 19-12, SPEC
  R16, R16a): Text matching, Match on, Required match strength, Confirm
  assignments, Ignore text enclosed by, Ignore suffixes and Ignore
  accents. SPACE or → shows the next choice, ← the previous one; every
  change applies at once and is one undo step. ESC or ENTER closes the
  box. Pure.
  """

  alias Agenda.Core
  alias Agenda.Core.TextMatch
  alias Agenda.TUI.State

  @rows [
    :enabled,
    :match_on,
    :strength,
    :confirm,
    :enclosed_by,
    :ignore_suffixes,
    :ignore_accents
  ]
  @confirm [:never, :always, :sometimes]

  def open(state), do: State.push(state, %{type: :auto_assign, cursor: 0})

  def handle(state, mode, key) do
    case key do
      k when k in [:esc, :enter] -> State.pop(state)
      :up -> State.put_mode(state, %{mode | cursor: max(mode.cursor - 1, 0)})
      :down -> State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, length(@rows) - 1)})
      k when k in [{:char, " "}, :right] -> change(state, Enum.at(@rows, mode.cursor), 1)
      :left -> change(state, Enum.at(@rows, mode.cursor), -1)
      _ -> state
    end
  end

  defp change(state, :confirm, step) do
    index = Enum.find_index(@confirm, &(&1 == state.db.confirm_assignments)) || 0
    mode = Enum.at(@confirm, Integer.mod(index + step, length(@confirm)))
    State.change_db(state, Core.set_confirm_assignments(state.db, mode))
  end

  defp change(state, row, step) do
    settings = TextMatch.cycle(state.db.match_settings, row, step)
    State.change_db(state, Core.set_match_settings(state.db, settings))
  end

  @doc "`{label, value}` for each row."
  def lines(state) do
    s = state.db.match_settings
    yes_no = &if(&1, do: "Yes", else: "No")

    [
      {"Text matching", if(s.enabled, do: "On", else: "Off")},
      {"Match on", %{item: "Item text", note: "Note text", both: "Both item & note"}[s.match_on]},
      {"Required match strength",
       %{exact: "Exact match - 100%", partial: "Partial match - 50%", minimal: "Minimal match"}[
         s.strength
       ]},
      {"Confirm assignments",
       %{never: "Never", always: "Always", sometimes: "Sometimes"}[state.db.confirm_assignments]},
      {"Ignore text enclosed by", TextMatch.encloser_label(s.enclosed_by)},
      {"Ignore suffixes", yes_no.(s.ignore_suffixes)},
      {"Ignore accents", yes_no.(s.ignore_accents)}
    ]
  end
end
