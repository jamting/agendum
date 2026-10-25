defmodule Agendum.TUI.NoteSymbolTest do
  @moduledoc """
  The note symbol in the control panel (User's Guide 12-2; screenshot
  126): ♪ at the top right when the highlighted item, section head, column
  entry or column head has a note, and F5 opens that note.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  import Agendum.Fixtures, only: [cat: 2, with_categories: 2]

  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.TUI.State

  # Calls, with a People column (People ─ Mattias, Göran) before When.
  # Mattias has a note, Göran none. "Call Mattias" (in Mattias) has a note
  # of its own; "Call Göran" (in Göran) has none. The cursor on Calls.
  setup do
    db = Core.new_file(view_name: "Calls", section_name: "Calls")
    db = with_categories(db, [{"People", [], ["Mattias", "Göran"]}])
    db = Core.set_category_note(db, cat(db, "Mattias"), "Home: Lund")
    [view] = Database.views(db)
    calls = cat(db, "Calls")
    {db, mattias} = Core.add_item(db, "Call Mattias", ~D[2026-10-08], section: calls)
    {db, goran} = Core.add_item(db, "Call Göran", ~D[2026-10-08], section: calls)
    db = Core.assign(db, mattias, cat(db, "Mattias"))
    db = Core.assign(db, goran, cat(db, "Göran"))
    db = Core.set_note(db, mattias, "Ask about the boat", ~D[2026-10-08])
    db = Core.add_column(db, view.id, cat(db, "People"), {0, 0}, 12)
    %{state: start(db)}
  end

  # the right end of the control panel's second line
  defp symbol?(state), do: state |> screen() |> String.split("\n") |> Enum.at(1) =~ "♪"

  # People is column 1, When column 2
  defp people(state), do: press(state, :right)

  test "an item with a note; not one without", %{state: state} do
    assert symbol?(press(state, :down))
    refute symbol?(press(state, [:down, :down]))
  end

  test "a section head whose category has a note", %{state: state} do
    refute symbol?(state)
    state = %{state | db: Core.set_category_note(state.db, cat(state.db, "Calls"), "Weekly")}
    assert symbol?(state)
  end

  test "a column entry whose category has a note, whatever the item's own note",
       %{state: state} do
    assert symbol?(state |> press(:down) |> people())
    refute symbol?(state |> press([:down, :down]) |> people())
    # a date has no note
    refute symbol?(press(state, [:down, :down, :right, :right]))
  end

  test "a column head whose category has a note", %{state: state} do
    refute symbol?(people(state))
    state = %{state | db: Core.set_category_note(state.db, cat(state.db, "People"), "Friends")}
    assert symbol?(people(state))
  end

  test "F5 opens the note of what is highlighted", %{state: state} do
    state = state |> press(:down) |> people() |> press({:f, 5})
    assert %{type: :note, target: {:category, id}} = State.mode(state)
    assert id == cat(state.db, "Mattias")
    assert screen(state) =~ "Home: Lund"

    head = state |> press(:esc) |> press([:up, {:f, 5}])
    assert %{target: {:category, people}} = State.mode(head)
    assert people == cat(head.db, "People")

    assert screen(press(state, [:esc, :left, {:f, 5}])) =~ "Ask about the boat"
  end

  test "F5 on a date tells there is no category there", %{state: state} do
    state = press(state, [:down, :right, :right, {:f, 5}])
    assert State.mode(state) == nil
    assert panel(state) =~ message(:not_on_category)
  end
end
