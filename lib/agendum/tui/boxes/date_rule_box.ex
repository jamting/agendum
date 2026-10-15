defmodule Agendum.TUI.Boxes.DateRuleBox do
  @moduledoc """
  A date category's Advanced settings (Category Properties ▸ Date
  settings; User's Guide 7-5 to 7-8, SPEC R6b): Assign item date, Which
  one, and whether F4 (DONE) and ALT-F2 (WHEN) set the date. SPACE shows
  the next choice (the arrows move); every change applies at once
  and is one undo step. Done always takes the Done key and When the When
  key. ENTER closes the box; ESC closes it and cancels its changes
  (`Agendum.TUI.Boxes.BoxCancel`). Drawn from `@layout`
  (`Agendum.TUI.Boxes.Template`). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, indicator: "PROPS", cancels: true

  alias Agendum.TUI.Boxes.{Box, Template}

  alias Agendum.Core
  alias Agendum.Core.DateRule
  alias Agendum.TUI.State

  @layout """
   Assign item date       : [assign                            ]
   Which one              : [which                             ]
   Set date from Done key : [done_key                          ]
   Set date from When key : [when_key                          ]
  """

  @rows Template.fields(@layout)
  @grid Template.grid(@layout, @rows)

  @help %{
    assign:
      "When the category gets a date: never, from the clock as the item is entered or " <>
        "edited, or from its text. SPACE changes it.",
    which: "Which date in the text to take: the first, the second… SPACE for the next one.",
    done_key: "Whether F4 (DONE) sets this date to the current date and time. SPACE switches.",
    when_key: "Whether ALT-F2 (WHEN) sets this date as well. SPACE switches."
  }

  def open(state, cat_id), do: State.push(state, %{type: :date_rule, cat_id: cat_id, cursor: 0})

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
    row = Enum.at(@rows, mode.cursor)

    if fixed?(state.db, mode.cat_id, row) do
      State.error(state, "#{state.db.categories[mode.cat_id].name} always takes that key")
    else
      rule = DateRule.cycle(state.db.categories[mode.cat_id].date_rule, row, step)
      {:ok, db} = Core.set_date_rule(state.db, mode.cat_id, rule)
      State.change_db(state, db)
    end
  end

  defp fixed?(db, cat_id, :done_key), do: cat_id == db.special.done
  defp fixed?(db, cat_id, :when_key), do: cat_id == db.special.when
  defp fixed?(_db, _cat_id, _row), do: false

  @impl Box
  def title(state, mode), do: "Advanced settings: " <> state.db.categories[mode.cat_id].name

  @impl Box
  def content(state, mode, inner, _max_rows) do
    rule = state.db.categories[mode.cat_id].date_rule
    yes_no = &if(&1, do: "Yes", else: "No")

    values = %{
      assign: DateRule.label(rule.assign),
      which:
        if(DateRule.sources(rule) == [], do: "(dates from text only)", else: "#{rule.which}"),
      done_key: yes_no.(rule.done_key),
      when_key: yes_no.(rule.when_key)
    }

    Template.render(@layout, values, selected: field(state, mode)) ++
      [[], Box.hint(keys(state, mode), inner)]
  end

  @impl Box
  def keys(_state, _mode), do: Box.settings_keys()

  @impl Box
  def help, do: @help

  @impl Box
  def field(_state, mode), do: Enum.at(@rows, mode.cursor)
end
