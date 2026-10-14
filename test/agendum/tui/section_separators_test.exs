defmodule Agendum.TUI.SectionSeparatorsTest do
  @moduledoc """
  Section separators (R58; User's Guide 5-12, 15-21; screenshots 48, 54,
  143): each section head is drawn as a line across the screen, in place
  of the blank line between sections.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  import Agendum.Fixtures, only: [cat: 2, with_categories: 2]

  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.TUI.{History, Layout}

  # Calls, Follow up and Errands, each with a linked People column and an
  # item; the cursor on Calls.
  setup do
    db = Core.new_file(view_name: "Activities", section_name: "Calls")
    db = with_categories(db, ["Follow up", "Errands", "People"])
    [view] = Database.views(db)
    db = Core.add_section(db, view.id, cat(db, "Follow up"), 1)
    db = Core.add_section(db, view.id, cat(db, "Errands"), 2)
    db = Core.add_column(db, view.id, cat(db, "People"), {0, 0}, 12)

    db =
      Enum.reduce(["Calls", "Follow up", "Errands"], db, fn section, db ->
        {db, _} = Core.add_item(db, "In #{section}", ~D[2026-10-08], section: cat(db, section))
        db
      end)

    %{state: start(db), view_id: view.id}
  end

  defp lines(state), do: state |> screen() |> String.split("\n")

  defp line_with(state, text), do: Enum.find(lines(state), &String.contains?(&1, text))

  defp separators(state), do: press(state, [{:f, 10}, "v", "s", "l"])

  test "off by default: a blank line between sections, no rule", %{state: state, view_id: v} do
    refute state.db.views[v].section_separators
    refute line_with(state, "Follow up") =~ "─"
    assert screen(state) =~ ~r/In Calls *\n *\n Follow up/
  end

  test "View ▸ Section ▸ Lines: each section head is a line across, without the blank line",
       %{state: state, view_id: v} do
    state = separators(state)
    assert state.db.views[v].section_separators
    # the rule runs from the start of the line, around the name and the
    # column heads, to the end of the screen
    assert line_with(state, "Calls") =~ ~r/^─Calls─+People─+When─+$/u
    assert line_with(state, "Follow up") =~ ~r/^─Follow up─+People─+When─+$/u
    assert String.length(line_with(state, "Errands")) == state.width
    assert screen(state) =~ ~r/In Calls *\n─Follow up/u

    state = separators(state)
    refute line_with(state, "Follow up") =~ "─"
  end

  test "one undo step", %{state: state, view_id: v} do
    state = separators(state)
    refute History.undo(state).db.views[v].section_separators
  end

  test "with Hide column heads the other section heads are rules", %{state: state} do
    state = state |> separators() |> press([{:f, 10}, "v", "h", "c"])
    assert line_with(state, "Calls") =~ ~r/^─Calls─+People─+When─+$/u
    assert line_with(state, "Follow up") =~ ~r/^─Follow up─+$/u
  end

  test "a section head takes one line, so the view scrolls by the lines shown",
       %{state: state} do
    state = separators(state)
    assert Layout.heights(Layout.rows(state), state) == [1, 1, 1, 1, 1, 1]
    # 4 lines of view: the last item is still in sight at the bottom
    state = %{state | height: 8} |> press(List.duplicate(:down, 5))
    assert List.last(Enum.reject(lines(state), &(&1 =~ ~r/^ *$|F1|File|View/))) =~ "In Errands"
  end
end
