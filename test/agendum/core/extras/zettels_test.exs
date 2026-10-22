defmodule Agendum.Core.Extras.ZettelsTest do
  @moduledoc "Zettel ids on items (R73, ADR 0039)."
  use ExUnit.Case, async: true

  import Agendum.Fixtures
  alias Agendum.Core
  alias Agendum.Core.{Invariants, JSONFile}

  setup do
    db = Core.new_file()
    {db, a} = Core.add_item(db, "a", today())
    {db, b} = Core.add_item(db, "b", today())
    {db, c} = Core.add_item(db, "c", today())
    %{db: db, a: a, b: b, c: c}
  end

  test "a new file gives its first Zettel id the number 1", %{db: db} do
    assert db.next_zettel == 1
    assert Enum.all?(Map.values(db.items), &(&1.zettel == nil))
  end

  test "attach_zettels gives the next ids in the order asked and counts on", ctx do
    assert {:ok, db, given} = Core.attach_zettels(ctx.db, [ctx.b, ctx.a])
    assert given == [{ctx.b, "bonalaku"}, {ctx.a, "pigavono"}]
    assert Core.zettel(db.items[ctx.b]) == "bonalaku"
    assert db.items[ctx.a].zettel == 2
    assert db.next_zettel == 3
    assert Invariants.violations(db) == []
  end

  test "an item that has an id keeps it, and is not given another", ctx do
    {:ok, db, _} = Core.attach_zettels(ctx.db, [ctx.a])
    assert {:ok, db, given} = Core.attach_zettels(db, [ctx.a, ctx.c, ctx.c])
    assert given == [{ctx.c, "pigavono"}]
    assert Core.zettel(db.items[ctx.a]) == "bonalaku"
    assert {:ok, ^db, []} = Core.attach_zettels(db, [ctx.a])
  end

  test "the reserved words are skipped", ctx do
    # 20_390 spells "makulera", the first reserved word
    db = %{ctx.db | next_zettel: 20_390}
    {:ok, db, [{_, word}]} = Core.attach_zettels(db, [ctx.a])
    assert db.items[ctx.a].zettel == 20_391
    refute word == "makulera"
    assert db.next_zettel == 20_392
  end

  test "when the ids run out the command is refused, nothing given", ctx do
    db = %{ctx.db | next_zettel: Agendum.Core.Extras.ZettelId.max()}
    assert {:error, :zettels_full} = Core.attach_zettels(db, [ctx.a, ctx.b])
  end

  test "a discarded item's id is never given again", ctx do
    {:ok, db, _} = Core.attach_zettels(ctx.db, [ctx.a])
    db = Core.discard_item(db, ctx.a)
    {:ok, _db, [{_, word}]} = Core.attach_zettels(db, [ctx.b])
    assert word == "pigavono"
  end

  test "item_by_zettel finds the item by its word, in any case", ctx do
    {:ok, db, _} = Core.attach_zettels(ctx.db, [ctx.a])
    assert Core.item_by_zettel(db, "bonalaku") == ctx.a
    assert Core.item_by_zettel(db, " BonaLaku ") == ctx.a
    assert Core.item_by_zettel(db, "pigavono") == nil
    assert Core.item_by_zettel(db, "not an id") == nil
  end

  test "it is a command, which says what it gave", ctx do
    assert {:ok, db, changes} = Core.run(ctx.db, {:attach_zettels, [ctx.a]}, today())
    assert changes.result == [{ctx.a, "bonalaku"}]
    assert changes.items.changed == [ctx.a]
    assert {:error, :no_such_item} = Core.run(db, {:attach_zettels, [999]}, today())
  end

  test "the invariants catch an id given twice, or not below the counter", ctx do
    give = fn db, id -> Agendum.Core.Database.update_item(db, id, &%{&1 | zettel: 1}) end
    db = ctx.db |> give.(ctx.a) |> give.(ctx.b)
    assert Enum.any?(Invariants.violations(db), &(&1 =~ "11. zettel ids: 1 is given to 2"))
    assert Enum.any?(Invariants.violations(db), &(&1 =~ "not below next_zettel"))
  end

  describe "JSON" do
    test "an id is written as its word and read back", ctx do
      {:ok, db, _} = Core.attach_zettels(ctx.db, [ctx.b])
      json = JSONFile.encode(db)
      assert json =~ ~s("zettel": "bonalaku")
      assert json =~ ~s("next_zettel": 2)
      assert {:ok, ^db} = JSONFile.decode(json)
    end

    test "a hand-written file without next_zettel counts on from its highest id", ctx do
      {:ok, db, _} = Core.attach_zettels(ctx.db, [ctx.a, ctx.b])
      doc = db |> JSONFile.encode() |> JSON.decode!() |> Map.delete("next_zettel")
      assert {:ok, read} = JSONFile.decode_document(doc)
      assert read.next_zettel == 3
    end

    test "a word that is not an id, or an id twice, is refused", ctx do
      doc = ctx.db |> JSONFile.encode() |> JSON.decode!()

      bad =
        update_in(doc["items"], fn [first | rest] ->
          [%{first | "zettel" => "honalaku"} | rest]
        end)

      assert {:error, message} = JSONFile.decode_document(bad)
      assert message =~ "items[0].zettel: not a Zettel id"

      twice =
        update_in(doc["items"], fn items -> Enum.map(items, &%{&1 | "zettel" => "bonalaku"}) end)

      assert {:error, "two items have the same Zettel id"} = JSONFile.decode_document(twice)
    end
  end
end
