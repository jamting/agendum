defmodule Agenda.TUI.DateRuleBox do
  @moduledoc """
  A date category's Advanced settings (Category Properties ▸ Date
  settings; User's Guide 7-5 to 7-8, SPEC R6b): Assign item date, Which
  one, and whether F4 (DONE) and ALT-F2 (WHEN) set the date. SPACE shows
  the next choice (the arrows move); every change applies at once
  and is one undo step. Done always takes the Done key and When the When
  key. ENTER closes the box; ESC closes it and cancels its changes
  (`Agenda.TUI.BoxCancel`). Pure.
  """

  import Agenda.TUI.BoxNav, only: [is_move: 1]
  alias Agenda.TUI.BoxNav

  alias Agenda.Core
  alias Agenda.Core.DateRule
  alias Agenda.TUI.State

  @rows [:assign, :which, :done_key, :when_key]

  def open(state, cat_id), do: State.push(state, %{type: :date_rule, cat_id: cat_id, cursor: 0})

  def handle(state, mode, key) do
    case key do
      k when k in [:esc, :enter] -> State.pop(state)
      k when is_move(k) -> BoxNav.move(state, mode, BoxNav.column(@rows), k)
      {:char, " "} -> change(state, mode, 1)
      _ -> state
    end
  end

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

  @doc "`{label, value}` for each row."
  def lines(state, mode) do
    rule = state.db.categories[mode.cat_id].date_rule
    yes_no = &if(&1, do: "Yes", else: "No")

    [
      {"Assign item date", DateRule.label(rule.assign)},
      {"Which one",
       if(DateRule.sources(rule) == [], do: "(dates from text only)", else: "#{rule.which}")},
      {"Set date from Done key", yes_no.(rule.done_key)},
      {"Set date from When key", yes_no.(rule.when_key)}
    ]
  end

  @doc "The highlighted field, for its help in the control panel (`Agenda.TUI.FieldHelp`)."
  def field(_state, mode), do: Enum.at(@rows, mode.cursor)
end
