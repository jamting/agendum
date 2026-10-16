defmodule Agendum.TUI.CommandDocsTest do
  @moduledoc """
  The commands' longer texts (R65b): each belongs to a command, and F1 `c`
  and `d` show them, wrapped to the screen.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Starters.Planner
  alias Agendum.TUI.{CommandDocs, Commands}

  @today ~D[2026-10-12]

  setup do
    db = Planner.build() |> Planner.with_samples(@today)
    %{state: start(db, today: @today, height: 40, width: 100)}
  end

  test "every text belongs to a command of its place, and says more than the summary" do
    for {place, docs} <- CommandDocs.all(), {id, doc} <- docs do
      command = Commands.get(place, id)
      assert command, "#{place} #{id} has a text but is no command"
      assert command.doc == doc
      assert String.length(doc) > String.length(command.summary)
    end
  end

  test "F1 c shows the highlighted command's text under it, and no other's", %{state: state} do
    text = state |> press([{:f, 1}, "c", "remove"]) |> screen()
    assert text =~ "Takes the item out of this section's category only."
    refute text =~ "Deletes the item from the whole file"
  end

  test "the text is wrapped to the screen", %{state: state} do
    narrow = %{state | width: 60}
    lines = narrow |> press([{:f, 1}, "c", "remove"]) |> screen() |> String.split("\n")
    assert Enum.all?(lines, &(String.length(&1) <= 60))
    assert Enum.count(lines, &(&1 =~ ~r/^ {19}\S/)) >= 3
  end

  test "F1 d shows a key's text after its summary", %{state: state} do
    text = state |> press([{:f, 1}, "d", {:alt, "y"}]) |> screen()
    assert text =~ "ALT-Y runs Yank in a view."
    assert text =~ "Puts back the item Remove took out last"
  end

  test "a global key's text too", %{state: state} do
    text = state |> press([{:f, 1}, "d", {:ctrl, "z"}]) |> screen()
    assert text =~ "Takes back the last change to the file"
  end
end
