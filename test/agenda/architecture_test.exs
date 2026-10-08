defmodule Agenda.ArchitectureTest do
  @moduledoc """
  Guards the layering described in docs/DATA_ACCESS.md: the TUI may read
  the database through `Agenda.Core.Database` queries, but every change
  must go through the `Agenda.Core` facade.
  """
  use ExUnit.Case, async: true

  @write_call ~r/\bDatabase\.(insert_\w+|update_\w+|delete_\w+|link|unlink|reorder_item|move_category|rename_category|promote|demote)\(/
  @struct_update ~r/%\{\s*(state\.)?db\s*\|/

  test "the TUI changes the database only through Agenda.Core" do
    violations =
      for path <- Path.wildcard("lib/agenda/tui/**/*.ex"),
          {line, number} <- path |> File.read!() |> String.split("\n") |> Enum.with_index(1),
          Regex.match?(@write_call, line) or Regex.match?(@struct_update, line) do
        "#{path}:#{number}: #{String.trim(line)}"
      end

    assert violations == [], """
    Direct database writes from the TUI (use or add an Agenda.Core function instead):

      #{Enum.join(violations, "\n  ")}
    """
  end
end
