# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.ScreensDocTest do
  @moduledoc "docs/SCREENS.md lists every mode the TUI can push."
  use ExUnit.Case, async: true

  @doc_path "docs/SCREENS.md"

  # Every kind of mode the TUI can push: a struct each (`Agendum.TUI.Modes`)
  defp mode_types, do: Enum.map(Agendum.TUI.Modes.types(), &Atom.to_string/1)

  test "every mode type is in the screen overview" do
    doc = File.read!(@doc_path)
    types = mode_types()
    assert length(types) > 25
    missing = Enum.reject(types, &String.contains?(doc, "`:#{&1}`"))
    assert missing == [], "add these to #{@doc_path}: #{Enum.join(missing, ", ")}"
  end
end
