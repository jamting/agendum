defmodule Agendum.TUI.AgendaMenusTest do
  @moduledoc """
  Agendum's menus compared with Lotus Agenda 2.0's own (meeting 2026-10-21,
  § 8), as `tools/agformat/capture_menus.py` captured them from the real
  program into `docs/reference/agenda_menus.json`. No DOSBox here: the test
  reads the capture.

  The menus are compared as the person sees them with the Extras
  preference off (R77): entry by entry, level by level, by label, and the
  order of the entries both have. Every difference found must be listed
  below with its tag (`docs/plans/AGENDA_PARITY.md`, ADR 0043), and every
  difference listed must still be there: a difference fixed, or a new one,
  fails the test until the list is brought up to date. The help lines are
  captured but not compared yet.
  """
  use ExUnit.Case, async: true

  alias Agendum.TUI.Menu

  @reference "docs/reference/agenda_menus.json"

  # Agenda's places and the menu Agendum has in each (nil: none)
  @places [view: :main, note: :note, catmgr: :catmgr]

  # Every difference, by what it says, with its tag:
  #
  #   :machine, :work, :quiet  stays (ADR 0043's test)
  #   :change_back             a difference to undo, a parity step of its
  #                            own (AGENDA_PARITY.md, "The steps")
  #   :not_built               Agenda has it, Agendum not yet: parity work
  #   :out_of_scope            left out on purpose (SPEC § 6): printing, DOS
  @differences %{
    "View menu ▸ System: missing" => {:out_of_scope, "exit to DOS (SPEC § 6)"},
    "View menu ▸ Utilities ▸ Launch: missing" =>
      {:out_of_scope, "running another DOS program (SPEC § 6)"},
    "View menu ▸ Utilities ▸ Trash: missing" =>
      {:not_built, "the trash (AGENDA_PARITY § The steps)"},
    "View menu ▸ Utilities ▸ Show ▸ ItemsDone: missing" =>
      {:not_built, "Show ItemsDone (AGENDA_PARITY § The steps)"},
    "View menu ▸ Utilities ▸ Show ▸ Circular: missing" =>
      {:not_built, "Show Circular (AGENDA_PARITY § The steps)"},
    "View menu ▸ Utilities ▸ Show ▸ Every: missing" =>
      {:not_built, "Show Every (AGENDA_PARITY § The steps)"},
    "View menu ▸ Utilities ▸ Show ▸ Prereqs: a menu in Agendum, a command in Agenda" =>
      {:change_back,
       "ours asks One level, All levels or Every item in a submenu; how Agenda chooses is unchecked (AGENDA_PARITY, the Show step)"},
    "View menu ▸ Utilities ▸ Show ▸ Depends: a menu in Agendum, a command in Agenda" =>
      {:change_back,
       "ours asks One level, All levels or Every item in a submenu; how Agenda chooses is unchecked (AGENDA_PARITY, the Show step)"},
    "Category manager menu ▸ Print: missing" =>
      {:out_of_scope, "printing the category hierarchy (SPEC § 6)"},
    "View menu ▸ File ▸ Abandon: missing" =>
      {:not_built, "back to the file as last saved (AGENDA_PARITY step 5)"},
    "View menu ▸ File ▸ Maintenance: missing" =>
      {:change_back,
       "MakeCopy in Write's place (roadmap); Erase not built; Compress and Reservation out of scope"},
    "View menu ▸ File ▸ Write: added" =>
      {:change_back,
       "gives way to File ▸ Maintenance ▸ MakeCopy (AGENDA_PARITY, tagged 2026-10-22)"},
    "View menu ▸ File ▸ Transfer ▸ Template: missing" =>
      {:not_built, "the file's structure without its items (AGENDA_PARITY step 5)"},
    "View menu ▸ Item ▸ Undisc: missing" => {:not_built, "the trash (AGENDA_PARITY step 4)"},
    "View menu ▸ Print: a command in Agendum, a menu in Agenda" =>
      {:machine,
       "Print writes the view to a text file; printing on paper is out of scope (AGENDA_PARITY)"},
    "Note menu ▸ File: missing" =>
      {:not_built, "external note files, NOTE_EDITOR.md step 7, still to be decided"},
    "Note menu ▸ Print: missing" => {:out_of_scope, "printing on paper (SPEC § 6)"}
  }

  setup_all do
    %{"menus" => menus} = @reference |> File.read!() |> JSON.decode!()
    %{agenda: menus}
  end

  test "every difference from Agenda's menus is known, and still there", %{agenda: agenda} do
    found =
      for {place, ours} <- @places,
          difference <-
            differences(place_name(place), agenda(agenda[Atom.to_string(place)]), ours(ours)),
          do: difference

    unknown = Enum.reject(found, &Map.has_key?(@differences, &1))
    gone = @differences |> Map.keys() |> Enum.reject(&(&1 in found))

    assert unknown == [] and gone == [], """
    #{if unknown != [], do: "New differences from Agenda's menus (tag them, or fix them):\n  " <> Enum.join(unknown, "\n  ") <> "\n", else: ""}#{if gone != [], do: "Listed differences that are gone (take them off the list):\n  " <> Enum.join(gone, "\n  "), else: ""}
    """
  end

  test "every listed difference has a known tag" do
    tags = [:machine, :work, :quiet, :change_back, :not_built, :out_of_scope]

    for {difference, {tag, why}} <- @differences do
      assert tag in tags, "#{difference}: unknown tag #{inspect(tag)}"
      assert is_binary(why) and why != "", "#{difference}: say why"
    end
  end

  # --- comparing ---------------------------------------------------------------

  defp place_name(:view), do: "View menu"
  defp place_name(:note), do: "Note menu"
  defp place_name(:catmgr), do: "Category manager menu"

  # both menus as trees of {label, children}, children nil for a command:
  # Agendum's as the person sees it with the extras off, Agenda's as captured
  defp ours(nil), do: nil
  defp ours(which) when is_atom(which), do: ours(Menu.shown(which, false))

  defp ours(level) when is_list(level),
    do: for({label, _description, action} <- level, do: {label, is_list(action) && ours(action)})

  defp agenda(nil), do: nil

  defp agenda(level),
    do: for(entry <- level, do: {entry["label"], agenda(entry["children"])})

  # The differences at one level and below, a line each: what Agenda has
  # and Agendum not ("missing"), what Agendum has and Agenda not ("added"),
  # an entry that opens a menu in one and runs a command in the other, and
  # the entries both have in another order ("order")
  defp differences(where, _theirs, nil), do: ["#{where}: missing"]

  defp differences(where, theirs, ours) do
    their_labels = Enum.map(theirs, &elem(&1, 0))
    our_labels = Enum.map(ours, &elem(&1, 0))

    missing = for label <- their_labels -- our_labels, do: "#{where} ▸ #{label}: missing"
    added = for label <- our_labels -- their_labels, do: "#{where} ▸ #{label}: added"

    # `--` keeps the order of its left side: the shared labels in each order
    order =
      if their_labels -- (their_labels -- our_labels) ==
           our_labels -- (our_labels -- their_labels),
         do: [],
         else: ["#{where}: order"]

    # a pattern with `^label` in a generator keeps only our entry of that label
    below =
      for {label, their_children} <- theirs,
          {^label, our_children} <- ours,
          line <- below("#{where} ▸ #{label}", their_children, our_children),
          do: line

    missing ++ added ++ order ++ below
  end

  defp below(_where, nil, false), do: []
  defp below(where, nil, _ours), do: ["#{where}: a menu in Agendum, a command in Agenda"]
  defp below(where, _theirs, false), do: ["#{where}: a command in Agendum, a menu in Agenda"]
  defp below(where, theirs, ours), do: differences(where, theirs, ours)
end
