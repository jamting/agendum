defmodule Agendum.TUI.ViewKeysTest do
  @moduledoc "Agenda's own accelerator keys in a view (R42; Help: \"Views: Accelerator Keys\")."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.TUI.{Layout, Render, State}

  # The sample's Activities view gets two more sections (Priority, Contact),
  # and there is a second view, Priorities.
  setup do
    Process.delete(:effects_seen)
    db = Agendum.Sample.build(~D[2026-10-08])
    activities = hd(db.view_order)
    cat = fn name -> hd(Agendum.Core.Database.find_categories(db, name)) end
    db = db |> Core.add_section(activities, cat.("Priority"), 1)
    db = Core.add_section(db, activities, cat.("Contact"), 2)
    {db, _} = Core.add_view(db, "Priorities", [cat.("High")])
    %{state: start(db)}
  end

  defp head(state) do
    case Layout.current_row(state) do
      %{kind: :section, category: cat} -> cat.name
      other -> other
    end
  end

  test "ALT-F5 lists the section heads; ENTER goes to the chosen one", %{state: state} do
    state = press(state, {:alt_f, 5})
    text = screen(state)
    assert text =~ "Go to section"
    assert text =~ "Calls"
    assert text =~ "Priority"
    assert text =~ "Contact"

    state = press(state, [:down, :down, :enter])
    assert state.modes == []
    assert head(state) == "Contact"
  end

  test "in the GO TO box, a letter highlights the next section starting with it",
       %{state: state} do
    # from Calls, "c" finds the next one: Contact
    state = press(state, [{:alt_f, 5}, "c", :enter])
    assert head(state) == "Contact"
    state = press(state, [{:alt_f, 5}, "p", :enter])
    assert head(state) == "Priority"
  end

  test "ESC leaves the GO TO box without moving", %{state: state} do
    state = press(state, [{:alt_f, 5}, :down, :esc])
    assert state.modes == []
    assert state.cursor == 0
  end

  test "ALT-N / ALT-P show the next / previous view, wrapping", %{state: state} do
    state = press(state, {:alt, "n"})
    assert State.view(state).name == "Priorities"
    state = press(state, {:alt, "n"})
    assert State.view(state).name == "Activities"
    state = press(state, {:alt, "p"})
    assert State.view(state).name == "Priorities"
  end

  test "ALT-W saves, ALT-G retrieves, ALT-Q quits", %{state: state} do
    assert screen(press(state, {:alt, "w"})) =~ "Save file as:"
    assert screen(press(state, {:alt, "g"})) =~ "File to retrieve:"

    press(%{state | dirty: false}, {:alt, "q"})
    assert :quit in effects()
  end

  test "ALT-V shows or hides empty sections", %{state: state} do
    state = press(state, {:alt, "v"})
    assert State.view(state).hide_empty
    state = press(state, {:alt, "v"})
    refute State.view(state).hide_empty
  end

  test "ALT-K hides the key map and gives its two lines to the view", %{state: state} do
    assert slots(state) =~ "F1 Help"
    hidden = press(state, {:alt, "k"})
    refute screen(hidden) =~ "Help  │"
    assert length(Render.render(hidden)) == state.height
    assert State.body_height(hidden) == State.body_height(state) + 2
    assert slots(press(hidden, {:alt, "k"})) =~ "F1 Help"
  end

  test "ALT-I inserts an item, like INS", %{state: state} do
    state = press(state, [{:alt, "i"}, "Buy stamps", :enter])
    assert Enum.any?(Map.values(state.db.items), &(&1.text == "Buy stamps"))
  end
end
