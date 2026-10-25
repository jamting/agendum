defmodule Agendum.TUI.AgendaBoxesTest do
  @moduledoc """
  Agendum's settings boxes compared with Lotus Agenda 2.0's own
  (AGENDA_PARITY.md, the texts step; meeting 2026-10-21, § 8), as
  `tools/agformat/capture_boxes.py` captured them from the real program
  into `docs/reference/agenda_boxes.json`, on Agenda's Activities Planner.
  No DOSBox here: the test reads the capture.

  Each box is opened in Agendum's Planner (`Agendum.Starters.Planner`, with
  its samples) the way it is reached in Agenda, and compared by its title,
  its bottom edge and its labels (the words before a colon), as the person
  sees them with the Extras preference off (R77). Every difference found
  must be listed below with its tag (`docs/plans/AGENDA_PARITY.md`, ADR
  0043), and every difference listed must still be there: a difference
  fixed, or a new one, fails the test until the list is brought up to date.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.TUI.Boxes.Box
  alias Agendum.TUI.{CategoryScreens, State}

  @reference "docs/reference/agenda_boxes.json"

  # Every difference, by what it says, with its tag, as in the menu test
  # (`agenda_menus_test.exs`):
  #
  #   :machine, :work, :quiet  stays (ADR 0043's test)
  #   :change_back             a difference to undo
  #   :not_built               Agenda has it, Agendum not yet: parity work
  #   :out_of_scope            left out on purpose (SPEC § 6)
  @differences %{
    "category_text_matching_long: Agenda's Assignment conditions, not ours" =>
      {:not_built,
       "turning text matching, conditions and actions on and off, and their rules of conflict (R15, R15b: not done)"},
    "category_text_matching_long: Agenda's Assignment actions, not ours" =>
      {:not_built,
       "turning text matching, conditions and actions on and off, and their rules of conflict (R15, R15b: not done)"},
    "category_text_matching_long: Agenda's Apply conditions, not ours" =>
      {:not_built,
       "turning text matching, conditions and actions on and off, and their rules of conflict (R15, R15b: not done)"},
    "category_text_matching_long: Agenda's If an assignment conflicts with another, not ours" =>
      {:not_built,
       "turning text matching, conditions and actions on and off, and their rules of conflict (R15, R15b: not done)"},
    "category_text_matching_long: Agenda's Allow explicit assignments, not ours" =>
      {:not_built,
       "turning text matching, conditions and actions on and off, and their rules of conflict (R15, R15b: not done)"},
    "category_text_matching_long: Agenda's Relationship of text/assignment conditions, not ours" =>
      {:not_built,
       "turning text matching, conditions and actions on and off, and their rules of conflict (R15, R15b: not done)"},
    "category_text_matching_long: Agenda's Category is protected, not ours" =>
      {:out_of_scope, "application protection (SPEC § 6)"},
    "category_text_matching_long: Agenda's Category can have new children, not ours" =>
      {:out_of_scope, "application protection (SPEC § 6)"},
    "alarm: no box opens in Agendum" =>
      {:not_built,
       "Agenda's Set Alarm box (date category, minutes before); ours asks on the top line"},
    "auto_assign_settings: Agenda's Assignment conditions, not ours" =>
      {:not_built,
       "turning text matching, conditions and actions on and off, and their rules of conflict (R15, R15b: not done)"},
    "auto_assign_settings: Agenda's Assignment actions, not ours" =>
      {:not_built,
       "turning text matching, conditions and actions on and off, and their rules of conflict (R15, R15b: not done)"},
    "auto_assign_settings: Agenda's Apply conditions, not ours" =>
      {:not_built,
       "turning text matching, conditions and actions on and off, and their rules of conflict (R15, R15b: not done)"},
    "auto_assign_settings: Agenda's If an assignment conflicts with another, not ours" =>
      {:not_built,
       "turning text matching, conditions and actions on and off, and their rules of conflict (R15, R15b: not done)"},
    "auto_assign_settings: Agenda's Relationship of text and assignment conditions, not ours" =>
      {:not_built,
       "turning text matching, conditions and actions on and off, and their rules of conflict (R15, R15b: not done)"},
    "category_add: no box opens in Agendum" =>
      {:not_built,
       "Agenda's Category Add box (the properties of the new category); ours asks for the name on the top line"},
    "category_date_settings: Agenda's If an assignment conflicts with another, not ours" =>
      {:not_built,
       "turning text matching, conditions and actions on and off, and their rules of conflict (R15, R15b: not done)"},
    "category_date_settings: Agenda's Category can use recurring dates, not ours" =>
      {:not_built, "turning recurring dates off per date category"},
    "category_date_settings: Agenda's Category is protected, not ours" =>
      {:out_of_scope, "application protection (SPEC § 6)"},
    "category_properties: Agenda's Match short name, not ours" =>
      {:not_built, "matching a category's short name on its own switch"},
    "category_properties: Agenda's Note file, not ours" =>
      {:not_built, "external note files (NOTE_EDITOR.md, step 7)"},
    "category_properties: ours Excludes, not Agenda's" =>
      {:quiet,
       "negative links between any two categories (R9, the patent's FIG. 6; Agenda only had exclusive siblings)"},
    "category_properties_date: Agenda's Note file, not ours" =>
      {:not_built, "external note files (NOTE_EDITOR.md, step 7)"},
    "category_properties_numeric: Agenda's Note file, not ours" =>
      {:not_built, "external note files (NOTE_EDITOR.md, step 7)"},
    "category_text_matching: Agenda's Assignment conditions, not ours" =>
      {:not_built,
       "turning text matching, conditions and actions on and off, and their rules of conflict (R15, R15b: not done)"},
    "category_text_matching: Agenda's Assignment actions, not ours" =>
      {:not_built,
       "turning text matching, conditions and actions on and off, and their rules of conflict (R15, R15b: not done)"},
    "category_text_matching: Agenda's Apply conditions, not ours" =>
      {:not_built,
       "turning text matching, conditions and actions on and off, and their rules of conflict (R15, R15b: not done)"},
    "category_text_matching: Agenda's If an assignment conflicts with another, not ours" =>
      {:not_built,
       "turning text matching, conditions and actions on and off, and their rules of conflict (R15, R15b: not done)"},
    "category_text_matching: Agenda's Allow explicit assignments, not ours" =>
      {:not_built,
       "turning text matching, conditions and actions on and off, and their rules of conflict (R15, R15b: not done)"},
    "category_text_matching: Agenda's Relationship of text/assignment conditions, not ours" =>
      {:not_built,
       "turning text matching, conditions and actions on and off, and their rules of conflict (R15, R15b: not done)"},
    "category_text_matching: Agenda's Category is protected, not ours" =>
      {:out_of_scope, "application protection (SPEC § 6)"},
    "category_text_matching: Agenda's Category can have new children, not ours" =>
      {:out_of_scope, "application protection (SPEC § 6)"},
    "customize: Agenda's Color, not ours" =>
      {:machine,
       "Agenda chose colours for the monitor; ours, Theme, chooses the terminal's colours (R40)"},
    "customize: Agenda's Display cond/act info, not ours" =>
      {:not_built, "Utilities Customize's other settings"},
    "customize: Agenda's Display carriage returns, not ours" =>
      {:not_built, "Utilities Customize's other settings"},
    "customize: Agenda's Item tag character, not ours" =>
      {:not_built, "Utilities Customize's other settings"},
    "customize: Agenda's Suppress snow, not ours" => {:machine, "CGA screens only"},
    "customize: Agenda's Text marker display, not ours" =>
      {:out_of_scope, "fonts and typesetting (SPEC § 6; R64a)"},
    "customize: Agenda's Character set, not ours" =>
      {:machine, "Agendum reads and writes Unicode"},
    "customize: Agenda's Memory usage, not ours" => {:machine, "DOS memory"},
    "customize: ours Theme, not Agenda's" =>
      {:machine,
       "Agenda's Color chose colours for the monitor; Theme chooses the terminal's (R40)"},
    "customize: ours Date language, not Agenda's" =>
      {:quiet, "date languages (R41), English by default"},
    "customize: ours Fallback language, not Agenda's" =>
      {:quiet, "date languages (R41), English by default"},
    "customize: ours Input format, not Agenda's" =>
      {:quiet, "the person's own input format (R54), beside the file's in Global Date Settings"},
    "customize: ours Sound, not Agenda's" =>
      {:machine, "sounds through the computer's audio player, which can be off (R76)"},
    "customize: ours Extras, not Agenda's" =>
      {:quiet, "the Extras switch (R77; tag confirmed by the owner, 2026-10-23)"},
    "file_properties: Agenda's File description, not ours" =>
      {:not_built, "File Properties' other settings (AGENDA_PARITY, Boxes and lists)"},
    "file_properties: Agenda's Set file password, not ours" =>
      {:not_built, "File Properties' other settings (AGENDA_PARITY, Boxes and lists)"},
    "file_properties: Agenda's Make backup on open, not ours" =>
      {:not_built, "File Properties' other settings (AGENDA_PARITY, Boxes and lists)"},
    "file_properties: Agenda's Get reservation, not ours" =>
      {:out_of_scope, "networks and file reservations (SPEC § 6)"},
    "file_properties: Agenda's Auto-import file, not ours" =>
      {:not_built, "File Properties' other settings (AGENDA_PARITY, Boxes and lists)"},
    "file_properties: Agenda's Empty trash, not ours" =>
      {:not_built, "File Properties' other settings (AGENDA_PARITY, Boxes and lists)"},
    "file_properties: Agenda's Global protection, not ours" =>
      {:out_of_scope, "application protection (SPEC § 6)"},
    "file_properties: Agenda's Update defaults, not ours" =>
      {:not_built, "File Properties' other settings (AGENDA_PARITY, Boxes and lists)"},
    "file_statistics: Agenda's Unused space, not ours" =>
      {:machine,
       "an Agendum file has no unused space to report: it is written whole on every save (no Compress)"},
    "file_statistics: Agenda's Items in trash, not ours" =>
      {:not_built, "the trash (Utilities ▸ Trash)"},
    "global_date_settings: Agenda's End of year, not ours" =>
      {:not_built, "Global Date Settings' other settings"},
    "global_date_settings: Agenda's Process Done items, not ours" =>
      {:not_built, "Global Date Settings' other settings"},
    "global_protection: not in Agendum" => {:out_of_scope, "application protection (SPEC § 6)"},
    "item_properties: Agenda's Note file, not ours" =>
      {:not_built, "external note files (NOTE_EDITOR.md, step 7)"},
    "section_add: Agenda's Item sorting, not ours" =>
      {:not_built,
       "the Section Add box's Item sorting, Section statistics and Filter (as Section Properties has)"},
    "section_add: Agenda's Section statistics, not ours" =>
      {:not_built,
       "the Section Add box's Item sorting, Section statistics and Filter (as Section Properties has)"},
    "section_add: Agenda's Filter, not ours" =>
      {:not_built,
       "the Section Add box's Item sorting, Section statistics and Filter (as Section Properties has)"},
    "view_add: no box opens in Agendum" =>
      {:not_built,
       "Agenda's View Add box (View Properties with a Type); ours asks for the name on the top line"},
    "view_properties: Agenda's Named print set, not ours" =>
      {:out_of_scope, "printing (SPEC § 6)"},
    "view_properties: Agenda's View protection, not ours" =>
      {:out_of_scope, "application protection (SPEC § 6)"}
  }

  # How each captured box is opened in Agendum, from the Planner's People
  # view with the highlight on its first section head (↓ to its first item,
  # → to its Priority column and → again to When) (Agenda's keys where ours are
  # the same); nil where Agendum has no such box
  defp open(state, box) do
    case Map.fetch!(openers(), box) do
      nil -> nil
      opener -> opener.(state)
    end
  end

  defp openers do
    %{
      "file_properties" => fn state -> menu(state, "fp") end,
      "global_date_settings" => fn state -> state |> menu("fp") |> sub("Global date settings") end,
      "auto_assign_settings" => fn state -> state |> menu("fp") |> sub("Auto-assign settings") end,
      "global_protection" => nil,
      "file_statistics" => fn state -> state |> menu("fp") |> sub("File statistics") end,
      "item_properties" => fn state -> press(state, [:down, {:f, 6}]) end,
      "category_properties" => fn state -> cat_props(state, "Calls") end,
      "category_properties_date" => fn state -> cat_props(state, "When") end,
      "category_properties_numeric" => fn state -> cat_props(state, "Amount") end,
      "category_text_matching" => fn state ->
        state |> cat_props("Calls") |> sub("Advanced settings")
      end,
      "category_date_settings" => fn state ->
        state |> cat_props("When") |> sub("Advanced settings")
      end,
      "category_statistics" => fn state -> state |> cat_props("Calls") |> sub("Statistics") end,
      "category_text_matching_long" => fn state ->
        state |> cat_props("Miscellaneous Activity") |> sub("Advanced settings")
      end,
      "category_add" => fn state -> menu(state, "ca") end,
      "view_properties" => fn state -> menu(state, "vvp") end,
      "sort" => fn state -> state |> menu("vvp") |> sub("Item sorting") end,
      "view_statistics" => fn state -> state |> menu("vvp") |> sub("View statistics") end,
      "view_add" => fn state -> menu(state, "vva") end,
      "section_properties" => fn state -> menu(state, "vvsp") end,
      "section_sort" => fn state -> state |> menu("vvsp") |> sub("Item sorting") end,
      "section_add" => fn state -> menu(state, "vvsa") end,
      "column_properties" => fn state -> state |> press([:down, :right]) |> menu("vvcp") end,
      "column_properties_date" => fn state ->
        state |> press([:down, :right, :right]) |> menu("vvcp")
      end,
      "column_add" => fn state -> menu(state, "vvca") end,
      "customize" => fn state -> menu(state, "uc") end,
      "execute" => fn state -> menu(state, "ue") end,
      "alarm" => fn state -> state |> press(:down) |> menu("ia") end
    }
  end

  setup_all do
    %{"boxes" => boxes} = @reference |> File.read!() |> JSON.decode!()
    db = Agendum.Starters.Planner.build() |> Agendum.Starters.Planner.with_samples(~D[2026-10-08])

    # Agenda's capture was made in PLANNER's first view, People, whose items
    # are sorted by When; ours is the same view, given the same sort
    {people, _} = Enum.find(db.views, fn {_, v} -> v.name == "People" end)
    when_key = %Agendum.Core.View.SortKey{on: {:category, cat_id(db, "When")}}
    db = Agendum.Core.set_sort(db, people, :view, [when_key])

    # and its When column shows the date only, in settings of its own
    date_only = %{db.date_format | show: :date}
    db = Agendum.Core.set_column_date_format(db, people, {0, 1}, date_only)

    state = db |> start(width: 80, height: 25) |> State.switch_view(people)
    %{agenda: boxes, state: state}
  end

  test "every difference from Agenda's boxes is known, and still there", %{
    agenda: agenda,
    state: state
  } do
    found =
      Enum.flat_map(Enum.sort(agenda), fn {name, theirs} ->
        case open(state, name) do
          nil -> ["#{name}: not in Agendum"]
          opened -> differences(name, theirs, ours(opened))
        end
      end)

    unknown = Enum.reject(found, &Map.has_key?(@differences, &1))
    gone = @differences |> Map.keys() |> Enum.reject(&(&1 in found))

    assert unknown == [] and gone == [], """
    #{if unknown != [], do: "New differences from Agenda's boxes (tag them, or fix them):\n  " <> Enum.join(unknown, "\n  ") <> "\n", else: ""}#{if gone != [], do: "Listed differences that are gone (take them off the list):\n  " <> Enum.join(gone, "\n  "), else: ""}
    """
  end

  test "every listed difference has a known tag" do
    tags = [:machine, :work, :quiet, :change_back, :not_built, :out_of_scope]

    for {difference, {tag, why}} <- @differences do
      assert tag in tags, "#{difference}: unknown tag #{inspect(tag)}"
      assert is_binary(why) and why != "", "#{difference}: say why"
    end
  end

  # --- what differs ---------------------------------------------------------

  defp differences(name, _theirs, nil), do: ["#{name}: no box opens in Agendum"]

  defp differences(name, theirs, ours) do
    title =
      if theirs["title"] == ours.title,
        do: [],
        else: ["#{name} title: Agenda #{theirs["title"]}, ours #{ours.title}"]

    bottom =
      if theirs["bottom"] == ours.bottom,
        do: [],
        else: ["#{name} bottom: Agenda #{theirs["bottom"]}, ours #{ours.bottom}"]

    agenda_labels = labels(theirs["rows"])
    our_labels = labels(ours.rows)

    title ++
      bottom ++
      for(label <- agenda_labels -- our_labels, do: "#{name}: Agenda's #{label}, not ours") ++
      for label <- our_labels -- agenda_labels, do: "#{name}: ours #{label}, not Agenda's"
  end

  # the words before a colon that start a column: "Short name:" in
  # "Short name:    Phone        Match short name:    Yes"
  @label ~r/(?:^|\s{2,}|^\s+)([A-Z][\w\/'&().%-]*(?: [\w\/'&().%-]+)*?) *:(?:\s|$)/u
  defp labels(rows) do
    rows
    |> Enum.flat_map(&Regex.scan(@label, &1, capture: :all_but_first))
    |> List.flatten()
    |> Enum.uniq()
  end

  # --- our box on top, as drawn -----------------------------------------------

  # the box on top, read from the screen: its title in the top edge, the
  # rows between its side edges, and the words in its bottom edge
  defp ours(state) do
    case Box.module(State.mode(state)) do
      nil -> nil
      box -> drawn(state, box)
    end
  end

  defp drawn(state, box) do
    mode = State.mode(state)
    title = box.title(state, mode)
    lines = state |> screen() |> String.split("\n")
    top = Enum.find_index(lines, &(&1 =~ "┌" and String.contains?(&1, " #{title} ")))
    assert top, "no box titled #{inspect(title)} on the screen:\n" <> Enum.join(lines, "\n")
    line = Enum.at(lines, top)
    left = line |> String.graphemes() |> Enum.find_index(&(&1 == "┌"))

    right =
      line
      |> String.graphemes()
      |> Enum.with_index()
      |> Enum.filter(&(elem(&1, 0) == "┐"))
      |> Enum.map(&elem(&1, 1))
      |> Enum.find(&(&1 > left))

    {inside, [edge | _]} =
      lines
      |> Enum.drop(top + 1)
      |> Enum.split_while(&(String.at(&1, left) != "└"))

    cut = fn line ->
      line |> String.slice((left + 1)..(right - 1)//1) |> String.trim_trailing()
    end

    bottom = edge |> cut.() |> String.trim("─") |> String.trim()
    %{title: title, rows: Enum.map(inside, cut), bottom: if(bottom == "", do: nil, else: bottom)}
  end

  # --- reaching a box ---------------------------------------------------------

  defp menu(state, letters), do: press(state, [{:f, 10} | String.graphemes(letters)])

  defp sub(state, label), do: state |> to_setting(label) |> press(" ")

  defp cat_props(state, name), do: CategoryScreens.open_props(state, cat(state, name))

  defp cat(state, name), do: cat_id(state.db, name)

  defp cat_id(db, name) do
    {id, _} = Enum.find(db.categories, fn {_, c} -> c.name == name end)
    id
  end
end
