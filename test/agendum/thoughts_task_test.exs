# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.ThoughtsTaskTest do
  # not async: one test sets an environment variable, which is global
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Agendum.{Core, Store, Thoughts}
  alias Agendum.Core.Database
  alias Mix.Tasks.Agendum.Thoughts, as: Task

  @moduletag :tmp_dir

  defp run(args), do: capture_io(fn -> Task.run(args) end)

  test "--init writes a new file for thoughts, and never overwrites one", %{tmp_dir: dir} do
    path = Path.join(dir, "project.agendum")
    assert run(["--init", path]) =~ "Wrote"
    assert {:ok, db} = Store.load(path)
    assert db == Thoughts.new_file()

    assert_raise Mix.Error, ~r/exists already/, fn -> run(["--init", path]) end
  end

  test "prints the thoughts of the file named, or of AGENDUM_PROJECT_FILE", %{tmp_dir: dir} do
    path = Path.join(dir, "project.agendum")
    db = Thoughts.new_file()
    [next] = Database.find_categories(db, "Next meeting")
    {db, _} = Core.add_item(db, "Menus by DOSBox", ~D[2026-10-22], section: next)
    :ok = Store.save(db, path)

    assert run([path]) =~ "## For the next meeting\n\n- Menus by DOSBox (2026-10-22)"

    System.put_env("AGENDUM_PROJECT_FILE", path)
    on_exit(fn -> System.delete_env("AGENDUM_PROJECT_FILE") end)
    assert run(["--next-meeting"]) =~ "Menus by DOSBox"
  end

  test "a file without thoughts says how to make one", %{tmp_dir: dir} do
    path = Path.join(dir, "other.agendum")
    :ok = Store.save(Core.new_file(), path)
    assert_raise Mix.Error, ~r/no Thoughts category/, fn -> run([path]) end
  end

  describe "--import-docs (meeting 2026-10-22-2309, § 5)" do
    # The owner's environment may name their private documents; each test
    # here starts without it, and gets it back afterwards
    setup do
      saved = System.get_env("AGENDUM_PRIVATE_DOCS")
      System.delete_env("AGENDUM_PRIVATE_DOCS")
      on_exit(fn -> if saved, do: System.put_env("AGENDUM_PRIVATE_DOCS", saved) end)
    end

    # a small repository: one meeting, one ADR, the roadmap, and the
    # meetings' template, which is not a document to import
    defp repo(dir) do
      write_files(Path.join(dir, "repo"), [
        {"docs/meetings/2026-10-21-2324/protokoll.md", "# Minutes, 2026-10-21\n"},
        {"docs/meetings/TEMPLATE.md", "# Agenda (dagordning) form\n"},
        {"docs/adr/0001-core.md", "# ADR 0001\n\n**Status:** accepted · 2026-10-08\n"},
        {"docs/ROADMAP.md", "# Roadmap\n"}
      ])
    end

    # the owner's private documents (the folder `--private` names): one
    # session summary
    defp private_docs(dir) do
      write_files(Path.join(dir, "private"), [
        {"summaries/2026-10-22-2311.md", "# Session summary, 2026-10-22 23:11\n"}
      ])
    end

    defp write_files(root, files) do
      for {path, text} <- files do
        File.mkdir_p!(Path.dirname(Path.join(root, path)))
        File.write!(Path.join(root, path), text)
      end

      root
    end

    defp imported(path, kind) do
      {:ok, db} = Store.load(path)
      [id] = Database.find_categories(db, kind)
      db |> Database.items_in(id) |> Enum.map(& &1.text)
    end

    test "imports the documents, keeping a copy of the file as it was", %{tmp_dir: dir} do
      path = Path.join(dir, "project.agendum")
      :ok = Store.save(Thoughts.new_file(), path)

      out =
        run(["--import-docs", "--yes", "--docs", repo(dir), "--private", private_docs(dir), path])

      assert out =~ "Agendum must be closed"
      assert out =~ "Imported 4 documents"

      assert {:ok, db} = Store.load(path)
      [home] = Database.find_categories(db, "Disposable")
      assert length(Database.items_in(db, home)) == 4
      assert imported(path, "Summaries") == ["Session summary, 2026-10-22 23:11"]
      assert {:ok, Thoughts.new_file()} == Store.load(path <> ".bak")
    end

    test "reads the summaries from AGENDUM_PRIVATE_DOCS", %{tmp_dir: dir} do
      path = Path.join(dir, "project.agendum")
      :ok = Store.save(Thoughts.new_file(), path)
      System.put_env("AGENDUM_PRIVATE_DOCS", private_docs(dir))
      on_exit(fn -> System.delete_env("AGENDUM_PRIVATE_DOCS") end)

      assert run(["--import-docs", "--yes", "--docs", repo(dir), path]) =~ "Imported 4 documents"
      assert imported(path, "Summaries") == ["Session summary, 2026-10-22 23:11"]
    end

    test "a private folder without summaries stops the import", %{tmp_dir: dir} do
      path = Path.join(dir, "project.agendum")
      :ok = Store.save(Thoughts.new_file(), path)
      before = File.read!(path)

      assert_raise Mix.Error, ~r/No summaries folder/, fn ->
        run(["--import-docs", "--yes", "--docs", repo(dir), "--private", repo(dir), path])
      end

      assert File.read!(path) == before
    end

    test "without the private documents, says the summaries are left out", %{tmp_dir: dir} do
      path = Path.join(dir, "project.agendum")
      :ok = Store.save(Thoughts.new_file(), path)

      out = run(["--import-docs", "--yes", "--docs", repo(dir), path])
      assert out =~ "Imported 3 documents"
      assert out =~ "summaries are left out"
      assert out =~ "AGENDUM_PRIVATE_DOCS"
      assert imported(path, "Summaries") == []
    end

    test "asks first, and changes nothing when the answer is no", %{tmp_dir: dir} do
      path = Path.join(dir, "project.agendum")
      :ok = Store.save(Thoughts.new_file(), path)
      before = File.read!(path)

      out =
        capture_io("n\n", fn -> Task.run(["--import-docs", "--docs", repo(dir), path]) end)

      assert out =~ "Import anyway?"
      assert out =~ "Nothing imported"
      assert File.read!(path) == before
      refute File.exists?(path <> ".bak")
    end
  end
end
