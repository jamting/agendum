defmodule Agendum.ThoughtsTest do
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.Thoughts

  @today ~D[2026-10-22]

  defp id(db, name) do
    [id] = Database.find_categories(db, name)
    id
  end

  # a thought typed into the Thoughts section, or into Next meeting
  defp think(db, text, section, note \\ "") do
    {db, item} = Core.add_item(db, text, @today, section: id(db, section))
    {Core.set_note(db, item, note, @today), item}
  end

  describe "new_file/0" do
    test "has Next meeting under Thoughts, and a Thoughts view with both, Next meeting first" do
      db = Thoughts.new_file()
      thoughts = id(db, "Thoughts")
      next = id(db, "Next meeting")

      assert db.categories[next].parent_id == thoughts

      [view] = Database.views(db)
      assert view.name == "Thoughts"
      assert Enum.map(view.sections, & &1.category_id) == [next, thoughts]
      # a thought for the meeting shows once, under Next meeting; handled
      # (done) thoughts drop out of sight
      assert view.hide_inherited
      assert view.hide_done
    end

    test "the categories do not catch items by the words in their text" do
      db = Thoughts.new_file()
      {db, item} = Core.add_item(db, "thoughts on the next meeting", @today)
      refute Database.member?(db, item, id(db, "Thoughts"))
    end
  end

  describe "read/1" do
    test "splits the open thoughts into those for the next meeting and the rest" do
      db = Thoughts.new_file()
      {db, _} = think(db, "Menus by DOSBox", "Next meeting", "capture them all")
      {db, _} = think(db, "A trash for DEL", "Thoughts")

      assert {:ok, %{next_meeting: [next], others: [other]}} = Thoughts.read(db)
      assert next == %{text: "Menus by DOSBox", note: "capture them all", entry: @today}
      assert other.text == "A trash for DEL"
    end

    test "leaves out done thoughts: the meeting handled them" do
      db = Thoughts.new_file()
      {db, item} = think(db, "Handled", "Next meeting")
      db = Core.mark_done(db, item, @today)

      assert {:ok, %{next_meeting: [], others: []}} = Thoughts.read(db)
    end

    test "a file without a Thoughts category is an error" do
      assert {:error, :no_thoughts_category} = Thoughts.read(Core.new_file())
    end
  end

  describe "to_markdown/2" do
    setup do
      db = Thoughts.new_file()
      {db, _} = think(db, "Menus by DOSBox", "Next meeting", "capture them all\nand compare")
      {db, _} = think(db, "A trash for DEL", "Thoughts")
      {:ok, thoughts} = Thoughts.read(db)
      %{thoughts: thoughts}
    end

    test "lists both groups, notes indented under their thought", %{thoughts: thoughts} do
      assert Thoughts.to_markdown(thoughts) == """
             ## For the next meeting

             - Menus by DOSBox (2026-10-22)
               capture them all
               and compare

             ## Other thoughts

             - A trash for DEL (2026-10-22)
             """
    end

    test "only the next meeting's, when asked", %{thoughts: thoughts} do
      refute Thoughts.to_markdown(thoughts, next_meeting: true) =~ "A trash"
    end

    test "says so when a group is empty" do
      empty = %{next_meeting: [], others: []}
      assert Thoughts.to_markdown(empty, next_meeting: true) =~ "(none)"
    end
  end
end
