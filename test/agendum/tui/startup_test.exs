# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.StartupTest do
  @moduledoc """
  How Agendum starts (R52): the splash screen, then, when no file was
  named, the prompt for a file to open or create; the last file used is
  remembered.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.{Core, Preferences}
  alias Agendum.TUI.{State, Update}

  @now ~N[2026-10-08 10:00:00]

  defp started(ask_file, prefs \\ %Preferences{}) do
    Core.new_file()
    |> start(now: @now, prefs: prefs)
    |> Update.start(ask_file)
  end

  test "the splash shows the title, tagline, copyright and the person" do
    state = started(false, %Preferences{user: "rabbit", company: "Hundred Acre Wood"})
    text = screen(state)

    assert text =~ "W O L ' S   A G E N D U M"
    assert text =~ "Hoo's in control? You are."
    assert text =~ "Copyright 2026 WOL and JW&D"
    assert text =~ "All rights reversed"
    assert text =~ ~r/Name: +rabbit/
    assert text =~ ~r/Company: +Hundred Acre Wood/
    # a name in the preferences wins over the login name
    assert screen(started(false, %Preferences{user: "rabbit", name: "Rabbit"})) =~
             ~r/Name: +Rabbit/
  end

  # the owner's wish (2026-10-25): the owl stands on the box itself, with no
  # block of its own colour around it
  test "the owl is drawn in the box's colours, with no block around it" do
    segments = started(false) |> Agendum.TUI.Render.render() |> List.flatten()
    refute Enum.any?(segments, &match?({:splash_logo, _}, &1))

    owl = Enum.find(segments, fn {_, text} -> String.contains?(text, "('v')") end)
    assert {:box, _} = owl
    assert elem(owl, 1) =~ "___('v')___"
    # without a company, its row is left out
    refute screen(started(false, %Preferences{user: "rabbit"})) =~ "Company:"
  end

  # Agenda passes the key on (checked in Agenda 2.0, 2026-10-31: an x
  # typed during its splash landed in the File Retrieve box)
  test "a key ends the splash and then does what it does under it" do
    state = press(started(false), "x")
    refute Enum.any?(state.modes, &(&1.type == :splash))
    assert screen(state) =~ "x"
    assert state.edit != nil

    # with the file prompt under it, the key goes to the prompt
    state = press(started(true), "/tmp/garden.agendum")
    assert %{type: :prompt, action: :startup_open} = State.mode(state)
    assert screen(state) =~ "/tmp/garden.agendum"
  end

  test "five seconds end it" do
    state = started(false)
    tick = fn seconds -> elem(Update.tick(state, NaiveDateTime.add(@now, seconds)), 0) end
    assert [%{type: :splash}] = tick.(4).modes
    assert tick.(5).modes == []
  end

  test "without a file, the prompt waits under it, with the last file" do
    state = started(true, %Preferences{last_file: "/home/rabbit/garden.agendum"})
    {state, []} = Update.tick(state, NaiveDateTime.add(@now, 5))
    assert %{type: :prompt, action: :startup_open} = State.mode(state)
    assert screen(state) =~ ~r"File to open or create:.*\n /home/rabbit/garden.agendum"

    press(state, :enter)
    assert {:open_or_create, "/home/rabbit/garden.agendum"} in effects()
  end

  test "a file that is not there starts a new file by that name" do
    state = started(true) |> press(:esc)
    state = Update.Results.opened(state, "/tmp/carrots.agendum", {:error, :enoent})
    assert state.path == "/tmp/carrots.agendum"
    assert panel(state) =~ "New file carrots.agendum"
    assert state.prefs.last_file == "/tmp/carrots.agendum"
  end

  test "a file that is there opens; opening and saving remember it" do
    db = Agendum.Sample.build(~D[2026-10-08])
    state = Update.Results.opened(started(false), "/tmp/garden.agendum", {:ok, db, "stamp"})
    assert state.db == db
    assert state.prefs.last_file == "/tmp/garden.agendum"

    state = Update.Results.saved(state, "/tmp/other.agendum", {:ok, "stamp"}, %{then: nil})
    assert state.prefs.last_file == "/tmp/other.agendum"
  end
end
