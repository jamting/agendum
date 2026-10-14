defmodule Agendum.DocsNamesTest do
  @moduledoc """
  The documents name modules in full (`Agendum.Core.Database`, not
  `Core.Database`), so that `mix docs` links them.
  """
  use ExUnit.Case, async: true

  @files ["README.md", "CLAUDE.md"] ++
           Path.wildcard("docs/*.md") ++ Path.wildcard("docs/adr/*.md")
  # a short module name, perhaps with a function and arity, alone in backticks
  @short ~r/`((?:Core|TUI)\.[A-Z][\w.]*?)(?:\.[a-z_][\w?!]*(?:\/\d+)?)?`/

  test "modules are named in full, so the API docs link them" do
    {:ok, modules} = :application.get_key(:agendum, :modules)
    known = MapSet.new(modules, &inspect/1)

    short =
      for file <- @files,
          {line, number} <- file |> File.read!() |> outside_code_blocks(),
          [_, name] <- Regex.scan(@short, line),
          MapSet.member?(known, "Agendum." <> name),
          do: "#{file}:#{number}: `#{name}` (write `Agendum.#{name}`)"

    assert short == [], Enum.join(short, "\n")
  end

  # numbered lines, without fenced code blocks (Mermaid diagrams, shell)
  defp outside_code_blocks(text) do
    text
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.reduce({[], false}, fn {line, n}, {acc, fenced} ->
      cond do
        String.starts_with?(String.trim_leading(line), "```") -> {acc, not fenced}
        fenced -> {acc, fenced}
        true -> {[{line, n} | acc], fenced}
      end
    end)
    |> elem(0)
  end
end
