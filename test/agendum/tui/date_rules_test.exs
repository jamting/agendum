defmodule Agendum.TUI.DateRulesTest do
  @moduledoc "Category Properties ▸ Date settings: a date category's Advanced settings (R6b)."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.TUI.{CategoryScreens, History}

  setup do
    %{state: start(Agendum.Sample.build(~D[2026-10-08]))}
  end

  defp date_settings(state, cat_id) do
    state
    |> CategoryScreens.open_props(cat_id)
    |> to_setting("Advanced settings")
    |> press(" ")
  end

  test "When's settings: from the item text, and the When key always", %{state: state} do
    state = date_settings(state, state.db.special.when)
    text = screen(state)
    assert text =~ "Advanced settings: When"
    assert text =~ ~r/Assign item date\s+: From the item text/
    assert text =~ ~r/Which one\s+: 1/
    assert text =~ ~r/Set date from When key\s+: Yes/

    state = press(state, [:down, :down, :down, " "])
    assert screen(state) =~ "When always takes that key"
  end

  test "When from the note text: a note's date sets the When date (R14f)", %{state: state} do
    # From the item text -> From the note text
    state = date_settings(state, state.db.special.when) |> press(" ")
    assert state.db.categories[state.db.special.when].date_rule.assign == :note_text
    assert screen(state) =~ ~r/Assign item date\s+: From the note text/

    # back to the view; the first item, below the Calls section head
    state = press(state, [:enter, :enter, :down, {:f, 5}, "Booked for next Tuesday", :esc])
    item = Agendum.TUI.Layout.current_row(state).item
    assert {item.note, item.when} == {"Booked for next Tuesday", ~D[2026-10-13]}
  end

  test "each change is one undo step", %{state: state} do
    state = date_settings(state, state.db.special.when) |> press([:down, " "])
    assert state.db.categories[state.db.special.when].date_rule.which == 2

    # back in Category Properties the row is Agenda's "..."
    state = press(state, :enter)
    assert screen(state) =~ ~r/Advanced settings: +\.\.\./

    state = History.undo(state)
    assert state.db.categories[state.db.special.when].date_rule.which == 1
  end

  test "a standard category's Advanced settings are its text matching (R16b)", %{state: state} do
    calls = hd(Agendum.Core.Database.find_categories(state.db, "Calls"))
    assert screen(date_settings(state, calls)) =~ "Advanced settings: Calls"
  end
end
