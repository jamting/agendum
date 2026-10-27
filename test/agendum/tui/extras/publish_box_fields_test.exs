defmodule Agendum.TUI.Extras.PublishBoxFieldsTest do
  @moduledoc """
  The Publish box's fields as the clone's settings boxes have them (UI
  guidelines, gaps 1, 5 and 8; the owner's answers, 2026-10-27): Posts and
  Drafts complete a category's name and F3 lists them; Folder is chosen
  from the file list; F8 and ALT-F8 put settings back to their defaults.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.TUI.State

  setup do
    db = Core.new_file()
    {:ok, db, posts} = Core.add_category(db, db.main_id, "Posts")
    {:ok, db, drafts} = Core.add_category(db, db.main_id, "Drafts")
    {:ok, db, _} = Core.add_category(db, db.main_id, "Postcards")
    state = start(db, extras: true)
    %{state: press(state, [{:f, 10}, "f", "t", "p"]), posts: posts, drafts: drafts}
  end

  defp settings(state), do: State.mode(state).settings

  describe "Posts and Drafts" do
    test "typing shows the first matching category, and ENTER takes it", %{state: state} do
      state = state |> to_setting("Posts category") |> press(["P", "o", "s", "t", "c"])
      assert screen(state) =~ "AUTOC"
      assert panel(state) =~ "Current choice: Postcards"
      assert settings(press(state, :enter)).posts == "Postcards"
    end

    test "F5 takes exactly what was typed, a new category when the box is done", %{state: state} do
      state = state |> to_setting("Posts category") |> press(["P", "o", "s", {:f, 5}])
      assert settings(state).posts == "Pos"
    end

    test "F3 opens the category list, and the one picked is the setting", ctx do
      state = ctx.state |> to_setting("Drafts") |> press({:f, 3})
      assert %{type: :picker} = State.mode(state)
      assert screen(state) =~ "Drafts: select a category"

      state = state |> press(["D", "r", "a"]) |> press(:enter)
      assert %{type: :publish} = State.mode(state)
      assert settings(state).drafts == "Drafts"
    end

    test "a category picked after something else came on top still reaches the box", ctx do
      # the fuzz walk, 2026-10-27: F3, then a macro's keys left a prompt on
      # top before the pick came back
      state = ctx.state |> to_setting("Drafts") |> press({:f, 3}) |> State.pop()
      state = State.push(state, %Agendum.TUI.Modes.Confirm{question: "?", action: :noop})

      state =
        Agendum.TUI.CategoryScreens.Picker.pick(
          state,
          {:box_field, :publish, :drafts},
          ctx.drafts
        )

      publish = Enum.find(state.modes, &(&1.type == :publish))
      assert publish.settings.drafts == "Drafts"
    end

    test "SPACE opens the list too", %{state: state} do
      assert %{type: :picker} =
               state |> to_setting("Posts category") |> press(" ") |> State.mode()
    end

    test "DEL clears Drafts to none", %{state: state} do
      state = state |> to_setting("Drafts") |> press(["D", "r", :enter, :delete])
      assert settings(state).drafts == ""
      assert screen(state) =~ "(none)"
    end
  end
end
