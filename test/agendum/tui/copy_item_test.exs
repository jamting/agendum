defmodule Agendum.TUI.CopyItemTest do
  @moduledoc """
  ALT-F9 COPY (R42, R35; User's Guide 13-8 to 13-9): the same item in one
  more section of the view, chosen in the Copy box. It keeps its other
  sections; with marked items Agenda asks which to copy.
  """
  use ExUnit.Case, async: true

  import Agendum.Fixtures, only: [cat: 2, item_id: 2]
  import Agendum.TUIHelpers

  alias Agendum.Core.Database
  alias Agendum.TUI.{History, State}

  @weed "Weed the carrot bed tomorrow morning"
  @count "Count the lettuces before Tigger bounces on them"

  # Rabbit's Week; the highlight on the first item, in Garden
  setup do
    db = Agendum.Sample.rabbit(~D[2026-10-12])
    %{state: db |> start(today: ~D[2026-10-12], height: 30) |> press(:down)}
  end

  defp in?(state, text, name),
    do: Database.member?(state.db, item_id(state.db, text), cat(state.db, name))

  test "the Copy box lists the view's sections, the current one highlighted", %{state: state} do
    state = press(state, {:alt_f, 9})
    assert %{type: :copy_items, cursor: 0} = State.mode(state)
    text = screen(state)
    assert text =~ "Copy to which section?"
    assert text =~ ~r/Garden[\s\S]*Notices[\s\S]*Friends and Relations/
  end

  test "ENTER copies the item: in both sections, one undo step", %{state: state} do
    state = press(state, [{:alt_f, 9}, :down, :enter])
    assert in?(state, @weed, "Garden") and in?(state, @weed, "Notices")
    assert State.mode(state) == nil
    assert panel(state) =~ "Copied to Notices"
    refute History.undo(state) |> in?(@weed, "Notices")
  end

  test "ESC copies nothing", %{state: state} do
    assert press(state, [{:alt_f, 9}, :down, :esc]).db == state.db
  end

  test "marked items: asked first, then all of them copied", %{state: state} do
    state = press(state, [{:f, 7}, :down, {:f, 7}, {:alt_f, 9}])
    assert %{type: :scope, action: :copy_item} = State.mode(state)
    state = press(state, ["m", :down, :down, :enter])
    assert in?(state, @weed, "Friends and Relations")
    assert in?(state, @count, "Friends and Relations")
  end

  test "on a section head there is no item to copy", %{state: state} do
    assert state |> press([:up, {:alt_f, 9}]) |> panel() =~ message(:not_on_item)
  end

  test "a datebook view's sections are its dates" do
    db = Agendum.Starters.Planner.build() |> Agendum.Starters.Planner.with_samples(~D[2026-10-12])
    today = Enum.find(Database.views(db), &(&1.name == "This Week"))

    state =
      db
      |> start(today: ~D[2026-10-12])
      |> State.switch_view(today.id)
      |> press([:down, {:alt_f, 9}])

    assert panel(state) =~ message(:datebook_change)
  end
end
