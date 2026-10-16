defmodule Agendum.DocsIndexTest do
  @moduledoc """
  The two indexes of the documents stay complete: SPEC.md's rule index
  lists every rule with the section it is in, and docs/INDEX.md names
  every document in `docs/`, `docs/plans/` and `docs/plans/archive/`.
  """
  use ExUnit.Case, async: true

  @spec_file "docs/SPEC.md"

  test "SPEC.md's rule index lists every rule, with its section" do
    text = File.read!(@spec_file)

    # `~r/.../m` is a regex with multiline mode: ^ matches at each line start.
    # Regex.scan returns one list per match: [whole match, group 1, group 2…]
    indexed =
      for [_, rule, section] <- Regex.scan(~r/^\| (R\d+[a-z]?) \| .+ \| (\d+[a-z]?) \|$/m, text),
          into: %{},
          do: {rule, section}

    assert indexed == rules_by_section(text)
  end

  test "docs/INDEX.md names every document" do
    index = File.read!("docs/INDEX.md")

    missing =
      for path <-
            Path.wildcard("docs/*.md") ++
              Path.wildcard("docs/plans/*.md") ++
              Path.wildcard("docs/plans/archive/*.md"),
          path != "docs/INDEX.md",
          # INDEX.md links relative to docs/, so drop that prefix
          not String.contains?(index, "(" <> Path.relative_to(path, "docs") <> ")"),
          do: path

    assert missing == [], "add to docs/INDEX.md: " <> Enum.join(missing, ", ")
  end

  # Each rule (`- **R7a ✅ …`) mapped to the `## N.` section it is written in.
  defp rules_by_section(text) do
    text
    |> String.split("\n")
    # reduce walks the lines carrying {current section, rules found so far}
    |> Enum.reduce({nil, %{}}, fn line, {section, rules} ->
      cond do
        match = Regex.run(~r/^## (\d+[a-z]?)\. /, line) ->
          {Enum.at(match, 1), rules}

        match = Regex.run(~r/^- \*\*(R\d+[a-z]?) /, line) ->
          {section, Map.put(rules, Enum.at(match, 1), section)}

        true ->
          {section, rules}
      end
    end)
    |> elem(1)
  end
end
