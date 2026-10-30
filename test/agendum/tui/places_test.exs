defmodule Agendum.TUI.PlacesTest do
  @moduledoc """
  A file opens where the person left it (R69; meeting 2026-10-16-1905, § 5):
  the view and the highlighted item, else its section, else the top of the
  view. The place is kept in the preferences by the file's path, never in
  the file, so moving around never asks to save.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.{Core, Preferences}
  alias Agendum.Preferences.Place
  alias Agendum.TUI.{Layout, State, Update}

  @path "/home/rabbit/rabbit.agendum"
  @prefs_path "/home/rabbit/.config/agendum/preferences"

  setup do
    db = Agendum.Sample.build(~D[2026-10-08])
    {db, everything} = Core.add_view(db, "Everything", [db.main_id])
    prefs = %Preferences{path: @prefs_path}
    state = start(db, path: @path, prefs: prefs)
    %{state: state, everything: everything}
  end

  # the state when the file is opened again, with these preferences
  defp reopened(db, prefs), do: start(db, path: @path, prefs: prefs)

  defp quit(state) do
    {state, effects} = Update.handle(state, {:ctrl, "q"})
    {state, effects}
  end

  test "quitting keeps the view and the item, and saves the preferences first", %{
    state: state,
    everything: everything
  } do
    state = press(state, [{:alt, "n"}, :down, :down, :down])
    assert state.view_id == everything
    {:item, _, item} = state.cursor_key

    {state, effects} = quit(state)
    # moving changed nothing in the file: no question, just quitting
    assert [{:save_preferences, @prefs_path, prefs}, :quit] = effects
    assert prefs == state.prefs
    assert %Place{view: ^everything, item: ^item} = Preferences.place(prefs, @path)

    again = reopened(state.db, prefs)
    assert again.view_id == everything
    assert {:item, _, ^item} = again.cursor_key
    assert Layout.current_row(again).item.id == item
  end

  test "saving then quitting saves the file, then keeps the place and quits", %{state: state} do
    state = press(state, [:down, "Water the haycorns", :enter])
    place = state.cursor_key

    {state, effects} =
      Enum.reduce([{:ctrl, "q"}, {:char, "y"}], {state, []}, fn key, {s, e} ->
        {s, new} = Update.handle(s, key)
        {s, e ++ new}
      end)

    # the quit waits for the save (R71); the shell saves the preferences
    # when a result changed them, before the quit that result asked for
    assert [{:save, @path, %{then: :quit} = opts}] = effects
    state = Update.Results.saved(state, @path, {:ok, "stamp"}, opts)
    assert state.effects == [:quit]
    assert Preferences.place(state.prefs, @path).item == elem(place, 2)
  end

  test "an item that is gone leaves the highlight on its section head", %{
    state: state,
    everything: everything
  } do
    state = press(state, [{:alt, "n"}, :down, :down])
    {:item, section, item} = state.cursor_key
    {_state, [{:save_preferences, _, prefs}, :quit]} = quit(state)

    {:ok, db, _} = Core.run(state.db, {:discard_items, [item]}, State.context(state))
    again = reopened(db, prefs)
    assert again.view_id == everything
    assert again.cursor_key == {:section, section}
  end

  test "a view that is gone opens the file on its first view", %{state: state} do
    state = press(state, [{:alt, "n"}, :down])
    {_state, [{:save_preferences, _, prefs}, :quit]} = quit(state)

    {:ok, db, _} = Core.run(state.db, {:discard_view, state.view_id}, State.context(state))
    again = reopened(db, prefs)
    assert again.view_id == hd(db.view_order)
    assert again.cursor == 0
  end

  test "another file, retrieved, opens where it was left; the first file's place is kept",
       %{state: state, everything: everything} do
    other = "/home/rabbit/other.agendum"
    prefs = Preferences.put_place(state.prefs, other, %Place{view: everything})
    state = press(%{state | prefs: prefs}, :down)
    first_key = state.cursor_key

    state = Update.Results.loaded(state, other, {:ok, state.db, "stamp"})
    assert state.path == other
    assert state.view_id == everything
    assert Preferences.place(state.prefs, @path).item == elem(first_key, 2)
    # the file left last comes first
    assert [{@path, _}, {^other, _}] = state.prefs.places
  end

  test "an untitled file keeps no place", %{state: state} do
    {state, effects} = quit(%{state | path: nil})
    assert effects == [:quit]
    assert state.prefs.places == []
  end
end
