defmodule Agendum.TUI.Boxes.AutoAssignBox do
  @moduledoc """
  File Properties ▸ Auto-assign settings (User's Guide 19-7 to 19-12, SPEC
  R16, R16a): Text matching, Match on, Required match strength, Confirm
  assignments, Ignore text enclosed by, Ignore suffixes and Ignore
  accents. SPACE shows the next choice (the arrows move); every
  change applies at once and is one undo step. ENTER closes the box; ESC
  closes it and cancels its changes (`Agendum.TUI.Boxes.BoxCancel`). Drawn
  from `@layout` (`Agendum.TUI.Boxes.Template`). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, indicator: "PROPS", cancels: true

  import Agendum.TUI.Boxes.BoxNav, only: [is_move: 1]
  alias Agendum.TUI.Boxes.{Box, BoxNav, Template}

  alias Agendum.Core
  alias Agendum.Core.TextMatch
  alias Agendum.TUI.State

  @layout """
   Text matching           : [enabled                         ]
   Match on                : [match_on                        ]
   Required match strength : [strength                        ]
   Confirm assignments     : [confirm                         ]
   Ignore text enclosed by : [enclosed_by                     ]
   Ignore suffixes         : [ignore_suffixes                 ]
   Ignore accents          : [ignore_accents                  ]
  """

  @rows Template.fields(@layout)
  @grid Template.grid(@layout, @rows)

  # also the base of a category's own settings (`Agendum.TUI.Boxes.CategoryMatchBox`)
  @help %{
    enabled:
      "Assign items to categories whose names or Also match words are in their text. " <>
        "SPACE switches.",
    match_on:
      "Choose whether to match the item text, the note, or both. SPACE for the next choice.",
    strength:
      "How closely text must match a name: exact, partial or minimal. SPACE for the next.",
    confirm:
      "Whether Agendum asks before assigning by text (Utilities Questions). " <>
        "SPACE for the next.",
    enclosed_by: "Text between these characters is not matched. SPACE for the next choice.",
    ignore_suffixes:
      "Match a name with endings such as -s, -ed or -ing (Call matches Calls). SPACE switches.",
    ignore_accents: "Match letters with and without accents alike (é and e). SPACE switches."
  }
  @confirm [:never, :always, :sometimes]

  def open(state), do: State.push(state, %{type: :auto_assign, cursor: 0})

  @impl Box
  def handle(state, mode, key) do
    case key do
      k when k in [:esc, :enter] -> State.pop(state)
      k when is_move(k) -> BoxNav.move(state, mode, @grid, k)
      {:char, " "} -> change(state, Enum.at(@rows, mode.cursor), 1)
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

  @impl Box
  def title(_state, _mode), do: "Auto-assign settings"

  @impl Box
  def content(state, mode, inner, _max_rows) do
    Template.render(@layout, values(state), selected: field(state, mode)) ++
      [[], Box.hint(keys(state, mode), inner)]
  end

  defp values(state) do
    s = state.db.match_settings
    yes_no = &if(&1, do: "Yes", else: "No")

    %{
      enabled: if(s.enabled, do: "On", else: "Off"),
      match_on: %{item: "Item text", note: "Note text", both: "Both item & note"}[s.match_on],
      strength:
        %{exact: "Exact match - 100%", partial: "Partial match - 50%", minimal: "Minimal match"}[
          s.strength
        ],
      confirm:
        %{never: "Never", always: "Always", sometimes: "Sometimes"}[state.db.confirm_assignments],
      enclosed_by: TextMatch.encloser_label(s.enclosed_by),
      ignore_suffixes: yes_no.(s.ignore_suffixes),
      ignore_accents: yes_no.(s.ignore_accents)
    }
  end

  @impl Box
  def keys(_state, _mode), do: Box.settings_keys()

  @impl Box
  def help, do: @help

  @impl Box
  def field(_state, mode), do: Enum.at(@rows, mode.cursor)
end
