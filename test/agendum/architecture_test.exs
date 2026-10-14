defmodule Agendum.ArchitectureTest do
  @moduledoc """
  Guards the layering described in docs/DATA_ACCESS.md: the TUI may read
  the database through `Agendum.Core.Database` queries, but every change
  must go through the `Agendum.Core` facade.
  """
  use ExUnit.Case, async: true

  @write_call ~r/\bDatabase\.(insert_\w+|update_\w+|delete_\w+|put_\w+|link|unlink|reorder_item|move_category|rename_category|promote|demote)\(/
  @struct_update ~r/%\{\s*(state\.)?db\s*\|/

  test "the TUI changes the database only through Agendum.Core" do
    violations =
      for path <- Path.wildcard("lib/agendum/tui/**/*.ex"),
          {line, number} <- path |> File.read!() |> String.split("\n") |> Enum.with_index(1),
          Regex.match?(@write_call, line) or Regex.match?(@struct_update, line) do
        "#{path}:#{number}: #{String.trim(line)}"
      end

    assert violations == [], """
    Direct database writes from the TUI (use or add an Agendum.Core function instead):

      #{Enum.join(violations, "\n  ")}
    """
  end

  test "the core never reads the clock, the environment or the outside world" do
    impure =
      ~r/Date\.utc_today|NaiveDateTime\.(utc_now|local_now)|DateTime\.(utc_now|now)|:calendar\.|:os\.|System\.|File\.|IO\.(puts|write|read|gets|inspect|binread|binwrite)|:rand\.|Process\.|send\(|spawn/

    offenders =
      for path <- ["lib/agendum/core.ex" | Path.wildcard("lib/agendum/core/**/*.ex")],
          {line, number} <- path |> File.read!() |> String.split("\n") |> Enum.with_index(1),
          not String.starts_with?(String.trim_leading(line), "#"),
          Regex.match?(impure, line),
          do: "#{path}:#{number}: #{String.trim(line)}"

    assert offenders == [], "impure calls in the core:\n" <> Enum.join(offenders, "\n")
  end
end
