# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.BoxOnEnterTest do
  @moduledoc """
  A settings box applies its changes on ENTER, as Agenda's does (checked in
  Agenda 2.0, 2026-10-22; ADR 0030, amended; the owner's choices,
  2026-10-24): the screen behind the box stays as it was while the box is
  open, the box itself showing the new values; ENTER makes the whole box
  one undo step; ESC puts everything back and leaves no step; an auto-save
  waits until the box is closed.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Core.Database
  alias Agendum.Preferences
  alias Agendum.Starters.Planner
  alias Agendum.TUI.{History, State, Update}

  @today ~D[2026-10-12]

  # the Planner's Tasks view with the sample data: it shows done items (‼)
  setup do
    db = Planner.build() |> Planner.with_samples(@today)
    view = Enum.find(Database.views(db), &(&1.name == "Tasks"))
    state = db |> start(today: @today, width: 100, height: 40) |> State.switch_view(view.id)
    %{state: state, view: view.id}
  end

  defp props(state), do: press(state, [{:f, 10}, "v", "p"])
  defp hide_done(state), do: state |> to_setting("Hide done items") |> press(" ")
  # the view's lines on screen, the box's lines left out
  defp behind(state), do: state |> screen() |> String.split("\n") |> Enum.reject(&(&1 =~ "│"))

  test "the view behind the box stays as it was until ENTER", %{state: state, view: v} do
    assert Enum.any?(behind(state), &(&1 =~ "‼"))
    open = state |> props() |> hide_done()
    assert open.db.views[v].hide_done
    assert screen(open) =~ ~r/Hide done items: +Yes/
    assert Enum.any?(behind(open), &(&1 =~ "‼"))

    closed = press(open, :enter)
    refute Enum.any?(behind(closed), &(&1 =~ "‼"))
  end

  test "after ENTER one undo takes back everything set in the box", %{state: state, view: v} do
    closed =
      state |> props() |> hide_done() |> to_setting("Hide empty sections") |> press([" ", :enter])

    assert closed.db.views[v].hide_done and closed.db.views[v].hide_empty
    assert length(closed.history.undo) == length(state.history.undo) + 1

    undone = History.undo(closed)
    assert undone.db.views[v] == state.db.views[v]
  end

  test "ESC puts it all back and leaves no undo step", %{state: state} do
    cancelled = state |> props() |> hide_done() |> press(:esc)
    assert cancelled.db == state.db
    assert cancelled.history.undo == state.history.undo
  end

  test "a box opened from a box: the outer ESC takes back the inner box's changes too",
       %{state: state} do
    inner = state |> props() |> hide_done() |> press([:home, :right, {:f, 6}])
    assert %{type: :section_props} = State.mode(inner)
    back = press(inner, [:enter, :esc])
    assert back.db == state.db
    assert back.history.undo == state.history.undo
  end

  test "an auto-save waits until the box is closed", %{state: state} do
    now = ~N[2026-10-12 09:00:00]

    state = %{
      state
      | path: "/home/rabbit/plan.agendum",
        prefs: %Preferences{auto_save: 5},
        now: now
    }

    open = state |> press(["Water the carrots", :enter]) |> props() |> hide_done()
    {_, effects} = Update.tick(open, NaiveDateTime.add(now, 3600))
    assert for({:save, _, _} <- effects, do: 1) == []

    {_, effects} = open |> press(:enter) |> Update.tick(NaiveDateTime.add(now, 7200))
    assert [_] = for({:save, _, _} <- effects, do: 1)
  end

  # found by the fuzz walk (seed 112): a macro run that closes the open box
  # and then changes the file is one undo step, as every run
  test "a macro run that closes a box is still one undo step", %{state: state} do
    {:ok, db, id} = Agendum.Core.add_macro(state.db, "Close and add")
    db = Agendum.Core.set_macro_keys(db, id, "{ENTER}Water the lettuces{ENTER}")
    open = %{state | db: db} |> props() |> hide_done()
    open = %{open | macro: %{open.macro | last: id}}

    run = press(open, {:alt, "z"})
    assert State.mode(run) == nil
    refute run.db == open.db
    assert History.undo(run).db == open.db
  end
end
