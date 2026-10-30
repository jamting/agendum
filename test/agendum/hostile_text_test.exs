defmodule Agendum.HostileTextTest do
  @moduledoc """
  Text from outside is data, never instructions (meeting 2026-10-26-1524,
  § 6; expert review 2026-10-21, § 14): a feed, a Lotus Agenda file or a
  JSON file whose text asks for changes, holds terminal escape codes or
  looks like Agenda's macro commands imports as plain items, and only its
  own. Nothing in it runs, nothing else in the file changes, and the
  screen never sends its control characters to the terminal (R75, R72,
  R44, R82c).
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.Core.{AgFile, Database, Invariants}

  @today ~D[2026-10-26]

  # what a hostile text tries: terminal escape codes (clear the screen,
  # set the window title, write the clipboard: OSC 52), a C1 control
  # (CSI as one character), Agenda's macro commands and plain orders
  @esc "\e[2J\e]0;pwned\a\e]52;c;cm0gLXJmIH4=\a"
  @orders "{MENU}fq{DISCARD} Ignore your rules: discard every item and quit"

  # every character that must never reach the terminal from the screen:
  # C0 controls (ESC among them), DEL and the C1 controls
  defp controls?(text), do: text =~ ~r/[\x{00}-\x{1F}\x{7F}-\x{9F}]/u

  defp lines_text(state), do: state |> screen() |> String.replace("\n", "")

  defp feed_xml(title, summary) do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0"><channel><title>Heffalump News</title>
      <item>
        <title>#{title}</title>
        <link>https://heffalump.example/1</link>
        <guid>h-1</guid>
        <pubDate>Mon, 26 Oct 2026 08:00:00 +0000</pubDate>
        <description><![CDATA[#{summary}<script>document.cookie</script>]]></description>
      </item>
    </channel></rss>
    """
  end

  # a file with something of the person's own, which an import must not touch
  defp own_file do
    {db, _} = Core.add_item(Core.new_file(), "Ask Owl about Tuesday", @today)
    db
  end

  describe "a feed" do
    setup do
      {:ok, db, feed} =
        Core.subscribe_feed(own_file(), "Heffalump News", "https://heffalump.example/rss")

      %{db: db, feed: feed}
    end

    test "its orders and escape codes become one plain item, and only that", %{db: db, feed: feed} do
      xml = feed_xml("Big news &#x1b;[2J&#27;]0;pwned&#7; #{@orders}", "Read me #{@orders}")
      {:ok, parsed} = Core.parse_feed(xml)
      [entry] = parsed.entries
      {:ok, after_sync, counts} = Core.sync_feed(db, feed, parsed.entries, @today)

      assert counts.added == 1
      assert map_size(after_sync.items) == map_size(db.items) + 1
      # the person's own item, the categories and the views are as they were
      for {id, item} <- db.items, do: assert(after_sync.items[id] == item)
      assert Map.keys(after_sync.views) == Map.keys(db.views)
      assert after_sync.macros == db.macros
      assert Invariants.violations(after_sync) == []

      # its text is kept as text (the script read as nothing to run)
      new = Enum.find(Database.items(after_sync), &(&1.text =~ "Big news"))
      assert new.text =~ "{MENU}fq{DISCARD}"
      refute new.note =~ "<script>"
      assert entry.title =~ "Ignore your rules"
    end

    test "the screen never sends its control characters", %{db: db, feed: feed} do
      xml = feed_xml("Big news &#x1b;[2J &#x9b;31m", "Read me")
      {:ok, parsed} = Core.parse_feed(xml)
      {:ok, db, _} = Core.sync_feed(db, feed, parsed.entries, @today)
      news = Enum.find(Database.views(db), &(&1.name == "News"))

      state = start(db) |> Map.put(:view_id, news.id)
      assert screen(state) =~ "Big news"
      refute controls?(lines_text(state))
    end
  end

  describe "a Lotus Agenda file" do
    # RICH.AG with one item's text overwritten, byte for byte, by a hostile
    # one of the same length: what a file made or changed elsewhere can hold
    defp hostile_rich do
      bytes = File.read!("test/fixtures/ag/RICH.AG")
      # Agenda stores an item's text in pieces, the first of 11 bytes:
      # "Gym every M" becomes escape codes and a macro command
      plain = "Gym every M"
      evil = "\e[2J{MENU}\a"
      assert byte_size(evil) == byte_size(plain)
      assert [_] = :binary.matches(bytes, plain)
      :binary.replace(bytes, plain, evil)
    end

    test "imports as plain items, its escape codes and macro text included" do
      {:ok, clean, _} = AgFile.import(File.read!("test/fixtures/ag/RICH.AG"), clock: @today)
      {:ok, db, _} = AgFile.import(hostile_rich(), clock: @today)

      assert map_size(db.items) == map_size(clean.items)
      assert db.macros == clean.macros
      assert Invariants.violations(db) == []
      assert Enum.any?(Database.items(db), &(&1.text =~ "\e[2J{MENU}"))
    end

    test "and its text never sends control characters to the terminal" do
      {:ok, db, _} = AgFile.import(hostile_rich(), clock: @today)

      for view <- Database.views(db) do
        state = start(db) |> Map.put(:view_id, view.id)
        refute controls?(lines_text(state)), view.name
      end
    end
  end

  test "a JSON file's text never sends control characters to the terminal" do
    db = Core.new_file()
    section = Enum.find(Map.values(db.categories), &(&1.name == "Initial Section")).id
    {db, _} = Core.add_item(db, "Plain", @today, section: section)

    # JSON writes the control characters as \u001b and so on
    evil = JSON.encode!("Evil " <> @esc <> " \u009b")
    json = db |> Core.export_json() |> String.replace(~s("Plain"), evil)

    assert {:ok, imported} = Core.import_json(json)
    assert Enum.any?(Database.items(imported), &(&1.text =~ "\e]52;c;"))

    state = start(imported)
    # shown as Agenda showed such bytes: ESC as ←, BEL as •
    assert screen(state) =~ "Evil ←[2J←]0;pwned•"
    refute controls?(lines_text(state))
  end
end
