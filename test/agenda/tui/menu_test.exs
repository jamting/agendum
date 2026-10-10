defmodule Agenda.TUI.MenuTest do
  use ExUnit.Case, async: true

  alias Agenda.TUI.Menu

  # Lotus menus are driven by first letters, so a duplicate makes a
  # command unreachable by letter.
  test "every menu level has unique first letters" do
    clashes =
      for {path, entries} <- levels(Menu.tree(), []),
          {letter, labels} <- Enum.group_by(entries, &String.first(elem(&1, 0)), &elem(&1, 0)),
          length(labels) > 1 do
        "#{Enum.join(path, " > ")}: #{letter} = #{Enum.join(labels, ", ")}"
      end

    assert clashes == [], "Duplicate menu letters:\n" <> Enum.join(clashes, "\n")
  end

  defp levels(entries, path) do
    nested =
      for {label, _, children} <- entries,
          is_list(children),
          do: levels(children, path ++ [label])

    [{if(path == [], do: ["(top)"], else: path), entries} | List.flatten(nested)]
  end

  describe "commands reached by letter" do
    import Agenda.TUIHelpers

    setup do
      %{state: start(Agenda.Sample.build(~D[2026-10-08])) |> press(:down)}
    end

    test "Item > Reposition starts moving the item", %{state: state} do
      assert %{type: :move_item} = Agenda.TUI.State.mode(press(state, [{:f, 10}, "i", "r"]))
    end

    test "Item > Discard asks to confirm", %{state: state} do
      assert screen(press(state, [{:f, 10}, "i", "d"])) =~ "Discard this item"
    end

    test "Item > Finished marks the item done", %{state: state} do
      state = press(state, [{:f, 10}, "i", "f"])
      assert Agenda.TUI.Layout.current_row(state).item.done
    end

    test "File > Write asks for a new file name", %{state: state} do
      assert screen(press(state, [{:f, 10}, "f", "w"])) =~ "Save file as:"
    end

    test "View > Column > After and Before add columns", %{state: state} do
      assert %{type: :picker} = Agenda.TUI.State.mode(press(state, [{:f, 10}, "v", "c", "a"]))
      assert %{type: :picker} = Agenda.TUI.State.mode(press(state, [{:f, 10}, "v", "c", "b"]))
    end
  end
end
