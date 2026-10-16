defmodule Agendum.Core.ZettelLinksTest do
  @moduledoc "Links between zettels (R73b)."
  use ExUnit.Case, async: true

  import Agendum.Fixtures
  alias Agendum.Core
  alias Agendum.Core.ZettelLinks

  # "Owl's birthday" is bonalaku (1), "The party" pigavono (2); "Notes"
  # has no id
  setup do
    db = Core.new_file()
    {db, owl} = Core.add_item(db, "Owl's birthday", today())
    {db, party} = Core.add_item(db, "The party", today())
    {db, notes} = Core.add_item(db, "Notes", today())
    {:ok, db, _} = Core.attach_zettels(db, [owl, party])
    %{db: db, owl: owl, party: party, notes: notes}
  end

  defp edit(db, id, text), do: Core.edit_item(db, id, text, today())

  test "[[id]] is a link, broken when no item has the id", %{db: db, owl: owl} do
    used = Core.zettels(db)

    assert [%{at: 4, length: 12, word: "bonalaku", target: ^owl, bracketed: true}] =
             ZettelLinks.scan("See [[bonalaku]].", used)

    assert [%{target: nil, word: "kitolido"}] = ZettelLinks.scan("[[kitolido]]", used)
    # not an id at all: plain text
    assert ZettelLinks.scan("[[honalaku]] [[short]]", used) == []
  end

  test "a bare word is a link only when an item has that id", %{db: db, party: party} do
    used = Core.zettels(db)

    assert [%{word: "PigaVono", target: ^party, bracketed: false}] =
             ZettelLinks.scan("about PigaVono, and kitolido", used)

    # part of a longer word is not an id
    assert ZettelLinks.scan("pigavonos xpigavono", used) == []
  end

  test "positions count characters, not bytes", %{db: db} do
    assert [%{at: 5}] = ZettelLinks.scan("Möte bonalaku", Core.zettels(db))
  end

  test "targets: text then note, each once, broken and itself left out", ctx do
    db = edit(ctx.db, ctx.notes, "pigavono and [[bonalaku]] and [[kitolido]]")
    db = Core.set_note(db, ctx.notes, "again bonalaku", today())
    assert Core.link_targets(db, ctx.notes) == [ctx.party, ctx.owl]

    db = edit(db, ctx.owl, "Owl's birthday, bonalaku")
    assert Core.link_targets(db, ctx.owl) == []
  end

  test "linked_from: the items that link to an item", ctx do
    db = edit(ctx.db, ctx.notes, "for the party: pigavono")
    db = Core.set_note(db, ctx.owl, "[[pigavono]]", today())
    assert Core.linked_from(db, ctx.party) == [ctx.owl, ctx.notes]
    assert Core.linked_from(db, ctx.notes) == []
  end

  test "text matching ignores bracketed links" do
    db = Core.new_file()
    db = with_categories(db, [{"Bonalaku", [], []}])
    {db, item} = Core.add_item(db, "Call [[bonalaku]]", today())
    refute Agendum.Core.Database.member?(db, item, cat(db, "Bonalaku"))
    assert ZettelLinks.strip("a [[bonalaku]] b") == "a              b"
  end
end
