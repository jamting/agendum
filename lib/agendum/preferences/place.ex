defmodule Agendum.Preferences.Place do
  @moduledoc """
  Where the person left one file (R69): the view shown, the section the
  highlight was in and the item it was on. Kept in the preferences, keyed
  by the file's path, never in the file: moving around does not change the
  file, and each person has their own place in it (meeting 2026-10-16,
  § 5). Agenda kept the view and item in the file itself
  (`docs/AGENDA_FILE_FORMAT.md`, header `0x044` and `0x1E8`).

  One line of the preferences file holds one file's place, the path last
  so that it may contain spaces:

      place = view:3 section:2 item:17 file:/Users/me/My work.agendum

  `parse/1` and `format/2` read and write the text after `place =`.
  """

  alias Agendum.Core.Database

  @type t :: %__MODULE__{
          view: Database.id() | nil,
          section: non_neg_integer | nil,
          item: Database.id() | nil
        }
  defstruct view: nil, section: nil, item: nil

  @doc "A file's path and its place from a `place` line's value; :error when it names no file."
  @spec parse(String.t()) :: {:ok, String.t(), t} | :error
  def parse(value) do
    # the fields come first and the path last, after "file:"; the fields
    # never hold " file:", so the first one found starts the path
    case Regex.split(~r/(?:^| )file:/, value, parts: 2) do
      [fields, path] when path != "" ->
        place =
          fields
          |> String.split(" ", trim: true)
          |> Enum.reduce(%__MODULE__{}, fn field, place ->
            case String.split(field, ":", parts: 2) do
              [key, number] -> put(place, key, Integer.parse(number))
              _ -> place
            end
          end)

        {:ok, path, place}

      _ ->
        :error
    end
  end

  # an unknown field or a value that is not a whole number is ignored
  defp put(place, "view", {id, ""}) when id > 0, do: %{place | view: id}
  defp put(place, "section", {index, ""}) when index >= 0, do: %{place | section: index}
  defp put(place, "item", {id, ""}) when id > 0, do: %{place | item: id}
  defp put(place, _key, _number), do: place

  @doc "The value of a `place` line for `path`."
  @spec format(String.t(), t) :: String.t()
  def format(path, %__MODULE__{} = place) do
    fields =
      for {key, value} <- [view: place.view, section: place.section, item: place.item],
          value != nil,
          do: "#{key}:#{value} "

    Enum.join(fields) <> "file:" <> path
  end
end
