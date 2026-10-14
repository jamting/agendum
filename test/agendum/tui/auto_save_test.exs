defmodule Agendum.TUI.AutoSaveTest do
  @moduledoc """
  Auto-save (R54; User's Guide 22-8): with an interval of N minutes, a
  file with a name and unsaved changes is saved once no key has been
  pressed for N minutes.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Preferences
  alias Agendum.TUI.Update

  @now ~N[2026-10-08 10:00:00]

  # a named file with one unsaved change, typed at 10:00
  defp changed(minutes, path \\ "/home/rabbit/rabbit.agendum") do
    Agendum.Sample.build(~D[2026-10-08])
    |> start(now: @now, path: path, prefs: %Preferences{auto_save: minutes})
    |> press(["Water the carrots", :enter])
  end

  defp tick(state, seconds), do: Update.tick(state, NaiveDateTime.add(@now, seconds))
  defp saves(effects), do: for({:save, path} <- effects, do: path)

  test "saves after the interval without a key, and only then" do
    state = changed(5)
    assert state.dirty
    {_, effects} = tick(state, 5 * 60 - 1)
    assert saves(effects) == []

    {state, effects} = tick(state, 5 * 60)
    assert saves(effects) == ["/home/rabbit/rabbit.agendum"]

    # not again straight away, even before the shell reports the save
    {_, effects} = tick(state, 5 * 60 + 1)
    assert saves(effects) == []
  end

  test "a key starts the idle time again" do
    state = changed(5)
    {state, _} = tick(state, 4 * 60)
    state = press(state, :down)
    {_, effects} = tick(state, 5 * 60)
    assert saves(effects) == []
    {_, effects} = tick(state, 9 * 60)
    assert saves(effects) == ["/home/rabbit/rabbit.agendum"]
  end

  test "not when off, not without changes, not for an untitled file" do
    {_, effects} = changed(0) |> tick(3600)
    assert saves(effects) == []

    {_, effects} = changed(5, nil) |> tick(3600)
    assert saves(effects) == []

    unchanged =
      start(Agendum.Sample.build(~D[2026-10-08]),
        now: @now,
        path: "/x.agendum",
        prefs: %Preferences{auto_save: 5}
      )

    {_, effects} = tick(unchanged, 3600)
    assert saves(effects) == []
  end

  test "Auto-save interval is in File ▸ Customize, and saved" do
    state = changed(0)
    state = %{state | prefs: %{state.prefs | path: "/prefs"}}
    state = state |> press([{:f, 10}, "f", "c"]) |> to_setting("Auto-save interval")
    assert screen(state) =~ ~r/Auto-save interval +: Off/

    {state, effects} = Update.handle(state, {:char, " "})
    assert [{:save_preferences, "/prefs", %Preferences{auto_save: 1}}] = effects
    assert screen(state) =~ ~r/Auto-save interval +: 1 minute/
    state = press(state, [" ", " "])
    assert screen(state) =~ ~r/Auto-save interval +: 5 minutes/
    assert press(state, " ").prefs.auto_save == 10
  end
end
