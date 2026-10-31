# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.ReviewSliceGTest do
  @moduledoc """
  The findings of the local review of group g, the boxes N to Z
  (docs/CODE_REVIEW_SLICES.md § The rest; 2026-10-31), each as the case
  that showed it.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.TUI.State

  @today ~D[2026-10-08]

  defp sample, do: start(Agendum.Sample.build(@today), today: @today)
  defp when_id(state), do: state.db.special.when

  describe "2. the Date Filter box's choice rows" do
    # the box opens on Show items; a digit, BACKSPACE or PGUP there
    # crashed (also found by the fuzz walks that start inside a box)
    for key <- [{:char, "1"}, :backspace, :pgup, {:char, "-"}] do
      test "#{inspect(key)} on Show items does nothing" do
        box = Agendum.TUI.Boxes.RangeFilterBox.open(sample(), :view, when_id(sample()))
        assert State.mode(box).type == :range_filter

        pressed = press(box, unquote(Macro.escape(key)))
        assert State.mode(pressed) == State.mode(box)
      end
    end
  end

  defp view_props(state), do: Agendum.TUI.Boxes.ViewProps.open(state, state.view_id)

  describe "1. View Properties after every section is removed" do
    # Section Select's F4 Clear all can take every section out; ENTER in
    # View Properties refuses that, but the keys before it crashed
    for key <- [:down, :up, :tab, :shift_tab, :insert, {:f, 6}, {:char, "x"}] do
      test "#{inspect(key)} with the cursor on a section that is gone" do
        state = sample()

        db =
          Agendum.Core.Database.update_view(state.db, state.view_id, &%{&1 | sections: []})

        box = view_props(%{state | db: db})
        box = State.put_mode(box, %{State.mode(box) | cursor: {:section, 0}})

        assert is_list(Agendum.TUI.Render.render(press(box, unquote(Macro.escape(key)))))
      end
    end
  end

  describe "3. Section statistics" do
    # sections are found by their index: Hide empty sections leaves an
    # empty one out of the view as drawn, and section sorting reorders them
    test "counts the section asked, with an empty one hidden before it" do
      state = sample()
      db = state.db
      {:ok, db, empty} = Agendum.Core.add_category(db, db.main_id, "Nothing here")
      db = Agendum.Core.add_section(db, state.view_id, empty, 0)
      db = Agendum.Core.Database.update_view(db, state.view_id, &%{&1 | hide_empty: true})
      view = db.views[state.view_id]
      clock = State.context(state)

      assert Agendum.Core.section_item_count(db, state.view_id, 0, clock) == 0

      shown = Agendum.Core.ViewModel.build(db, view, clock)
      first = Enum.find(shown, &(&1.index == 1))
      assert Agendum.Core.section_item_count(db, state.view_id, 1, clock) == length(first.rows)
    end
  end

  describe "4. and 5. the New File box's password" do
    defp new_file, do: Agendum.TUI.Boxes.NewFileBox.open(sample(), "/tmp/new.agendum")

    test "the key that starts it is hidden too, on the Password row" do
      on_password = press(new_file(), :down)
      assert Agendum.TUI.Update.Prompts.password_prompt?(on_password)
      refute Agendum.TUI.Update.Prompts.password_prompt?(new_file())
    end

    test "is kept as typed, spaces too, as the other password boxes keep it" do
      typed = press(new_file(), [:down, "pass ", :enter])
      assert State.mode(typed).password == "pass "
    end
  end

  describe "6. → in View Properties with many sections" do
    test "from Number items goes to Filter, not to a section out of sight" do
      state = sample()

      db =
        Enum.reduce(1..10, state.db, fn n, db ->
          {:ok, db, cat} = Agendum.Core.add_category(db, db.main_id, "S#{n}")
          Agendum.Core.add_section(db, state.view_id, cat, 0)
        end)

      box = view_props(%{state | db: db})
      box = State.put_mode(box, %{State.mode(box) | cursor: :number})
      assert State.mode(press(box, :right)).cursor == :filter
    end
  end

  describe "7. a choice's own letter" do
    test "Y on Yes keeps Yes, without an error" do
      box = press(sample(), [{:f, 10}, "f", "p"]) |> to_setting("Update defaults")
      opened = press(box, " ")
      assert State.mode(opened).type == :update_defaults

      pressed = press(opened, "y")
      refute match?({:error, _}, pressed.message)
      assert State.mode(pressed) == State.mode(opened)
    end
  end
end
