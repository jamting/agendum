defmodule Agendum.TUI.FileCommandsTest do
  @moduledoc """
  Agenda's File commands (User's Guide 22-8 to 22-11, 23-26; checked in
  Agenda 2.0, 2026-10-25): Abandon, Maintenance MakeCopy and Erase,
  Transfer Template.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core.Database
  alias Agendum.TUI.Update

  setup do
    %{state: start(Agendum.Sample.build(~D[2026-10-08]), width: 80, height: 25)}
  end

  defp count(state), do: length(Database.items(state.db))
  defp line(state, n), do: state |> screen() |> String.split("\n") |> Enum.at(n)

  describe "File ▸ Abandon" do
    # Agenda's box: "Revert to last saved version:  No", No first
    test "asks with No first; Yes goes back to the file as last saved", %{state: state} do
      before = count(state)
      state = press(state, ["Buy honey", :enter])
      assert count(state) == before + 1

      asked = press(state, [{:f, 10}, "f", "a"])
      screen = screen(asked)
      assert screen =~ "Abandon File"
      assert screen =~ ~r/Revert to last saved version: +No/
      assert screen =~ "Type Y to abandon all changes made since the last time you saved"

      # ENTER on No changes nothing
      assert count(press(asked, :enter)) == before + 1

      reverted = press(asked, [" ", :enter])
      assert count(reverted) == before
      refute reverted.dirty

      # and, as any change, it can be undone
      assert count(Agendum.TUI.History.undo(reverted)) == before + 1
    end
  end

  describe "File ▸ Maintenance ▸ MakeCopy" do
    # Agenda saves the current file and writes the copy, and you stay in
    # the current file (User's Guide 22-11; checked in Agenda 2.0); ours
    # writes the copy first (R71)
    test "writes the copy, then saves the file; the file stays open", %{state: state} do
      state = %{state | path: "/wood/owl.agendum"}
      state = press(state, [{:f, 10}, "f", "m", "m"])
      assert screen(state) =~ "Make a copy as:"

      state = press(state, [{:ctrl, "u"}, "/wood/owl-copy"])
      {state, effects} = Update.handle(state, :enter)

      assert [{:save_copy, "/wood/owl-copy.agendum", db}, {:save, "/wood/owl.agendum", _opts}] =
               effects

      assert db == state.db
      assert state.path == "/wood/owl.agendum"

      state = Update.copied(%{state | effects: []}, "/wood/owl-copy.agendum", {:ok, "stamp"})
      assert panel(state) =~ "Copied to owl-copy.agendum"
    end

    test "a copy that could not be written still says so after the save", %{state: state} do
      state = %{state | path: "/wood/owl.agendum"}
      state = Update.copied(state, "/locked/copy.agendum", {:error, :eacces})
      opts = %{expect: :any, then: {:copied, "/locked/copy.agendum"}, auto: false}
      state = Update.saved(state, "/wood/owl.agendum", {:ok, "stamp"}, opts)
      assert panel(state) =~ "Could not write the copy"
      refute state.dirty
    end

    test "an untitled file only writes the copy", %{state: state} do
      state = press(state, [{:f, 10}, "f", "m", "m", "/wood/new"])
      {_state, effects} = Update.handle(state, :enter)
      assert [{:save_copy, "/wood/new.agendum", _db}] = effects
    end

    test "File ▸ Write has given way to it", %{state: state} do
      refute screen(press(state, [{:f, 10}, "f"])) =~ "Write"
    end
  end

  describe "File ▸ Maintenance ▸ Erase" do
    # Agenda's question, "Discard MK.AG?  No", No first (checked in Agenda
    # 2.0); the file then goes to the system's Trash (the owner's choice)
    test "asks with No first; Yes moves the file to the Trash", %{state: state} do
      state = press(state, [{:f, 10}, "f", "m", "e", "/wood/old", :enter])
      assert screen(state) =~ ~r/Discard old.agendum\? +No/
      assert line(state, 0) =~ "Press Y to discard the file from your disk."

      {_state, []} = Update.handle(state, :enter)
      {_state, effects} = Update.handle(state, {:char, "y"})
      assert effects == [{:trash_file, "/wood/old.agendum"}]

      state = Update.trashed(state, "/wood/old.agendum", :ok)
      assert panel(state) =~ "old.agendum is in the Trash"
    end

    test "the open file cannot be discarded", %{state: state} do
      state = %{state | path: "/wood/owl.agendum"}
      state = press(state, [{:f, 10}, "f", "m", "e", {:ctrl, "u"}, "/wood/owl", :enter])
      assert panel(state) =~ "You can't discard a file while it is open."
    end
  end
end
