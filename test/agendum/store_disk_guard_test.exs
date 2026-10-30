# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.StoreDiskGuardTest do
  @moduledoc """
  The file changed on disk (R71): a save says what it expects to find on
  disk, the stamp of the file as it was read or last saved, and refuses
  to write over anything else.
  """
  use ExUnit.Case, async: true

  alias Agendum.Store

  @moduletag :tmp_dir

  setup %{tmp_dir: dir} do
    db = Agendum.Sample.build(~D[2026-10-08])
    path = Path.join(dir, "garden.agendum")
    :ok = Store.save(db, path)
    {:ok, ^db, stamp} = Store.load_with_stamp(path)
    %{db: db, path: path, stamp: stamp}
  end

  test "a file's stamp is the one it was loaded with", %{path: path, stamp: stamp} do
    assert Store.stamp(path) == stamp
    assert Store.stamp(path <> ".not-there") == nil
  end

  test "a file as it was is saved over, and the new stamp returned", ctx do
    {db, _id} = Agendum.Core.add_item(ctx.db, "Water the haycorns", ~D[2026-10-08])
    assert {:ok, stamp} = Store.save(db, ctx.path, ctx.stamp)
    assert stamp == Store.stamp(ctx.path)
    assert stamp != ctx.stamp
    assert {:ok, ^db} = Store.load(ctx.path)
  end

  test "a file changed by another writer is not saved over", ctx do
    {theirs, _id} = Agendum.Core.add_item(ctx.db, "Theirs", ~D[2026-10-08])
    :ok = Store.save(theirs, ctx.path)

    assert {:error, :changed_on_disk} = Store.save(ctx.db, ctx.path, ctx.stamp)
    assert {:ok, ^theirs} = Store.load(ctx.path)
  end

  test ":any saves over whatever is there", ctx do
    {theirs, _id} = Agendum.Core.add_item(ctx.db, "Theirs", ~D[2026-10-08])
    :ok = Store.save(theirs, ctx.path)

    assert {:ok, _stamp} = Store.save(ctx.db, ctx.path, :any)
    assert Store.load(ctx.path) == {:ok, ctx.db}
  end

  test "a file removed since is written again: nothing is lost", ctx do
    File.rm!(ctx.path)
    assert {:ok, _stamp} = Store.save(ctx.db, ctx.path, ctx.stamp)
    assert Store.load(ctx.path) == {:ok, ctx.db}
  end

  test "a new file (nil) is not written over one that appeared meanwhile", ctx do
    assert {:error, :changed_on_disk} = Store.save(Agendum.Core.new_file(), ctx.path, nil)
    assert Store.load(ctx.path) == {:ok, ctx.db}
  end
end
