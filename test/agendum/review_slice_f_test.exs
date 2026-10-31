# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.ReviewSliceFTest do
  @moduledoc """
  The findings of the local review of group f, the boxes A to M
  (docs/CODE_REVIEW_SLICES.md § The rest; 2026-10-31), each as the case
  that showed it.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Core
  alias Agendum.TUI.{Render, State, Update}

  @today ~D[2026-10-08]

  defp sample(opts \\ []), do: start(Agendum.Sample.build(@today), [today: @today] ++ opts)

  describe "1. Abandon with a view made since the file was saved" do
    test "a Show View made since: the file's first view, no crash" do
      shown = press(sample(), [{:f, 10}, "u", "s", "i"])
      refute Map.has_key?(shown.saved.db.views, shown.view_id)

      reverted = press(shown, [{:f, 10}, "f", "a", "y", :enter])
      assert reverted.db == shown.saved.db
      assert reverted.view_id == hd(reverted.db.view_order)
      assert is_list(Render.render(reverted))
    end
  end

  describe "2. Item Column Properties when its fields shrink" do
    test "the cursor past the fields shown keeps to the last" do
      state = sample()
      db = Core.set_item_column(state.db, state.view_id, 0, set: :manual)
      box = %{state | db: db} |> Agendum.TUI.Boxes.ItemColumnBox.open(0)
      # five fields with Automatically, four with Manually
      box = State.put_mode(box, %{State.mode(box) | cursor: 4})

      assert Agendum.TUI.Boxes.ItemColumnBox.field(box, State.mode(box)) != nil
      assert is_list(Render.render(press(box, " ")))
    end
  end

  describe "3. the clock while a settings box is open" do
    test "an alarm rung while File Properties is open stays rung after ESC" do
      state = sample(now: ~N[2026-10-08 09:00:00])
      [item | _] = state.db.item_order

      db =
        Agendum.Core.Database.update_item(
          state.db,
          item,
          &%{&1 | when: @today, when_time: ~T[10:00:00]}
        )

      {:ok, db} = Core.set_alarm(db, item, 0)
      state = %{state | db: db, saved: %{state.saved | db: db}}

      box = press(state, [{:f, 10}, "f", "p"])
      {rung, _} = Update.tick(box, ~N[2026-10-08 10:01:00])
      assert rung.db != box.db

      cancelled = press(rung, :esc)
      assert cancelled.db == rung.db
      assert {again, _} = Update.tick(cancelled, ~N[2026-10-08 10:02:00])
      assert again.db == cancelled.db
    end
  end

  describe "4. Column Add with a new head" do
    test "ESC takes back the category the head made" do
      state = press(sample(), :down)
      before = state.db
      cancelled = press(state, [{:f, 10}, "v", "c", "a", "Zebra", :enter, :esc])

      assert cancelled.db == before
    end
  end

  describe "6. the Copy box with more sections than fit" do
    test "the highlighted section stays in the box" do
      state = sample(height: 14)

      db =
        Enum.reduce(1..20, state.db, fn n, db ->
          {:ok, db, cat} = Core.add_category(db, db.main_id, "Section #{n}")
          Core.add_section(db, state.view_id, cat, length(db.views[state.view_id].sections))
        end)

      box = %{state | db: db} |> press(:down) |> press({:alt_f, 9})
      down = press(box, List.duplicate(:down, 20))
      name = db.categories[Enum.at(db.views[state.view_id].sections, 20).category_id].name

      assert screen(down) =~ name
    end
  end

  describe "7. Item Properties with many assignments" do
    test "the hint under the list stays in the box" do
      state = sample(height: 20)
      item = hd(state.db.item_order)

      db =
        Enum.reduce(1..25, state.db, fn n, db ->
          {:ok, db, cat} = Core.add_category(db, db.main_id, "Topic #{n}")
          Core.assign(db, item, cat)
        end)

      box = %{state | db: db} |> Agendum.TUI.Boxes.ItemProperties.open(item)
      # the highlight in the middle of the list, rows below it too
      middle = press(box, List.duplicate(:down, 6))
      assert screen(middle) =~ "DEL remove"
    end
  end
end
