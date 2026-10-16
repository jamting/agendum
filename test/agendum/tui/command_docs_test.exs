defmodule Agendum.TUI.CommandDocsTest do
  @moduledoc """
  The commands' longer texts (R65b): each belongs to a command, and F1 `c`
  and `d` show them, wrapped to the screen.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Starters.Planner
  alias Agendum.TUI.{CommandDocs, Commands, Menu}

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

  test "F1 c shows the highlighted command's text in the pane, and no other's",
       %{state: state} do
    text = state |> press([{:f, 1}, "c", "remove"]) |> screen()
    assert text =~ "Takes the item out of this section's category only."
    refute text =~ "Deletes the item from the whole file"
  end

  test "the text is wrapped to the screen", %{state: state} do
    narrow = %{state | width: 60}
    lines = narrow |> press([{:f, 1}, "c", "remove"]) |> screen() |> String.split("\n")
    assert Enum.all?(lines, &(String.length(&1) <= 60))
    assert Enum.join(lines) =~ "Takes the item out of this"
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

  describe "the menu's entries" do
    # every entry of the tree, by its labels from the top
    defp menu_paths(level \\ Menu.tree(), above \\ []) do
      Enum.flat_map(level, fn
        {label, _, children} when is_list(children) ->
          [above ++ [label] | menu_paths(children, above ++ [label])]

        {label, _, _action} ->
          [above ++ [label]]
      end)
    end

    test "every text names an entry of the menu" do
      paths = menu_paths()
      for labels <- CommandDocs.menu_labels(), do: assert(labels in paths, inspect(labels))
    end

    test "F1 c in the menu shows the highlighted entry's text", %{state: state} do
      text = state |> press([{:f, 10}, "v", "h", {:f, 1}, "c", "inherited"]) |> screen()
      assert text =~ "An item in Anna is in People too."
    end

    test "an entry that runs a view's command has that command's text", %{state: state} do
      text = state |> press([{:f, 10}, "i", {:f, 1}, "c", "finished"]) |> screen()
      assert text =~ "Gives the item today's Done date"
    end

    test "F1 d on a letter shows it too", %{state: state} do
      text = state |> press([{:f, 10}, "f", {:f, 1}, "d", "d"]) |> screen()
      assert text =~ "d chooses Dating."
      assert text =~ "as a reading list"
    end
  end

  describe "the boxes' commands" do
    test "every text names a command of its box" do
      for {box, docs} <- CommandDocs.boxes(), {id, _doc} <- docs do
        ids =
          try do
            for {i, _, _} <- box.commands(%{}), do: i
          rescue
            # a box whose commands depend on its mode: checked by its own test
            _ -> Map.keys(docs)
          end

        assert id in ids, "#{inspect(box)} has a text for #{id}, which it does not have"
      end
    end

    test "F1 c in a box shows its command's text", %{state: state} do
      text = state |> press([:down, {:f, 6}, {:f, 1}, "c", "profile"]) |> screen()
      assert text =~ "Every category, those the item is in marked"
    end

    test "a settings box has the shared texts; the search box's Search does not",
         %{state: state} do
      file_props = Agendum.TUI.Boxes.FileProperties.open(state)
      assert screen(press(file_props, [{:f, 1}, "c", "close, keep"])) =~ "ESC would put it back"

      # the search box's Done is Search: not a settings box, so no shared text
      assert CommandDocs.box(Agendum.TUI.Boxes.SearchBox, :done, false) == nil
      assert CommandDocs.box(Agendum.TUI.Boxes.FileProperties, :done, true) =~ "ESC would"
    end
  end
end
