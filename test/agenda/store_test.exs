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
    assert Store.normalize_path("/tmp/work") == "/tmp/work.agendum"
    assert Store.normalize_path("/tmp/work.agd") == "/tmp/work.agd"
  end

  test "a name without extension finds a file from before the rename", %{tmp_dir: dir} do
    File.write!(Path.join(dir, "old.agenda"), "")
    assert Store.normalize_path(Path.join(dir, "old")) == Path.join(dir, "old.agenda")

    # the new extension wins when both are there
    File.write!(Path.join(dir, "old.agendum"), "")
    assert Store.normalize_path(Path.join(dir, "old")) == Path.join(dir, "old.agendum")
  end

  test "files in format version 1 are upgraded on load", %{tmp_dir: dir} do
    db = Agenda.Sample.build(~D[2026-10-08])

    # what a version 1 file held: no Database.auto_date (now When's date
    # rule), no Item.when_explicit
    v1_items = Map.new(db.items, fn {id, item} -> {id, Map.delete(item, :when_explicit)} end)
    v1 = db |> without_date_rules() |> Map.put(:items, v1_items)

    path = Path.join(dir, "old.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 1, v1}))

    assert {:ok, loaded} = Store.load(path)
    assert loaded.categories[db.special.when].date_rule.assign == :item_text
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
    v14 = db |> without_date_rules() |> Map.put(:auto_date, false)
    path = Path.join(dir, "v14.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 14, v14}))

    assert {:ok, loaded} = Store.load(path)
    never = %{Agenda.Core.DateRule.builtin(:when) | assign: :never}
    {:ok, expected} = Agenda.Core.set_date_rule(db, db.special.when, never)
    assert loaded == expected
  end

  test "files in format version 17 get date rules: When's from when_from; their dates were set by hand",
       %{tmp_dir: dir} do
    db = Agenda.Sample.build(~D[2026-10-08])
    {:ok, db, due} = Agenda.Core.add_category(db, db.main_id, "Due")
    {:ok, db} = Agenda.Core.make_date(db, due, ~D[2026-10-08])
    item = hd(db.item_order)
    db = Agenda.Core.set_date(db, item, due, ~D[2026-11-01])

    v17 =
      db
      |> without_date_rules()
      |> Map.put(:when_from, :note)
      |> Map.put(:dates, %{{item, due} => {~D[2026-11-01], nil}})

    path = Path.join(dir, "v17.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 17, v17}))

    assert {:ok, loaded} = Store.load(path)
    assert loaded.categories[db.special.when].date_rule.assign == :note_text
    assert loaded.categories[due].date_rule == %Agenda.Core.DateRule{}
    assert Agenda.Core.Database.date_explicit?(loaded, item, due)
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

  test "files in format version 20 get global date columns and Agenda's new display settings",
       %{tmp_dir: dir} do
    db = Agenda.Sample.build(~D[2026-10-08])
    old_format = Map.drop(db.date_format, [:show, :am_pm, :time_separator])

    v20_views =
      Map.new(db.views, fn {id, v} ->
        {id, %{v | columns: Enum.map(v.columns, &Map.delete(&1, :date))}}
      end)

    v20 = %{db | date_format: old_format, views: v20_views}
    path = Path.join(dir, "v20.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 20, v20}))

    assert {:ok, loaded} = Store.load(path)
    assert loaded.date_format == %Agenda.Core.DateFormat{}
    assert loaded == db
  end

  test "files in format version 21 get no calendars", %{tmp_dir: dir} do
    db = Agenda.Sample.build(~D[2026-10-08])
    path = Path.join(dir, "v21.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 21, Map.delete(db, :calendars)}))
    assert {:ok, loaded} = Store.load(path)
    assert loaded.calendars == %{}
    assert loaded == db
  end

  test "calendar subscriptions are saved", %{tmp_dir: dir} do
    db = Agenda.Core.new_file()
    {:ok, db, cal} = Agenda.Core.subscribe_calendar(db, "Work", "https://example.com/w.ics")
    event = %Agenda.Core.ICal.Event{uid: "a", summary: "Tea", start: {:date, ~D[2026-10-13]}}
    {:ok, db, _} = Agenda.Core.sync_calendar(db, cal, [event], ~N[2026-10-12 10:00:00])
    path = Path.join(dir, "cal.agenda")
    :ok = Store.save(db, path)
    assert {:ok, ^db} = Store.load(path)
  end

  test "a date column's own format is saved", %{tmp_dir: dir} do
    db = Agenda.Sample.build(~D[2026-10-08])
    view = hd(db.view_order)
    format = %Agenda.Core.DateFormat{order: :relative, show: :date}
    db = Agenda.Core.set_column_date_format(db, view, 0, format)
    path = Path.join(dir, "col.agenda")
    :ok = Store.save(db, path)
    assert {:ok, ^db} = Store.load(path)
  end

  test "newer, unknown format versions are refused", %{tmp_dir: dir} do
    path = Path.join(dir, "future.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 99, Agenda.Core.new_file()}))
    assert {:error, {:unsupported_version, 99}} = Store.load(path)
  end

  # categories as files before format 18 held them: no date rules
  defp without_date_rules(db),
    do: %{
      db
      | categories: Map.new(db.categories, fn {id, c} -> {id, Map.delete(c, :date_rule)} end)
    }
end
