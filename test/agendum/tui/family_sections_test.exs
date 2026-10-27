defmodule Agendum.TUI.FamilySectionsTest do
  @moduledoc """
  Inserting a category in the category manager, in a family whose other
  members are all sections of a view, adds its section to that view
  (User's Guide 16-11, R42), in the same undo step.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.TUI.{CategoryScreens, History}

  setup do
    db = Core.new_file()
    {:ok, db, people} = Core.add_category(db, db.main_id, "People")
    {:ok, db, meg} = Core.add_category(db, people, "Meg")
    {:ok, db, tom} = Core.add_category(db, people, "Tom")
    {db, view} = Core.add_view(db, "By Person", [meg, tom])
    db = Core.move_view(db, view, 0)
    %{state: start(db, width: 80, height: 25), view: view, tom: tom}
  end

  test "ALT-D on Tom adds Sharon, and Sharon's section after Tom's", ctx do
    state =
      ctx.state
      |> press({:f, 9})
      |> CategoryScreens.move_cursor_to(ctx.tom)
      |> press([{:alt, "d"}, "Sharon", :enter, {:f, 9}])

    names = Enum.map(state.db.views[ctx.view].sections, &state.db.categories[&1.category_id].name)
    assert names == ["Meg", "Tom", "Sharon"]
    assert screen(state) =~ "Sharon"

    # one undo takes back the category and its section together
    undone = History.undo(state)
    assert length(undone.db.views[ctx.view].sections) == 2
    refute Enum.any?(Map.values(undone.db.categories), &(&1.name == "Sharon"))
  end
end
