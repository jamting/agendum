# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.FileCheckTest do
  @moduledoc """
  A file is checked when it is opened (docs/SECURITY.md, door 2; the owner,
  2026-11-01): one whose values are of the wrong kind, or whose parts do not
  agree, is refused as damaged, as Agenda refused a damaged file, rather
  than opened to crash Agendum later.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Core
  alias Agendum.Core.{FileCheck, Links}
  alias Agendum.Store

  @moduletag :tmp_dir

  # a file with one item, and the item's id
  defp file do
    {db, id} = Core.add_item(Core.new_file(), "Honey", ~D[2026-11-01])
    {db, id}
  end

  # the database written as Store writes it, without Store's own checks:
  # what a crafted or damaged file holds
  defp write_raw(db, dir) do
    path = Path.join(dir, "crafted.agendum")
    File.write!(path, :erlang.term_to_binary({:agenda, Store.format_version(), db}))
    path
  end

  test "a sound file has no problem, and opens", %{tmp_dir: dir} do
    {db, _} = file()
    assert FileCheck.problem(db) == nil
    path = Path.join(dir, "sound.agendum")
    Store.save(db, path, :any)
    assert {:ok, _db} = Store.load(path)
  end

  test "an item assigned to a category that does not exist is refused", %{tmp_dir: dir} do
    {db, id} = file()
    db = %{db | links: Links.link(db.links, id, 999)}

    assert {:error, {:damaged, problem}} = db |> write_raw(dir) |> Store.load()
    assert problem =~ "missing category"
  end

  test "a value of the wrong kind is refused, not opened to crash later", %{tmp_dir: dir} do
    {db, id} = file()
    db = put_in(db.items[id].text, 42)

    assert {:error, {:damaged, problem}} = db |> write_raw(dir) |> Store.load()
    assert is_binary(problem)
  end

  test "a tree that is not a list is refused, not crashed on", %{tmp_dir: dir} do
    {db, _} = file()
    db = put_in(db.categories[db.main_id].children, "everything")

    assert {:error, {:damaged, _problem}} = db |> write_raw(dir) |> Store.load()
  end

  test "Retrieve says the file is damaged and why, and keeps the file open", %{tmp_dir: dir} do
    {db, id} = file()
    path = %{db | links: Links.link(db.links, id, 999)} |> write_raw(dir)
    state = start(Core.new_file())

    after_ = Agendum.TUI.Update.Results.loaded(state, path, Store.load_with_stamp(path))

    assert after_.db == state.db
    assert screen(after_) =~ "crafted.agendum is damaged and cannot be opened"
  end
end
