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
end
