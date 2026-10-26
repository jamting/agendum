defmodule Agendum.TUI.HelpTopicsTest do
  @moduledoc """
  The help as Agenda's (R65e, ADR 0047; meeting 2026-10-26; checked in
  Agenda 2.0, 2026-10-26): F1 shows the topic for where you are, with
  links; Agenda's keys move between topics; and the checks that keep the
  help whole: every box, menu and place has a topic, every link leads to
  one, every key a written topic names is a key.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.TUI.{HelpScreen, Keymap, Menu, State}
  alias Agendum.TUI.Boxes.Box
  alias Agendum.TUI.Help.{Topic, Topics}

  setup do
    %{state: start(Agendum.Sample.build(~D[2026-10-26]), height: 40, width: 100)}
  end

  defp title(state), do: State.mode(state).topic.title

  # the highlighted link's label
  defp highlighted(state) do
    for line <- HelpScreen.lines(state, State.mode(state)),
        {:help_link_selected, label} <- line,
        do: label
  end

  describe "a topic and its links" do
    test "F1 shows the place's topic, its first link highlighted", %{state: state} do
      state = press(state, {:f, 1})
      assert title(state) == "Views"
      assert highlighted(state) == ["Keys"]
    end

    test "↓ and ↑ go through the links; ENTER reads one; F8 goes back", %{state: state} do
      state = press(state, [{:f, 1}, :down])
      assert highlighted(state) == ["Commands you can run here"]
      assert highlighted(press(state, :up)) == ["Keys"]

      keys = press(state, [:up, :enter])
      assert title(keys) == "Keys"
      assert title(press(keys, {:f, 8})) == "Views"
      assert title(press(keys, :backspace)) == "Views"
    end

    test "a letter highlights the next link it begins; one none begins does nothing", %{
      state: state
    } do
      state = press(state, [{:f, 1}, {:f, 1}])
      assert title(state) == "How to Use Help"
      assert highlighted(press(state, "d")) == ["Describe a key"]
      assert State.mode(press(state, "q")) == State.mode(state)
    end

    test "F9 and ESC leave the help; another key stays", %{state: state} do
      state = press(state, {:f, 1})
      assert press(state, {:f, 9}).modes == []
      assert press(state, :esc).modes == []
      assert %{type: :help} = State.mode(press(state, {:f, 2}))
    end

    test "the key bar is Agenda's", %{state: state} do
      bar = state |> press({:f, 1}) |> screen() |> String.split("\n") |> Enum.take(-1) |> hd()

      for label <- ["On Help", "Index", "Find", "Keys", "Review", "Return"],
          do: assert(bar =~ label)
    end
  end

  describe "F3, F5 and F6" do
    test "F3: the letters, each to its page of titles", %{state: state} do
      index = press(state, [{:f, 1}, {:f, 3}])
      assert title(index) == "Help Index"
      # END: the last letter that has titles
      assert highlighted(press(index, :end)) != []
      page = press(index, [:enter])
      assert title(page) =~ "Help Index: "
    end

    test "F5: the topics with a word, and ALT-N steps through them", %{state: state} do
      found = press(state, [{:f, 1}, {:f, 5}, "trash", :enter])
      assert title(found) == ~s(Topics with "trash")
      assert screen(found) =~ "Undiscard Box"

      first = press(found, {:alt, "n"})
      second = press(first, {:alt, "n"})
      assert title(first) != title(second)
      assert title(press(second, {:alt, "p"})) == title(first)
    end

    test "F5 with a word no topic has says so", %{state: state} do
      state = press(state, [{:f, 1}, {:f, 5}, "heffalump", :enter])
      assert screen(state) =~ ~s(No help topic has "heffalump")
    end

    test "F6: the keys, the commands here and describe key first", %{state: state} do
      keys = press(state, [{:f, 1}, {:f, 6}])
      assert highlighted(keys) == ["Commands you can run here"]
      assert %{page: :commands} = State.mode(press(keys, :enter))
      # F8 goes back from the command list too, as everywhere in the help
      assert %{page: :topic} = State.mode(press(keys, [:enter, {:f, 8}]))
      assert %{page: :describe} = State.mode(press(keys, [:down, :enter]))
    end
  end

  describe "the checks (ADR 0047)" do
    test "every box, place and menu has a topic", %{state: state} do
      for box <- Box.registry() |> Map.values() |> Enum.uniq(),
          do: assert(Topics.get(state, Topics.box_title(box)), inspect(box))

      for {_place, title} <- Topics.place_titles(), do: assert(Topics.get(state, title), title)

      for which <- [:main, :catmgr, :note] do
        assert Topics.get(state, Topics.menu_title(which, []))

        for {label, _, action} <- Menu.shown(which, false),
            is_list(action),
            do: assert(Topics.get(state, Topics.menu_title(which, [label])), label)
      end
    end

    test "every link leads to a topic or a page of the help", %{state: state} do
      for title <- Topics.titles(state) ++ ["Help Index"],
          target <- Topic.targets(Topics.get(state, title)),
          do: assert(Topics.get(state, target) || Topics.special(target), "#{title} → #{target}")
    end

    test "every key a written topic names is a key of the help or a keymap", %{state: state} do
      bound =
        for(place <- Keymap.places(), {key, _} <- Keymap.bindings(place), do: Keymap.name(key)) ++
          Enum.map(HelpScreen.keys(), &Keymap.name/1)

      for title <- Topics.hand_written(),
          line <- Topic.lines(Topics.get(state, title), 76),
          text = Enum.map_join(line, &Topic.label/1),
          [key] <- Regex.scan(~r/\b(?:F\d{1,2}|(?:ALT|CTRL|SHIFT)-[A-Z0-9]+)\b/, text),
          do: assert(key in bound, "#{title} names #{key}")
    end
  end
end
