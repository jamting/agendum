defmodule Agendum.TUI.UnsavedChangesTest do
  @moduledoc """
  Retrieve, New and Import ask before replacing a file with unsaved changes,
  as Quit does: Y saves first, N goes on, ESC cancels.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.TUI.{State, Update}

  @question "Save changes first?"
  @commands [
    {"Retrieve", [{:f, 10}, "f", "r"], "File to retrieve:"},
    {"New", [{:f, 10}, "f", "n"], "Name of new file:"},
    {"Import", [{:f, 10}, "f", "t", "i"], "JSON file to import"}
  ]

  setup do
    state = start(Agendum.Sample.build(~D[2026-10-08]))
    # a change: a new item
    changed = press(state, [:down | String.graphemes("Water the haycorns")] ++ [:enter])
    assert changed.dirty
    %{state: state, changed: %{changed | path: "/home/rabbit/rabbit.agenda"}}
  end

  defp keys(state, keys) do
    Enum.reduce(keys, {state, []}, fn key, {state, effects} ->
      key = if is_binary(key), do: {:char, key}, else: key
      {state, new} = Update.handle(state, key)
      {state, effects ++ new}
    end)
  end

  test "nothing is asked when everything is saved", %{state: state} do
    for {name, open, prompt} <- @commands do
      assert screen(press(state, open)) =~ prompt, name
    end
  end

  test "with unsaved changes they ask first", %{changed: changed} do
    for {name, open, _prompt} <- @commands do
      assert screen(press(changed, open)) =~ @question, name
    end
  end

  test "Y saves, then goes on", %{changed: changed} do
    for {name, open, prompt} <- @commands do
      {state, effects} = keys(changed, open ++ ["y"])
      assert effects == [{:save, "/home/rabbit/rabbit.agenda"}], name
      assert screen(state) =~ prompt, name
    end
  end

  test "Y on an untitled file asks for a name first", %{changed: changed} do
    {state, _} = keys(%{changed | path: nil}, [{:f, 10}, "f", "r", "y"])
    assert screen(state) =~ "Save file as:"
    {state, effects} = keys(state, String.graphemes("/tmp/mine") ++ [:enter])
    assert effects == [{:save, "/tmp/mine.agendum"}]
    assert screen(state) =~ "File to retrieve:"
  end

  test "N goes on without saving", %{changed: changed} do
    {state, effects} = keys(changed, [{:f, 10}, "f", "r", "n"])
    assert effects == []
    assert screen(state) =~ "File to retrieve:"
  end

  test "ESC cancels and keeps the file", %{changed: changed} do
    {state, effects} = keys(changed, [{:f, 10}, "f", "r", :esc, :esc, :esc])
    assert effects == []
    assert state.modes == []
    assert state.db == changed.db
  end

  test "CTRL-O asks too", %{changed: changed} do
    assert screen(press(changed, {:ctrl, "o"})) =~ @question
  end

  test "the next file is not opened until the question is answered", %{changed: changed} do
    state = press(changed, [{:f, 10}, "f", "r"])
    assert %{type: :confirm} = State.mode(state)
  end
end
