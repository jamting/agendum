defmodule Agendum.TUI.AvailableTest do
  @moduledoc """
  Whether a command can run now (R65a): F1 `c` greys the commands that
  cannot, says why on the highlighted one, and ENTER on one gives the
  reason instead of running it. Each place says what it cannot run
  (`unavailable/1`); a test keeps that honest by running every command
  it names and checking that nothing changed.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Core
  alias Agendum.Starters.Planner
  alias Agendum.TUI.{HelpScreen, State}
  alias Agendum.TUI.Boxes.ViewManager
  alias Agendum.TUI.CategoryScreens.Manager
  alias Agendum.TUI.Update.{Notes, ViewKeys}

  @today ~D[2026-10-12]

  setup do
    db = Planner.build() |> Planner.with_samples(@today)
    %{state: start(db, today: @today, height: 40, width: 100)}
  end

  # the reasons F1 c would show, by command id, for the place `from`
  defp why(state, from),
    do: Map.new(HelpScreen.unavailable(state, from), fn {{_, id}, r} -> {id, r} end)

  # the state with the highlight on the first item of the view
  defp on_item(state) do
    rows = Agendum.TUI.Layout.rows(state)
    index = Enum.find_index(rows, &(&1.kind == :item))
    Agendum.TUI.Layout.move_to(state, index)
  end

  defp on_section(state) do
    rows = Agendum.TUI.Layout.rows(state)
    Agendum.TUI.Layout.move_to(state, Enum.find_index(rows, &(&1.kind == :section)))
  end

  describe "in a view" do
    test "on an item with nothing marked or removed", %{state: state} do
      reasons = why(on_item(state), :view)
      assert reasons[:yank] == "No removed item to yank back"
      assert reasons[:next_marked] == "No marked items in this view"
      assert reasons[:unmark_all] == "No items are marked"
      assert reasons[:dependency] == "Mark the items it depends on with F7, then ALT-O"
      refute Map.has_key?(reasons, :edit)
      refute Map.has_key?(reasons, :down)
      refute Map.has_key?(reasons, :done)
    end

    test "on a section head: the commands that need an item", %{state: state} do
      reasons = why(on_section(state), :view)
      assert reasons[:copy] == "Highlight an item to copy"
      assert reasons[:hop] == "Highlight an item to hop to its next occurrence"
      assert reasons[:alarm] == "Highlight an item first"
      assert reasons[:done] == "Highlight an item, or mark some with F7"
      refute Map.has_key?(reasons, :mark)
      refute Map.has_key?(reasons, :edit)
    end

    test "on a section head with items marked, Done works on the marked ones", %{state: state} do
      marked = state |> on_item() |> press({:f, 7}) |> on_section()
      reasons = why(marked, :view)
      refute Map.has_key?(reasons, :done)
      refute Map.has_key?(reasons, :unmark_all)
    end

    test "after DEL removes an item, Yank can put it back", %{state: state} do
      removed = state |> on_item() |> press(:delete)
      refute Map.has_key?(why(removed, :view), :yank)
    end

    test "Undo has nothing to undo at first, then something", %{state: state} do
      assert why(state, :view)[:undo] == "Nothing to undo"
      assert why(state, :view)[:redo] == "Nothing to redo"
      refute Map.has_key?(why(state |> on_item() |> press({:f, 7}), :view), :undo)
    end
  end

  describe "in the category manager" do
    test "on MAIN: what MAIN cannot do", %{state: state} do
      reasons = why(press(state, {:f, 9}), :catmgr)
      assert reasons[:rename] == "MAIN cannot be renamed"
      assert reasons[:discard] == "MAIN cannot be discarded"
      assert reasons[:add_above] == "Nothing can be added beside MAIN"
      assert reasons[:promote] == "Already at the top level"
      refute Map.has_key?(reasons, :add_child)
    end

    test "on Entry, a top-level date category: what it cannot do", %{state: state} do
      reasons = why(press(state, [{:f, 9}, :down]), :catmgr)
      assert reasons[:promote] == "Already at the top level"
      assert reasons[:add_family] == "Nothing can be added at the same level as MAIN"
      assert reasons[:add_child] == "Children can be added only to standard categories"
      assert reasons[:move_up] == "Already the first of its siblings"
      assert reasons[:rename] == "Entry cannot be renamed"
    end

    test "on a person: a child that can do almost everything", %{state: state} do
      reasons = why(press(state, [{:f, 9}, :down, :down, :down, :down, :down]), :catmgr)
      assert reasons[:move_up] == "Already the first of its siblings"

      for id <- [:rename, :move, :discard, :add_above, :add_child, :promote],
          do: refute(reasons[id])
    end
  end

  test "in the view manager: the first view cannot move up", %{state: state} do
    reasons = why(press(state, [{:f, 8}, :home]), :viewmgr)
    assert reasons[:move_up] == "Already the first view"
    refute Map.has_key?(reasons, :move_down)
  end

  test "in a note: nothing to paste or search again yet", %{state: state} do
    reasons = why(state |> on_item() |> press({:f, 5}), :note)
    assert reasons[:paste] == "Nothing to paste: F3 copies, F4 cuts"
    assert reasons[:search_next] == "Nothing to search for yet; press ALT-F6"
    refute Map.has_key?(reasons, :mark)
  end

  describe "honest: a command said not to run really does nothing" do
    # every place's unavailable commands, run as their keys would: the
    # file, the screens and the editing stay as they were
    defp assert_honest(state, from, run) do
      for {{place, id}, reason} <- HelpScreen.unavailable(state, from), place == from do
        next = run.(state, id)

        assert {next.db, next.modes, next.edit, next.view_id} ==
                 {state.db, state.modes, state.edit, state.view_id},
               "#{from} #{id} (#{reason}) changed something"
      end
    end

    test "in a view, on an item, a section head, and with no rows", %{state: state} do
      for s <- [on_item(state), on_section(state), state] do
        assert_honest(s, :view, &ViewKeys.run(&1, &2))
      end

      {db, view_id} = Core.add_view(state.db, "Empty", [])
      empty = State.switch_view(%{state | db: db}, view_id)
      assert Agendum.TUI.Layout.rows(empty) == []
      assert_honest(empty, :view, &ViewKeys.run(&1, &2))
    end

    test "in the managers and a note", %{state: state} do
      assert_honest(press(state, {:f, 9}), :catmgr, &Manager.run(&1, &2))
      assert_honest(press(state, [{:f, 9}, :down]), :catmgr, &Manager.run(&1, &2))
      assert_honest(press(state, [{:f, 8}, :home]), :viewmgr, &ViewManager.run(&1, &2))
      assert_honest(state |> on_item() |> press({:f, 5}), :note, &Notes.run(&1, &2))
    end
  end

  describe "F1 c" do
    defp list(state), do: press(state, [{:f, 1}, "c"])

    defp row_style(listed, name) do
      mode = State.mode(listed)

      listed
      |> HelpScreen.lines(mode)
      |> Enum.find(fn segments -> Enum.any?(segments, &(elem(&1, 1) =~ ~r/^ #{name} /)) end)
      |> hd()
      |> elem(0)
    end

    test "greys what cannot run now, and leaves the rest as it was", %{state: state} do
      # a tall screen, so that Yank is in the list as it opens
      listed = list(on_item(%{state | height: 80}))
      assert row_style(listed, "Yank") == :dim
      assert row_style(listed, "Edit") == :normal
    end

    test "the highlighted one says why it cannot run", %{state: state} do
      listed = state |> on_item() |> list() |> press("yank")
      assert screen(listed) =~ "Not now: No removed item to yank back"
    end

    test "ENTER on one gives the reason and changes nothing", %{state: state} do
      here = on_item(state)
      ran = here |> list() |> press(["yank", :enter])
      assert ran.modes == [] and ran.db == here.db
      assert ran.message == {:error, "No removed item to yank back"}
    end

    test "typing highlights the first match that can run", %{state: state} do
      # on a section head with nothing marked, "item(s)" matches Done
      # (which needs an item) first, then Discard (which discards the
      # section's category)
      listed = state |> on_section() |> list() |> press("item(s)")
      assert State.mode(listed).cursor == 1
    end

    test "d says so too", %{state: state} do
      text = state |> on_item() |> press([{:f, 1}, "d", {:alt, "y"}]) |> screen()
      assert text =~ "ALT-Y runs Yank in a view."
      assert text =~ "Not now: No removed item to yank back"
    end
  end
end
