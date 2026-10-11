defmodule Agenda.Preferences do
  @moduledoc """
  The person's preferences, for every file they open (ADR 0008): for now
  the Input format (`Agenda.Core.InputFormat`, R41b). Kept in a plain
  text file, one `key = value` per line, in the config directory
  (`$XDG_CONFIG_HOME/agenda/preferences` or
  `~/.config/agenda/preferences`). A setting left out is the date
  language's; unknown lines are ignored.

  `parse/1` and `format/1` are pure; `load/1` and `save/2` touch the disk
  (imperative shell, like `Agenda.Store`).
  """

  alias Agenda.Core.InputFormat

  @type t :: %__MODULE__{input: InputFormat.t()}
  defstruct input: %InputFormat{}

  @doc "Where the preferences file is, from the environment; nil without a home."
  @spec path(%{String.t() => String.t()}) :: String.t() | nil
  def path(env) do
    case env do
      %{"XDG_CONFIG_HOME" => dir} when dir != "" -> Path.join([dir, "agenda", "preferences"])
      %{"HOME" => home} when home != "" -> Path.join([home, ".config", "agenda", "preferences"])
      _ -> nil
    end
  end

  @doc "Reads preferences; a missing or unreadable file gives the defaults."
  @spec load(String.t()) :: t
  def load(path) do
    case File.read(path) do
      {:ok, text} -> parse(text)
      {:error, _} -> %__MODULE__{}
    end
  end

  @doc "Writes preferences, making the directory if needed."
  @spec save(t, String.t()) :: :ok | {:error, term}
  def save(prefs, path) do
    with :ok <- File.mkdir_p(Path.dirname(path)), do: File.write(path, format(prefs))
  end

  @doc "Preferences from the file's text."
  @spec parse(String.t()) :: t
  def parse(text) do
    input =
      text
      |> String.split("\n")
      |> Enum.map(&String.split(&1, "=", parts: 2))
      |> Enum.reduce(%InputFormat{}, fn
        [key, value], input -> put(input, String.trim(key), String.trim(value))
        _, input -> input
      end)

    %__MODULE__{input: input}
  end

  defp put(input, key, value) do
    case setting(key, value) do
      {:ok, field, value} -> Map.put(input, field, value)
      :error -> input
    end
  end

  @doc """
  One Input format setting from its key and text ("number_order", "dmy"),
  as the file and the command line write it.
  """
  @spec setting(String.t(), String.t()) :: {:ok, atom, term} | :error
  def setting("number_order", value) do
    case Enum.find(InputFormat.orders(), &(Atom.to_string(&1) == String.downcase(value))) do
      nil -> :error
      order -> {:ok, :number_order, order}
    end
  end

  def setting("date_separator", value) when value in ["/", "-", ".", ",", ":"],
    do: {:ok, :separator, value}

  def setting("clock", "12"), do: {:ok, :clock, 12}
  def setting("clock", "24"), do: {:ok, :clock, 24}
  def setting(_key, _value), do: :error

  @doc "The file's text."
  @spec format(t) :: String.t()
  def format(%__MODULE__{input: input}) do
    lines =
      [
        {"number_order", input.number_order && Atom.to_string(input.number_order)},
        {"date_separator", input.separator},
        {"clock", input.clock && Integer.to_string(input.clock)}
      ]
      |> Enum.reject(&(elem(&1, 1) == nil))
      |> Enum.map(fn {key, value} -> "#{key} = #{value}\n" end)

    "# Agenda preferences: yours, for every file. A setting left out is your\n" <>
      "# date language's. Number order: mdy myd dmy dym ydm ymd; date separator:\n" <>
      "# / - . , :; clock: 12 or 24.\n" <> Enum.join(lines)
  end
end
