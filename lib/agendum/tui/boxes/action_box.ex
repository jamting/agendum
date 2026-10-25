defmodule Agendum.TUI.Boxes.ActionBox do
  @moduledoc """
  The Date Action and Numeric Action boxes (SPEC R15b; User's Guide 21-4 to
  21-7), opened when a date or numeric category is chosen in a category's
  Assignment actions. Rows: what to do (set a date or number, or clear it)
  and the date or value. The arrows move; SPACE changes the choice; typing
  goes into the value. ENTER applies, DEL removes the action, ESC cancels.
  Drawn from a layout (`Agendum.TUI.Boxes.Template`), one for a date and one
  for a number. Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, indicator: "PROPS", choices: true

  alias Agendum.TUI.Boxes.{Box, Template}
  alias Agendum.TUI.{Typing.LineEdit, State}
  alias Agendum.TUI.Update.Editing

  @date_layout """
   Action      : [what                                        ]
   With date   : [value                                       ]
  """
  @number_layout """
   Action      : [what                                        ]
   With value  : [value                                       ]
  """

  @rows Template.fields(@date_layout)
  @grid Template.grid(@date_layout, @rows)

  @help %{
    what: "Choose whether the action gives items a date or a number, or removes it. SPACE.",
    value:
      "Type the date (\"tomorrow\", read when the action runs) or the number. " <>
        "ENTER applies, DEL removes the action."
  }

  def open(state, owner, target) do
    {clear, value} =
      case List.keyfind(state.db.categories[owner].actions, target, 0) do
        {_, :clear} ->
          {true, ""}

        {_, {:set, value}} when is_number(value) ->
          {false, Editing.number_text(value, State.number_opts(state))}

        {_, {:set, value}} ->
          {false, value}

        nil ->
          {false, ""}
      end

    State.push(state, %Agendum.TUI.Modes.ActionBox{
      owner: owner,
      target: target,
      clear: clear,
      line: LineEdit.new(value),
      cursor: 0
    })
  end

  @doc "Whether the action is on a numeric category (else a date category)."
  def numeric?(state, mode), do: state.db.categories[mode.target].kind == :numeric

  @impl Box
  # On the value the person types: ← → HOME END move in it, other keys
  # edit it; ↑ ↓ TAB still move between settings, ENTER and ESC end.
  def handle(state, mode, key) when key in [:up, :down, :tab, :shift_tab, :enter, :esc],
    do: run(state, mode, Map.fetch!(keymap(mode), key))

  def handle(state, mode, key) do
    case LineEdit.handle(mode.line, key) do
      {:ok, line} -> State.put_mode(state, %{mode | line: line})
      :unhandled -> state
    end
  end

  @impl Box
  def typing?(_state, mode), do: Enum.at(@rows, mode.cursor) == :value

  # the settings box's keys; ENTER sets the action, DEL removes it (R65)
  @keymap %{:delete => :remove}

  @impl Box
  def keymap(_mode), do: Box.settings_keymap(@keymap)

  @impl Box
  def commands(_mode),
    do:
      Box.settings_commands([
        {:done, "Done", "Set the action and close"},
        {:remove, "Remove", "Remove the action"}
      ])

  @impl Box
  def run(state, mode, :done), do: apply_action(state, mode)
  def run(state, mode, :change), do: State.put_mode(state, %{mode | clear: not mode.clear})

  def run(state, mode, :remove) do
    state
    |> State.pop()
    |> State.run({:remove_action, mode.owner, mode.target})
  end

  def run(state, mode, id), do: Box.run_settings(state, mode, @grid, id)

  defp apply_action(state, mode) do
    action = if mode.clear, do: :clear, else: {:set, mode.line.text}

    case State.command(state, {:set_action, mode.owner, mode.target, action}) do
      {:ok, state, _} ->
        State.pop(state)

      {:error, :invalid_date} ->
        State.error(state, Agendum.TUI.Messages.text(:bad_date))

      {:error, :not_a_number} ->
        State.error(state, Agendum.TUI.Messages.text(:bad_number))

      {:error, :self} ->
        State.error(state, "A category cannot act on itself")
    end
  end

  @impl Box
  def title(state, mode) do
    kind = if numeric?(state, mode), do: "Numeric", else: "Date"
    "#{kind} action: #{state.db.categories[mode.target].name}"
  end

  @impl Box
  def content(state, mode, inner, _max_rows) do
    name = state.db.categories[mode.target].name

    {layout, noun} =
      if numeric?(state, mode), do: {@number_layout, "value"}, else: {@date_layout, "date"}

    values = %{
      what: if(mode.clear, do: "Remove the #{noun} in #{name}", else: "Give items a #{noun}"),
      value: mode.line.text
    }

    # the value on the cursor is drawn as the line being typed
    row = field(state, mode)
    editing = if row == :value, do: [editing: {:value, mode.line}], else: []

    Template.render(layout, values, [selected: row] ++ editing) ++
      [[], Box.hint(keys(state, mode), inner)]
  end

  @impl Box
  def keys(_state, _mode),
    do: [
      {"↑↓←→", "Setting", "Move between settings"},
      {"SPACE", "Change", "Change the setting"},
      {"ENTER", "Apply"},
      {"DEL", "Remove"},
      {"ESC", "Cancel"}
    ]

  @impl Box
  def help, do: @help

  @impl Box
  def field(_state, mode), do: Enum.at(@rows, mode.cursor)
end
