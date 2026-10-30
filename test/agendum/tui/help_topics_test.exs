defmodule Agendum.TUI.HelpTopicsTest do
  @moduledoc """
  The help as Agenda's (R65e, ADR 0047; meeting 2026-10-26-0829; checked in
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
      # the written Views topic takes the place of the view's F1 text
      assert title(state) == "Views"
      assert highlighted(state) == ["View Menu"]
      # F9 leaves the help, F9 opens the category manager: its generated topic
      assert title(press(state, [{:f, 9}, {:f, 9}, {:f, 1}])) == "Category Manager"
    end

    test "↓ and ↑ go through the links; ENTER reads one; F8 goes back", %{state: state} do
      state = press(state, [{:f, 1}, :down])
      assert highlighted(state) == ["View Manager"]
      assert highlighted(press(state, :up)) == ["View Menu"]

      menu = press(state, [:up, :enter])
      assert title(menu) == "View Menu"
      assert title(press(menu, {:f, 8})) == "Views"
      assert title(press(menu, :backspace)) == "Views"
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
    test "F3's pages are Agenda's keyword index: headings and their sub-entries", %{
      state: state
    } do
      page = Topics.get(state, "Help Index: A")

      text =
        page
        |> Topic.lines(76)
        |> Enum.map_join("\n", &Enum.map_join(&1, fn s -> Topic.label(s) end))

      # "Add" is a heading of its own, with what can be added under it
      assert text =~ ~r/\n  Add\n    Categories\n/
      assert {:link, "Items", "Enter Items"} in List.flatten(Topic.lines(page, 76))
      # a box is listed under its name and under Boxes
      boxes = state |> Topics.get("Help Index: B") |> Topic.lines(76) |> List.flatten()
      assert {:link, "Undiscard", "Undiscard Box"} in boxes
    end

    test "F3: the letters, each to its page of titles", %{state: state} do
      index = press(state, [{:f, 1}, {:f, 3}])
      assert title(index) == "Help Index"
      # END: the last letter that has titles
      assert highlighted(press(index, :end)) != []
      page = press(index, [:enter])
      assert title(page) =~ "Help Index: "
    end

    test "F5: Agenda's Find Topic box, typed at once", %{state: state} do
      asked = press(state, [{:f, 1}, {:f, 5}])
      assert screen(asked) =~ "Find Topic"
      assert panel(asked) =~ "Type the topic or term you want help on."
      assert screen(press(asked, ["t", "r"])) =~ ~r/Topic to find: +tr/
      # ESC goes back to the topic being read
      assert title(press(asked, :esc)) == "Views"
    end

    test "ENTER: Agenda's Select Help Screen box; ENTER reads one, ALT-N the next", %{
      state: state
    } do
      found = press(state, [{:f, 1}, {:f, 5}, "trash", :enter])
      assert screen(found) =~ "Select Help Screen"
      assert screen(found) =~ "Undiscard Box"
      assert panel(found) =~ "Highlight Help screen to display."
      assert title(press(found, :esc)) == "Views"

      %{found: [first_title, second_title | _]} = State.mode(found)
      first = press(found, :enter)
      assert title(first) == first_title
      assert title(press(found, [:down, :enter])) == second_title

      second = press(first, {:alt, "n"})
      assert title(second) == second_title
      assert title(press(second, {:alt, "p"})) == first_title
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

  test "a box's topic lists its settings by the box's labels, in its order", %{state: state} do
    topic = Topics.get(state, "File Properties Box")

    text =
      topic
      |> Topic.lines(76)
      |> Enum.map_join("\n", &Enum.map_join(&1, fn s -> Topic.label(s) end))

    assert text =~ ~r/SETTING +DESCRIPTION/
    assert text =~ ~r/File description +Enter a short description/
    {description, _} = :binary.match(text, "File description")
    {trash, _} = :binary.match(text, "Empty trash")
    {stats, _} = :binary.match(text, "File statistics")
    assert description < trash and trash < stats
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

    # 68 columns and the help's margin fit an 80-column screen
    test "every written line fits the help on an 80-column screen", %{state: state} do
      for title <- Topics.hand_written(),
          line <- Topic.lines(Topics.get(state, title), 76),
          text = Enum.map_join(line, &Topic.label/1),
          do: assert(String.length(text) <= 68, "#{title}: #{text}")
    end

    # docs/HELP_WOOD.md lists the Hundred Acre Wood in the help (meeting
    # 2026-10-26-1108, § 8): each listed line must still be in its topic
    test "every Wood touch docs/HELP_WOOD.md lists is in its topic", %{state: state} do
      rows =
        for line <- File.read!("docs/HELP_WOOD.md") |> String.split("\n"),
            [_, title, words] <- [Regex.run(~r/^\| ([^|]+?) \| (.+?) \| [^|]+ \|$/, line)],
            title not in ["Topic", "---"],
            do: {title, words}

      assert length(rows) >= 10

      for {title, words} <- rows do
        topic = Topics.get(state, title)
        assert topic, "#{title} is not a topic"

        text =
          topic
          |> Topic.lines(76)
          |> Enum.map_join(" ", &Enum.map_join(&1, fn s -> Topic.label(s) end))
          |> String.split()
          |> Enum.join(" ")

        # each quoted part of the listed words is in the topic's text
        for quoted <- Regex.scan(~r/"([^"]+)"/, words, capture: :all_but_first) |> List.flatten(),
            part <- String.split(quoted, " … "),
            do: assert(text =~ String.trim(part), "#{title}: #{part}")
      end
    end

    test "every key a written topic names is a key of the help or a keymap", %{state: state} do
      bound =
        for(
          place <- Keymap.places(),
          {_key, id} <- Keymap.bindings(place),
          key <- Keymap.keys_for(place, id),
          do: Keymap.name(key)
        ) ++
          Enum.map(HelpScreen.keys() ++ Agendum.TUI.Macros.keys(), &Keymap.name/1)

      for title <- Topics.hand_written(),
          line <- Topic.lines(Topics.get(state, title), 76),
          text = Enum.map_join(line, &Topic.label/1),
          [key] <- Regex.scan(~r/\b(?:F\d{1,2}|(?:ALT|CTRL|SHIFT)-[A-Z0-9]+)\b/, text),
          do: assert(key in bound, "#{title} names #{key}")
    end
  end
end
