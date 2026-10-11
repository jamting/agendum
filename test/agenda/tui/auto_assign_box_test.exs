defmodule Agenda.TUI.AutoAssignBoxTest do
  @moduledoc "File Properties ▸ Auto-assign settings (R16a)."
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.TUI.History

  setup do
    state = start(Agenda.Sample.build(~D[2026-10-08]))
    %{state: press(state, [{:f, 10}, "f", "p"] ++ List.duplicate(:down, 20) ++ [" "])}
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

  test "SPACE and ← change a setting; each change is one undo step", %{state: state} do
    state = press(state, [:down, :down, " "])
    assert state.db.match_settings.strength == :partial
    state = press(state, [:up, :left])
    assert state.db.match_settings.match_on == :both
    assert screen(state) =~ ~r/Match on\s+: Both item & note/

    state = History.undo(state)
    assert state.db.match_settings.match_on == :item
  end

  test "with text matching off, a new item matches nothing", %{state: state} do
    state = press(state, [" ", :esc, :esc, "Set up a meeting with Anna", :enter])
    item = Enum.find(Map.values(state.db.items), &(&1.text == "Set up a meeting with Anna"))

    assert Agenda.Core.Database.explicit_categories(state.db, item.id)
           |> Enum.map(&state.db.categories[&1].name) == ["Calls"]
  end
end
