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

    # what a version 1 file held: no Database.auto_date (now when_from), no Item.when_explicit
    v1_items = Map.new(db.items, fn {id, item} -> {id, Map.delete(item, :when_explicit)} end)
    v1 = db |> Map.delete(:when_from) |> Map.put(:items, v1_items)

    path = Path.join(dir, "old.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 1, v1}))

    assert {:ok, loaded} = Store.load(path)
    assert loaded.when_from == :item
    assert Enum.all?(Map.values(loaded.items), &(&1.when_explicit == false))
    assert loaded == db
  end

  test "files in format version 6 get the default date format", %{tmp_dir: dir} do
    db = Agenda.Sample.build(~D[2026-10-08])
    path = Path.join(dir, "v6.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 6, Map.delete(db, :date_format)}))

    assert {:ok, loaded} = Store.load(path)
    assert loaded.date_format == %Agenda.Core.DateFormat{}
    assert loaded == db
  end

  test "files before format version 15 that did not read dates read them never",
       %{tmp_dir: dir} do
    db = Agenda.Sample.build(~D[2026-10-08])
    v14 = db |> Map.delete(:when_from) |> Map.put(:auto_date, false)
    path = Path.join(dir, "v14.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 14, v14}))

    assert {:ok, loaded} = Store.load(path)
    assert loaded.when_from == :never
    assert loaded == %{db | when_from: :never}
  end

  test "files before format version 17 get no dates of user date categories",
       %{tmp_dir: dir} do
    db = Agenda.Sample.build(~D[2026-10-08])
    path = Path.join(dir, "v16.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 16, Map.delete(db, :dates)}))

    assert {:ok, loaded} = Store.load(path)
    assert loaded.dates == %{}
    assert loaded == db
  end

  test "files in format version 13 get the default date settings", %{tmp_dir: dir} do
    db = Agenda.Sample.build(~D[2026-10-08])
    path = Path.join(dir, "v13.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 13, Map.delete(db, :date_settings)}))

    assert {:ok, loaded} = Store.load(path)
    assert loaded.date_settings == %Agenda.Core.DateSettings{}
    assert loaded == db
  end

  test "files in format version 7 get no numbers and default column formats",
       %{tmp_dir: dir} do
    db = Agenda.Sample.build(~D[2026-10-08])

    v7_views =
      Map.new(db.views, fn {id, v} ->
        {id, %{v | columns: Enum.map(v.columns, &Map.delete(&1, :number))}}
      end)

    v7 = db |> Map.delete(:numbers) |> Map.put(:views, v7_views)
    path = Path.join(dir, "v7.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 7, v7}))

    assert {:ok, loaded} = Store.load(path)
    assert loaded.numbers == %{}
    assert loaded == db
  end

  test "files in format version 8 get items without a recurrence", %{tmp_dir: dir} do
    db = Agenda.Sample.build(~D[2026-10-08])
    v8_items = Map.new(db.items, fn {id, item} -> {id, Map.delete(item, :recurrence)} end)
    path = Path.join(dir, "v8.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 8, %{db | items: v8_items}}))

    assert {:ok, loaded} = Store.load(path)
    assert Enum.all?(Map.values(loaded.items), &(&1.recurrence == nil))
    assert loaded == db
  end

  test "files in format version 9 get no dependencies", %{tmp_dir: dir} do
    db = Agenda.Sample.build(~D[2026-10-08])
    v9_views = Map.new(db.views, fn {id, v} -> {id, Map.delete(v, :hide_dependent)} end)
    v9 = db |> Map.delete(:dependencies) |> Map.put(:views, v9_views)
    path = Path.join(dir, "v9.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 9, v9}))

    assert {:ok, loaded} = Store.load(path)
    assert loaded.dependencies == Agenda.Core.Links.new()
    assert loaded == db
  end

  test "files in format version 10 get categories without text conditions", %{tmp_dir: dir} do
    db = Agenda.Sample.build(~D[2026-10-08])
    v10_cats = Map.new(db.categories, fn {id, c} -> {id, Map.delete(c, :also_match)} end)
    path = Path.join(dir, "v10.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 10, %{db | categories: v10_cats}}))

    assert {:ok, loaded} = Store.load(path)
    assert Enum.all?(Map.values(loaded.categories), &(&1.also_match == ""))
    assert loaded == db
  end

  test "files in format version 11 get categories without actions", %{tmp_dir: dir} do
    db = Agenda.Sample.build(~D[2026-10-08])

    v11_cats =
      Map.new(db.categories, fn {id, c} ->
        {id, c |> Map.delete(:actions) |> Map.delete(:special)}
      end)

    path = Path.join(dir, "v11.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 11, %{db | categories: v11_cats}}))

    assert {:ok, loaded} = Store.load(path)
    assert Enum.all?(Map.values(loaded.categories), &(&1.actions == [] and &1.special == nil))
    assert loaded == db
  end

  test "files in format version 12 never ask to confirm assignments", %{tmp_dir: dir} do
    db = Agenda.Sample.build(~D[2026-10-08])
    v12 = db |> Map.delete(:confirm_assignments) |> Map.delete(:suggestions)
    path = Path.join(dir, "v12.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 12, v12}))

    assert {:ok, loaded} = Store.load(path)
    assert loaded.confirm_assignments == :never and loaded.suggestions == %{}
    assert loaded == db
  end

  test "recurrence rules are saved", %{tmp_dir: dir} do
    {db, id} = Agenda.Core.add_item(Agenda.Core.new_file(), "Gym every Monday", ~D[2026-10-08])
    path = Path.join(dir, "recur.agenda")
    :ok = Store.save(db, path)
    assert {:ok, loaded} = Store.load(path)
    assert loaded.items[id].recurrence == db.items[id].recurrence
  end

  test "the date format is saved", %{tmp_dir: dir} do
    format = %Agenda.Core.DateFormat{order: :ddmmyy, separator: ".", clock: 12}
    db = Agenda.Core.set_date_format(Agenda.Core.new_file(), format)
    path = Path.join(dir, "fmt.agenda")
    :ok = Store.save(db, path)
    assert {:ok, %{date_format: ^format}} = Store.load(path)
  end

  test "newer, unknown format versions are refused", %{tmp_dir: dir} do
    path = Path.join(dir, "future.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 99, Agenda.Core.new_file()}))
    assert {:error, {:unsupported_version, 99}} = Store.load(path)
  end
end
