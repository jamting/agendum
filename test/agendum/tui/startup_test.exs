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

  test "any key ends the splash and does nothing else" do
    state = press(started(false), "x")
    assert state.modes == []
    assert state.db.items == Core.new_file().items
  end

  test "five seconds end it" do
    state = started(false)
    tick = fn seconds -> elem(Update.tick(state, NaiveDateTime.add(@now, seconds)), 0) end
    assert [%{type: :splash}] = tick.(4).modes
    assert tick.(5).modes == []
  end

  test "without a file, the prompt waits under it, with the last file" do
    state = started(true, %Preferences{last_file: "/home/rabbit/garden.agendum"})
    state = press(state, :enter)
    assert %{type: :prompt, action: :startup_open} = State.mode(state)
    assert screen(state) =~ ~r"File to open or create:.*\n /home/rabbit/garden.agendum"

    press(state, :enter)
    assert {:open_or_create, "/home/rabbit/garden.agendum"} in effects()
  end

  test "a file that is not there starts a new file by that name" do
    state = started(true) |> press(:esc)
    state = Update.opened(state, "/tmp/carrots.agendum", {:error, :enoent})
    assert state.path == "/tmp/carrots.agendum"
    assert panel(state) =~ "New file carrots.agendum"
    assert state.prefs.last_file == "/tmp/carrots.agendum"
  end

  test "a file that is there opens; opening and saving remember it" do
    db = Agendum.Sample.build(~D[2026-10-08])
    state = Update.opened(started(false), "/tmp/garden.agendum", {:ok, db})
    assert state.db == db
    assert state.prefs.last_file == "/tmp/garden.agendum"

    state = Update.saved(state, "/tmp/other.agendum", :ok)
    assert state.prefs.last_file == "/tmp/other.agendum"
  end
end
