# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.GoldenFilesTest do
  @moduledoc """
  The golden files of the file format (`test/fixtures/formats/`, one saved
  by each format version from 33 on, `Agendum.Starters.Golden`): each one
  still loads, is sound, says what it said when it was saved, works in the
  UI, and survives saving again. The file the current version would write
  has to be there, and the builder has to use every stored field.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core.Database
  alias Agendum.Starters.Golden
  alias Agendum.Store

  @dir "test/fixtures/formats"

  # `Path.wildcard` runs when the module compiles: one test per file found.
  # `@external_resource` recompiles the module when a golden file appears.
  @files Path.wildcard(Path.join(@dir, "v*.agendum")) |> Enum.sort()
  for file <- @files, do: @external_resource(file)

  test "the current format version has its golden file (make it with mix agendum.golden)" do
    path = Path.join(@dir, "v#{Store.format_version()}.agendum")
    assert File.exists?(path), "no #{path}: run `mix agendum.golden` and commit what it writes"
  end

  for file <- @files do
    @file_path file
    @facts_path String.replace(file, ".agendum", ".facts.exs")

    describe Path.basename(file) do
      test "loads, is sound and says what it said when saved" do
        assert {:ok, db} = Store.load(@file_path)
        assert Agendum.Core.Invariants.violations(db) == []

        # the facts were written beside it when it was made
        {facts, _binding} = Code.eval_file(@facts_path)
        assert Golden.facts(db) == facts
      end

      test "every view opens in the UI and draws a full screen" do
        {:ok, db} = Store.load(@file_path)
        state = Agendum.TUIHelpers.start(db, today: Golden.today(), width: 100, height: 30)

        for view_id <- db.view_order do
          screen =
            Agendum.TUI.Render.render(Agendum.TUI.Layout.settle(%{state | view_id: view_id}))

          assert length(screen) == 30
        end
      end

      test "saved again by this version, it reads back the same", %{tmp_dir: dir} do
        {:ok, db} = Store.load(@file_path)
        path = Path.join(dir, "again.agendum")
        :ok = Store.save(db, path)
        assert Store.load(path) == {:ok, db}
      end
    end
  end

  @moduletag :tmp_dir

  # fields a database has while open but that are never written: the
  # password, with which the file is encrypted instead (ADR 0046)
  @never_written [{Agendum.Core.Database, :password}]

  test "the golden file uses every field of every stored struct" do
    unused =
      for {module, instances} <- instances(Golden.build()),
          default = struct(module),
          field <- Map.keys(default) -- [:__struct__],
          {module, field} not in @never_written,
          Enum.all?(instances, &(Map.get(&1, field) == Map.get(default, field))),
          do: "#{inspect(module)}.#{field}"

    assert unused == [], """
    Agendum.Starters.Golden leaves these stored fields at their defaults; set
    them in its build/0, so that the golden files carry them:

      #{Enum.join(unused, "\n  ")}
    """
  end

  # Every stored struct in a file, by module.
  defp instances(%Database{} = db) do
    views = Map.values(db.views)
    sections = Enum.flat_map(views, & &1.sections)
    columns = Enum.flat_map(views, & &1.columns) ++ Enum.flat_map(sections, & &1.columns)
    categories = Map.values(db.categories)
    items = Map.values(db.items)

    [
      {Database, [db]},
      {Agendum.Core.Item, items},
      {Agendum.Core.Recurrence, items |> Enum.map(& &1.recurrence) |> Enum.reject(&is_nil/1)},
      {Agendum.Core.Category, categories},
      {Agendum.Core.DateRule, categories |> Enum.map(& &1.date_rule) |> Enum.reject(&is_nil/1)},
      {Agendum.Core.View, views},
      {Agendum.Core.View.Section, sections},
      {Agendum.Core.View.Column, columns},
      {Agendum.Core.View.ItemColumn, Enum.map(sections, & &1.item_column)},
      {Agendum.Core.View.SortKey,
       Enum.flat_map(views, & &1.sort) ++ Enum.flat_map(sections, &(&1.sort || []))},
      {Agendum.Core.Datebook, views |> Enum.map(& &1.datebook) |> Enum.reject(&is_nil/1)},
      {Agendum.Core.Search, for(%{match: %Agendum.Core.Search{} = s} <- views, do: s)},
      {Agendum.Core.DateFormat,
       [db.date_format | columns |> Enum.map(& &1.date) |> Enum.reject(&is_nil/1)]},
      {Agendum.Core.NumberFormat, Enum.map(columns, & &1.number)},
      {Agendum.Core.DateSettings, [db.date_settings]},
      {Agendum.Core.TextMatch, [db.match_settings]},
      {Agendum.Core.Extras.Calendar, Map.values(db.calendars)},
      {Agendum.Core.Macro, Map.values(db.macros)}
    ]
  end
end
