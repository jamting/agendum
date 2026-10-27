defmodule Agendum.TUI.Extras.ManagersTest do
  @moduledoc """
  The Feeds and Calendars boxes as managers, as the Macros manager is (UI
  guidelines, gaps 2-4; the owner's answers, 2026-10-27): ENTER reads the
  highlighted one, ALT-ENTER all of them, INS subscribes, F2 renames, F6
  its properties, DEL unsubscribes; in Feeds, F7 imports an OPML list and
  F8 exports one. The letter keys are gone.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.TUI.State

  setup do
    db = Core.new_file()
    {:ok, db, _} = Core.subscribe_feed(db, "Owl's Gazette", "https://owl.example/rss")
    {:ok, db, _} = Core.subscribe_feed(db, "Piglet Post", "https://piglet.example/rss")
    {:ok, db, _} = Core.subscribe_calendar(db, "Wood Events", "https://wood.example/cal.ics")
    {:ok, db, _} = Core.subscribe_calendar(db, "Owl's Days", "https://owl.example/cal.ics")
    Process.delete(:effects_seen)
    %{state: start(db, extras: true)}
  end

  defp feeds(state), do: press(state, [{:f, 10}, "f", "t", "f"])
  defp calendars(state), do: press(state, [{:f, 10}, "f", "t", "c"])
  defp fetched(kind), do: for(e <- effects(), elem(e, 0) == kind, do: elem(e, 2))

  test "ALT-ENTER reads every feed, ENTER the highlighted one", %{state: state} do
    state |> feeds() |> press({:alt, :enter})

    assert Enum.sort(fetched(:fetch_feed)) == [
             "https://owl.example/rss",
             "https://piglet.example/rss"
           ]

    Process.delete(:effects_seen)
    state |> feeds() |> press(:enter)
    assert length(fetched(:fetch_feed)) == 1
  end

  test "ALT-ENTER reads every calendar", %{state: state} do
    state |> calendars() |> press({:alt, :enter})
    assert length(fetched(:fetch_calendar)) == 2
  end

  test "F7 asks for an OPML list to import, F8 where to export one", %{state: state} do
    assert panel(state |> feeds() |> press({:f, 7})) =~ "OPML file to import:"
    assert panel(state |> feeds() |> press({:f, 8})) =~ "Write the feed list (OPML) to:"
  end

  test "the letter keys do nothing any more", %{state: state} do
    for {open, letters} <- [{&feeds/1, ~w(f k r i e)}, {&calendars/1, ~w(f a r)}] do
      box = open.(state)

      for letter <- letters,
          do:
            assert(
              press(box, letter).db == box.db and
                State.mode(press(box, letter)) == State.mode(box)
            )
    end
  end

  test "the key hints are made from the keys", %{state: state} do
    text = screen(feeds(state))
    assert text =~ "F7"
    refute text =~ "K how long kept"
  end

  describe "F6, a feed's properties" do
    setup %{state: state} do
      %{box: state |> feeds() |> press({:f, 6})}
    end

    defp feed(state), do: hd(Agendum.Core.Database.feeds(state.db))

    test "shows its name, address, settings and last read", %{box: box} do
      text = screen(box)
      assert text =~ "Feed Properties"
      assert text =~ "https://owl.example/rss"
      assert text =~ "not read yet"
    end

    test "SPACE changes a setting at once; ESC puts it back", %{box: box} do
      changed = box |> to_setting("Keep") |> press(" ")
      assert feed(changed).keep_days == 90
      assert feed(press(changed, :esc)).keep_days == 30
    end

    test "typing on Name renames the feed and its category", %{box: box} do
      state = box |> press(["O", "w", "l", :enter, :enter])
      assert feed(state).name == "Owl"
      assert state.db.categories[feed(state).category_id].name == "Owl"
    end

    test "a read that comes while the box is open stays when ESC closes it", %{state: state} do
      # the review of 2026-10-27: ESC put back the file as it was when the
      # box opened, and the read with it
      state = state |> feeds() |> press(:enter) |> press({:f, 6})
      id = feed(state).id

      state =
        Agendum.TUI.Update.Results.feed_read(state, id, feed(state).url, {:error, "no answer"})

      assert feed(state).error == "no answer"
      assert feed(press(state, :esc)).error == "no answer"
    end

    test "ALT-ENTER with nothing left to read says so", %{state: state} do
      state = state |> feeds() |> press({:alt, :enter}) |> press({:alt, :enter})
      assert panel(state) =~ "No feeds to read now"
    end

    test "F8 puts a setting back to a new feed's", %{box: box} do
      changed = box |> to_setting("Read every") |> press([" ", " "])
      assert feed(changed).refresh_minutes == 1440
      assert feed(press(changed, {:f, 8})).refresh_minutes == 60
    end
  end
end
