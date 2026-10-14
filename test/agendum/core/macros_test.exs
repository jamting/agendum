defmodule Agendum.Core.MacrosTest do
  @moduledoc "Macros kept in the file (R50; Working with Macros, chapter 1)."
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.{Database, Macro}

  setup do
    db = Core.new_file()
    {:ok, db, weed} = Core.add_macro(db, "Weed the garden")
    %{db: db, weed: weed}
  end

  defp names(db), do: db |> Database.macros() |> Enum.map(& &1.name)

  test "a new macro has a name, no keys yet, and runs in views, notes and the manager",
       %{db: db, weed: weed} do
    assert %Macro{id: ^weed, name: "Weed the garden", keys: "", key: nil} = db.macros[weed]
    assert db.macros[weed].run_from == %{view: true, note: true, catmgr: true, elsewhere: false}
    assert names(db) == ["Weed the garden"]
  end

  test "names are needed, and unique regardless of case", %{db: db} do
    assert Core.add_macro(db, "  ") == {:error, :empty_name}
    assert Core.add_macro(db, "weed THE garden") == {:error, :name_taken}
    assert Core.add_macro(db, String.duplicate("x", 36)) == {:error, :name_too_long}
  end

  test "keys, names and where it runs can change", %{db: db, weed: weed} do
    db = Core.set_macro_keys(db, weed, "{F10}vc{ENTER}")
    assert db.macros[weed].keys == "{F10}vc{ENTER}"

    assert {:ok, db} = Core.rename_macro(db, weed, "Weed")
    assert db.macros[weed].name == "Weed"
    {:ok, db, other} = Core.add_macro(db, "Water")
    assert Core.rename_macro(db, other, "weed") == {:error, :name_taken}

    db = Core.set_macro_run_from(db, weed, :elsewhere, true)
    assert db.macros[weed].run_from.elsewhere
  end

  test "a key belongs to one macro at a time", %{db: db, weed: weed} do
    {:ok, db, water} = Core.add_macro(db, "Water")
    db = Core.attach_macro(db, weed, "{ShfF4}")
    assert db.macros[weed].key == "{ShfF4}"

    db = Core.attach_macro(db, water, "{ShfF4}")
    assert db.macros[water].key == "{ShfF4}"
    assert db.macros[weed].key == nil

    db = Core.attach_macro(db, water, nil)
    assert db.macros[water].key == nil
  end

  test "macros keep an order: moved, sorted, deleted", %{db: db, weed: weed} do
    {:ok, db, _} = Core.add_macro(db, "Count lettuces")
    {:ok, db, _} = Core.add_macro(db, "Animals")
    assert names(db) == ["Weed the garden", "Count lettuces", "Animals"]

    db = Core.move_macro(db, weed, 2)
    assert names(db) == ["Count lettuces", "Animals", "Weed the garden"]

    db = Core.sort_macros(db)
    assert names(db) == ["Animals", "Count lettuces", "Weed the garden"]

    db = Core.delete_macro(db, weed)
    assert names(db) == ["Animals", "Count lettuces"]
    refute Map.has_key?(db.macros, weed)
  end

  test "a macro is found by name, regardless of case", %{db: db, weed: weed} do
    assert Database.find_macro(db, "WEED THE GARDEN").id == weed
    assert Database.find_macro(db, "nothing") == nil
  end
end
