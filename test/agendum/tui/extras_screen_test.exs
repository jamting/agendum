# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.ExtrasScreenTest.Labels do
  @moduledoc false
  # the labels in `on` (a menu level with the extras) that `off` (without)
  # does not have, and those of the submenus both have, all the way down
  def extra_labels(on, off) do
    off_by_label = Map.new(off, fn {label, _, action} -> {label, action} end)

    Enum.flat_map(on, fn {label, _, action} ->
      case off_by_label do
        %{^label => sub} when is_list(sub) and is_list(action) -> extra_labels(action, sub)
        %{^label => _} -> []
        _ -> [label]
      end
    end)
  end
end

defmodule Agendum.TUI.ExtrasScreenTest do
  @moduledoc """
  The extras off, checked on screen (R77, ADR 0043): with the Extras
  preference off, as Agendum starts, no screen shows a word of the extras.
  It draws every menu level (the view's, the category manager's, the
  note's), every place (the view, the managers, a note), every box the fuzz
  walks start in (`Agendum.BoxPaths`), the F1 page and its list of commands
  in each, and the text of every F1 topic, and fails on any of the extras'
  words. The other tests check the code paths (`ExtrasSwitchTest`, the doors
  in `ArchitectureTest`); this one checks what is drawn.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.TUI.{Help.Topic, Help.Topics, Menu, Update}

  # the extras' words: Zettel ids, the blog, feeds, calendar subscriptions
  # (Agenda's own pop-up calendar, ALT-C, is the clone's, so "Calendar"
  # alone is not one); whole words, so "feedback" in an item is not "feed"
  @words ~r/\b(Zettels?|Quadsyl|Feeds?|feeds?|RSS|OPML|Atom|Publish\w*|publish\w*|[Bb]logs?|Calendars|calendars|webcal|[Ss]ubscri\w*|permalinks?|Extras?)\b/

  # the menus' own names of the extras' entries, whatever they are called:
  # the labels a level has only with the extras on, level by level
  @menu_extras (for which <- [:main, :catmgr, :note] do
                  Agendum.TUI.ExtrasScreenTest.Labels.extra_labels(
                    Menu.shown(which, true),
                    Menu.shown(which, false)
                  )
                end)
               |> List.flatten()
               |> Enum.uniq()

  setup do
    # the sample file, with nothing of the extras in it
    %{state: start(Agendum.Sample.build(~D[2026-10-08]))}
  end

  # every word of the extras on a screen, with where it was seen
  defp extras_on(text, where) do
    words = @words |> Regex.scan(text) |> Enum.map(&hd/1)
    labels = Enum.filter(@menu_extras, &String.contains?(text, &1))

    if switch?(where),
      do: [],
      else: for(word <- Enum.uniq(words ++ labels), do: "#{where}: #{word}")
  end

  defp seen(state, where), do: extras_on(screen(state), where)

  # the switch itself (Utilities ▸ Customize ▸ Extras, R77) names what it
  # turns on: its box and its topic may, nothing else
  defp switch?(where), do: where =~ "Customize Box" or where =~ ~s(char: "u", char: "c"])

  # a screen, and its F1 page, and F1's list of commands there
  defp with_help(state, where) do
    seen(state, where) ++
      seen(press(state, {:f, 1}), "#{where} ▸ F1") ++
      seen(press(state, [{:f, 1}, {:f, 6}, :enter]), "#{where} ▸ F1 commands")
  end

  # the menu from `state` (open), each level drawn, its entries' submenus
  # opened by their first letter
  defp menu_levels(state, level, where) do
    here = seen(state, where)

    below =
      for {label, _, action} <- level,
          is_list(action),
          letter = label |> String.first() |> String.downcase(),
          problem <-
            menu_levels(press(state, {:char, letter}), action, "#{where} ▸ #{label}"),
          do: problem

    here ++ below
  end

  defp open_box(state, {:answer, :new_file}),
    do: Update.Results.loaded(state, "/tmp/extras-off.agendum", {:error, :enoent})

  defp open_box(state, {:answer, :import_report}),
    do:
      Update.Results.import_ag(
        state,
        "/tmp/RICH.AG",
        File.read!("test/fixtures/ag/RICH.AG"),
        nil
      )

  defp open_box(state, keys) when is_list(keys), do: press(state, keys)
  defp open_box(state, {keys, labels}), do: open_box(state, {keys, labels, []})

  # as the fuzz walks do: a setting this file's box cannot reach leaves
  # the outer box open
  defp open_box(state, {keys, labels, after_}) do
    state = press(state, keys)

    try do
      labels
      |> List.wrap()
      |> Enum.reduce(state, fn label, state -> state |> to_setting(label) |> press(" ") end)
      |> press(after_)
    rescue
      e in RuntimeError ->
        if e.message =~ "no setting labelled", do: state, else: reraise(e, __STACKTRACE__)
    end
  end

  test "every menu level", %{state: state} do
    problems =
      menu_levels(press(state, {:f, 10}), Menu.shown(:main, false), "F10") ++
        menu_levels(press(state, [{:f, 9}, {:f, 10}]), Menu.shown(:catmgr, false), "F9 F10") ++
        menu_levels(press(state, [:down, {:f, 5}, {:f, 10}]), Menu.shown(:note, false), "F5 F10")

    assert problems == [], Enum.join(problems, "\n")
  end

  test "every place, with its F1 page and commands", %{state: state} do
    problems =
      with_help(state, "the view") ++
        with_help(press(state, {:f, 9}), "the category manager") ++
        with_help(press(state, {:f, 8}), "the view manager") ++
        with_help(press(state, [:down, {:f, 5}]), "a note") ++
        seen(start(Agendum.Sample.build(~D[2026-10-08]), width: 160), "a wide view")

    assert problems == [], Enum.join(problems, "\n")
  end

  test "every box, with its F1 page and commands", %{state: state} do
    problems =
      for path <- Agendum.BoxPaths.all(),
          problem <- state |> open_box(path) |> with_help(inspect(path)),
          do: problem

    assert problems == [], Enum.join(problems, "\n")
  end

  test "every F1 topic, and the list of them", %{state: state} do
    titles = Topics.titles(state)

    problems =
      extras_on(Enum.join(titles, "\n"), "the topics' titles") ++
        for title <- titles,
            line <- Topic.lines(Topics.get(state, title), 76),
            problem <- extras_on(Enum.map_join(line, &Topic.label/1), title),
            do: problem

    assert problems == [], Enum.join(Enum.uniq(problems), "\n")
  end
end
