defmodule Agendum.TUI.RecoveryTest do
  @moduledoc """
  A recovery file on a crash (R82b; meeting 2026-10-26-4, § 6; the owner's
  choices, 2026-10-26): the unsaved changes written beside the file as
  `notes@.agendum` (Agenda's name for a damaged file's changes,
  `MYINFO@.AG`), and offered when the file is next opened.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.{Core, Store}
  alias Agendum.TUI.{App, State, Update}

  @moduletag :tmp_dir

  test "the recovery file's name: Agenda's @ before the extension" do
    assert Store.recovery_path("/wood/notes.agendum") == "/wood/notes@.agendum"
    assert Store.recovery_path("/wood/old.agenda") == "/wood/old@.agenda"

    assert Store.recovery_path(nil, %{"HOME" => "/h"}) ==
             "/h/.local/state/agendum/untitled@.agendum"

    assert Store.recovery_path(nil, %{"XDG_STATE_HOME" => "/s", "HOME" => "/h"}) ==
             "/s/agendum/untitled@.agendum"
  end

  describe "on a crash" do
    test "unsaved changes are written beside the file", %{tmp_dir: dir} do
      path = Path.join(dir, "notes.agendum")
      {db, _} = Core.add_item(Core.new_file(), "Ask Owl about the crash", ~D[2026-10-26])
      state = %{start(db) | path: path, dirty: true}

      assert App.keep_unsaved(state, %{}) == Path.join(dir, "notes@.agendum")
      assert {:ok, kept} = Store.load(Path.join(dir, "notes@.agendum"))
      assert kept.items == db.items
    end

    test "with nothing unsaved, nothing is written", %{tmp_dir: dir} do
      state = %{start(Core.new_file()) | path: Path.join(dir, "notes.agendum"), dirty: false}
      assert App.keep_unsaved(state, %{}) == nil
      assert File.ls!(dir) == []
    end
  end

  describe "when the file is opened again" do
    setup %{tmp_dir: dir} do
      path = Path.join(dir, "notes.agendum")
      {recovered, _} = Core.add_item(Core.new_file(), "Kept from the crash", ~D[2026-10-26])
      state = Update.loaded(start(Core.new_file()), path, {:ok, Core.new_file(), "stamp"})
      asked = Update.recovery_found(state, path, {:ok, recovered, ~N[2026-10-26 15:40:00]})
      %{asked: asked, path: path, rpath: Path.join(dir, "notes@.agendum"), recovered: recovered}
    end

    test "Agendum asks whether to open the changes", ctx do
      assert screen(ctx.asked) =~ "notes.agendum: changes not saved before a crash"
      assert screen(ctx.asked) =~ "notes@.agendum"
      assert screen(ctx.asked) =~ ~r/Open them\? +Yes/
    end

    test "Yes opens them as unsaved changes; the save removes the recovery file", ctx do
      opened = press(ctx.asked, :enter)
      assert opened.db.items == ctx.recovered.items
      assert opened.dirty
      assert opened.path == ctx.path

      saved = Update.saved(%{opened | effects: []}, ctx.path, {:ok, "new"}, %{then: nil})
      assert {:remove_recovery, ctx.rpath} in saved.effects
    end

    test "No keeps the file as saved and moves the changes to the Trash", ctx do
      Process.delete(:effects_seen)
      kept = press(ctx.asked, ["n", :enter])
      assert kept.db == Core.new_file()
      assert {:trash_file, ctx.rpath} in effects()

      # and a later save removes nothing
      saved = Update.saved(%{kept | effects: []}, ctx.path, {:ok, "new"}, %{then: nil})
      refute Enum.any?(saved.effects, &match?({:remove_recovery, _}, &1))
    end

    test "ESC decides nothing: the question comes again next time", ctx do
      Process.delete(:effects_seen)
      left = press(ctx.asked, :esc)
      assert State.mode(left) == nil
      assert effects() == []
      refute left.dirty
    end
  end

  test "a recovery file that cannot be read says so", %{tmp_dir: dir} do
    path = Path.join(dir, "notes.agendum")
    state = Update.recovery_found(start(Core.new_file()), path, {:error, :bad_format})
    assert screen(state) =~ "notes@.agendum could not be read"
  end
end
