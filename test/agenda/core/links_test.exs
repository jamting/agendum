defmodule Agenda.Core.LinksTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Agenda.Core.Links

  test "links are reachable from both sides" do
    links = Links.new() |> Links.link(:i1, :c1) |> Links.link(:i1, :c2) |> Links.link(:i2, :c1)

    assert Links.rights(links, :i1) == MapSet.new([:c1, :c2])
    assert Links.lefts(links, :c1) == MapSet.new([:i1, :i2])
    assert Links.linked?(links, :i2, :c1)
    refute Links.linked?(links, :i2, :c2)
  end

  test "drop_right removes a category from every item" do
    links = Links.new() |> Links.link(:i1, :c1) |> Links.link(:i2, :c1) |> Links.drop_right(:c1)
    assert links == Links.new()
  end

  property "both indexes always describe the same relation" do
    ops = list_of({one_of([constant(:link), constant(:unlink)]), integer(1..5), integer(1..5)})

    check all(ops <- ops) do
      links =
        Enum.reduce(ops, Links.new(), fn
          {:link, l, r}, acc -> Links.link(acc, l, r)
          {:unlink, l, r}, acc -> Links.unlink(acc, l, r)
        end)

      from_left = for {l, rs} <- links.by_left, r <- rs, into: MapSet.new(), do: {l, r}
      from_right = for {r, ls} <- links.by_right, l <- ls, into: MapSet.new(), do: {l, r}
      assert from_left == from_right
      # no empty sets are kept around
      refute Enum.any?(
               Map.values(links.by_left) ++ Map.values(links.by_right),
               &(MapSet.size(&1) == 0)
             )
    end
  end
end
