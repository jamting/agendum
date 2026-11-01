# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.BoxPaths do
  @moduledoc """
  The keys that open each of the clone's boxes from a view, for the tests
  that must reach them all: the fuzz walks start in them
  (`Agendum.TUI.Fuzz`), and the screen test of the extras off draws them
  (`Agendum.TUI.ExtrasScreenTest`).

  A path is a list of keys from the view; `{keys, labels}` or `{keys,
  labels, after}` a box inside a box, reached by SPACE on the setting with
  each label (`Agendum.TUIHelpers.to_setting/2`) and then the keys after;
  `{:answer, kind}` a box only the shell's answer opens (`:new_file`, a
  file that is not there; `:import_report`, an Agenda file imported).
  """

  # A random walk from the view hardly reaches the boxes inside boxes, where
  # the crash of 2026-10-30 was (View Properties on a datebook, ↑ from
  # Filter): hence this list (expert review 2026-10-30, § 18.1).
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
    # Item ▸ Reposition (R26a): the item carried with ↑ ↓
    [:down, @f10, {:char, "i"}, {:char, "r"}],
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
    [:down, {:f, 5}, {:f, 3}],
    # the two boxes only the shell's answer opens: a file that is not
    # there (New File), and an Agenda file imported (its report)
    {:answer, :new_file},
    {:answer, :import_report}
  ]

  @doc "Every path, in the order the fuzz walks pick from."
  @spec all() :: list
  def all, do: @boxes
end
