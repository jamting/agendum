# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.FileCheck do
  @moduledoc """
  The check a file passes when it is opened (docs/SECURITY.md, door 2; the
  owner, 2026-11-01): a file whose values are of the wrong kind, or whose
  parts do not agree, is damaged, and is refused rather than opened to
  crash Agendum later, as Agenda refused a damaged file (User's Guide,
  Appendix I). Agendum never writes such a file itself (the fuzz walks
  check every key), so one comes from a damaged disk, another program, or
  someone who made it to harm.

  Two checks, in order:

    1. **Types**, through the JSON format's strict reading
       (`Agendum.Core.JSONFile`): the file written as JSON and read back.
       Its checks already know every stored field, so a new field is
       checked without a line here.
    2. **Consistency**, `Agendum.Core.Invariants`: the tree, links,
       references and ids agree.

  Pure.
  """

  alias Agendum.Core.{Database, Invariants, JSONFile}

  @doc "The first thing wrong with the file, in words; nil when it is sound."
  @spec problem(Database.t()) :: String.t() | nil
  def problem(%Database{} = db) do
    types(db) || consistency(db)
  end

  # Domain: writing a damaged file as JSON may raise on a value of the
  # wrong kind (a number where text belongs); that is an answer here, not
  # a bug, so `rescue` turns it into the problem.
  defp types(db) do
    case db |> JSONFile.encode() |> JSONFile.decode() do
      {:ok, _db} -> nil
      {:error, message} -> message
    end
  rescue
    _ -> "a value of the wrong kind"
  end

  # the invariants walk the structure, and could raise on a shape the JSON
  # check let through: that too is a damaged file
  defp consistency(db) do
    case Invariants.violations(db) do
      [] -> nil
      [first | _] -> first
    end
  rescue
    _ -> "its parts do not fit together"
  end
end
