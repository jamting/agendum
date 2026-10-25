defmodule Agendum.TUI.MenuTest do
  use ExUnit.Case, async: true

  alias Agendum.TUI.Menu

  # Lotus menus are driven by first letters, so a duplicate makes a
  # command unreachable by letter.
  test "every menu level has unique first letters" do
    clashes =
      for tree <- [:main, :note],
          {path, entries} <- levels(Menu.tree(tree), []),
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
    import Agendum.TUIHelpers

    setup do
      %{state: start(Agendum.Sample.build(~D[2026-10-08])) |> press(:down)}
    end

    test "Item > Reposition starts moving the item", %{state: state} do
      assert %{type: :move_item} = Agendum.TUI.State.mode(press(state, [{:f, 10}, "i", "r"]))
    end

    test "Item > Discard asks to confirm", %{state: state} do
      assert screen(press(state, [{:f, 10}, "i", "d"])) =~ "Discard this item"
    end

    test "Item > Discard asks before discarding the item", %{state: state} do
      state = press(state, [{:f, 10}, "i", "d"])
      assert screen(state) =~ "Discard this item from the whole file?"
    end

    test "File > Maintenance > MakeCopy asks for the copy's name", %{state: state} do
      assert screen(press(state, [{:f, 10}, "f", "m", "m"])) =~ "Make a copy as:"
    end

    test "View > Column > Add opens the Column Add box", %{state: state} do
      assert %{type: :column_add} =
               Agendum.TUI.State.mode(press(state, [{:f, 10}, "v", "c", "a"]))
    end
  end

  describe "ESC steps back through the menu (screenshot notes 8-15)" do
    import Agendum.TUIHelpers
    alias Agendum.TUI.State

    setup do
      %{state: start(Agendum.Sample.build(~D[2026-10-08]))}
    end

    defp menu_path(state) do
      case State.mode(state) do
        %{type: :menu, path: path} -> path
        other -> other
      end
    end

    test "ESC in a box opened from the menu goes back to the menu level it came from",
         %{state: state} do
      state = press(state, [{:f, 10}, "f", "p"])
      assert %{type: :file_props} = State.mode(state)

      # back at File, with Properties highlighted
      state = press(state, :esc)
      assert %{type: :menu, path: [_file]} = State.mode(state)

      assert Enum.at(Menu.entries(State.mode(state)), State.mode(state).selected) |> elem(0) ==
               "Properties"

      assert menu_path(press(state, :esc)) == []
      assert State.mode(press(state, [:esc, :esc])) == nil
    end

    test "a box closed with ENTER goes back to the view", %{state: state} do
      state = press(state, [{:f, 10}, "u", "c", :enter])
      assert State.mode(state) == nil
    end

    test "a prompt from the menu goes back to it with ESC", %{state: state} do
      state = press(state, [{:f, 10}, "v", "a"])
      assert %{type: :prompt} = State.mode(state)
      assert %{type: :menu} = State.mode(press(state, :esc))
    end

    test "a box opened from a box goes back to that box, then to the menu", %{state: state} do
      state = press(state, [{:f, 10}, "f", "p", :down, :down, " "])
      assert %{type: :date_settings} = State.mode(state)
      assert %{type: :file_props} = State.mode(press(state, :esc))
      assert %{type: :menu} = State.mode(press(state, [:esc, :esc]))
    end
  end

  test "a menu wider than the screen scrolls to the highlighted entry, ◄ ► marking more" do
    state = Agendum.TUIHelpers.start(Agendum.Sample.build(~D[2026-10-08]), width: 50)
    first = fn state -> state |> Agendum.TUIHelpers.screen() |> String.split("\n") |> hd() end

    state = Agendum.TUIHelpers.press(state, [{:f, 10}, "i"])
    assert first.(state) =~ ~r/^  Properties .* ►$/
    refute first.(state) =~ "Alarm"

    state = Agendum.TUIHelpers.press(state, :end)
    assert first.(state) =~ ~r/^◄ .*Reposition   Alarm/
    assert String.length(first.(state)) <= 50
  end
end
