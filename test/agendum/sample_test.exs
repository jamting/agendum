# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.SampleTest do
  @moduledoc "The built-in files: the patent's sample (`--demo`) and Rabbit's (`--rabbit`)."
  use ExUnit.Case, async: true

  alias Agendum.Core.{Database, ViewModel}
  alias Agendum.Sample

  test "Rabbit's file: his week in three sections, with Priority and Friends" do
    db = Sample.rabbit(~D[2026-10-12])
    [view] = Database.views(db)
    assert view.name == "Rabbit's Week"

    sections = ViewModel.build(db, view, ~D[2026-10-12])

    assert Enum.map(sections, & &1.category.name) == [
             "Garden",
             "Notices",
             "Friends and Relations"
           ]

    # six items; one that names Tigger shows under Friends too
    assert map_size(db.items) == 6
    assert sections |> Enum.flat_map(& &1.rows) |> length() == 7

    [weed | _] = hd(sections).rows
    assert weed.item.text == "Weed the carrot bed tomorrow morning"
    assert weed.item.when == ~D[2026-10-13]
    assert "High" in weed.cells
  end

  test "its dates follow the day it is opened" do
    db = Sample.rabbit(~D[2027-03-01])
    weed = db |> Database.items() |> hd()
    assert weed.when == ~D[2027-03-02]
  end
end
