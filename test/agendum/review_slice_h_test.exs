# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.ReviewSliceHTest do
  @moduledoc """
  The findings of the local review of group h, drawing and the rest
  (docs/CODE_REVIEW_SLICES.md § The rest; 2026-10-31), each as the case
  that showed it.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.TUI.{CategoryScreens, Layout, Render, State, Terminal.Draw, Terminal.Keys}

  @today ~D[2026-10-08]

  defp sample, do: Agendum.Sample.build(@today)
  defp lines(state), do: state |> screen() |> String.split("\n")

  @tag :tmp_dir
  test "1. a file holding invalid UTF-8 opens, its text repaired as Latin-1", %{tmp_dir: dir} do
    db = sample()
    id = hd(db.item_order)
    db = Database.update_item(db, id, &%{&1 | text: "Caf" <> <<0xE9>>})
    path = Path.join(dir, "bad.agendum")
    :ok = Agendum.Store.save(db, path)

    {:ok, loaded} = Agendum.Store.load(path)
    assert loaded.items[id].text == "Café"
    assert screen(start(loaded)) =~ "Café"
  end

  test "1. a screen with invalid UTF-8 still draws" do
    assert [[{:normal, text}]] = Draw.clean([[{:normal, "x\e" <> <<0xFF>> <> "tail"}]])
    assert String.valid?(text)
    assert text =~ "tail"
  end

  describe "2. escape sequences" do
    test "the Linux console's F1 to F5 are F-keys" do
      for {letter, n} <- Enum.zip(~w(A B C D E), 1..5) do
        assert Keys.decode("\e[[" <> letter) == {[{:f, n}], ""}
      end
    end

    test "an unknown sequence is one unknown key, not ESC and typed text" do
      assert Keys.decode("\e[11^x") == {[:unknown, {:char, "x"}], ""}
      assert Keys.decode("\e[?1;2c") == {[:unknown], ""}
    end

    test "F1 from the Linux console starts no item" do
      state = start(sample())
      {keys, ""} = Keys.decode("\e[[A")
      assert press(state, keys).edit == nil
    end
  end

  test "4. a CR LF in a category name keeps the line as wide as the screen" do
    db = sample()
    cat = State.view(start(db)).sections |> hd() |> Map.get(:category_id)
    db = Database.update_category(db, cat, &%{&1 | name: "Ca\r\nlls"})

    # every line of the drawn screen, trailing spaces kept
    for line <- db |> start(width: 80) |> Render.render() do
      assert line |> Enum.map_join(fn {_style, text} -> text end) |> String.length() <= 80
    end
  end

  test "5. with Number items, a calculation stays under its column" do
    db = Agendum.Starters.Golden.build()
    {vid, view} = Enum.find(db.views, fn {_, v} -> v.name == "Tasks" end)

    count_at = fn numbered ->
      view = %{
        view
        | number_items: numbered,
          sections: Enum.map(view.sections, &%{&1 | collapsed: false})
      }

      state = %{
        start(%{db | views: Map.put(db.views, vid, view)}, width: 100, height: 30)
        | view_id: vid
      }

      line = state |> Layout.settle() |> lines() |> Enum.find(&(&1 =~ "COUNT"))
      :binary.match(line, "COUNT")
    end

    assert count_at.(true) == count_at.(false)
  end

  test "out of scope: a row taller than the screen shows its first line" do
    long = Enum.map_join(1..60, " ", fn _ -> "word" end)
    db = sample()
    id = hd(db.item_order)
    db = Database.update_item(db, id, &%{&1 | text: "First " <> long})
    # moving on the row (→ to a column, or ↓ ↑) scrolled to its last line
    for keys <- [[:down, :right], [:down, :down, :up]] do
      state = db |> start(width: 40, height: 10) |> press(keys)

      assert Layout.current_row(state).item.id == id
      assert screen(state) =~ "First"
    end
  end

  test "out of scope: the password box fits a 40-column screen" do
    state = start(sample(), width: 40, height: 12)
    box = Agendum.TUI.Boxes.PasswordBox.open(state)

    # the box's right edge is on the screen
    assert screen(box) =~ ~r/Enter the new password ─+┐/u
  end

  describe "h2-1. an item a special action discards from its profile" do
    setup do
      db = Agendum.Starters.Planner.build() |> Agendum.Starters.Planner.with_samples(@today)
      {:ok, db, bin} = Core.add_category(db, db.main_id, "Aardvark bin", match_name: false)
      {:ok, db} = Core.set_special_action(db, bin, :discard)
      %{db: db, bin: bin}
    end

    defp on(state, cat) do
      rows = CategoryScreens.rows(state, State.mode(state))
      at = Enum.find_index(rows, fn {id, _} -> id == cat end)
      State.put_mode(state, %{State.mode(state) | cursor: at})
    end

    test "the profile closes with Agenda's message", %{db: db, bin: bin} do
      item = hd(db.item_order)
      state = db |> start() |> CategoryScreens.open_profile(item) |> on(bin)
      done = press(state, {:char, " "})

      refute Map.has_key?(done.db.items, item)
      assert done.modes == []
      assert panel(done) =~ "special action"
      assert screen(done)
    end

    test "the marked items' profile closes when all are gone", %{db: db, bin: bin} do
      items = Enum.take(db.item_order, 3)
      state = db |> start() |> CategoryScreens.open_group_profile(items) |> on(bin)
      done = press(state, {:char, " "})

      assert Enum.all?(items, &(not Map.has_key?(done.db.items, &1)))
      assert done.modes == []
    end
  end

  test "h2-2. Advanced settings of an unindexed category says it has none" do
    db = Agendum.Starters.Planner.build()
    {:ok, db, address} = Core.add_category(db, db.main_id, "Address")
    {:ok, db} = Core.make_unindexed(db, address)

    state =
      db |> start() |> CategoryScreens.open_props(address) |> to_setting("Advanced settings")

    done = press(state, {:char, " "})

    assert panel(done) =~ "Unindexed categories have no advanced settings"
  end

  describe "h2-3. a category under one that has no children" do
    setup do
      db = Agendum.Starters.Planner.build()
      [calls] = Database.find_categories(db, "Calls")
      [amount] = Database.find_categories(db, "Amount")
      %{db: db, calls: calls, amount: amount}
    end

    test "moving it under a date or numeric category is refused", %{db: db, calls: calls} = c do
      assert Core.move_category(db, calls, db.special.when, nil) ==
               {:error, :parent_has_no_children}

      assert Core.move_category(db, calls, c.amount, nil) == {:error, :parent_has_no_children}
    end

    test "demoting it under one is refused, as Agenda's", %{db: db, calls: calls, amount: amount} do
      # Calls placed right after Amount, at its level, then F8
      {:ok, db} = Core.move_category(db, calls, db.categories[amount].parent_id, amount)
      assert Core.demote(db, calls) == {:error, :parent_has_no_children}
    end
  end

  test "h2-6. an import of documents from a folder without any is refused" do
    dir = Path.join(System.tmp_dir!(), "agendum-thoughts-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    path = Path.join(dir, "t.agendum")
    :ok = Agendum.Store.save(Agendum.Thoughts.new_file(), path)

    ExUnit.CaptureIO.capture_io(fn ->
      assert_raise Mix.Error, ~r/No documents/, fn ->
        Mix.Tasks.Agendum.Thoughts.run([path, "--import-docs", "--yes", "--docs", dir])
      end
    end)

    File.rm_rf!(dir)
  end

  # found by the fuzz walks during this review (seed 682380): a macro run
  # from the macro manager over F1 over a settings box, then ESC on the box
  test "a box cancelled after a macro run leaves no undo step that changes nothing" do
    db = sample()
    {:ok, db, water} = Core.add_macro(db, "Water")
    db = Core.set_macro_keys(db, water, "Water the lettuces{ENTER}{DOWN}{CALL Again}")
    {:ok, db, again} = Core.add_macro(db, "Again")
    db = Core.set_macro_keys(db, again, "{AltF3}{ENTER}x{AltZ}")
    state = start(db, width: 51, height: 20, extras: true)

    done = press(state, [{:f, 10}, "v", "s", "p", {:f, 1}, {:alt_f, 3}, :enter, :esc])
    assert done.db == state.db
    assert done.history.undo == []
  end

  test "h2-7. the Planner's conference dinner keeps its Dinner" do
    db = Agendum.Starters.Planner.build() |> Agendum.Starters.Planner.with_samples(@today)

    {id, _} =
      Enum.find(db.items, fn {_, i} -> i.text == "Dinner with the conference speakers" end)

    [dinner] = Database.find_categories(db, "Dinner")

    assert Database.member?(db, id, dinner)
  end
end
