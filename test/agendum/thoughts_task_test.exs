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
    # a small repository: one meeting, one ADR, the roadmap, one summary,
    # and the meetings' template, which is not a document to import
    defp repo(dir) do
      root = Path.join(dir, "repo")

      for {path, text} <- [
            {"docs/meetings/2026-10-21-2324/protokoll.md", "# Minutes, 2026-10-21\n"},
            {"docs/meetings/TEMPLATE.md", "# Agenda (dagordning) form\n"},
            {"docs/adr/0001-core.md", "# ADR 0001\n\n**Status:** accepted · 2026-10-08\n"},
            {"docs/ROADMAP.md", "# Roadmap\n"},
            {"docs/summaries/2026-10-22-2311.md", "# Session summary\n"}
          ] do
        File.mkdir_p!(Path.dirname(Path.join(root, path)))
        File.write!(Path.join(root, path), text)
      end

      root
    end

    test "imports the documents, keeping a copy of the file as it was", %{tmp_dir: dir} do
      path = Path.join(dir, "project.agendum")
      :ok = Store.save(Thoughts.new_file(), path)

      out = run(["--import-docs", "--yes", "--docs", repo(dir), path])
      assert out =~ "Agendum must be closed"
      assert out =~ "Imported 4 documents"

      assert {:ok, db} = Store.load(path)
      [home] = Database.find_categories(db, "Disposable")
      assert length(Database.items_in(db, home)) == 4
      assert {:ok, Thoughts.new_file()} == Store.load(path <> ".bak")
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
