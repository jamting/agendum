defmodule Agenda.TUI.ConfirmModeTest do
  @moduledoc """
  Confirm mode (R54; User's Guide 2-23): with No, Agendum does what was
  asked without "are you sure?" questions; questions with two real
  answers (save first? discard a calendar's items too?) are still asked.
  """
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.Preferences
  alias Agenda.TUI.{History, State}

  defp started(confirm) do
    start(Agenda.Sample.build(~D[2026-10-08]), prefs: %Preferences{confirm: confirm})
  end

  test "with Confirm mode Yes, discarding asks first" do
    state = started(true) |> press([:down, {:ctrl, "d"}])
    assert %{type: :confirm} = State.mode(state)
  end

  test "with No, discarding an item happens at once, and can be undone" do
    before = started(false)
    count = map_size(before.db.items)
    state = press(before, [:down, {:ctrl, "d"}])
    assert State.mode(state) == nil
    assert map_size(state.db.items) == count - 1
    assert state |> History.undo() |> Map.get(:db) |> Map.get(:items) |> map_size() == count
  end

  test "with No, discarding a view in the view manager happens at once" do
    state = started(false)
    {db, _} = Agenda.Core.add_view(state.db, "Calls", [state.db.main_id])
    state = press(%{state | db: db}, [{:f, 8}, :end, :delete])
    assert %{type: :viewmgr} = State.mode(state)
    assert length(state.db.view_order) == 1
  end

  test "with No, saving first is still asked" do
    state = started(false) |> press(["New thing", :enter, {:ctrl, "q"}])
    assert %{type: :confirm} = State.mode(state)
    assert screen(state) =~ "Save changes before quitting?"
  end

  test "Confirm mode is in File ▸ Customize, and saved" do
    state = %{started(true) | prefs: %Preferences{path: "/prefs"}}
    state = press(state, [{:f, 10}, "f", "c"] ++ List.duplicate(:down, 5))
    assert screen(state) =~ ~r/Confirm mode +: Yes/
    {state, effects} = Agenda.TUI.Update.handle(state, {:char, " "})
    refute state.prefs.confirm
    assert [{:save_preferences, "/prefs", %Preferences{confirm: false}}] = effects
    assert screen(state) =~ ~r/Confirm mode +: No/
  end
end
