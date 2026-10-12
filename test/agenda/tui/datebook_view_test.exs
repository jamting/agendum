defmodule Agenda.TUI.DatebookViewTest do
  @moduledoc "A datebook view in the TUI (R47): its slots, typing into one, and its restrictions."
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.Core
  alias Agenda.Core.Datebook
  alias Agenda.TUI.{Layout, State}

  # Monday 12 October 2026
  setup do
    db = Agenda.Sample.build(~D[2026-10-12])
    {:ok, db, view} = Core.add_datebook_view(db, "This week", %Datebook{})
    state = start(db, width: 80, height: 25, today: ~D[2026-10-12])
    state = %{state | now: ~N[2026-10-12 10:00:00]}
    %{state: state |> State.switch_view(view) |> Layout.settle()}
  end

  test "each slot is a section, named by its date", %{state: state} do
    text = screen(state)
    for day <- ~w(Mon Tue Wed Thu Fri), do: assert(text =~ day <> " 2026-10-")
    assert text =~ "Mon 2026-10-12"
    assert text =~ "Fri 2026-10-16"
  end

  test "an item typed into a slot gets the slot's date", %{state: state} do
    # Wednesday's slot is the third section; its head is the third row
    wednesday =
      Enum.find_index(Layout.rows(state), &(&1[:slot] && &1.slot.from == ~D[2026-10-14]))

    state = state |> Layout.move_to(wednesday) |> press(["Picnic with Pooh", :enter])

    item = state.db.items |> Map.values() |> Enum.find(&(&1.text == "Picnic with Pooh"))
    assert item.when == ~D[2026-10-14]
    assert screen(state) =~ ~r/Wed 2026-10-14\n • Picnic with Pooh/
  end

  test "its sections cannot be added, removed, changed or collapsed", %{state: state} do
    for keys <- [{:alt, "d"}, {:alt, "u"}, :delete, {:f, 3}, {:alt, "-"}] do
      after_ = press(state, keys)
      assert after_.db == state.db
      assert screen(after_) =~ "A datebook view's sections are its dates"
    end
  end
end
