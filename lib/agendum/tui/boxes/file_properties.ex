defmodule Agendum.TUI.Boxes.FileProperties do
  @moduledoc """
  The File Properties box (File ▸ Properties; User's Guide 7-13 to 7-17)
  and the boxes it opens, nested as in Agenda 2.0, each row with "..."
  opening the next box:

    * File Properties (`:file_props`): Insert new columns in (R55), Global
      date settings ..., and Auto-assign settings ...
      (`Agendum.TUI.Boxes.AutoAssignBox`, R16a). Drawn from `@layout`
      (`Agendum.TUI.Boxes.Template`), Agenda's box (screenshot 130) with only the
      settings Agendum has
    * Global Date Settings (`Agendum.TUI.Boxes.DateSettingsBox`, R14e)
    * Display Format (`Agendum.TUI.Boxes.DisplayFormatBox`, R41)

  SPACE shows the next choice (or opens a "..." box), the arrows move
  between settings (`Agendum.TUI.Boxes.BoxNav`); every change applies at once
  and is one undo step. ENTER closes
  the box, ESC closes it and cancels its changes (`Agendum.TUI.Boxes.BoxCancel`);
  either goes back to the box beneath. Pure.
  """

  import Agendum.TUI.Boxes.BoxNav, only: [is_move: 1]
  alias Agendum.TUI.Boxes.BoxNav

  alias Agendum.Core
  alias Agendum.TUI.{State, Boxes.Template}

  # Agenda's File Properties (screenshot 130), its other settings left out
  # until Agendum has them
  @layout """
   Insert new columns in:  [insert_columns ]

   Global date settings:   [dates]   Auto-assign settings:  [auto ]

   SPACE next choice or open ... · arrows move
  """

  @rows %{file_props: Template.fields(@layout)}
  # File Properties has two settings side by side; the others one a row
  defp grid(:file_props), do: Template.grid(@layout, @rows.file_props)
  defp grid(type), do: BoxNav.column(@rows[type])

  def open(state, type \\ :file_props), do: State.push(state, %{type: type, cursor: 0})

  def handle(state, mode, key) do
    rows = @rows[mode.type]
    row = Enum.at(rows, mode.cursor)

    case key do
      k when k in [:esc, :enter] -> State.pop(state)
      k when is_move(k) -> BoxNav.move(state, mode, grid(mode.type), k)
      {:char, " "} -> change(state, row, 1)
      _ -> state
    end
  end

  defp change(state, :dates, _step), do: Agendum.TUI.Boxes.DateSettingsBox.open(state)
  defp change(state, :display_format, _step), do: Agendum.TUI.Boxes.DisplayFormatBox.open(state)
  defp change(state, :auto, _step), do: Agendum.TUI.Boxes.AutoAssignBox.open(state)

  # two choices, so SPACE, → and ← all flip it
  defp change(state, :insert_columns, _step) do
    where = if state.db.insert_columns == :all, do: :section, else: :all
    State.change_db(state, Core.set_insert_columns(state.db, where))
  end

  @doc "The File Properties box's lines, the highlighted setting selected."
  def content(state, mode) do
    values = %{
      insert_columns:
        if(state.db.insert_columns == :all, do: "All sections", else: "Current section"),
      dates: "...",
      auto: "..."
    }

    Template.render(@layout, values, selected: Enum.at(@rows.file_props, mode.cursor))
  end

  @doc "The highlighted field, for its help in the control panel (`Agendum.TUI.Boxes.FieldHelp`)."
  def field(_state, mode), do: Enum.at(@rows[mode.type], mode.cursor)
end
