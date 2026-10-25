defmodule Agendum.Core.FileSettingsTest do
  @moduledoc """
  File Properties' File description and Make backup on open (R82; User's
  Guide 22-8, 22-12; checked in Agenda 2.0, 2026-10-25).
  """
  use ExUnit.Case, async: true

  alias Agendum.Core

  test "a file has a description of up to forty characters, empty at first" do
    db = Core.new_file()
    assert db.description == ""
    assert {:ok, db} = Core.set_description(db, "  The Hundred Acre Wood  ")
    assert db.description == "The Hundred Acre Wood"
    assert Core.set_description(db, String.duplicate("x", 41)) == {:error, :too_long}
  end

  test "Make backup on open is off at first" do
    db = Core.new_file()
    refute db.backup_on_open
    assert Core.set_backup_on_open(db, true).backup_on_open
  end
end
