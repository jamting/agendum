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
  @places [view: :main, note: :note, catmgr: nil]

  # Every difference, by what it says, with its tag:
  #
  #   :machine, :work, :quiet  stays (ADR 0043's test)
  #   :change_back             a difference to undo, a parity step of its
  #                            own (AGENDA_PARITY.md, "The steps")
  #   :not_built               Agenda has it, Agendum not yet: parity work
  #   :out_of_scope            left out on purpose (SPEC § 6): printing, DOS
  @differences %{
    "View menu ▸ Utilities: missing" =>
      {:change_back, "the menu's shape (AGENDA_PARITY, tagged 2026-10-22): Utilities back"},
    "View menu ▸ System: missing" => {:out_of_scope, "exit to DOS (SPEC § 6)"},
    "View menu ▸ Search: added" =>
      {:change_back,
       "the menu's shape (AGENDA_PARITY, tagged 2026-10-22): its commands go back to Utilities ▸ Show"},
    "View menu ▸ Undo: added" =>
      {:change_back,
       "the menu's shape (AGENDA_PARITY, tagged 2026-10-22): off the top level, CTRL-Z stays"},
    "View menu ▸ Redo: added" =>
      {:change_back,
       "the menu's shape (AGENDA_PARITY, tagged 2026-10-22): off the top level, CTRL-Y stays"},
    "View menu ▸ File ▸ Abandon: missing" =>
      {:not_built, "back to the file as last saved (AGENDA_PARITY step 5)"},
    "View menu ▸ File ▸ Maintenance: missing" =>
      {:change_back,
       "MakeCopy in Write's place (roadmap); Erase not built; Compress and Reservation out of scope"},
    "View menu ▸ File ▸ Write: added" =>
      {:change_back,
       "gives way to File ▸ Maintenance ▸ MakeCopy (AGENDA_PARITY, tagged 2026-10-22)"},
    "View menu ▸ File ▸ New: added" =>
      {:change_back,
       "leaves the menus, keeps its key and CTRL-X (AGENDA_PARITY, tagged 2026-10-22)"},
    "View menu ▸ File ▸ Dating: added" =>
      {:change_back,
       "leaves the menus, keeps its key and CTRL-X (AGENDA_PARITY, tagged 2026-10-22)"},
    "View menu ▸ File ▸ Customize: added" =>
      {:change_back, "the menu's shape (AGENDA_PARITY, tagged 2026-10-22): back to Utilities"},
    "View menu ▸ File ▸ Transfer ▸ Template: missing" =>
      {:not_built, "the file's structure without its items (AGENDA_PARITY step 5)"},
    "View menu ▸ File ▸ Transfer: order" =>
      {:change_back,
       "Agenda's name and order come back, keys unchanged (owner, 2026-10-23): Import before Export"},
    "View menu ▸ Item ▸ MakeAssign: missing" =>
      {:change_back,
       "Agenda's name and order come back, keys unchanged (owner, 2026-10-23): Categorize is MakeAssign"},
    "View menu ▸ Item ▸ Categorize: added" =>
      {:change_back,
       "Agenda's name and order come back, keys unchanged (owner, 2026-10-23): Categorize is MakeAssign"},
    "View menu ▸ Item ▸ Undisc: missing" => {:not_built, "the trash (AGENDA_PARITY step 4)"},
    "View menu ▸ Item ▸ BrkAssign: missing" =>
      {:not_built,
       "DEL: Agendum has the key only; the entry comes, keys unchanged (owner, 2026-10-23)"},
    "View menu ▸ Item ▸ Note: added" =>
      {:change_back,
       "leaves the menus, keeps its key and CTRL-X (AGENDA_PARITY, tagged 2026-10-22)"},
    "View menu ▸ Item ▸ When: added" =>
      {:change_back,
       "leaves the menus, keeps its key and CTRL-X (AGENDA_PARITY, tagged 2026-10-22)"},
    "View menu ▸ Item ▸ Show: added" =>
      {:change_back,
       "leaves the menus, keeps its key and CTRL-X (AGENDA_PARITY, tagged 2026-10-22)"},
    "View menu ▸ Item ▸ Finished: added" =>
      {:change_back,
       "leaves the menus, keeps its key and CTRL-X (AGENDA_PARITY, tagged 2026-10-22)"},
    "View menu ▸ Item ▸ Mark: added" =>
      {:change_back,
       "leaves the menus, keeps its key and CTRL-X (AGENDA_PARITY, tagged 2026-10-22)"},
    "View menu ▸ Item ▸ Unmark: added" =>
      {:change_back,
       "leaves the menus, keeps its key and CTRL-X (AGENDA_PARITY, tagged 2026-10-22)"},
    "View menu ▸ Item: order" =>
      {:change_back, "follows from the entries above leaving and coming"},
    "View menu ▸ Category ▸ Properties: missing" =>
      {:not_built,
       "F6: Agendum has the key only; the entry comes, keys unchanged (owner, 2026-10-23)"},
    "View menu ▸ Category ▸ Discard: missing" =>
      {:not_built,
       "ALT-F4 in the category manager: Agendum has the key only; the entry comes, keys unchanged (owner, 2026-10-23)"},
    "View menu ▸ Category ▸ Manager: added" =>
      {:change_back,
       "a shortcut Agenda reaches by a Properties box or F8/F9: leaves the menu once View Properties is built (owner, 2026-10-23)"},
    "View menu ▸ Category ▸ Recalc: added" =>
      {:change_back,
       "leaves the menus, keeps its key and CTRL-X (AGENDA_PARITY, tagged 2026-10-22)"},
    "View menu ▸ Category ▸ Execute: added" =>
      {:change_back, "the menu's shape (AGENDA_PARITY, tagged 2026-10-22): back to Utilities"},
    "View menu ▸ Category ▸ Questions: added" =>
      {:change_back, "the menu's shape (AGENDA_PARITY, tagged 2026-10-22): back to Utilities"},
    "View menu ▸ View ▸ Manager: added" =>
      {:change_back,
       "a shortcut Agenda reaches by a Properties box or F8/F9: leaves the menu once View Properties is built (owner, 2026-10-23)"},
    "View menu ▸ View ▸ Rename: added" =>
      {:change_back,
       "leaves the menus, keeps its key and CTRL-X (AGENDA_PARITY, tagged 2026-10-22)"},
    "View menu ▸ View ▸ Filter: added" =>
      {:change_back,
       "a shortcut Agenda reaches by a Properties box or F8/F9: leaves the menu once View Properties is built (owner, 2026-10-23)"},
    "View menu ▸ View ▸ Order: added" =>
      {:change_back,
       "a shortcut Agenda reaches by a Properties box or F8/F9: leaves the menu once View Properties is built (owner, 2026-10-23)"},
    "View menu ▸ View ▸ Last: added" =>
      {:change_back,
       "leaves the menus, keeps its key and CTRL-X (AGENDA_PARITY, tagged 2026-10-22)"},
    "View menu ▸ View ▸ Hide: added" =>
      {:change_back,
       "a shortcut Agenda reaches by a Properties box or F8/F9: leaves the menu once View Properties is built (owner, 2026-10-23)"},
    "View menu ▸ View: order" => {:change_back, "follows from the entries above leaving"},
    "View menu ▸ View ▸ Section ▸ Add: missing" =>
      {:change_back,
       "Agenda's name and order come back, keys unchanged (owner, 2026-10-23): Below and Above are Add (ALT-D, ALT-U)"},
    "View menu ▸ View ▸ Section ▸ Below: added" =>
      {:change_back,
       "Agenda's name and order come back, keys unchanged (owner, 2026-10-23): Below and Above are Add (ALT-D, ALT-U)"},
    "View menu ▸ View ▸ Section ▸ Above: added" =>
      {:change_back,
       "Agenda's name and order come back, keys unchanged (owner, 2026-10-23): Below and Above are Add (ALT-D, ALT-U)"},
    "View menu ▸ View ▸ Section ▸ Collapse: added" =>
      {:change_back,
       "a shortcut Agenda reaches by a Properties box or F8/F9: leaves the menu once View Properties is built (owner, 2026-10-23)"},
    "View menu ▸ View ▸ Section ▸ Filter: added" =>
      {:change_back,
       "a shortcut Agenda reaches by a Properties box or F8/F9: leaves the menu once View Properties is built (owner, 2026-10-23)"},
    "View menu ▸ View ▸ Section ▸ Sort: added" =>
      {:change_back,
       "a shortcut Agenda reaches by a Properties box or F8/F9: leaves the menu once View Properties is built (owner, 2026-10-23)"},
    "View menu ▸ View ▸ Section ▸ Lines: added" =>
      {:change_back,
       "a shortcut Agenda reaches by a Properties box or F8/F9: leaves the menu once View Properties is built (owner, 2026-10-23)"},
    "View menu ▸ View ▸ Section: order" =>
      {:change_back, "follows from the entries above leaving and coming"},
    "View menu ▸ Print: a command in Agendum, a menu in Agenda" =>
      {:machine,
       "Print writes the view to a text file; printing on paper is out of scope (AGENDA_PARITY)"},
    "Note menu ▸ File: missing" =>
      {:not_built, "external note files, NOTE_EDITOR.md step 7, still to be decided"},
    "Note menu ▸ Print: missing" => {:out_of_scope, "printing on paper (SPEC § 6)"},
    "Category manager menu: missing" =>
      {:not_built, "F10 in the category manager (AGENDA_PARITY step 9)"}
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
