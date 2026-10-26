defmodule Agendum.TUI.Help.Topics do
  @moduledoc """
  Every help topic, by title (ADR 0047; `docs/plans/archive/HELP.md`):

    * **hand-written** ones, a text file each in `lib/agendum/tui/help/topics/`,
      compiled in (`@external_resource`), in Agenda's layout;
    * **generated** ones, made from the program so they cannot drift from
      it: a topic for each place with a keymap (its F1 text), each box
      (its settings' help, and where F1 was pressed its text about the
      box), each menu (its entries), the key charts (**Keys**), and the
      **Help Index**.

  A hand-written topic with the title of a generated one takes its place
  (a written "Views" says more than the view's F1 text). Titles are found
  whatever their case. Two titles are pages of the help screen rather
  than topics: "Commands you can run here" and "Describe a key"
  (`special/1`). Pure.
  """

  alias Agendum.TUI.{HelpScreen, Menu, State}
  alias Agendum.TUI.Boxes.Box
  alias Agendum.TUI.Help.Topic
  alias Agendum.TUI.Render.Help, as: KeyCharts

  @dir Path.join(__DIR__, "topics")

  # Domain: the hand-written topics are read when this module is compiled,
  # so the escript carries them (ADR 0021: no runtime files);
  # `@external_resource` recompiles it when one of them changes.
  @files @dir |> Path.join("*.txt") |> Path.wildcard() |> Enum.sort()
  for file <- @files, do: @external_resource(file)

  @hand @files
        |> Enum.map(&Topic.parse(File.read!(&1)))
        |> Map.new(&{String.downcase(&1.title), &1})

  # a new topic file is picked up by a recompile
  def __mix_recompile__?, do: Path.wildcard(Path.join(@dir, "*.txt")) |> Enum.sort() != @files

  @special %{
    "commands you can run here" => :commands,
    "describe a key" => :describe
  }

  # Agenda's titles for the places, where it had them ("Views",
  # "Category Manager", "View Manager", "Note Editor")
  @places %{
    view: "Views",
    catmgr: "Category Manager",
    viewmgr: "View Manager",
    note: "Note Editor",
    move_item: "Moving Items",
    searching: "Searching a View",
    browse: "Browsing Dates",
    column_width: "A Column's Width",
    column_move: "Moving a Column",
    section_move: "Moving a Section"
  }

  @trees [main: "", catmgr: "Category Manager ", note: "Note "]

  @doc "The hand-written topics' titles."
  @spec hand_written() :: [String.t()]
  def hand_written, do: @hand |> Map.values() |> Enum.map(& &1.title) |> Enum.sort()

  @doc ~s(A help screen page a link leads to instead of a topic: `:commands`, `:describe`, or nil.)
  @spec special(String.t()) :: :commands | :describe | nil
  def special(title), do: @special[String.downcase(title)]

  @doc """
  The topic for where F1 was pressed (`from`, as `HelpScreen.place/1`
  says; `state` the state there): the place's, the menu level's, the box's
  (with its text about the box as it is now), or How to Use Help.
  """
  @spec for_place(State.t(), atom) :: Topic.t()
  def for_place(state, :box) do
    mode = State.mode(state)
    box = Box.module!(mode)
    text = box.about(state, mode) || Box.default_about(box, state, mode)
    override(box_topic(box, text))
  end

  def for_place(state, :menu) do
    mode = State.mode(state)
    which = Map.get(mode, :tree) || :main
    get(state, menu_title(which, Menu.labels(mode)))
  end

  def for_place(state, from) do
    case @places[from] do
      nil -> get(state, "How to Use Help")
      title -> get(state, title)
    end
  end

  @doc """
  The topic titled `title` (any case), or nil. `state` is the state under
  the help: the extras' menu entries show only while they are on (R77).
  """
  @spec get(State.t(), String.t()) :: Topic.t() | nil
  def get(state, title) do
    key = String.downcase(title)
    @hand[key] || generated(state)[key]
  end

  @doc "Every topic's title, for the index and Find: hand-written and generated."
  @spec titles(State.t()) :: [String.t()]
  def titles(state) do
    (hand_written() ++ Enum.map(base(state), & &1.title))
    |> Enum.uniq_by(&String.downcase/1)
    |> Enum.sort_by(&String.downcase/1)
  end

  @doc "The titles of the place topics, by place."
  @spec place_titles() :: %{atom => String.t()}
  def place_titles, do: @places

  # boxes whose module's name is not what the person sees, by Agenda's
  # names for them where it had them ("Category Properties Box")
  @box_titles %{
    Agendum.TUI.CategoryScreens.Properties => "Category Properties Box",
    Agendum.TUI.CategoryScreens.Profile => "Assignment Profile Box",
    Agendum.TUI.CategoryScreens.Picker => "Choose a Category Box",
    Agendum.TUI.CategoryScreens.Choices => "Assign Conflicting Items Box",
    Agendum.TUI.Update.Prompts => "Question Box",
    Agendum.TUI.Update.Marked => "Marked or Current Item Box",
    Agendum.TUI.Macros => "Macro Manager",
    Agendum.TUI.Boxes.ViewManager => "View Manager",
    Agendum.TUI.Boxes.ColumnBox => "Column Properties Box",
    Agendum.TUI.Boxes.SectionBox => "Section Properties Box",
    Agendum.TUI.Boxes.ViewProps => "View Properties Box",
    Agendum.TUI.Boxes.MacroProps => "Macro Properties Box",
    Agendum.TUI.Boxes.FileStatsBox => "File Statistics Box",
    Agendum.TUI.Boxes.CategoryStatsBox => "Category Statistics Box",
    Agendum.TUI.Boxes.ViewStatsBox => "View Statistics Box",
    Agendum.TUI.Boxes.DateSettingsBox => "Global Date Settings Box",
    Agendum.TUI.Boxes.AutoAssignBox => "Auto-Assign Settings Box",
    Agendum.TUI.Boxes.GoTo => "Go To Section Box"
  }

  @doc """
  A box's topic title: Agenda's name for it where the module's is not what
  the person sees, else made from the module: `UndiscardBox` is
  "Undiscard Box".
  """
  @spec box_title(module) :: String.t()
  def box_title(box) do
    Map.get_lazy(@box_titles, box, fn ->
      name = box |> Module.split() |> List.last() |> String.replace_suffix("Box", "")
      Regex.replace(~r/([a-z])([A-Z])/, name, "\\1 \\2") <> " Box"
    end)
  end

  @doc "A menu level's topic title: \"Main Menu\", \"File Maintenance Menu\", \"Note Menu\"."
  @spec menu_title(atom, [String.t()]) :: String.t()
  def menu_title(:main, []), do: "Main Menu"

  def menu_title(which, labels),
    do: String.trim(Keyword.fetch!(@trees, which) <> Enum.join(labels, " ")) <> " Menu"

  # --- generated topics -------------------------------------------------------

  # by lower-case title; made each time (they are small, and depend on
  # the extras and the width)
  defp generated(state) do
    listed = listed(state)
    topics = base(state) ++ [index(listed) | letters(listed)]
    Map.new(topics, &{String.downcase(&1.title), &1})
  end

  # every topic the index lists, written ones in place of generated ones
  defp listed(state) do
    written = Map.values(@hand)
    taken = MapSet.new(written, &String.downcase(&1.title))
    written ++ Enum.reject(base(state), &MapSet.member?(taken, String.downcase(&1.title)))
  end

  @doc """
  A topic's entries in the Help Index (`{heading, sub}`, sub nil for the
  heading itself): its title, and a written topic's `INDEX` lines, or a
  generated one's kind: a box under Boxes, a menu under Menus.
  """
  @spec entries(Topic.t()) :: [Topic.entry()]
  def entries(%Topic{title: title, index: index}) do
    kind =
      cond do
        String.ends_with?(title, " Box") ->
          [{"Boxes", String.replace_suffix(title, " Box", "")}]

        String.ends_with?(title, " Menu") ->
          [{"Menus", String.replace_suffix(title, " Menu", "")}]

        true ->
          []
      end

    Enum.uniq([{title, nil} | index] ++ kind)
  end

  # the topics the index lists (not the index's own pages)
  defp base(state) do
    # a place's topic first: the view manager is a place and a box
    ([keys()] ++
       Enum.map(@places, fn {from, title} -> place_topic(from, title) end) ++
       Enum.map(boxes(), &box_topic(&1, nil)) ++ menus(state.prefs.extras))
    |> Enum.uniq_by(&String.downcase(&1.title))
  end

  defp override(topic), do: @hand[String.downcase(topic.title)] || topic

  defp see_also(links) do
    [{:line, [{:text, ""}]}, {:line, [{:text, "SEE ALSO      "} | spaced(links)]}]
  end

  defp spaced(titles), do: titles |> Enum.map(&{:link, &1, &1}) |> Enum.intersperse({:text, "  "})

  defp paragraphs(text) do
    text
    |> String.split("\n\n", trim: true)
    |> Enum.map(&{:wrap, "  ", String.replace(String.trim(&1), "\n", " ")})
    |> Enum.intersperse({:line, [{:text, ""}]})
  end

  defp place_topic(from, title) do
    %Topic{
      title: title,
      body:
        paragraphs(HelpScreen.about(nil, from)) ++ see_also(["Keys", "Commands you can run here"])
    }
  end

  defp boxes, do: Box.registry() |> Map.values() |> Enum.uniq()

  # a box: what F1 in it says (when pressed there), then each setting and
  # its help, as Agenda's "SETTING / DESCRIPTION"
  defp box_topic(box, text) do
    intro = if text, do: paragraphs(text) ++ [{:line, [{:text, ""}]}], else: []

    settings =
      case box.help() do
        texts when is_map(texts) and map_size(texts) > 0 -> settings(box, texts)
        text when is_binary(text) and intro == [] -> [{:wrap, "  ", text}]
        _ -> []
      end

    %Topic{title: box_title(box), body: intro ++ settings ++ see_also(["Keys"])}
  end

  # the settings as the box shows them: its labels, in its order (from its
  # layout); a setting the layout does not name comes last, by its name
  defp settings(box, texts) do
    labelled =
      for {field, label} <- box.layout_labels(), Map.has_key?(texts, field), do: {field, label}

    named = Enum.map(labelled, &elem(&1, 0))

    rest =
      for {field, _} <- Enum.sort(texts), field not in named, do: {field, setting_name(field)}

    rows = labelled ++ rest
    column = rows |> Enum.map(&String.length(elem(&1, 1))) |> Enum.max() |> Kernel.+(4) |> min(28)

    [{:line, [{:text, String.pad_trailing("SETTING", column) <> "DESCRIPTION"}]}] ++
      Enum.map(rows, fn {field, label} ->
        {:hang, [{:text, "  " <> label}], column, texts[field]}
      end)
  end

  # `:empty_trash` is "Empty trash"
  defp setting_name(field) do
    field |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
  end

  # every level of each menu, its entries and what they do; a level that
  # holds more links to its own topic
  defp menus(extras?) do
    Enum.flat_map(@trees, fn {which, _} -> menu_levels(which, [], Menu.shown(which, extras?)) end)
  end

  defp menu_levels(which, labels, level) do
    body =
      Enum.map(level, fn {label, description, action} ->
        name =
          if is_list(action),
            do: {:link, label, menu_title(which, labels ++ [label])},
            else: {:text, label}

        {:hang, [{:text, "  "}, name], 16, description}
      end)

    # the top of a menu says how menus work (the menu's F1 text)
    intro = if labels == [], do: paragraphs(Menu.about()) ++ [{:line, [{:text, ""}]}], else: []
    own = %Topic{title: menu_title(which, labels), body: intro ++ body ++ see_also(["Keys"])}

    deeper =
      for {label, _, action} <- level,
          is_list(action),
          do: menu_levels(which, labels ++ [label], action)

    [own | List.flatten(deeper)]
  end

  # F6: the commands here and describe key first (today's F1 c and d),
  # then every key, from the keymaps (today's F1 a)
  defp keys do
    charts = fn width ->
      for line <- KeyCharts.lines(width), do: [{:text, Enum.map_join(line, "", &elem(&1, 1))}]
    end

    %Topic{
      title: "Keys",
      body: [
        {:line,
         [{:text, "  "}, {:link, "Commands you can run here", "Commands you can run here"}]},
        {:line, [{:text, "  "}, {:link, "Describe a key", "Describe a key"}]},
        {:line, [{:text, ""}]},
        {:lines, charts}
      ]
    }
  end

  # F3: the letters, each leading to its page of entries, as Agenda's
  # index starts
  defp index(listed) do
    initials = listed |> index_entries() |> Enum.map(&initial(elem(&1, 0))) |> MapSet.new()

    rows =
      for row <- [?A..?M, ?N..?Z] do
        segments =
          Enum.flat_map(row, fn c ->
            letter = <<c>>

            if MapSet.member?(initials, letter),
              do: [{:text, "  "}, {:link, letter, "Help Index: " <> letter}, {:text, " "}],
              else: [{:text, "  " <> letter <> " "}]
          end)

        {:line, [{:text, "     "} | segments]}
      end

    %Topic{
      title: "Help Index",
      body: [
        {:line, [{:text, "     Pick a letter and press ENTER."}]},
        {:line, [{:text, ""}]}
        | Enum.intersperse(rows, {:line, [{:text, ""}]})
      ]
    }
  end

  # every `{heading, sub, topic title}` of the index
  defp index_entries(listed) do
    for topic <- listed, {heading, sub} <- entries(topic), do: {heading, sub, topic.title}
  end

  # a letter's page, as Agenda's: each heading, a link when a topic is
  # listed under it alone, and its sub-entries indented under it
  defp letters(listed) do
    listed
    |> index_entries()
    |> Enum.group_by(&initial(elem(&1, 0)))
    |> Enum.map(fn {letter, entries} ->
      headings =
        entries
        |> Enum.group_by(&elem(&1, 0))
        |> Enum.sort_by(fn {heading, _} -> String.downcase(heading) end)
        |> Enum.flat_map(&heading_lines/1)

      %Topic{title: "Help Index: " <> letter, body: headings ++ see_also(["Help Index"])}
    end)
  end

  defp heading_lines({heading, entries}) do
    own = for {_, nil, title} <- entries, do: title
    subs = for {_, sub, title} <- entries, sub != nil, do: {sub, title}

    first =
      case own do
        [title | _] -> [{:text, "  "}, {:link, heading, title}]
        [] -> [{:text, "  " <> heading}]
      end

    rows =
      subs
      |> Enum.uniq()
      |> Enum.sort_by(&String.downcase(elem(&1, 0)))
      |> Enum.map(fn {sub, title} -> {:line, [{:text, "    "}, {:link, sub, title}]} end)

    [{:line, first} | rows]
  end

  defp initial(title), do: title |> String.first() |> String.upcase()
end
