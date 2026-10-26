defmodule Agendum.TUI.Help.Topics do
  @moduledoc """
  Every help topic, by title (ADR 0047; `docs/plans/HELP.md`):

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

  @doc "A box's topic title, as Agenda named them: `UndiscardBox` is \"Undiscard Box\"."
  @spec box_title(module) :: String.t()
  def box_title(box) do
    name = box |> Module.split() |> List.last() |> String.replace_suffix("Box", "")
    Regex.replace(~r/([a-z])([A-Z])/, name, "\\1 \\2") <> " Box"
  end

  @doc "A menu level's topic title: \"Main Menu\", \"File Maintenance Menu\", \"Note Menu\"."
  @spec menu_title(atom, [String.t()]) :: String.t()
  def menu_title(:main, []), do: "Main Menu"

  def menu_title(which, labels),
    do: Keyword.fetch!(@trees, which) <> Enum.join(labels, " ") <> " Menu"

  # --- generated topics -------------------------------------------------------

  # by lower-case title; made each time (they are small, and depend on
  # the extras and the width)
  defp generated(state) do
    titles = titles(state)
    topics = base(state) ++ [index(titles) | letters(titles)]
    Map.new(topics, &{String.downcase(&1.title), &1})
  end

  # the topics the index lists (not the index's own pages)
  defp base(state) do
    [keys()] ++
      Enum.map(@places, fn {from, title} -> place_topic(from, title) end) ++
      Enum.map(boxes(), &box_topic(&1, nil)) ++ menus(state.prefs.extras)
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

  # F3: the letters, each leading to its page of titles, as Agenda's
  # index starts
  defp index(titles) do
    initials = titles |> Enum.map(&initial/1) |> MapSet.new()

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

  defp letters(titles) do
    titles
    |> Enum.group_by(&initial/1)
    |> Enum.map(fn {letter, titles} ->
      %Topic{
        title: "Help Index: " <> letter,
        body:
          Enum.map(titles, &{:line, [{:text, "  "}, {:link, &1, &1}]}) ++ see_also(["Help Index"])
      }
    end)
  end

  defp initial(title), do: title |> String.first() |> String.upcase()
end
