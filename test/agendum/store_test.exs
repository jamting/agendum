defmodule Agendum.StoreTest do
  use ExUnit.Case, async: true

  alias Agendum.Store

  @moduletag :tmp_dir

  test "saves and loads a database", %{tmp_dir: dir} do
    db = Agendum.Sample.build(~D[2026-10-08])
    path = Path.join(dir, "sample.agenda")

    assert :ok = Store.save(db, path)
    assert {:ok, ^db} = Store.load(path)
  end

  # The modules were Agenda.* before the code was renamed (ADR 0019); a
  # file keeps the struct names it was saved with.
  test "a file saved before the modules were renamed still loads", %{tmp_dir: dir} do
    db = Agendum.Sample.build(~D[2026-10-08])
    path = Path.join(dir, "old.agendum")
    old = old_names(db)
    assert %{__struct__: :"Elixir.Agenda.Core.Database"} = old

    File.write!(path, :erlang.term_to_binary({:agenda, Store.format_version(), old}))
    assert {:ok, ^db} = Store.load(path)
  end

  # every Agendum.* atom in a term as the Agenda.* it was before
  defp old_names(term) when is_atom(term) do
    case Atom.to_string(term) do
      # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
      "Elixir.Agendum." <> rest -> String.to_atom("Elixir.Agenda." <> rest)
      _ -> term
    end
  end

  defp old_names(term) when is_map(term),
    do: term |> Map.to_list() |> Map.new(fn {k, v} -> {old_names(k), old_names(v)} end)

  defp old_names(term) when is_list(term), do: Enum.map(term, &old_names/1)

  defp old_names(term) when is_tuple(term),
    do: term |> Tuple.to_list() |> old_names() |> List.to_tuple()

  defp old_names(term), do: term

  # The extras' data are stored fields of the file (ADR 0043, ADR 0044):
  # whatever the program shows, saving keeps them as they were. Written
  # before the extras moved to a shelf of their own, to guard the move; the
  # Extras preference (off by default) will run the same save with it off.
  test "a saved file keeps the extras' fields: Zettel ids, blog, feeds, calendars",
       %{tmp_dir: dir} do
    db = Agendum.Starters.Golden.build()
    path = Path.join(dir, "extras.agendum")

    # the golden file sets every one of them away from its default
    assert db.next_zettel > 1
    assert Enum.any?(Map.values(db.items), & &1.zettel)
    assert db.blog != %Agendum.Core.Database{}.blog
    assert map_size(db.feeds) > 0
    assert map_size(db.calendars) > 0

    assert :ok = Store.save(db, path)
    assert {:ok, loaded} = Store.load(path)

    assert loaded.next_zettel == db.next_zettel

    assert Map.new(loaded.items, fn {id, i} -> {id, i.zettel} end) ==
             Map.new(db.items, fn {id, i} -> {id, i.zettel} end)

    assert loaded.blog == db.blog
    assert loaded.feeds == db.feeds
    assert loaded.calendars == db.calendars
    assert loaded == db
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
    db = Agendum.Sample.build(~D[2026-10-08])

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
    db = Agendum.Sample.build(~D[2026-10-08])
    path = Path.join(dir, "v6.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 6, Map.delete(db, :date_format)}))

    assert {:ok, loaded} = Store.load(path)
    assert loaded.date_format == %Agendum.Core.DateFormat{}
    assert loaded == db
  end

  test "files before format version 15 that did not read dates read them never",
       %{tmp_dir: dir} do
    db = Agendum.Sample.build(~D[2026-10-08])
    v14 = db |> without_date_rules() |> Map.put(:auto_date, false)
    path = Path.join(dir, "v14.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 14, v14}))

    assert {:ok, loaded} = Store.load(path)
    never = %{Agendum.Core.DateRule.builtin(:when) | assign: :never}
    {:ok, expected} = Agendum.Core.set_date_rule(db, db.special.when, never)
    assert loaded == expected
  end

  test "files in format version 17 get date rules: When's from when_from; their dates were set by hand",
       %{tmp_dir: dir} do
    db = Agendum.Sample.build(~D[2026-10-08])
    {:ok, db, due} = Agendum.Core.add_category(db, db.main_id, "Due")
    {:ok, db} = Agendum.Core.make_date(db, due, ~D[2026-10-08])
    item = hd(db.item_order)
    db = Agendum.Core.set_date(db, item, due, ~D[2026-11-01])

    v17 =
      db
      |> without_date_rules()
      |> Map.put(:when_from, :note)
      |> Map.put(:dates, %{{item, due} => {~D[2026-11-01], nil}})

    path = Path.join(dir, "v17.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 17, v17}))

    assert {:ok, loaded} = Store.load(path)
    assert loaded.categories[db.special.when].date_rule.assign == :note_text
    assert loaded.categories[due].date_rule == %Agendum.Core.DateRule{}
    assert Agendum.Core.Database.date_explicit?(loaded, item, due)
  end

  test "files before format version 17 get no dates of user date categories",
       %{tmp_dir: dir} do
    db = Agendum.Sample.build(~D[2026-10-08])
    path = Path.join(dir, "v16.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 16, Map.delete(db, :dates)}))

    assert {:ok, loaded} = Store.load(path)
    assert loaded.dates == %{}
    assert loaded == db
  end

  test "files in format version 13 get the default date settings", %{tmp_dir: dir} do
    db = Agendum.Sample.build(~D[2026-10-08])
    path = Path.join(dir, "v13.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 13, Map.delete(db, :date_settings)}))

    assert {:ok, loaded} = Store.load(path)
    assert loaded.date_settings == %Agendum.Core.DateSettings{}
    assert loaded == db
  end

  test "files in format version 7 get no numbers and default column formats",
       %{tmp_dir: dir} do
    db = Agendum.Sample.build(~D[2026-10-08])

    v7_views = old_columns(db.views, &Map.delete(&1, :number))

    v7 = db |> Map.delete(:numbers) |> Map.put(:views, v7_views)
    path = Path.join(dir, "v7.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 7, v7}))

    assert {:ok, loaded} = Store.load(path)
    assert loaded.numbers == %{}
    assert loaded == db
  end

  test "files in format version 8 get items without a recurrence", %{tmp_dir: dir} do
    db = Agendum.Sample.build(~D[2026-10-08])
    v8_items = Map.new(db.items, fn {id, item} -> {id, Map.delete(item, :recurrence)} end)
    path = Path.join(dir, "v8.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 8, %{db | items: v8_items}}))

    assert {:ok, loaded} = Store.load(path)
    assert Enum.all?(Map.values(loaded.items), &(&1.recurrence == nil))
    assert loaded == db
  end

  test "files in format version 9 get no dependencies", %{tmp_dir: dir} do
    db = Agendum.Sample.build(~D[2026-10-08])
    v9_views = Map.new(db.views, fn {id, v} -> {id, Map.delete(v, :hide_dependent)} end)
    v9 = db |> Map.delete(:dependencies) |> Map.put(:views, v9_views)
    path = Path.join(dir, "v9.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 9, v9}))

    assert {:ok, loaded} = Store.load(path)
    assert loaded.dependencies == Agendum.Core.Links.new()
    assert loaded == db
  end

  test "files in format version 10 get categories without text conditions", %{tmp_dir: dir} do
    db = Agendum.Sample.build(~D[2026-10-08])
    v10_cats = Map.new(db.categories, fn {id, c} -> {id, Map.delete(c, :also_match)} end)
    path = Path.join(dir, "v10.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 10, %{db | categories: v10_cats}}))

    assert {:ok, loaded} = Store.load(path)
    assert Enum.all?(Map.values(loaded.categories), &(&1.also_match == ""))
    assert loaded == db
  end

  test "files in format version 11 get categories without actions", %{tmp_dir: dir} do
    db = Agendum.Sample.build(~D[2026-10-08])

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
    db = Agendum.Sample.build(~D[2026-10-08])
    v12 = db |> Map.delete(:confirm_assignments) |> Map.delete(:suggestions)
    path = Path.join(dir, "v12.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 12, v12}))

    assert {:ok, loaded} = Store.load(path)
    assert loaded.confirm_assignments == :never and loaded.suggestions == %{}
    assert loaded == db
  end

  test "recurrence rules are saved", %{tmp_dir: dir} do
    {db, id} = Agendum.Core.add_item(Agendum.Core.new_file(), "Gym every Monday", ~D[2026-10-08])
    path = Path.join(dir, "recur.agenda")
    :ok = Store.save(db, path)
    assert {:ok, loaded} = Store.load(path)
    assert loaded.items[id].recurrence == db.items[id].recurrence
  end

  test "the date format is saved", %{tmp_dir: dir} do
    format = %Agendum.Core.DateFormat{order: :ddmmyy, separator: ".", clock: 12}
    db = Agendum.Core.set_date_format(Agendum.Core.new_file(), format)
    path = Path.join(dir, "fmt.agenda")
    :ok = Store.save(db, path)
    assert {:ok, %{date_format: ^format}} = Store.load(path)
  end

  test "files in format version 20 get global date columns and Agenda's new display settings",
       %{tmp_dir: dir} do
    db = Agendum.Sample.build(~D[2026-10-08])
    old_format = Map.drop(db.date_format, [:show, :am_pm, :time_separator])

    v20_views = old_columns(db.views, &Map.delete(&1, :date))

    v20 = %{db | date_format: old_format, views: v20_views}
    path = Path.join(dir, "v20.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 20, v20}))

    assert {:ok, loaded} = Store.load(path)
    assert loaded.date_format == %Agendum.Core.DateFormat{}
    assert loaded == db
  end

  test "files in format version 24 get their columns in every section, linked",
       %{tmp_dir: dir} do
    db = Agendum.Sample.build(~D[2026-10-08])
    path = Path.join(dir, "v24.agenda")
    old = %{db | views: old_columns(db.views, & &1)}
    File.write!(path, :erlang.term_to_binary({:agenda, 24, old}))
    assert {:ok, loaded} = Store.load(path)
    assert loaded == db
  end

  test "files in format version 26 get a link for each linked column", %{tmp_dir: dir} do
    alias Agendum.Core.View
    db = Agendum.Sample.build(~D[2026-10-08])
    path = Path.join(dir, "v26.agenda")
    # as 26 stored them: `linked: true` rather than a link
    old =
      update_in(db.views, fn views ->
        Map.new(views, fn {id, v} ->
          sections =
            Enum.map(v.sections, fn s ->
              columns =
                Enum.map(
                  s.columns,
                  &(&1 |> Map.put(:linked, &1.link != nil) |> Map.delete(:link))
                )

              %{s | columns: columns}
            end)

          {id, %{v | sections: sections}}
        end)
      end)

    File.write!(path, :erlang.term_to_binary({:agenda, 26, old}))
    assert {:ok, loaded} = Store.load(path)

    # the same columns, linked the same way (the numbers may differ)
    same = fn db ->
      for {_, v} <- db.views, View.columns(v, 0) != [] do
        Enum.map(v.sections, fn s -> Enum.map(s.columns, &{&1.category_id, &1.link != nil}) end)
      end
    end

    assert same.(loaded) == same.(db)

    for {id, v} <- loaded.views, s <- v.sections, c <- s.columns do
      refute Map.has_key?(c, :linked), "view #{id}"
    end
  end

  test "files in format version 21 get no calendars", %{tmp_dir: dir} do
    db = Agendum.Sample.build(~D[2026-10-08])
    path = Path.join(dir, "v21.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 21, Map.delete(db, :calendars)}))
    assert {:ok, loaded} = Store.load(path)
    assert loaded.calendars == %{}
    assert loaded == db
  end

  test "calendar subscriptions are saved", %{tmp_dir: dir} do
    db = Agendum.Core.new_file()
    {:ok, db, cal} = Agendum.Core.subscribe_calendar(db, "Work", "https://example.com/w.ics")
    event = %Agendum.Core.ICal.Event{uid: "a", summary: "Tea", start: {:date, ~D[2026-10-13]}}
    {:ok, db, _} = Agendum.Core.sync_calendar(db, cal, [event], ~N[2026-10-12 10:00:00])
    path = Path.join(dir, "cal.agenda")
    :ok = Store.save(db, path)
    assert {:ok, ^db} = Store.load(path)
  end

  test "a date column's own format is saved", %{tmp_dir: dir} do
    db = Agendum.Sample.build(~D[2026-10-08])
    view = hd(db.view_order)
    format = %Agendum.Core.DateFormat{order: :relative, show: :date}
    db = Agendum.Core.set_column_date_format(db, view, {0, 0}, format)
    path = Path.join(dir, "col.agenda")
    :ok = Store.save(db, path)
    assert {:ok, ^db} = Store.load(path)
  end

  test "files in format version 22 get standard views only", %{tmp_dir: dir} do
    db = Agendum.Sample.build(~D[2026-10-08])
    views = Map.new(db.views, fn {id, v} -> {id, Map.delete(v, :datebook)} end)
    path = Path.join(dir, "v22.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 22, %{db | views: views}}))
    assert {:ok, ^db} = Store.load(path)
  end

  test "a datebook view is saved", %{tmp_dir: dir} do
    db = Agendum.Core.new_file()
    datebook = %Agendum.Core.Datebook{period: :day, interval: 15, base: "tomorrow"}
    {:ok, db, _} = Agendum.Core.add_datebook_view(db, "Tomorrow", datebook)
    path = Path.join(dir, "datebook.agenda")
    :ok = Store.save(db, path)
    assert {:ok, ^db} = Store.load(path)
  end

  test "files in format version 23 get no macros", %{tmp_dir: dir} do
    db = Agendum.Sample.build(~D[2026-10-08])
    old = db |> Map.delete(:macros) |> Map.delete(:macro_order)
    path = Path.join(dir, "v23.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 23, old}))
    assert {:ok, ^db} = Store.load(path)
  end

  test "macros are saved", %{tmp_dir: dir} do
    db = Agendum.Core.new_file()
    {:ok, db, m} = Agendum.Core.add_macro(db, "Weed")
    db = Agendum.Core.set_macro_keys(db, m, "{F10}vc{ENTER}")
    path = Path.join(dir, "macros.agenda")
    :ok = Store.save(db, path)
    assert {:ok, ^db} = Store.load(path)
  end

  test "a folder is listed for the Select File box: folders, then files, hidden ones left out",
       %{tmp_dir: dir} do
    File.mkdir_p!(Path.join(dir, "Garden"))
    File.write!(Path.join(dir, "rabbit.agendum"), "")
    File.write!(Path.join(dir, "notes.txt"), "")
    File.write!(Path.join(dir, ".hidden"), "")

    assert {:ok, entries} = Store.list_dir(dir)

    assert Enum.map(entries, &{&1.name, &1.dir?}) ==
             [{"Garden", true}, {"notes.txt", false}, {"rabbit.agendum", false}]

    assert %NaiveDateTime{} = hd(entries).modified
    assert {:error, _} = Store.list_dir(Path.join(dir, "nowhere"))
  end

  test "newer, unknown format versions are refused", %{tmp_dir: dir} do
    path = Path.join(dir, "future.agenda")
    File.write!(path, :erlang.term_to_binary({:agenda, 99, Agendum.Core.new_file()}))
    assert {:error, {:unsupported_version, 99}} = Store.load(path)
  end

  # categories as files before format 18 held them: no date rules
  defp without_date_rules(db),
    do: %{
      db
      | categories: Map.new(db.categories, fn {id, c} -> {id, Map.delete(c, :date_rule)} end)
    }

  # Views as files before format 25 stored them (R55): the columns, every
  # section's, in the view, without `linked`, and changed by `fun` for
  # older formats still.
  defp old_columns(views, fun) do
    Map.new(views, fn {id, v} ->
      columns =
        v.sections
        |> hd()
        |> Map.fetch!(:columns)
        |> Enum.map(&(&1 |> Map.delete(:linked) |> fun.()))

      sections = Enum.map(v.sections, &Map.delete(&1, :columns))
      {id, %{v | columns: columns, sections: sections}}
    end)
  end
end
