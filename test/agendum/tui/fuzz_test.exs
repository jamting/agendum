# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Fuzz do
  @moduledoc """
  Random key sequences must never crash the UI, and every frame must fill the
  screen. The runs are shared among `@parts` test modules (defined at the end
  of this file) so that ExUnit runs them side by side (`async: true` runs
  modules in parallel, never the tests inside one module); one module alone
  set the length of the whole suite.

  A quarter of the walks start from the golden file with the extras on
  (feeds, calendars, a blog), perhaps in one of the extras' boxes; about
  half the others start inside one of the clone's boxes (`@boxes`), on a
  standard view or a datebook of any period. Between
  the keys, a walk also plays the shell's side (meeting 2026-10-26-2234, § 7):
  the answers of reads and uploads under way, out of order and sometimes
  after another file was opened, through `Agendum.TUI.App.background/2`,
  checking that nothing is filed into a file that did not ask for it.
  """
  use ExUnitProperties
  import ExUnit.Assertions

  alias Agendum.Core.Invariants
  alias Agendum.TUI.{History, Terminal.Draw, Render, Update}
  import Agendum.TUIHelpers, only: [start: 2, assert_known_effects: 2]

  @keys [
    :up,
    :down,
    :left,
    :right,
    :home,
    :end,
    :pgup,
    :pgdn,
    :enter,
    :esc,
    :tab,
    :shift_tab,
    :insert,
    :delete,
    :backspace,
    :ctrl_pgup,
    :ctrl_pgdn,
    :ctrl_home,
    :ctrl_end,
    {:alt, :up},
    {:alt, :down},
    {:alt, "d"},
    {:alt, "u"},
    {:alt, "r"},
    {:alt, "l"},
    {:alt_f, 4},
    {:alt_f, 10},
    {:ctrl, "u"},
    {:ctrl, "d"},
    {:ctrl, "z"},
    {:ctrl, "z"},
    {:ctrl, "y"},
    {:ctrl, "n"},
    {:ctrl, "e"},
    {:ctrl, "k"},
    {:ctrl, "a"},
    {:ctrl, "w"},
    # the extras' keys (Zettel ids and links, a feed entry's link), which
    # do nothing while the extras are off (R77)
    {:ctrl, "t"},
    {:ctrl, "g"},
    {:ctrl, "r"},
    {:ctrl, "v"},
    {:ctrl, "l"},
    # run by name (R65d): letters then ENTER run whatever matches
    {:ctrl, "x"},
    {:alt, "b"},
    {:alt, :backspace},
    {:alt, "n"},
    {:alt, "p"},
    {:alt, "-"},
    {:alt, "="},
    {:alt_f, 7},
    {:alt, "j"},
    {:alt, "m"},
    {:alt_f, 5},
    {:alt_f, 6},
    {:alt_f, 8},
    {:alt, "a"},
    {:alt, "s"},
    {:alt, "k"},
    {:alt, "v"},
    {:alt, "w"},
    {:alt, "g"},
    {:alt, "i"},
    {:alt, "t"},
    {:alt, "q"},
    {:alt, "o"},
    {:alt, "x"},
    {:alt, "e"},
    {:alt_f, 3},
    {:alt_f, 3},
    {:alt, "z"},
    # a count (R65)
    {:alt, "1"},
    {:alt, "3"},
    :tick
  ]

  # `frequency/1` picks a generator by weight: the keys, function keys and
  # characters a third each as before, and now and then something from the
  # shell's side, not a key (meeting 2026-10-26-2234, § 7): a background
  # task's answer (`{:background, pick, outcome}`, see `deliver/3`), or
  # another file opened (`:switch_file`) while reads are under way.
  defp key do
    frequency([
      {10, member_of(@keys)},
      {10, map(integer(1..10), &{:f, &1})},
      {10, map(member_of(~w(a b H h y n v c d s m x 1 / ! å) ++ [" "]), &{:char, &1})},
      # characters two columns wide, an accent that combines with the letter
      # before and a flag (two code points, one character): every screen is
      # checked for lines exactly as wide as the screen with them in it
      # (R40; the width bugs of v0.73.5 were of that kind)
      {3, map(member_of(["日", "語", "한", "🎉", "e\u0301", "🇸🇪"]), &{:char, &1})},
      {2,
       map({integer(0..3), member_of([:ok, :error, :crash])}, fn {pick, outcome} ->
         {:background, pick, outcome}
       end)},
      {1, constant(:switch_file)}
    ])
  end

  # The golden file (`Agendum.Starters.Golden`: feeds, calendars, a blog,
  # ingested categories), built once per test run: `:persistent_term` keeps
  # a value for the whole VM, cheap to read from any process.
  defp golden do
    case :persistent_term.get({__MODULE__, :golden}, nil) do
      nil ->
        db = Agendum.Starters.Golden.build()
        :persistent_term.put({__MODULE__, :golden}, db)
        db

      db ->
        db
    end
  end

  # The patent's sample, optionally with a numeric Amount column (R29) whose
  # first item has a number.
  defp sample(false), do: Agendum.Sample.build(~D[2026-10-08])

  defp sample(true) do
    db = sample(false)
    {:ok, db, amount} = Agendum.Core.add_category(db, db.main_id, "Amount")
    {:ok, db} = Agendum.Core.make_numeric(db, amount)
    db = Agendum.Core.add_column(db, hd(db.view_order), amount, {0, 0})
    {:ok, db} = Agendum.Core.set_number(db, hd(db.item_order), amount, 12.5)
    db
  end

  # With a date filter on the view, to browse (R48).
  defp with_filter(db, false), do: db

  defp with_filter(db, true) do
    range = {:assigned, "today", "end of this week", :inside}

    {:ok, db} =
      Agendum.Core.set_range_filter(
        db,
        hd(db.view_order),
        :view,
        db.special.when,
        range,
        ~D[2026-10-08]
      )

    db
  end

  defp with_circular(db, false), do: db

  defp with_circular(db, true) do
    {:ok, db, folk} = Agendum.Core.add_category(db, db.main_id, "Folk")
    {:ok, db, ed} = Agendum.Core.add_category(db, folk, "Ed")
    {:ok, db} = Agendum.Core.add_condition(db, ed, folk, :not_assigned)
    db
  end

  # With the alarm list (R38) shown first: one alarm rung, one waiting on an
  # item without a date.
  defp with_alarms(db, false), do: db

  defp with_alarms(db, true) do
    [first, second | _] = db.item_order
    {:ok, db} = Agendum.Core.set_alarm(db, first, 0)
    db = Agendum.Core.Database.update_item(db, first, &%{&1 | when: ~D[2026-10-07]})
    {db, _} = Agendum.Core.ring_alarms(db, ~N[2026-10-08 09:00:00])
    {:ok, db} = Agendum.Core.set_alarm(db, second, 5)
    {db, view} = Agendum.Core.show_alarms(db)
    Agendum.Core.move_view(db, view, 0)
  end

  # With a datebook view of that period (R47), shown first.
  defp with_datebook(db, nil), do: db

  defp with_datebook(db, period) do
    datebook = %Agendum.Core.Datebook{period: period}
    {:ok, db, view} = Agendum.Core.add_datebook_view(db, "Datebook", datebook)
    Agendum.Core.move_view(db, view, 0)
  end

  # A key that changed the file recorded undo steps, and undoing them gives
  # the file back as it was (R30): one user action, one database change.
  # Undo takes a step off the stack (redo puts one on, which undo takes
  # back like any other); a new file starts without history; a full
  # history (100 steps) has dropped its oldest.
  defp assert_undoable(before, state, key) do
    steps = length(state.history.undo) - length(before.history.undo)
    new_file = state.saved.db != before.saved.db
    full = length(state.history.undo) >= 100

    if state.db != before.db and steps >= 0 and not new_file and not full and
         not settled?(before, state) do
      assert steps >= 1, "#{inspect(key)} changed the file but recorded no undo step"
      undone = Enum.reduce(1..steps, state, fn _, s -> History.undo(s) end)
      assert undone.db == before.db, "undoing #{inspect(key)} did not give the file back"
    end
  end

  # The key closed the outermost settings box, which folded the steps made
  # in it into one (ADR 0030, `BoxCancel.settle/2`), perhaps in place of
  # the one it had (found by the long fuzz run, seed 5914, 2026-10-26):
  # the steps of when it opened and one more, which gives the file back as
  # it was then.
  defp settled?(before, state) do
    case before.modes |> Enum.filter(&Map.get(&1, :opened)) |> List.last() do
      %{opened: opened} ->
        length(state.history.undo) == length(opened.undo) + 1 and
          History.undo(state).db == opened.db

      nil ->
        false
    end
  end

  # Each gives the new state and the effects asked for on the way, so the
  # walk knows which reads and uploads are under way.
  defp tick(state, now) do
    {state, effects} = Update.tick(state, now)
    assert_known_effects(effects, :tick)
    {state, effects}
  end

  defp handle(state, keys, seen \\ [])
  defp handle(state, [], seen), do: {state, seen}

  defp handle(state, [key | keys], seen) do
    {state, effects} = Update.handle(state, key)
    assert_known_effects(effects, key)
    played = for {:play, played} <- effects, k <- played ++ [:macro_done], do: k
    handle(state, played ++ keys, seen ++ effects)
  end

  # the clock ten minutes on, as the shell's loop moves it
  defp clock(walk) do
    {state, effects} = tick(walk.state, NaiveDateTime.add(walk.state.now, 600))
    %{walk | state: state, pending: walk.pending ++ asked(effects, walk.file)}
  end

  # File ▸ Transfer ▸ Feeds, Calendars or Publish; `:preview` is Publish's
  # ENTER too, which shows what publishing would change, and `:upload` the
  # preview's ENTER after it, so the upload is under way from the start
  # The boxes a walk may start in (expert review 2026-10-30, § 18.1): the
  # keys that open each from the view, and for a box opened from a box,
  # the setting's label to go to first and the keys there. A random walk
  # from the view hardly reaches the boxes inside boxes, where the
  # crash of 2026-10-30 was (View Properties on a datebook, ↑ from Filter).
  @f10 {:f, 10}
  # "When" typed into a category list, to find it
  @when_typed for c <- ~w(W h e n), do: {:char, c}

  @boxes [
    [@f10, {:char, "v"}, {:char, "p"}],
    [@f10, {:char, "v"}, {:char, "s"}, {:char, "p"}],
    [@f10, {:char, "v"}, {:char, "s"}, {:char, "a"}],
    [@f10, {:char, "f"}, {:char, "p"}],
    [@f10, {:char, "f"}, {:char, "a"}],
    [@f10, {:char, "u"}, {:char, "c"}],
    [@f10, {:char, "u"}, {:char, "q"}],
    [@f10, {:char, "u"}, {:char, "e"}],
    [@f10, {:char, "u"}, {:char, "s"}, {:char, "m"}],
    [@f10, {:char, "u"}, {:char, "s"}, {:char, "s"}],
    [:down, @f10, {:char, "v"}, {:char, "c"}, {:char, "a"}],
    [:down, :right, @f10, {:char, "v"}, {:char, "c"}, {:char, "p"}],
    [:down, @f10, {:char, "i"}, {:char, "a"}],
    [:down, {:f, 6}],
    [:down, {:f, 3}],
    [:down, {:alt_f, 9}],
    [:down, {:f, 5}, {:alt_f, 6}],
    [{:f, 8}],
    [{:f, 9}, {:f, 6}],
    [{:alt_f, 5}],
    [{:alt_f, 3}, {:f, 3}],
    [{:alt_f, 3}, :down, {:f, 6}],
    [{:alt, "c"}],
    [@f10, {:char, "f"}, {:char, "r"}, {:f, 3}],
    {[@f10, {:char, "v"}, {:char, "p"}], "Item sorting"},
    {[@f10, {:char, "v"}, {:char, "p"}], "Filter"},
    {[@f10, {:char, "v"}, {:char, "p"}], "View statistics"},
    {[@f10, {:char, "v"}, {:char, "s"}, {:char, "p"}], "Filter"},
    {[@f10, {:char, "f"}, {:char, "p"}], "Global date settings"},
    {[@f10, {:char, "f"}, {:char, "p"}], "Auto-assign settings"},
    {[@f10, {:char, "f"}, {:char, "p"}], "File statistics"},
    {[@f10, {:char, "f"}, {:char, "p"}], "Update defaults"},
    {[@f10, {:char, "u"}, {:char, "c"}], "Input format"},
    {[{:f, 9}, {:f, 6}], "Statistics"},
    {[{:f, 9}, {:f, 6}], "Advanced settings"},
    {[{:f, 9}, {:f, 6}], "Assignment conditions"},
    {[{:f, 9}, {:f, 6}], "Assignment actions"},
    # boxes deeper inside, or needing the file in a certain state
    # (ROADMAP, Sharpen the saw): Advanced settings of a date category
    # (Entry) is its date rule box; a date category picked in a filter or
    # an action opens its range or action box
    {[{:f, 9}, :down, {:f, 6}], "Advanced settings"},
    {[@f10, {:char, "f"}, {:char, "p"}], ["Global date settings", "Display format"]},
    {[@f10, {:char, "f"}, {:char, "p"}], "Set file password"},
    {[@f10, {:char, "v"}, {:char, "s"}, {:char, "p"}], "Select numeric functions"},
    {[@f10, {:char, "v"}, {:char, "p"}], "Filter", @when_typed ++ [:enter, {:char, " "}]},
    {[{:f, 9}, :ctrl_end, {:f, 6}], "Assignment actions", @when_typed ++ [:enter, {:char, " "}]},
    # the item column's box: Column Properties on the item text
    [:down, @f10, {:char, "v"}, {:char, "c"}, {:char, "p"}],
    # Undisc with two items in the trash asks which
    [:down, {:alt_f, 4}, :enter, {:alt_f, 4}, :enter, @f10, {:char, "i"}, {:char, "u"}],
    # F3 in a note with nothing marked asks what to copy
    [:down, {:f, 5}, {:f, 3}]
  ]

  defp open_box(walk, nil), do: walk
  defp open_box(walk, keys) when is_list(keys), do: press_shell(walk, keys)

  # a box inside a box: SPACE on its setting (on each in turn, for a list
  # of labels), then the keys after, when the outer box (on this view, at
  # this size) can reach it; when it cannot, the walk starts in the outer
  # box
  defp open_box(walk, {keys, labels}), do: open_box(walk, {keys, labels, []})

  defp open_box(walk, {keys, labels, after_}) do
    walk = press_shell(walk, keys)

    try do
      labels
      |> List.wrap()
      |> Enum.reduce(walk, fn label, walk ->
        %{walk | state: Agendum.TUIHelpers.to_setting(walk.state, label)}
        |> press_shell([{:char, " "}])
      end)
      |> press_shell(after_)
    rescue
      e in RuntimeError ->
        if e.message =~ "no setting labelled", do: walk, else: reraise(e, __STACKTRACE__)
    end
  end

  defp open_extra(walk, nil), do: walk

  defp open_extra(walk, box) do
    letter = %{feeds: "f", calendars: "c"}[box] || "p"
    walk = press_shell(walk, [{:f, 10}, {:char, "f"}, {:char, "t"}, {:char, letter}])
    walk = if box in [:preview, :upload], do: press_shell(walk, [:enter]), else: walk
    if box == :upload, do: press_shell(walk, [:enter]), else: walk
  end

  # keys, and the publish scan they ask for answered, as in the walk
  defp press_shell(walk, keys) do
    {state, effects} = handle(walk.state, keys)
    {state, more} = scanned(state, effects)
    %{walk | state: state, pending: walk.pending ++ asked(effects ++ more, walk.file)}
  end

  # --- the shell's side: background answers and another file -----------------
  #
  # The walk keeps the reads and uploads under way (`pending`), each with
  # the file it was asked for in (`file`, a count of the files opened in
  # the walk), as the shell would have them in flight.

  defp asked(effects, file) do
    for effect <- effects, request = request(effect), request != nil, do: {request, file}
  end

  # The publish box's ENTER asks the shell what the site's folder holds
  # (`{:publish_scan, …}`), which `App` answers at once; the walk answers
  # it as an empty folder would, so the preview opens and its ENTER asks
  # for the upload (`{:publish, …}`), whose answer comes back later.
  defp scanned(state, effects) do
    Enum.reduce(effects, {state, []}, fn
      {:publish_scan, folder, files}, {state, more} ->
        state =
          Agendum.TUI.Extras.Publish.Results.publish_scanned(
            state,
            folder,
            files,
            {:ok, empty_folder()}
          )

        {%{state | effects: []}, more ++ state.effects}

      _effect, acc ->
        acc
    end)
  end

  defp empty_folder, do: %{existing: %{}, published: []}

  defp request({:fetch_feed, id, url}), do: {:feed_read, id, url}
  defp request({:fetch_calendar, id, url}), do: {:calendar_read, id, url}
  defp request({:probe_feed, url}), do: {:feed_probed, url}
  defp request({:probe_calendar, url}), do: {:calendar_probed, url}
  defp request({:publish, _folder, _files, changes, _password}), do: {:published, changes}
  defp request(_effect), do: nil

  # One of the answers waited for, picked out of order (`pick`), or, with
  # none waited for, an answer for a feed or calendar the file has that
  # nobody asked to read (as one started for a file open before). Gives the
  # message the shell would receive, the file that asked (nil: none) and
  # the answers still waited for.
  defp answer(state, pending, pick, outcome) do
    case pending do
      [] ->
        ids =
          Enum.map(Map.values(state.db.feeds), &{:feed_read, &1.id, &1.url}) ++
            Enum.map(Map.values(state.db.calendars), &{:calendar_read, &1.id, &1.url})

        if ids == [],
          do: {nil, nil, pending},
          else: {message(Enum.at(ids, rem(pick, length(ids))), outcome), nil, pending}

      _ ->
        {request, file} = Enum.at(pending, rem(pick, length(pending)))
        {message(request, outcome), file, List.delete(pending, {request, file})}
    end
  end

  # a read that crashed outright, as `App.fetched/1` reports it
  defp message({tag, id, url}, :crash) when tag in [:feed_read, :calendar_read],
    do: {tag, id, url, Agendum.TUI.App.fetched(fn -> raise "boom" end), 1}

  defp message({tag, id, url}, :error) when tag in [:feed_read, :calendar_read],
    do: {tag, id, url, {:error, "the server answered 503"}, 1}

  defp message({:feed_read, id, url}, :ok) do
    entry = %{
      id: "fuzz-#{System.unique_integer([:positive])}",
      title: "Heffalump sighted",
      link: "https://owl.example/heffalump",
      summary: "Piglet says so.",
      published: ~N[2026-10-07 07:00:00]
    }

    {:feed_read, id, url, {:ok, [entry]}, 1}
  end

  defp message({:calendar_read, id, url}, :ok) do
    event = %Agendum.Core.Extras.ICal.Event{
      uid: "fuzz-#{System.unique_integer([:positive])}",
      summary: "Tea",
      start: {:date, ~D[2026-10-09]}
    }

    {:calendar_read, id, url, {:ok, [event]}, 1}
  end

  # a read before subscribing (R75, R45): its title and what it holds,
  # why it failed, or a crash
  defp message({tag, url}, :crash) when tag in [:feed_probed, :calendar_probed],
    do: {tag, url, Agendum.TUI.App.fetched(fn -> raise "boom" end), 1}

  defp message({tag, url}, :error) when tag in [:feed_probed, :calendar_probed],
    do: {tag, url, {:error, "no answer"}, 1}

  defp message({:feed_probed, url}, :ok) do
    {:feed_read, _, _, {:ok, entries}, _} = message({:feed_read, 0, url}, :ok)
    {:feed_probed, url, {:ok, %{title: "Owl's \e[2J Gazette", entries: entries}}, 1}
  end

  defp message({:calendar_probed, url}, :ok) do
    {:calendar_read, _, _, {:ok, events}, _} = message({:calendar_read, 0, url}, :ok)
    {:calendar_probed, url, {:ok, %{title: nil, events: events}}, 1}
  end

  defp message({:published, changes}, :ok), do: {:published, changes, :ok}
  defp message({:published, changes}, :error), do: {:published, changes, {:error, "no rsync"}}
  defp message({:published, changes}, :crash), do: {:published, changes, {:error, :password}}

  # Delivers an answer through `App.background/2`, as the shell's loop
  # does. One that nobody asked for, or that another file asked for, must
  # leave this file alone (code review 2026-10-26), unless this file is
  # reading the same address under the same id itself: files count their
  # ids from one, and a file opened again has the same ones.
  defp deliver(walk, pick, outcome) do
    case answer(walk.state, walk.pending, pick, outcome) do
      {nil, _, _} ->
        walk

      {message, asked_in, pending} ->
        state = Agendum.TUI.App.background(walk.state, message)

        if asked_in != walk.file and not reading_too?(walk.state, message),
          do:
            assert(
              state.db == walk.state.db,
              "#{inspect(message)} for another file was filed into this one"
            )

        # what the answer asked for next, as the loop runs it
        effects = state.effects
        assert_known_effects(effects, message)
        state = %{state | effects: []}
        %{walk | state: state, pending: pending ++ asked(effects, walk.file)}
    end
  end

  defp reading_too?(state, {tag, id, url, _result, _ms}) do
    subscriptions = if tag == :feed_read, do: state.db.feeds, else: state.db.calendars
    match?(%{^id => {_kind, ^url}}, state.fetching) and match?(%{url: ^url}, subscriptions[id])
  end

  defp reading_too?(_state, {:published, _changes, _result}), do: false
  # a read before subscribing changes no file: it only asks for a name
  defp reading_too?(_state, {_probed, _url, _result, _ms}), do: false

  # Another file opened, as `App` hands a Retrieve's result to
  # `Update.Results.loaded/3`, while the old file's reads may still come
  # back: the golden file, whose ids are those of a walk started from it,
  # every other time with other addresses under the same ids (another file
  # altogether), else as it is (the same file opened again).
  defp switch_file(walk) do
    file = walk.file + 1
    db = if rem(file, 2) == 1, do: readdressed(golden()), else: golden()
    state = Update.Results.loaded(walk.state, "other.agendum", {:ok, db, "stamp"})
    effects = state.effects

    %{
      walk
      | state: %{state | effects: []},
        file: file,
        pending: walk.pending ++ asked(effects, file)
    }
  end

  # `Map.new/2` makes a map from another one, each pair through the function
  defp readdressed(db) do
    other = fn subscriptions ->
      Map.new(subscriptions, fn {id, s} -> {id, %{s | url: s.url <> "?other"}} end)
    end

    %{db | feeds: other.(db.feeds), calendars: other.(db.calendars)}
  end

  # With macros (R50): one on F4 that types and calls the other, which runs
  # the manager's first macro from inside itself.
  defp with_macros(db) do
    {:ok, db, water} = Agendum.Core.add_macro(db, "Water")
    db = Agendum.Core.set_macro_keys(db, water, "Water the lettuces{ENTER}{DOWN}{CALL Again}")
    db = Agendum.Core.attach_macro(db, water, "{F4}")
    {:ok, db, again} = Agendum.Core.add_macro(db, "Again")
    Agendum.Core.set_macro_keys(db, again, "{AltF3}{ENTER}x{AltZ}")
  end

  # 1,000 runs in the suite (300 until 2026-10-31, when the owner gave
  # mix check about 8 seconds more for a net three times wider); FUZZ_RUNS
  # sets more for a longer search after a large TUI change:
  # FUZZ_RUNS=3000 mix test test/agendum/tui/fuzz_test.exs
  @runs String.to_integer(System.get_env("FUZZ_RUNS", "1000"))
  @parts 8

  @doc "How many test modules share the runs."
  def parts, do: @parts

  @doc "ExUnit's timeout for one part: its 60 seconds for every 300 runs."
  def timeout, do: 60_000 * max(1, div(@runs, 300))

  @doc """
  Runs part `part` (1..parts) of the property. Each part starts from its own
  seed, ExUnit's plus the part, so the parts try different sequences and
  `mix test --seed N` still repeats a failure.
  """
  def run(part) do
    check all(
            keys <- list_of(key(), max_length: 60),
            width <- integer(40..120),
            height <- integer(10..40),
            numeric <- boolean(),
            datebook <- member_of([nil, nil, :day, :week, :month, :quarter]),
            filtered <- boolean(),
            # the alarm list (R38) shown first, with a past and a current alarm
            alarms <- boolean(),
            # a contradictory condition (Ed, under Folk, if not in Folk), so
            # that items are caught in a circular reference (R37's o)
            circular <- boolean(),
            # the Extras preference (R77), off as Agendum starts, or on
            extras <- boolean(),
            # a quarter of the walks start from the golden file with the
            # extras on: feeds, calendars, a blog (meeting 2026-10-26-2234, § 7)
            from_golden <- member_of([false, false, false, true]),
            # and then perhaps with one of the extras' boxes open, which a
            # random walk would hardly reach through the menu
            opening <- member_of([nil, :feeds, :calendars, :publish, :preview, :upload]),
            # about half the other walks start inside one of the boxes
            box <- member_of(List.duplicate(nil, length(@boxes)) ++ @boxes),
            max_runs: div(@runs + @parts - 1, @parts),
            initial_seed: ExUnit.configuration()[:seed] + part
          ) do
      state =
        if from_golden do
          # a day after the golden file's, when its feed and calendar are
          # due to be read again, so the first tick asks for them
          golden()
          |> start(
            width: width,
            height: height,
            extras: true,
            today: ~D[2026-10-17],
            now: ~N[2026-10-17 12:00:00]
          )
        else
          numeric
          |> sample()
          |> with_filter(filtered)
          |> with_datebook(datebook)
          |> with_macros()
          |> with_alarms(alarms)
          |> with_circular(circular)
          |> start(width: width, height: height, extras: extras)
        end

      # the walk: the state, the reads and uploads under way, and which
      # file is open (a count of the files opened)
      walk = %{state: state, pending: [], file: 0}

      # the golden file's walks begin as the shell does, with the clock's
      # tick before the first drawing: its feed and calendar are due, so
      # their reads are under way from the start
      walk =
        if from_golden,
          do: walk |> clock() |> open_extra(opening),
          else: open_box(walk, box)

      Enum.reduce(keys, walk, fn key, walk ->
        # :tick advances the clock ten minutes, as the shell's loop would;
        # a macro run's keys are played next, as the shell plays them
        before = walk.state

        walk =
          case key do
            :tick ->
              clock(walk)

            {:background, pick, outcome} ->
              deliver(walk, pick, outcome)

            :switch_file ->
              switch_file(walk)

            key ->
              press_shell(walk, [key])
          end

        state = walk.state

        assert state.macro.playing == 0

        # the file stays sound (docs/DATA_MODEL.md, "Invariants")
        assert Invariants.violations(state.db) == [], "after #{inspect(key)}"
        # the circular items kept up to date as keys change the file are
        # those worked out afresh (R37's o)
        assert state.circular ==
                 MapSet.new(
                   Agendum.Core.circular_items(state.db, Agendum.TUI.State.context(state))
                 ),
               "circular items after #{inspect(key)}"

        # every mode on the stack is its struct, none a bare map (Agendum.TUI.Modes)
        assert Enum.all?(state.modes, &is_struct/1), "a bare map mode after #{inspect(key)}"

        if key not in [:tick, :switch_file], do: assert_undoable(before, state, key)

        screen = Render.render(state)

        assert length(screen) == height, "screen has #{length(screen)} lines, expected #{height}"

        for line <- screen,
            do: assert(Draw.width(line) == width, "line width #{Draw.width(line)} != #{width}")

        walk
      end)
    end
  end
end

# One test module per part; `for` at the top level defines them when the file
# is loaded, and a module body sees the variables around it, so `@part` keeps
# each one's number.
for part <- 1..Agendum.TUI.Fuzz.parts() do
  defmodule Module.concat(Agendum.TUI.FuzzTest, "Part#{part}") do
    @moduledoc "Part #{part} of the fuzz property (`Agendum.TUI.Fuzz`)."
    use ExUnit.Case, async: true
    @part part

    @tag timeout: Agendum.TUI.Fuzz.timeout()
    test "the UI survives any key sequence (part #{@part})" do
      Agendum.TUI.Fuzz.run(@part)
    end
  end
end
