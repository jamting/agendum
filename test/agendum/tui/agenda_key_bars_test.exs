# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.AgendaKeyBarsTest do
  @moduledoc """
  Agendum's key bars compared with Lotus Agenda 2.0's own (ADR 0045;
  meeting 2026-10-24-2057, § 5), as `tools/agformat/capture_key_bars.py`
  captured them from the real program into
  `docs/reference/agenda_key_bars.json`: in a view, a note, the category
  manager and the view manager, with no key held and with ALT, CTRL or
  SHIFT held. No DOSBox here: the test reads the capture.

  The bars are compared slot by slot, as the person sees them with the
  Extras preference off (R77) and no macros. Every difference found must
  be listed below with its tag (`docs/plans/AGENDA_PARITY.md`, ADR 0043),
  and every difference listed must still be there: a difference fixed, or
  a new one, fails the test until the list is brought up to date.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.TUI.Render.KeyBar

  @reference "docs/reference/agenda_key_bars.json"
  @places ["view", "note", "catmgr", "viewmgr"]
  @held ["none", "alt", "ctrl", "shift"]

  # Every difference, by what it says, with its tag, as in the menu test
  # (`agenda_menus_test.exs`):
  #
  #   :machine, :work, :quiet  stays (ADR 0043's test)
  #   :change_back             a difference to undo
  #   :not_built               Agenda has it, Agendum not yet: parity work
  #   :out_of_scope            left out on purpose (SPEC § 6)
  @differences %{
    "view ALT-F1: Agenda Compose, ours none" =>
      {:not_built, "COMPOSE, Agenda's characters typed by code (NOTE_EDITOR.md, optional)"},
    "note ALT-F1: Agenda Compose, ours none" =>
      {:not_built, "COMPOSE, Agenda's characters typed by code (NOTE_EDITOR.md, optional)"},
    "catmgr ALT-F1: Agenda Compose, ours none" =>
      {:not_built, "COMPOSE, Agenda's characters typed by code (NOTE_EDITOR.md, optional)"},
    "viewmgr ALT-F1: Agenda Compose, ours none" =>
      {:not_built, "COMPOSE, Agenda's characters typed by code (NOTE_EDITOR.md, optional)"},
    "note F6: Agenda Marker, ours none" =>
      {:out_of_scope, "fonts and typesetting (SPEC § 6; R64a)"},
    "catmgr F7: Agenda Prm ( ), ours Promote" =>
      {:change_back,
       "Agenda's label; what its brackets hold is unchecked (AGENDA_PARITY, the texts step)"},
    "catmgr F8: Agenda Dem ( ), ours Demote" =>
      {:change_back,
       "Agenda's label; what its brackets hold is unchecked (AGENDA_PARITY, the texts step)"},
    "catmgr ALT-F6: Agenda Search, ours none" => {:not_built, "searching the category manager"},
    "catmgr ALT-F7: Agenda ShowC/A, ours none" =>
      {:not_built, "show the categories' conditions and actions"},
    "catmgr ALT-F8: Agenda Clr C/A, ours none" =>
      {:not_built, "clear a category's conditions and actions"},
    "catmgr ALT-F9: Agenda Cpy C/A, ours none" =>
      {:not_built, "copy a category's conditions and actions"},
    "viewmgr ALT-F3: Agenda none, ours Macro" =>
      {:quiet, "ALT-F3 opens the macro manager from anywhere (R50), the view manager too"},
    "viewmgr ALT-F9: Agenda Copy, ours none" =>
      {:not_built, "copying a view (Agenda's View ▸ Copy too)"},
    "viewmgr ALT-F10: Agenda Move, ours none" =>
      {:not_built, "moving a view with ALT-F10; ALT-↑↓ move it meanwhile (R65)"}
  }

  setup_all do
    %{"bars" => bars} = @reference |> File.read!() |> JSON.decode!()
    %{agenda: bars, state: start(Agendum.Core.new_file())}
  end

  test "the capture has every place and every held key" do
    %{"bars" => bars} = @reference |> File.read!() |> JSON.decode!()
    assert Enum.sort(Map.keys(bars)) == Enum.sort(@places)
    for place <- @places, held <- @held, do: assert(length(bars[place][held]) == 10)
  end

  test "every difference from Agenda's key bars is known, and still there", %{
    agenda: agenda,
    state: state
  } do
    found =
      for place <- @places,
          held <- @held,
          {{theirs, {ours, _full}}, n} <-
            Enum.with_index(
              Enum.zip(
                agenda[place][held],
                KeyBar.slots(state, String.to_atom(place), String.to_atom(held))
              ),
              1
            ),
          theirs != ours,
          do: difference(place, held, n, theirs, ours)

    unknown = Enum.reject(found, &Map.has_key?(@differences, &1))
    gone = @differences |> Map.keys() |> Enum.reject(&(&1 in found))

    assert unknown == [] and gone == [], """
    #{if unknown != [], do: "New differences from Agenda's key bars (tag them, or fix them):\n  " <> Enum.join(unknown, "\n  ") <> "\n", else: ""}#{if gone != [], do: "Listed differences that are gone (take them off the list):\n  " <> Enum.join(gone, "\n  "), else: ""}
    """
  end

  test "every listed difference has a known tag" do
    tags = [:machine, :work, :quiet, :change_back, :not_built, :out_of_scope]

    for {difference, {tag, why}} <- @differences do
      assert tag in tags, "#{difference}: unknown tag #{inspect(tag)}"
      assert is_binary(why) and why != "", "#{difference}: say why"
    end
  end

  # "catmgr ALT-F7: Agenda ShowC/A, ours none"
  defp difference(place, held, n, theirs, ours) do
    key = %{"none" => "F", "alt" => "ALT-F", "ctrl" => "CTRL-F", "shift" => "SHIFT-F"}[held]
    "#{place} #{key}#{n}: Agenda #{blank(theirs)}, ours #{blank(ours)}"
  end

  defp blank(""), do: "none"
  defp blank(label), do: label
end
