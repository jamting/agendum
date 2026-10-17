defmodule Agendum.Core.TabSizeTest do
  @moduledoc "File Properties ▸ Tab size (R64e): the note editor's tab stops, kept in the file."
  use ExUnit.Case, async: true

  alias Agendum.Core

  test "a new file has Agenda's 5" do
    assert Core.new_file().tab_size == 5
  end

  test "it is set from 1 to 16, through the command layer too" do
    db = Core.new_file()
    assert Core.set_tab_size(db, 8).tab_size == 8
    assert {:ok, %{tab_size: 2}, _} = Core.run(db, {:set_tab_size, 2}, ~D[2026-10-17])
    assert {:error, :bad_arguments} = Core.run(db, {:set_tab_size, 0}, ~D[2026-10-17])
    assert {:error, :bad_arguments} = Core.run(db, {:set_tab_size, 17}, ~D[2026-10-17])
  end

  test "it goes through JSON and back" do
    db = Core.set_tab_size(Core.new_file(), 3)
    {:ok, back} = Core.import_json(Core.export_json(db))
    assert back.tab_size == 3
  end
end
