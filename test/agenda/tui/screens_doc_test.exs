defmodule Agenda.TUI.ScreensDocTest do
  @moduledoc "docs/SCREENS.md lists every mode the TUI can push."
  use ExUnit.Case, async: true

  @doc_path "docs/SCREENS.md"

  # Every `type: :name` a TUI module puts in a mode map.
  defp mode_types do
    "lib/agenda/tui/**/*.ex"
    |> Path.wildcard()
    |> Enum.flat_map(fn path ->
      ~r/%\{\s*type: :([a-z_]+)/
      |> Regex.scan(File.read!(path))
      |> Enum.map(fn [_, type] -> type end)
    end)
    |> Enum.uniq()
  end

  test "every mode type is in the screen overview" do
    doc = File.read!(@doc_path)
    types = mode_types()
    assert length(types) > 25
    missing = Enum.reject(types, &String.contains?(doc, "`:#{&1}`"))
    assert missing == [], "add these to #{@doc_path}: #{Enum.join(missing, ", ")}"
  end
end
