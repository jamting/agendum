defmodule Agendum.TUI.FileCommandsTest do
  @moduledoc """
  Agenda's File commands (User's Guide 22-8 to 22-11, 23-26; checked in
  Agenda 2.0, 2026-10-25): Abandon, Maintenance MakeCopy and Erase,
  Transfer Template.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core.Database

  setup do
    %{state: start(Agendum.Sample.build(~D[2026-10-08]), width: 80, height: 25)}
  end

  defp count(state), do: length(Database.items(state.db))

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
end
