defmodule Agendum.TUI.ExtrasSwitchTest do
  @moduledoc """
  The Extras preference (R77, ADR 0043): off by default, it hides every
  extra (Zettel ids and links, the blog, feeds, calendars, the view
  manager's ► and F5, the key bar's long labels, the "While you were
  away" box) from the menus, the keys, F1 and CTRL-X, and stops the
  feeds and calendars being read. The file's data stay, and show as they
  are. Turned on in Utilities ▸ Customize, it brings them all back.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.TUI.{Layout, Update}

  setup do
    Process.delete(:effects_seen)
    %{db: quiet_meetings(Agendum.Sample.build(~D[2026-10-08]))}
  end

  defp current(state), do: Layout.current_row(state).item

  describe "off, as Agendum starts the first time" do
    test "the menus have no extras", %{db: db} do
      state = start(db)
      transfer = state |> press([{:f, 10}, "f", "t"]) |> screen()
      assert transfer =~ "Export"
      refute transfer =~ "Calendars"
      refute transfer =~ "Publish"
      refute transfer =~ "Feeds"

      item = state |> press([{:f, 10}, "i"]) |> screen()
      refute item =~ "Zettel"
      refute item =~ "Open link"
    end

    test "File ▸ Transfer says only what it holds", %{db: db} do
      menu = db |> start() |> press([{:f, 10}, "f"]) |> to_entry("Transfer") |> screen()
      refute menu =~ "feeds"
    end

    test "the extras' keys do nothing", %{db: db} do
      state = db |> start() |> press([:down, {:ctrl, "t"}])
      assert current(state).zettel == nil
      assert state.db == db |> start() |> press(:down) |> Map.get(:db)
    end

    test "F1 c and CTRL-X do not list them", %{db: db} do
      state = start(db)
      refute state |> press([{:f, 1}, "c" | String.graphemes("attach")]) |> screen() =~ "Attach"
      refute state |> press([{:ctrl, "x"} | String.graphemes("attach")]) |> screen() =~ "Attach"
    end

    test "the view manager has no ► and no F5", %{db: db} do
      state = db |> start() |> press({:f, 8})
      refute screen(state) =~ "►"
      refute slots(state) =~ "F5"
      state = press(state, {:f, 5})
      refute screen(state) =~ "recently used"
    end

    test "the key bar keeps Agenda's short labels on a wide screen", %{db: db} do
      bar = db |> start(width: 160) |> slots()
      assert bar =~ "F8 Vw Mgr"
      refute bar =~ "View manager"
    end

    test "feeds and calendars are not read", %{db: db} do
      {:ok, db, _id} = Core.subscribe_feed(db, "Owl's Gazette", "https://owl.example/rss")
      {_state, effects} = db |> start() |> Update.tick(~N[2026-10-08 10:00:00])
      refute Enum.any?(effects, &match?({:fetch_feed, _, _}, &1))
    end

    test "a missed alarm rings, as Agenda's does, without a box", %{db: db} do
      {db, id} = Core.add_item(db, "Personnel meeting at 2:00", ~N[2026-10-07 10:00:00])
      {:ok, db} = Core.set_alarm(db, id, 5)

      state =
        db |> start(today: ~D[2026-10-08], now: ~N[2026-10-08 09:00:00]) |> Update.arrive()

      refute screen(state) =~ "While you were away"
      assert screen(state) =~ "Alarm: Personnel meeting at 2:00"
      assert {:sound, :alarm} in state.effects
      assert id in Core.alarm_list(state.db).past
    end
  end

  describe "on" do
    test "the menus, keys and lists have the extras", %{db: db} do
      state = start(db, extras: true, width: 160)
      assert state |> press([{:f, 10}, "f", "t"]) |> screen() =~ "Feeds"
      assert state |> press([{:f, 10}, "i"]) |> screen() =~ "Zettel"

      assert state |> press([{:f, 1}, "c" | String.graphemes("attach")]) |> screen() =~
               "Attach Zettel id"

      assert state |> press([:down, {:ctrl, "t"}]) |> current() |> Map.get(:zettel) != nil
      assert state |> press({:f, 8}) |> screen() =~ "►"
    end

    test "feeds are read on schedule", %{db: db} do
      {:ok, db, _id} = Core.subscribe_feed(db, "Owl's Gazette", "https://owl.example/rss")
      {_state, effects} = db |> start(extras: true) |> Update.tick(~N[2026-10-08 10:00:00])
      assert Enum.any?(effects, &match?({:fetch_feed, _, _}, &1))
    end
  end

  test "Customize turns it on, in the person's preferences", %{db: db} do
    state = db |> start() |> press([{:f, 10}, "f", "c"]) |> to_setting("Extras")
    assert screen(state) =~ ~r/Extras +: No/
    state = press(state, " ")
    assert state.prefs.extras
    assert screen(state) =~ ~r/Extras +: Yes/
    state = press(state, [:enter, {:f, 10}, "f", "t"])
    assert screen(state) =~ "Feeds"
  end

  test "turned off, the view manager goes back to the person's order", %{db: db} do
    state = db |> start(extras: true) |> press([{:f, 8}, {:f, 5}])
    assert screen(state) =~ "recently used"

    state =
      state
      |> press([:esc, {:f, 10}, "f", "c"])
      |> to_setting("Extras")
      |> press([" ", :enter, {:f, 8}])

    refute screen(state) =~ "recently used"
  end

  # moves the menu's highlight to an entry by its label, without choosing it
  defp to_entry(state, label) do
    Enum.reduce_while(1..20, state, fn _, state ->
      if menu_highlight(state) == label,
        do: {:halt, state},
        else: {:cont, press(state, :right)}
    end)
  end

  defp menu_highlight(state) do
    mode = Agendum.TUI.State.mode(state)
    {label, _, _} = Enum.at(Agendum.TUI.Menu.entries(mode), mode.selected)
    label
  end
end
