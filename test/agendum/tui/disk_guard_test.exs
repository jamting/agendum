# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.DiskGuardTest do
  @moduledoc """
  The file changed on disk (R71): Agendum does not save over a file that
  another writer changed since it was read or saved, without asking; what
  follows a save (quitting, opening another file) waits for the save to
  succeed.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Preferences
  alias Agendum.TUI.{State, Update}

  @path "/home/rabbit/rabbit.agendum"
  @now ~N[2026-10-08 10:00:00]

  # a named file read with stamp "s1", and one unsaved change
  defp changed(opts \\ []) do
    Agendum.Sample.build(~D[2026-10-08])
    |> start(Keyword.merge([now: @now, path: @path, stamp: "s1"], opts))
    |> press(["Water the haycorns", :enter])
  end

  defp keys(state, keys) do
    Enum.reduce(List.wrap(keys), {state, []}, fn key, {state, effects} ->
      key = if is_binary(key), do: {:char, key}, else: key
      {state, new} = Update.handle(state, key)
      {state, effects ++ new}
    end)
  end

  # what the shell does after a save: hands the result to `Update.saved/4`,
  # then carries out the effects that asked for
  defp saved(state, {:save, path, opts}, result) do
    state = Update.Results.saved(state, path, result, opts)
    {%{state | effects: []}, state.effects}
  end

  test "a save expects the file as it was read" do
    {_state, effects} = keys(changed(), {:ctrl, "s"})
    assert effects == [{:save, @path, %{expect: "s1", then: nil, auto: false}}]
  end

  test "after a good save the next one expects the file as saved" do
    {state, [save]} = keys(changed(), {:ctrl, "s"})
    {state, []} = saved(state, save, {:ok, "s2"})
    refute state.dirty
    state = press(state, ["Feed the bees", :enter])
    {_state, effects} = keys(state, {:ctrl, "s"})
    assert [{:save, @path, %{expect: "s2"}}] = effects
  end

  test "a file changed on disk is not saved over without asking" do
    {state, [save]} = keys(changed(), {:ctrl, "s"})
    {state, []} = saved(state, save, {:error, :changed_on_disk})
    assert screen(state) =~ "rabbit.agendum has changed on disk"
    assert screen(state) =~ "Save over it?"
    assert state.dirty
  end

  test "Yes saves over it" do
    {state, [save]} = keys(changed(), {:ctrl, "s"})
    {state, []} = saved(state, save, {:error, :changed_on_disk})
    {_state, effects} = keys(state, "y")
    assert effects == [{:save, @path, %{expect: :any, then: nil, auto: false}}]
  end

  test "No leaves the changes unsaved and says how to keep both" do
    {state, [save]} = keys(changed(), {:ctrl, "s"})
    {state, []} = saved(state, save, {:error, :changed_on_disk})
    {state, effects} = keys(state, "n")
    assert effects == [{:sound, :error}]
    assert state.dirty
    assert screen(state) =~ "Not saved"
    assert screen(state) =~ "MakeCopy"
  end

  test "a new file not yet saved finds one there: it asks too, in its own words" do
    state =
      Agendum.Core.new_file()
      |> start(now: @now, path: @path)
      |> press(["Plant carrots", :enter])

    {state, [save]} = keys(state, {:ctrl, "s"})
    assert {:save, @path, %{expect: nil}} = save
    {state, []} = saved(state, save, {:error, :changed_on_disk})
    assert screen(state) =~ "rabbit.agendum already exists"
  end

  # MakeCopy (R82) writes the copy whatever is at its name, then saves the
  # open file as any save does, the file on disk checked first: when that
  # file changed, the changes are kept in the copy
  test "MakeCopy writes the copy, then saves the file with its check" do
    {state, _} = keys(changed(), [{:f, 10}, "f", "m", "m"])
    {state, effects} = keys(state, String.graphemes("/tmp/other") ++ [:enter])

    assert [{:save_copy, "/tmp/other.agendum", _db}, {:save, @path, %{expect: "s1"} = opts}] =
             effects

    assert opts.then == {:copied, "/tmp/other.agendum"}
    # the open file keeps its name
    assert state.path == @path
  end

  describe "quitting" do
    test "Quit, Yes: quits only after the save succeeded" do
      {state, effects} = keys(changed(), [{:f, 10}, "q", "y"])
      assert [{:save, @path, %{then: :quit}} = save] = effects
      {_state, effects} = saved(state, save, {:ok, "s2"})
      assert :quit in effects
    end

    test "a save that fails does not quit, and says so" do
      {state, [save]} = keys(changed(), [{:f, 10}, "q", "y"])
      {state, effects} = saved(state, save, {:error, :enospc})
      assert effects == []
      assert state.dirty
      assert screen(state) =~ "Could not save"
      assert screen(state) =~ "not quitting"
    end

    test "a file changed on disk asks; Yes saves over it, then quits" do
      {state, [save]} = keys(changed(), [{:f, 10}, "q", "y"])
      {state, []} = saved(state, save, {:error, :changed_on_disk})
      {state, effects} = keys(state, "y")
      assert [{:save, @path, %{expect: :any, then: :quit}} = save] = effects
      {_state, effects} = saved(state, save, {:ok, "s2"})
      assert :quit in effects
    end

    test "a file changed on disk asks; No stays open" do
      {state, [save]} = keys(changed(), [{:f, 10}, "q", "y"])
      {state, []} = saved(state, save, {:error, :changed_on_disk})
      {state, effects} = keys(state, "n")
      # "Not saved" is an error message, and beeps (R76)
      assert effects == [{:sound, :error}]
      assert state.dirty
    end
  end

  describe "opening another file" do
    test "Retrieve, Yes: the file prompt comes once the save succeeded" do
      {state, [save]} = keys(changed(), [{:f, 10}, "f", "r", "y"])
      assert {:save, @path, %{then: {:replace_file, :retrieve}}} = save
      refute screen(state) =~ "File to retrieve:"
      {state, []} = saved(state, save, {:ok, "s2"})
      assert screen(state) =~ "File to retrieve:"
    end

    test "a save that fails opens nothing" do
      {state, [save]} = keys(changed(), [{:f, 10}, "f", "r", "y"])
      {state, []} = saved(state, save, {:error, :enospc})
      refute screen(state) =~ "File to retrieve:"
      assert screen(state) =~ "Could not save"
    end
  end

  describe "auto-save (R54)" do
    defp auto(state, seconds), do: Update.tick(state, NaiveDateTime.add(@now, seconds))

    test "finding the file changed, it asks nothing, says so and stops trying" do
      state = changed(prefs: %Preferences{auto_save: 5})
      {state, [save]} = auto(state, 5 * 60)
      assert {:save, @path, %{expect: "s1", auto: true}} = save
      {state, []} = saved(state, save, {:error, :changed_on_disk})
      assert State.mode(state) == nil
      assert screen(state) =~ "Not auto-saved"
      assert screen(state) =~ "changed on disk"

      {_state, effects} = auto(state, 20 * 60)
      assert effects == []
    end

    test "a save made by hand settles it, and auto-save goes on" do
      state = changed(prefs: %Preferences{auto_save: 5})
      {state, [save]} = auto(state, 5 * 60)
      {state, []} = saved(state, save, {:error, :changed_on_disk})

      {state, [save]} = keys(state, {:ctrl, "s"})
      {state, []} = saved(state, save, {:error, :changed_on_disk})
      {state, [save]} = keys(state, "y")
      {state, []} = saved(state, save, {:ok, "s2"})

      state = press(state, ["Feed the bees", :enter])
      {_state, effects} = Update.tick(state, NaiveDateTime.add(state.last_key.at, 5 * 60))
      assert [{:save, @path, %{expect: "s2", auto: true}}] = effects
    end
  end
end
