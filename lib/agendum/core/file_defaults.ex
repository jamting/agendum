# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.FileDefaults do
  @moduledoc """
  The defaults for new files (File Properties ▸ Update defaults, R82a;
  User's Guide 22-14; checked in Agenda 2.0, 2026-10-26): the file's
  settings taken as the starting point for every new, empty file the person
  makes. Agenda kept them in its own settings file (`AGENDA.ENV`), never in
  a data file; Agendum keeps them in the person's preferences (ADR 0008,
  amended), which the shell reads and passes in.

  They are the settings of `Agendum.Core.JSONFile.settings/1` (File
  Properties, the global date settings with the display format, the
  auto-assign settings) without the description, flattened to dotted keys
  (`"date_format.clock" => 24`), and only those that differ from Agenda's
  own, which `Agendum.Core.Database.new/1` gives (meeting 2026-10-26-1358,
  § 5). The password was never a setting here, as in Agenda. Pure.
  """

  alias Agendum.Core.{Database, DateFormat, JSONFile}

  @typedoc "Dotted setting names and their values as JSON writes them."
  @type t :: %{optional(String.t()) => term}

  # the file's own, never a default (Agenda left it blank in a new file)
  @not_defaults ["description"]

  @doc "The file's settings that differ from a new file's: the defaults Update defaults keeps."
  @spec take(Database.t()) :: t
  def take(db) do
    agenda = flat(Database.new())

    db
    |> flat()
    # `Map.reject/2` keeps the pairs for which the function is false
    |> Map.reject(fn {key, value} -> key in @not_defaults or agenda[key] == value end)
  end

  @doc """
  The file with the defaults put on it, one at a time: a setting unknown to
  this version, or a value that cannot be read (a preferences file edited by
  hand), is left out, and the others still apply.
  """
  @spec apply(Database.t(), t) :: Database.t()
  def apply(db, defaults) do
    defaults
    |> Enum.sort()
    |> Enum.reduce(db, fn {key, value}, db -> put(db, key, value) end)
  end

  defp put(db, key, value) do
    settings = JSONFile.settings(db)
    path = String.split(key, ".")

    # the setting must be there already, so an unknown name never adds one
    with true <- key not in @not_defaults and known?(settings, path),
         true <- valid?(key, value),
         {:ok, db} <- JSONFile.put_settings(db, put_in(settings, path, value)) do
      db
    else
      _ -> db
    end
  end

  defp known?(%{} = map, [key | rest]), do: Map.has_key?(map, key) and known?(map[key], rest)
  # a whole group (`date_format`) is not one setting
  defp known?(%{}, []), do: false
  defp known?(_value, []), do: true
  defp known?(_value, _path), do: false

  # what the boxes can choose that a JSON file's types do not say
  defp valid?("date_format.separator", value), do: value in DateFormat.separators()
  defp valid?("date_format.time_separator", value), do: value in [":", "hm"]
  defp valid?("date_format.clock", value), do: value in [12, 24]
  defp valid?("date_settings.week_" <> _, value), do: value in 1..7//1
  defp valid?("date_settings.quarter_start", value), do: value in 1..12//1
  defp valid?("date_settings.year_start", value), do: value in 1..12//1

  defp valid?("date_settings.month_alone", value),
    do: value in ["first", "last"] or value in 2..31//1

  defp valid?(_key, _value), do: true

  # the settings as dotted keys: `%{"date_format" => %{"clock" => 12}}`
  # becomes `%{"date_format.clock" => 12}`
  defp flat(db), do: db |> JSONFile.settings() |> flatten("")

  defp flatten(%{} = map, prefix),
    do:
      Enum.reduce(map, %{}, fn {k, v}, acc -> Map.merge(acc, flatten(v, prefix <> k <> ".")) end)

  defp flatten(value, prefix), do: %{String.trim_trailing(prefix, ".") => value}
end
