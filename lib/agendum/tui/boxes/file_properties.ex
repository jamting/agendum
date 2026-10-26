defmodule Agendum.TUI.Boxes.FileProperties do
  @moduledoc """
  The File Properties box (File ▸ Properties; User's Guide 7-13 to 7-17)
  and the boxes it opens, nested as in Agenda 2.0, each row with "..."
  opening the next box:

    * File Properties (`:file_props`): Insert new columns in (R55), Empty
      trash (R24a), Tab
      size (R64e, typed as a number), Global
      date settings ..., Auto-assign settings ...
      (`Agendum.TUI.Boxes.AutoAssignBox`, R16a) and File statistics ...
      (`Agendum.TUI.Boxes.FileStatsBox`). Drawn from `@layout`
      (`Agendum.TUI.Boxes.Template`), Agenda's box (screenshot 130) with only the
      settings Agendum has
    * Global Date Settings (`Agendum.TUI.Boxes.DateSettingsBox`, R14e)
    * Display Format (`Agendum.TUI.Boxes.DisplayFormatBox`, R41), from Global
      Date Settings

  SPACE shows the next choice (or opens a "..." box), the arrows move
  between settings (`Agendum.TUI.Boxes.BoxNav`); every change applies at once
  and is one undo step. ENTER closes
  the box, ESC closes it and cancels its changes (`Agendum.TUI.Boxes.BoxCancel`);
  either goes back to the box beneath. Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, cancels: true

  alias Agendum.TUI.Boxes.{AutoAssignBox, Box, DateSettingsBox, FieldTyping, FileStatsBox}
  alias Agendum.TUI.Boxes.Template
  alias Agendum.TUI.State

  # Agenda's File Properties (screenshot 130), its other settings left out
  # until Agendum has them
  @layout """
   File description:       [description                             ]
   Set file password:      [password]
   Make backup on open:    [backup ]

   Insert new columns in:  [insert_columns ]
   Empty trash:            [empty_trash          ]

   Tab size:               [tab_size]

   Global date settings:   [dates]   Auto-assign settings:  [auto ]
                                     File statistics:       [stats]
  """

  @rows Template.fields(@layout)

  # Empty trash's choices in Agenda's words
  @empty_trash %{
    on_demand: "On demand",
    file_closed: "When file is closed",
    end_of_day: "End of day",
    discarded: "When item is discarded"
  }
  # two settings side by side, as Agenda's
  @grid Template.grid(@layout, @rows)

  @help %{
    description: "Enter a short description of the file. Press F2 to edit.",
    password: "Press SPACE BAR to create or change a password that protects access to the file.",
    backup: "Choose whether to back up the file automatically each time you open it.",
    insert_columns:
      "Choose to insert new columns in one or all sections in the view. " <>
        "You can override when you add individual columns.",
    empty_trash:
      "Choose when to remove discarded items from the trash, so that " <>
        "they can no longer be recovered.",
    tab_size:
      "Type the number of characters between tab stops in notes (1 to 16), or SPACE for the next.",
    dates:
      "Press SPACE BAR to choose date and time formats to use as defaults throughout the file.",
    auto: "Press SPACE BAR to choose how items are assigned to categories by their text.",
    stats: "Press SPACE BAR to display current statistics for the file."
  }

  def open(state), do: State.push(state, %Agendum.TUI.Modes.FileProps{cursor: 0})

  @impl Box
  # its keys are the settings box's (R65): SPACE changes the setting; a
  # digit on Tab size starts typing it, as in Agenda (R64e)
  def handle(state, %{typing: {_, _}} = mode, key),
    do: FieldTyping.key(state, mode, key, &typed/3)

  def handle(state, mode, {:char, c}) do
    case field(state, mode) do
      :tab_size ->
        if FieldTyping.digit?(c), do: FieldTyping.start(state, mode, :tab_size, c), else: state

      # any character starts typing a description (R82), as in Agenda
      :description ->
        FieldTyping.start(state, mode, :description, c)

      _ ->
        state
    end
  end

  def handle(state, _mode, _key), do: state

  defp typed(state, :description, text) do
    case State.command(state, {:set_description, text}) do
      {:ok, state, _} -> state
      {:error, :too_long} -> State.error(state, "A description has at most 40 characters")
    end
  end

  defp typed(state, :tab_size, text) do
    case FieldTyping.number(text, 1, 16) do
      {:ok, size} -> State.run(state, {:set_tab_size, size})
      :error -> State.error(state, Agendum.TUI.Messages.text(:bad_number))
    end
  end

  @impl Box
  def keymap(_mode), do: Box.settings_keymap()

  @impl Box
  def commands(_mode), do: Box.settings_commands()

  @impl Box
  def run(state, mode, :change), do: change(state, field(state, mode))
  def run(state, mode, id), do: Box.run_settings(state, mode, @grid, id)

  # F8 and ALT-F8 (`Agendum.TUI.Boxes.BoxDefaults`): what a new file has;
  # the "..." boxes have their own settings
  @impl Box
  def defaults(_state, _mode) do
    new = Agendum.Core.new_file()

    %{
      insert_columns:
        &if(&1.db.insert_columns == new.insert_columns,
          do: &1,
          else: State.run(&1, {:set_insert_columns, new.insert_columns})
        ),
      empty_trash:
        &if(&1.db.trash.empty == new.trash.empty,
          do: &1,
          else: State.run(&1, {:set_empty_trash, new.trash.empty})
        ),
      tab_size:
        &if(&1.db.tab_size == new.tab_size,
          do: &1,
          else: State.run(&1, {:set_tab_size, new.tab_size})
        )
    }
  end

  defp change(state, :dates), do: DateSettingsBox.open(state)

  # SPACE on the description: nothing (typing starts it); on backup: flips
  defp change(state, :description), do: state

  # Agenda's boxes, one after another (ADR 0046)
  defp change(state, :password), do: Agendum.TUI.Boxes.PasswordBox.open(state)

  defp change(state, :backup),
    do: State.run(state, {:set_backup_on_open, not state.db.backup_on_open})

  defp change(state, :auto), do: AutoAssignBox.open(state)
  defp change(state, :stats), do: FileStatsBox.open(state)

  # SPACE: the next size, after 16 back to 1 (F3 lists them, `BoxChoices`)
  defp change(state, :tab_size),
    do: State.run(state, {:set_tab_size, rem(state.db.tab_size, 16) + 1})

  # SPACE: the next of Agenda's four, in its order (R24a)
  defp change(state, :empty_trash) do
    choices = Agendum.Core.empty_trash_choices()
    at = Enum.find_index(choices, &(&1 == state.db.trash.empty))
    State.run(state, {:set_empty_trash, Enum.at(choices, rem(at + 1, length(choices)))})
  end

  # two choices, so SPACE flips it
  defp change(state, :insert_columns) do
    where = if state.db.insert_columns == :all, do: :section, else: :all
    State.run(state, {:set_insert_columns, where})
  end

  @impl Box
  def title(_state, _mode), do: "File Properties"

  # two columns of settings, as Agenda's (screenshot 130)
  @impl Box
  def width(state, _mode), do: min(state.width - 8, 72)

  @impl Box
  def content(state, mode, inner, _max_rows) do
    values = %{
      description: state.db.description,
      password: "...",
      backup: if(state.db.backup_on_open, do: "Yes", else: "No"),
      insert_columns:
        if(state.db.insert_columns == :all, do: "All sections", else: "Current section"),
      empty_trash: @empty_trash[state.db.trash.empty],
      tab_size: Integer.to_string(state.db.tab_size),
      dates: "...",
      auto: "...",
      stats: "..."
    }

    Template.render(@layout, values, [selected: field(state, mode)] ++ FieldTyping.editing(mode)) ++
      [[], Box.hint(keys(state, mode), inner)]
  end

  @impl Box
  def keys(_state, _mode),
    do: [
      {"↑↓←→", "Setting", "Move between settings"},
      {"SPACE", "Next", "Next choice or open ..."},
      {"ENTER", "Done"},
      {"ESC", "Cancel"}
    ]

  @impl Box
  def help, do: @help

  @impl Box
  def field(_state, mode), do: Enum.at(@rows, mode.cursor)
end
