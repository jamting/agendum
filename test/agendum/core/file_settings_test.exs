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

  # Set file password (ADR 0046): up to 12 characters, as Agenda's; an
  # empty one removes it
  test "a password of up to 12 characters, removed by an empty one" do
    db = Core.new_file()
    assert db.password == nil
    assert {:ok, db} = Core.set_password(db, "Hoot")
    assert db.password == "Hoot"
    assert Core.set_password(db, String.duplicate("x", 13)) == {:error, :too_long}
    assert {:ok, %{password: nil}} = Core.set_password(db, "")
  end
end
