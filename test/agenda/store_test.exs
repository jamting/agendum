defmodule Agenda.StoreTest do
  use ExUnit.Case, async: true

  alias Agenda.Store

  @moduletag :tmp_dir

  test "saves and loads a database", %{tmp_dir: dir} do
    db = Agenda.Sample.build(~D[2026-10-08])
    path = Path.join(dir, "sample.agenda")

    assert :ok = Store.save(db, path)
    assert {:ok, ^db} = Store.load(path)
  end

  test "rejects files that are not Agenda files", %{tmp_dir: dir} do
    path = Path.join(dir, "junk.agenda")
    File.write!(path, "not a term")
    assert {:error, :not_an_agenda_file} = Store.load(path)

    File.write!(path, :erlang.term_to_binary(:other))
    assert {:error, :not_an_agenda_file} = Store.load(path)
  end

  test "normalize_path adds the extension" do
    assert Store.normalize_path("/tmp/work") == "/tmp/work.agenda"
    assert Store.normalize_path("/tmp/work.agd") == "/tmp/work.agd"
  end

  test "files in format version 1 are upgraded on load", %{tmp_dir: dir} do
    db = Agenda.Sample.build(~D[2026-10-08])

    # what a version 1 file held: no Database.auto_date, no Item.when_explicit
    v1_items = Map.new(db.items, fn {id, item} -> {id, Map.delete(item, :when_explicit)} end)
    v1 = db |> Map.delete(:auto_date) |> Map.put(:items, v1_items)

    path = Path.join(dir, "old.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 1, v1}))

    assert {:ok, loaded} = Store.load(path)
    assert loaded.auto_date == true
    assert Enum.all?(Map.values(loaded.items), &(&1.when_explicit == false))
    assert loaded == db
  end

  test "newer, unknown format versions are refused", %{tmp_dir: dir} do
    path = Path.join(dir, "future.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 99, Agenda.Core.new_file()}))
    assert {:error, {:unsupported_version, 99}} = Store.load(path)
  end
end
