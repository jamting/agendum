defmodule Agendum.Core.FileDefaultsTest do
  @moduledoc """
  File Properties ▸ Update defaults (R82a; User's Guide 22-14, 17-50, H-9;
  checked in Agenda 2.0, 2026-10-26): the file's settings taken as the
  defaults for new files, kept as the settings that differ from Agenda's.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core

  defp changed do
    db = Core.new_file()
    {:ok, db} = Core.set_description(db, "Owl's file")
    {:ok, db} = Core.set_password(db, "Hoot")

    %{
      Core.set_tab_size(db, 8)
      | date_format: %{db.date_format | separator: "-", clock: 24},
        date_settings: %{db.date_settings | morning: ~T[09:00:00], week_start: 2},
        match_settings: %{db.match_settings | strength: :partial},
        confirm_assignments: :always,
        backup_on_open: true,
        insert_columns: :section,
        trash: %{db.trash | empty: :discarded}
    }
  end

  test "a new file's defaults are none: it has Agenda's settings" do
    assert Core.file_defaults(Core.new_file()) == %{}
  end

  test "only the settings that differ from Agenda's are taken, never the description or password" do
    assert Core.file_defaults(changed()) == %{
             "tab_size" => 8,
             "date_format.separator" => "-",
             "date_format.clock" => 24,
             "date_settings.morning" => "09:00:00",
             "date_settings.week_start" => 2,
             "match_settings.strength" => "partial",
             "confirm_assignments" => "always",
             "backup_on_open" => true,
             "insert_columns" => "section",
             "empty_trash" => "discarded"
           }
  end

  test "a new file made with the defaults has those settings, and nothing else of the file" do
    old = changed()
    db = Core.new_file(defaults: Core.file_defaults(old))

    assert db.tab_size == 8
    assert db.date_format == old.date_format
    assert db.date_settings == old.date_settings
    assert db.match_settings == old.match_settings

    assert {db.confirm_assignments, db.backup_on_open, db.insert_columns} ==
             {:always, true, :section}

    assert db.trash.empty == :discarded
    assert {db.description, db.password} == {"", nil}
  end

  test "the New File box's file takes them too, with its own description and password" do
    defaults = Core.file_defaults(changed())
    assert {:ok, db} = Core.new_file_with("Notes", "", defaults)
    assert {db.description, db.tab_size} == {"Notes", 8}
  end

  test "an unknown setting or a value that cannot be read is left out; the others are kept" do
    db =
      Core.new_file(
        defaults: %{
          "tab_size" => 8,
          "tab_size_typo" => 3,
          "date_format.clock" => "loud",
          "date_format.order" => "nonsense",
          "date_settings.week_start" => 99,
          "description" => "not a default"
        }
      )

    assert db.tab_size == 8
    assert db.date_format == Core.new_file().date_format
    assert db.date_settings == Core.new_file().date_settings
    assert db.description == ""
  end
end
