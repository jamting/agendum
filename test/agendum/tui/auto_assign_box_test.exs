defmodule Agendum.TUI.AutoAssignBoxTest do
  @moduledoc "File Properties ▸ Auto-assign settings (R16a)."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.TUI.History

  setup do
    state = start(Agendum.Sample.build(~D[2026-10-08]))
    # File Properties: ↓ to Global date settings, → to Auto-assign settings beside it
    %{state: press(state, [{:f, 10}, "f", "p", :down, :right, " "])}
  end

  test "shows Agenda's settings with their defaults", %{state: state} do
    text = screen(state)
    assert text =~ ~r/Text matching\s+: On/
    assert text =~ ~r/Match on\s+: Item text/
    assert text =~ ~r/Required match strength\s+: Exact match - 100%/
    assert text =~ ~r/Ignore text enclosed by\s+: " "/
    assert text =~ ~r/Ignore suffixes\s+: Yes/
    assert text =~ ~r/Ignore accents\s+: No/
  end

  test "SPACE changes a setting; each change is one undo step", %{state: state} do
    state = press(state, [:down, :down, " "])
    assert state.db.match_settings.strength == :partial
    # Match on: Item text -> Note text -> Both item & note
    state = press(state, [:up, " ", " "])
    assert state.db.match_settings.match_on == :both
    assert screen(state) =~ ~r/Match on\s+: Both item & note/

    # one step back: the first SPACE's Note text
    state = History.undo(state)
    assert state.db.match_settings.match_on == :note
  end

  test "with text matching off, a new item matches nothing", %{state: state} do
    state = press(state, [" ", :enter, :enter, "Set up a meeting with Anna", :enter])
    item = Enum.find(Map.values(state.db.items), &(&1.text == "Set up a meeting with Anna"))

    assert Agendum.Core.Database.explicit_categories(state.db, item.id)
           |> Enum.map(&state.db.categories[&1].name) == ["Calls"]
  end
end
