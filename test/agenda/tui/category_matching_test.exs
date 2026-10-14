defmodule Agenda.TUI.CategoryMatchingTest do
  @moduledoc "Category Properties ▸ Advanced settings for a standard category (R16b)."
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.TUI.{CategoryScreens, History, State}

  setup do
    state = start(Agenda.Sample.build(~D[2026-10-08]))
    meetings = hd(Agenda.Core.Database.find_categories(state.db, "Meetings"))
    index = Enum.find_index(CategoryScreens.Properties.props_fields(), &(&1 == :advanced))
    state = CategoryScreens.open_props(state, meetings)
    state = State.put_mode(state, %{State.mode(state) | cursor: index}) |> press(" ")
    %{state: state, meetings: meetings}
  end

  test "every setting starts Global, showing the file's", %{state: state} do
    text = screen(state)
    assert text =~ "Advanced settings: Meetings"
    assert text =~ ~r/Text matching\s+: Global \(On\)/
    assert text =~ ~r/Match on\s+: Global \(Item text\)/
    assert text =~ ~r/Ignore suffixes\s+: Global \(Yes\)/
  end

  test "a setting of its own; T= in the category manager; one undo step each",
       %{state: state, meetings: meetings} do
    state = press(state, [:down, " ", " "])
    assert state.db.categories[meetings].match_overrides == %{match_on: :note}
    assert screen(state) =~ ~r/Match on\s+: Note text/

    state = press(state, :enter)
    assert screen(state) =~ ~r/Advanced settings\s+: Match on: Note text/

    state = press(state, [:enter, {:f, 9}])
    assert screen(state) =~ "T= Note"

    state = History.undo(state)
    assert state.db.categories[meetings].match_overrides == %{match_on: :item}
  end
end
