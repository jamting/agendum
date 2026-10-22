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

  describe "import_docs/3 (meeting 2026-10-22-2, § 5)" do
    @docs [
      %{
        path: "docs/meetings/2026-10-21/protokoll.md",
        text: "# Minutes of the panel meeting, 2026-10-21\n\nOwl opened the meeting."
      },
      %{
        path: "docs/adr/0044-one-repository.md",
        text:
          "# ADR 0044 — One repository\n\n**Status:** accepted · 2026-10-21 (meeting)\n\nThe extras on a shelf."
      },
      %{path: "docs/ROADMAP.md", text: "# Roadmap\n\n- [ ] Next thing"},
      %{
        path: "docs/summaries/2026-10-22-2311.md",
        text: "# Session summary, 2026-10-22 23:11\n\nA big evening."
      }
    ]

    defp items_under(db, name) do
      db |> Database.items_in(id(db, name)) |> Enum.map(& &1.text) |> Enum.sort()
    end

    test "one item per document under Disposable ▸ its kind, the title as text" do
      {:ok, db, 4} = Thoughts.import_docs(Thoughts.new_file(), @docs, @today)

      assert items_under(db, "Meetings") == ["Minutes of the panel meeting, 2026-10-21"]
      assert items_under(db, "ADRs") == ["ADR 0044 — One repository"]
      assert items_under(db, "Roadmap") == ["Roadmap"]
      assert items_under(db, "Summaries") == ["Session summary, 2026-10-22 23:11"]
      assert length(items_under(db, "Disposable")) == 4

      for kind <- ~w(Meetings ADRs Roadmap Summaries),
          do: assert(db.categories[id(db, kind)].parent_id == id(db, "Disposable"))
    end

    test "the whole document is the note; its own date the Entry date; no When from the title" do
      {:ok, db, _} = Thoughts.import_docs(Thoughts.new_file(), @docs, @today)
      by_text = Map.new(Database.items(db), &{&1.text, &1})

      adr = by_text["ADR 0044 — One repository"]
      assert adr.note =~ "The extras on a shelf."
      assert adr.entry == ~D[2026-10-21]
      assert by_text["Minutes of the panel meeting, 2026-10-21"].entry == ~D[2026-10-21]
      assert by_text["Session summary, 2026-10-22 23:11"].entry == ~D[2026-10-22]
      assert by_text["Roadmap"].entry == @today

      when_id = db.special.when
      refute Enum.any?(Database.items(db), &Database.member?(db, &1.id, when_id))
    end

    test "a Documents view: a section per kind, newest first" do
      {:ok, db, _} = Thoughts.import_docs(Thoughts.new_file(), @docs, @today)
      view = Enum.find(Database.views(db), &(&1.name == "Documents"))

      assert Enum.map(view.sections, &db.categories[&1.category_id].name) ==
               ~w(Meetings ADRs Roadmap Summaries)

      assert [%{on: {:category, entry}, order: :desc}] = view.sort
      assert entry == db.special.entry
    end

    test "importing again replaces the Disposable items and leaves every other item alone" do
      {db, thought} = think(Thoughts.new_file(), "Ask Owl about the roadmap", "Next meeting")
      {:ok, db, 4} = Thoughts.import_docs(db, @docs, @today)
      {:ok, again, 3} = Thoughts.import_docs(db, Enum.drop(@docs, 1), @today)

      assert length(items_under(again, "Disposable")) == 3
      refute "Minutes of the panel meeting, 2026-10-21" in items_under(again, "Disposable")
      assert again.items[thought] == db.items[thought]
      assert length(Database.views(again)) == length(Database.views(db))
      assert items_under(again, "Next meeting") == ["Ask Owl about the roadmap"]
    end

    test "the kinds do not catch the person's items by the words in them" do
      {:ok, db, _} = Thoughts.import_docs(Thoughts.new_file(), @docs, @today)
      {db, item} = think(db, "summaries of meetings and the roadmap", "Thoughts")
      refute Database.member?(db, item, id(db, "Disposable"))
    end
  end
end
