defmodule Agendum.TUI.CategoryMatchingTest do
  @moduledoc "Category Properties ▸ Advanced settings for a standard category (R16b)."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.TUI.{CategoryScreens, History, State}

  setup do
    state = start(Agendum.Sample.build(~D[2026-10-08]))
    meetings = hd(Agendum.Core.Database.find_categories(state.db, "Meetings"))

    state =
      state
      |> CategoryScreens.open_props(meetings)
      |> to_setting("Advanced settings")
      |> press(" ")

    %{state: state, meetings: meetings}
  end

  test "every setting starts Global, showing the file's", %{state: state} do
    text = screen(state)
    assert text =~ "Advanced settings: Meetings"
    assert text =~ ~r/Text matching\s+: Global \(On\)/
    assert text =~ ~r/Match on\s+: Global \(Item text\)/
    assert text =~ ~r/Ignore suffixes\s+: Global \(Yes\)/
  end

  test "a setting of its own; T= in the category manager; the box one undo step",
       %{state: state, meetings: meetings} do
    state = press(state, [:down, " ", " "])
    assert state.db.categories[meetings].match_overrides == %{match_on: :note}
    assert screen(state) =~ ~r/Match on\s+: Note text/

    state = press(state, :enter)
    assert %{type: :props} = State.mode(state)

    state = press(state, [:enter, {:f, 9}])
    assert screen(state) =~ "T= Note"

    # the Category Properties box and the box opened from it: one step
    state = History.undo(state)
    assert state.db.categories[meetings].match_overrides == %{}
  end
end
